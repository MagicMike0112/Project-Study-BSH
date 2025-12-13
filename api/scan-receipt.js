// api/scan-inventory.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// PWA 域名
const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

//  JSON body
async function readBody(req) {
  if (req.headers["content-type"]?.includes("application/json")) {
    return req.body ?? {};
  }
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
  // ---- CORS ----
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }
  // 只允许 POST
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const body = await readBody(req);
    const { imageBase64, mode } = body || {};

    if (!imageBase64 || typeof imageBase64 !== "string") {
      return res.status(400).json({ error: "imageBase64 is required" });
    }

    const scanMode = mode === "receipt" ? "receipt" : "fridge";

    // ---- 构造多模态请求 ----
    const userContent = [
      {
        type: "input_text",
        text: `
You are a kitchen inventory assistant.

You will see a photo of either:
- a supermarket receipt (mode = "receipt"), OR
- items in a fridge / freezer / shelf (mode = "fridge").

Mode: "${scanMode}".

Your tasks:

1) **Detect individual food items** from the image.
2) For each item, decide:
   - name: short, normalized English name (e.g. "pork belly", "frozen fish sticks", "cola zero").
   - quantity: numeric quantity as a float (e.g. 1, 2, 0.5).
   - unit: short unit string, e.g. "pcs", "g", "kg", "ml", "L", "pack", "box".
   - location: one of ONLY "fridge", "freezer", "pantry".
     * Use "freezer" for anything clearly frozen:
       - words like "frozen", "deep-frozen", "ice cream", "fish sticks (frozen)",
         "tiefkühl", "TK", "冷冻", "-18°C", etc.
       - frozen dumplings, frozen vegetables, frozen meat, ice cream, etc.
     * Use "fridge" for chilled items: fresh meat, dairy, opened drinks, cut fruit, etc.
     * Use "pantry" for shelf-stable items: rice, pasta, canned food (unopened), snacks, etc.
   - purchasedDate: "YYYY-MM-DD"
     * If mode = "receipt": read the receipt date if possible.
     * If mode = "fridge": assume "today" as purchased date when unsure.
   - shelfLifeDays: INTEGER, estimated remaining safe shelf life in days,
     counted from the PURCHASE DATE.

Shelf life rules (be conservative, Europe household, normal fridge/freezer):
- In FREEZER:
  * frozen meat/fish: 60–180 days
  * ice cream: 30–90 days
  * frozen dumplings / vegetables: 60–180 days
  * never exceed 365 days
- In FRIDGE:
  * fresh leafy greens / salad: 2–5 days
  * fresh berries: 2–5 days
  * fresh meat/fish: 1–3 days
  * cooked leftovers: 2–4 days
  * opened canned fruit / sauces: 3–7 days
  * yogurt, milk, fresh cheese: 3–10 days
- In PANTRY:
  * rice, pasta, flour: 90–365 days
  * canned food (unopened): 180–365 days
  * snacks (chips, biscuits): 30–180 days
Always choose **shorter, safer** values when unsure.
Clamp shelfLifeDays to 1..365.

OUTPUT:
Return ONLY valid JSON of this shape:
{
  "items": [
    {
      "name": "string",
      "quantity": 1,
      "unit": "pcs",
      "location": "fridge",
      "purchasedDate": "2025-12-13",
      "shelfLifeDays": 7
    },
    ...
  ]
}
No extra text, no markdown.
        `.trim(),
      },
      {
        type: "input_image",
        image_url: `data:image/jpeg;base64,${imageBase64}`,
      },
    ];

    const response = await client.chat.completions.create({
      model: "gpt-4.1-mini", // 够用了，成本也低
      messages: [
        {
          role: "system",
          content:
            "You are a strict JSON API. Always respond with exactly one JSON object.",
        },
        {
          role: "user",
          content: userContent,
        },
      ],
      response_format: { type: "json_object" },
      max_output_tokens: 800,
    });

    const raw = response.choices?.[0]?.message?.content;
    if (!raw || typeof raw !== "string") {
      console.error("No text output from model", response);
      return res
        .status(500)
        .json({ error: "No text output from model", raw: response });
    }

    let data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      console.error("JSON parse error:", e, raw);
      return res.status(500).json({ error: "LLM returned invalid JSON" });
    }

    const now = new Date();

    const items = Array.isArray(data.items) ? data.items : [];

    const normalized = items.map((item) => {
      const name = String(item.name ?? "").trim() || "Unnamed item";

      let quantity = Number(item.quantity ?? 1);
      if (!Number.isFinite(quantity) || quantity <= 0) quantity = 1;

      let unit = String(item.unit ?? "pcs").trim() || "pcs";

      let locStr = String(item.location ?? "fridge").toLowerCase();
      if (locStr !== "fridge" && locStr !== "freezer" && locStr !== "pantry") {
        locStr = "fridge";
      }

      let purchasedDateStr = String(item.purchasedDate ?? "").trim();
      let purchasedDate = new Date(purchasedDateStr);
      if (isNaN(purchasedDate.getTime())) {
        purchasedDate = now;
      }

      // 从 shelfLifeDays 计算 predictedExpiry
      let shelfDays = parseInt(item.shelfLifeDays ?? item.days ?? 7, 10);
      if (!Number.isFinite(shelfDays) || shelfDays <= 0) shelfDays = 7;
      if (shelfDays > 365) shelfDays = 365;

      const predicted = new Date(
        purchasedDate.getTime() + shelfDays * 24 * 60 * 60 * 1000
      );

      return {
        name,
        quantity,
        unit,
        location: locStr, // 'fridge' | 'freezer' | 'pantry'
        purchasedDate: purchasedDate.toISOString().slice(0, 10),
        predictedExpiry: predicted.toISOString(),
        shelfLifeDays: shelfDays,
      };
    });

    return res.status(200).json({ items: normalized });
  } catch (err) {
    console.error("scan-inventory API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
