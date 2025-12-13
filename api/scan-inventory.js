// api/scan-inventory.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// 允许的前端域名（你的 PWA）
const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// --------- 工具：读取 JSON body（兼容本地 / Vercel） ----------
async function readBody(req) {
  if (req.body && typeof req.body === "object") {
    return req.body;
  }

  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => {
      data += chunk;
    });
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

// --------- 主 handler ----------
export default async function handler(req, res) {
  // CORS
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }

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

    // data URL 传给模型
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

Task:
- Look at the provided image (${scanMode} mode).
- Extract a list of food items.

For each item, you MUST provide:
- name: short English name, e.g. "glass noodles", "chicken thigh", "Greek yogurt"
- quantity: number
- unit: string (examples: "pcs", "pack", "box", "g", "kg", "ml", "L")
- storageLocation: "fridge" | "freezer" | "pantry"
- predictedExpiry: ISO 8601 datetime string, e.g. "2025-06-25T00:00:00.000Z"
- category: always "scan"
- confidence: a number between 0 and 1

Expiry rules:
- Be conservative but realistic.
- Fridge: usually days to a few weeks (leafy veg very short, sauces longer).
- Freezer: weeks to months, but NEVER exceed 365 days.
- Pantry: days to months depending on food, NEVER exceed 365 days.
- If purchaseDate is unknown, assume items were bought recently but still keep expiry realistic.

purchaseDate:
- If you can infer a common purchase date from the image (receipt header or printed date),
  set top-level "purchaseDate" to that date in "YYYY-MM-DD" format.
- Otherwise, set "purchaseDate" to empty string "".

Output format (VERY IMPORTANT):
Return ONLY a single JSON object:

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

Constraints:
- "items" must be an array (possibly empty).
- If you are unsure about quantity, set quantity = 1 and a generic unit such as "pcs" or "pack".
- If you really cannot detect anything useful, return "items": [].
`;

    // 使用 gpt-4.1-mini + chat.completions（支持图片 + JSON）
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
            {
              type: "image_url",
              image_url: {
                url: imageUrl,
              },
            },
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

    if (!Array.isArray(data.items)) {
      data.items = [];
    }

    // 兜底清洗一下，防止前端崩
    data.items = data.items.map((item) => ({
      name: item.name ?? "",
      quantity:
        typeof item.quantity === "number" && isFinite(item.quantity)
          ? item.quantity
          : 1,
      unit: item.unit || "pcs",
      storageLocation: ["fridge", "freezer", "pantry"].includes(
        item.storageLocation
      )
        ? item.storageLocation
        : "fridge",
      predictedExpiry: item.predictedExpiry || "",
      category: "scan",
      confidence:
        typeof item.confidence === "number" && isFinite(item.confidence)
          ? Math.max(0, Math.min(1, item.confidence))
          : 0.0,
    }));

    return res.status(200).json(data);
  } catch (err) {
    console.error("scan-inventory API error:", err);
    return res.status(500).json({
      error: err?.message || "Internal server error",
    });
  }
}
