// api/scan-inventory.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// ---------- 通用：读取 JSON body ----------
async function readBody(req) {
  if (req.body && typeof req.body === "object") return req.body;

  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => (data += chunk));
    req.on("end", () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });
}

export default async function handler(req, res) {
  // CORS
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const body = await readBody(req);
    const imageBase64 = (body.imageBase64 || "").toString().trim();
    const modeRaw = (body.mode || "receipt").toString().trim();

    if (!imageBase64) {
      return res.status(400).json({ error: "imageBase64 is required" });
    }

    const scanMode = modeRaw === "fridge" ? "fridge" : "receipt";
    const imageUrl = `data:image/jpeg;base64,${imageBase64}`;

    const modeExplanation =
      scanMode === "receipt"
        ? `The image is a supermarket receipt.
You should:
- Read all relevant food / grocery items.
- Infer a common purchase date if possible (from the receipt).
  If you really cannot, set purchaseDate to empty string "" (frontend will use today).
- For each item, suggest a storageLocation: "fridge", "freezer", or "pantry".
- Infer a reasonable quantity and unit if visible (e.g. "500 g", "2 packs", "1 bottle").`
        : `The image shows items inside a fridge/freezer or on a shelf.
You should:
- Detect each distinct food item you can clearly see.
- Decide a realistic storageLocation:
    * Frozen-looking items / in freezer drawers -> "freezer"
    * Drinks, dairy, fresh veg, leftovers -> "fridge"
    * Dry goods on shelf (rice, pasta, cans, snacks) -> "pantry"
- In fridge mode, purchase date is usually unknown:
    * In that case, set purchaseDate to empty string "" so frontend can fall back to today.
- Infer rough quantity + unit (1 pack, 250 g, 1 bottle, etc.).`;

    const prompt = `
You are a food-inventory JSON API.

${modeExplanation}

For each detected item, you MUST provide:
- name: short English name, e.g. "glass noodles", "chicken thigh", "Greek yogurt"
- quantity: number
- unit: string (examples: "pcs", "pack", "box", "g", "kg", "ml", "L")
- storageLocation: "fridge" | "freezer" | "pantry"
- predictedExpiry: ISO 8601 datetime string, e.g. "2025-06-25T00:00:00.000Z"
- category: always "scan"
- confidence: a number between 0 and 1

Expiry rules (very important):
- predictedExpiry MUST be **on or after today**, never in the past.
- If a purchase date is available, predictedExpiry MUST be **on or after the purchase date**.
- Fridge: usually days to a few weeks (leafy veg very short, sauces longer).
- Freezer: weeks to months, but NEVER exceed 365 days from today.
- Pantry: days to months depending on food, NEVER exceed 365 days from today.
- Be conservative but realistic, do not output dates many years in the future.

purchaseDate:
- If you can infer a common purchase date from the image (e.g. a printed date on the receipt),
  set top-level "purchaseDate" to that date in "YYYY-MM-DD" format.
- Otherwise, set "purchaseDate" to empty string "".

Output format (STRICT):
Return ONLY this JSON shape:

{
  "purchaseDate": "YYYY-MM-DD or empty string",
  "items": [
    {
      "name": "string",
      "quantity": number,
      "unit": "string",
      "storageLocation": "fridge" | "freezer" | "pantry",
      "predictedExpiry": "ISO-8601 datetime string",
      "category": "scan",
      "confidence": 0.0-1.0
    },
    ...
  ]
}

No extra text, no markdown.
`;

    const completion = await client.chat.completions.create({
      model: "gpt-4.1-mini",
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content:
            "You are a precise JSON API. Always respond with valid JSON only, no explanations.",
        },
        {
          role: "user",
          content: [
            { type: "text", text: prompt },
            { type: "image_url", image_url: { url: imageUrl } },
          ],
        },
      ],
    });

    const raw = completion.choices?.[0]?.message?.content ?? "";
    let data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      console.error("scan-inventory JSON parse error:", e, raw);
      return res
        .status(500)
        .json({ error: "Failed to parse JSON from model output" });
    }

    if (!data || typeof data !== "object") {
      return res.status(500).json({ error: "Model returned invalid structure" });
    }

    if (!Array.isArray(data.items)) data.items = [];

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    let purchaseDate = null;
    if (typeof data.purchaseDate === "string" && data.purchaseDate.trim()) {
      const d = new Date(data.purchaseDate.trim());
      if (!isNaN(d.getTime())) {
        d.setHours(0, 0, 0, 0);
        purchaseDate = d;
      }
    }

    const msPerDay = 24 * 60 * 60 * 1000;
    const defaultDaysByLoc = {
      fridge: 5,
      freezer: 90,
      pantry: 30,
    };

    data.items = data.items.map((item) => {
      const loc = ["fridge", "freezer", "pantry"].includes(
        item.storageLocation
      )
        ? item.storageLocation
        : "fridge";

      // 解析模型给的 predictedExpiry
      let predicted = null;
      if (typeof item.predictedExpiry === "string" && item.predictedExpiry) {
        const d = new Date(item.predictedExpiry);
        if (!isNaN(d.getTime())) predicted = d;
      }

      // base = purchaseDate(如果有) 否则 today
      const base = purchaseDate || today;
      const max = new Date(today.getTime() + 365 * msPerDay);
      const defaultDays = defaultDaysByLoc[loc] ?? 7;

      // 如果模型给的日期无效 / 早于 purchase / 早于 today / 超过 365 天，就重算
      if (
        !predicted ||
        predicted.getTime() < base.getTime() ||
        predicted.getTime() < today.getTime() ||
        predicted.getTime() > max.getTime()
      ) {
        predicted = new Date(base.getTime() + defaultDays * msPerDay);
      }

      predicted.setHours(0, 0, 0, 0);

      return {
        name: item.name ?? "",
        quantity:
          typeof item.quantity === "number" && isFinite(item.quantity)
            ? item.quantity
            : 1,
        unit: item.unit || "pcs",
        storageLocation: loc,
        predictedExpiry: predicted.toISOString(),
        category: "scan",
        confidence:
          typeof item.confidence === "number" && isFinite(item.confidence)
            ? Math.max(0, Math.min(1, item.confidence))
            : 0.0,
      };
    });

    return res.status(200).json({
      purchaseDate: purchaseDate
        ? purchaseDate.toISOString().slice(0, 10)
        : "",
      items: data.items,
    });
  } catch (err) {
    console.error("scan-inventory API error:", err);
    return res.status(500).json({
      error: err?.message || "Internal server error",
    });
  }
}
