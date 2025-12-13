// api/scan-inventory.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});


const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// 小工具：解析 JSON body（兼容 Vercel/Node 环境）
async function readBody(req) {
  if (req.body) return req.body; // 已经被解析过

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
  // ---- CORS ----
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader(
    "Access-Control-Allow-Methods",
    "GET,POST,OPTIONS"
  );
  res.setHeader(
    "Access-Control-Allow-Headers",
    "Content-Type, Authorization"
  );

  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }
  // ----------------

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const body = await readBody(req);
    const { imageBase64, mode } = body || {};

    if (!imageBase64 || typeof imageBase64 !== "string") {
      return res.status(400).json({ error: "imageBase64 is required" });
    }

    const scanMode =
      mode === "fridge" || mode === "shelf" ? "fridge" : "receipt";

    const prompt = `
You are a grocery inventory helper.

The user took a photo (mode = "${scanMode}").

If mode = "receipt":
- The image is a supermarket receipt.
- Extract each distinct product line that represents something the user took home.
- Ignore coupons, discounts, payment info, loyalty points, etc.

If mode = "fridge":
- The image is the inside of a fridge or shelf.
- Identify individual food items or packages that are reasonably visible.

For ALL cases, output a JSON object with this exact shape:

{
  "items": [
    {
      "name": "clear product name in English",
      "quantity": 1,
      "unit": "pcs | pack | kg | g | L | ml | box | tray | bottle | can",
      "location": "fridge | freezer | pantry",
      "purchasedDate": "YYYY-MM-DD",
      "predictedExpiry": "YYYY-MM-DD"
    },
    ...
  ]
}

Rules:
- location: 
  * Obvious frozen food (ice cream, frozen dumplings, frozen vegetables, etc.) -> "freezer".
  * Shelf-stable packaged goods (dry noodles, canned food, snacks) -> "pantry".
  * Others -> "fridge".
- purchasedDate:
  * For receipts: use the purchase date printed on the receipt.
    If absent/unclear, assume today's date in the user's timezone and still return ISO string.
  * For fridge photos: estimate a reasonable recent purchase date (e.g., within last 1–7 days)
    based on how "fresh" it likely is, but keep it realistic.
- predictedExpiry:
  * Give a conservative safe date (not more than 365 days after purchasedDate).
  * Fresh meat/fish, leafy greens, fresh fruit -> short times.
  * Frozen food can be much longer, but still <= 365 days.
  * Always format as "YYYY-MM-DD".

Return ONLY valid JSON. No extra commentary, no markdown.
`;

    const response = await client.responses.create({
      model: "gpt-4.1-mini",
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: prompt,
            },
            {
              type: "input_image",
              image_url: `data:image/jpeg;base64,${imageBase64}`,
            },
          ],
        },
      ],
      response_format: { type: "json_object" },
    });

    // 兼容新的 Responses 结构，安全地拿到文本
    let raw = "";
    const firstOutput = response.output?.[0];
    const firstContent = firstOutput?.content?.[0];
    if (firstContent?.type === "output_text") {
      const t = firstContent.text;
      if (typeof t === "string") {
        raw = t;
      } else if (t && typeof t.value === "string") {
        raw = t.value;
      }
    }

    if (!raw) {
      console.error("No text output from model:", JSON.stringify(response));
      return res.status(500).json({ error: "LLM returned empty output" });
    }

    let data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      console.error("JSON parse error:", e, raw);
      return res.status(500).json({ error: "LLM returned invalid JSON" });
    }

    const items = Array.isArray(data.items) ? data.items : [];
    // 轻微兜底，防止字段缺失
    const sanitized = items.map((it) => {
      const name = (it.name || "").toString().trim() || "Unnamed item";
      const quantity = Number(it.quantity) || 1;
      const unit = (it.unit || "pcs").toString();
      const location = (it.location || "fridge").toString();
      const purchasedDate = (it.purchasedDate || "").toString();
      const predictedExpiry = (it.predictedExpiry || "").toString();

      return {
        name,
        quantity,
        unit,
        location,
        purchasedDate,
        predictedExpiry,
      };
    });

    return res.status(200).json({ items: sanitized });
  } catch (err) {
    console.error("scan-inventory error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
