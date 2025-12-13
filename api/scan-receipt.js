// api/scan-receipt.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// 和 recipe.js 保持一致
const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// 读 body（兼容 vercel 的 req.body 和原始流）
async function readBody(req) {
  if (req.body) return req.body;

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

    const imageBase64 = body.imageBase64;
    const mode = (body.mode || "receipt").toString(); // "receipt" | "fridge"

    if (!imageBase64 || typeof imageBase64 !== "string") {
      return res.status(400).json({ error: "imageBase64 is required" });
    }

    // prompt：告诉模型我们要什么结构
    const modeText =
      mode === "fridge"
        ? "The photo is of food items in a fridge or on shelves."
        : "The photo is a supermarket or grocery receipt.";

    const prompt = `
You are a JSON-only API that extracts a household food inventory from an image.

${modeText}

Your job:
1. Extract individual food items from the image.
2. For each food item, decide:
   - a sensible quantity and unit
   - the best default storage location for a European household:
     * "fridge"
     * "freezer"
     * "pantry"
   - a coarse food category (e.g. "dairy", "meat", "vegetable", "fruit",
     "frozen", "snack", "condiment", "grain", "bread", "other").
   - a confidence score between 0 and 1.

3. For receipts:
   - If a clear purchase date is printed on the receipt, parse it as ISO string.
   - Otherwise leave "purchaseDate" as null (frontend will default to today).

4. For fridge / shelf photos:
   - Assume "purchaseDate" is null. The frontend will default to today.

Output format (IMPORTANT):
Return ONLY a JSON object like this, with no extra text:

{
  "purchaseDate": "2025-01-01T00:00:00.000Z" | null,
  "items": [
    {
      "name": "Milk 3.5%",
      "quantity": 1,
      "unit": "L",
      "storageLocation": "fridge",
      "category": "dairy",
      "confidence": 0.9
    }
  ]
}

Constraints:
- "purchaseDate" must be either a valid ISO string (if you are confident)
  or null if not clearly visible.
- "items" must be an array (can be empty).
- "quantity" must be a positive number (use 1 as default if you are not sure).
- "unit" must be a short string like "pcs", "kg", "g", "L", "ml", "pack", "box".
- "storageLocation" must be exactly one of: "fridge", "freezer", "pantry".
- "confidence" between 0 and 1.
- If you are unsure about some item, you may still include it but with low confidence.
`;

    const response = await client.chat.completions.create({
      model: "gpt-4.1-mini", // ✅ 保持和 recipe.js 一样的模型即可
      messages: [
        {
          role: "system",
          content:
            "You are a precise JSON API. Always respond with valid JSON only.",
        },
        {
          role: "user",
          // vision 消息需要 text + image 两段 content
          content: [
            {
              type: "text",
              text: prompt,
            },
            {
              type: "input_image",
              image_url: {
                // 假设前端传的是纯 base64，不带 data: 前缀
                url: `data:image/jpeg;base64,${imageBase64}`,
              },
            },
          ],
        },
      ],
      response_format: { type: "json_object" },
    });

    const raw = response.choices[0]?.message?.content ?? "";
    let data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      console.error("scan-receipt JSON parse error:", e, raw);
      return res.status(500).json({ error: "LLM returned invalid JSON" });
    }

    // 保险起见做一点简单兜底
    if (!data || typeof data !== "object") {
      return res.status(500).json({ error: "Invalid JSON structure" });
    }

    if (!Array.isArray(data.items)) {
      data.items = [];
    }

    // purchaseDate 允许 null 或 string，其余交给前端
    return res.status(200).json({
      purchaseDate:
        typeof data.purchaseDate === "string" ? data.purchaseDate : null,
      items: data.items,
    });
  } catch (err) {
    console.error("scan-receipt API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
