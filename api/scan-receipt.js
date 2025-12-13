// /api/scan-receipt.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// 允许的前端域名
const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// --------- 小工具 ---------
async function readBody(req) {
  if (req.body) return req.body; // Vercel 可能已经 parse 好了

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

function safeJsonParse(str) {
  try {
    return JSON.parse(str);
  } catch {
    return null;
  }
}

// --------- main handler ---------
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

  if (!process.env.OPENAI_API_KEY) {
    // 这个错误会直接在前端看到，方便你排查
    return res.status(500).json({ error: "OPENAI_API_KEY is missing" });
  }

  try {
    const body = await readBody(req);

    const rawBase64 = body?.imageBase64;
    const kind =
      body?.kind === "receipt" || body?.kind === "fridge"
        ? body.kind
        : "fridge";

    if (!rawBase64 || typeof rawBase64 !== "string") {
      return res
        .status(400)
        .json({ error: "imageBase64 is required in request body" });
    }

    // 兼容带 data: 前缀 / 不带前缀的情况
    const cleanBase64 = rawBase64.replace(
      /^data:image\/[a-zA-Z0-9+.-]+;base64,/,
      ""
    );

    if (!cleanBase64.trim()) {
      return res.status(400).json({ error: "imageBase64 is empty" });
    }

    const dataUrl = `data:image/jpeg;base64,${cleanBase64}`;

    const modeDescription =
      kind === "receipt"
        ? "a supermarket grocery receipt"
        : "a fridge / pantry shelf with stored food";

    const systemPrompt = `
You are an assistant that extracts grocery inventory from images.

You must ALWAYS respond with a JSON object of the following shape:

{
  "items": [
    {
      "name": "string - food name in English, short but clear",
      "quantity": number,             // e.g. 1, 2, 0.5
      "unit": "string",               // e.g. "pcs", "kg", "g", "L", "ml", "pack"
      "location": "fridge|freezer|pantry",
      "purchasedDate": "YYYY-MM-DD"   // best guess, never empty
    }
  ]
}

Rules:
- If the image is a RECEIPT, infer the purchase date from the receipt (printed date).
  If not visible, assume TODAY (in the user's local time).
- If the image is a FRIDGE / SHELF:
  * Assume the purchase date is TODAY for most items, unless the image clearly shows leftovers or opened packages.
  * For cooked leftovers or clearly old items you may approximate an earlier purchase date,
    but keep it within the last 7 days.
- location:
  * Items currently on a fridge shelf -> "fridge".
  * Items obviously frozen or in freezer drawers -> "freezer".
  * Dry goods in cupboard/shelf -> "pantry".
- Only include food items or drinks that can be stored.
- Do NOT add commentary, only the JSON.
`;

    const userPrompt = `
The user uploaded ${modeDescription}.
Extract all clearly visible or listed food items, infer sensible units and quantities, and assign a storage location and purchase date.
`;

    // 使用 Responses API + vision
    const response = await client.responses.create({
      model: "gpt-4.1-mini",
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: systemPrompt + "\n\n" + userPrompt,
            },
            {
              type: "input_image",
              image_url: dataUrl,
              detail: "low",
            },
          ],
        },
      ],
      // 只要 text 输出
      max_output_tokens: 800,
    });

    // 按照官方结构取出文本
    const firstOutput = response.output?.[0];
    const firstContent = firstOutput?.content?.[0];

    let textValue;

    // 兼容两种结构：
    // 1) content[0].text 是 string（你现在就是这种）
    // 2) content[0].text.value 是 string（某些示例里是这种）
    if (typeof firstContent?.text === "string") {
      textValue = firstContent.text;
    } else if (
      firstContent?.text &&
      typeof firstContent.text.value === "string"
    ) {
      textValue = firstContent.text.value;
    }

    if (!textValue || !textValue.trim()) {
      console.error("No text in response.output:", JSON.stringify(response));
      return res.status(500).json({
        error: "No text output from model",
        raw: response,
      });
    }


    const json = safeJsonParse(textValue);
    if (!json || !Array.isArray(json.items)) {
      console.error("Model output is not valid JSON:", textValue);
      return res.status(500).json({
        error: "Model returned invalid JSON",
        rawText: textValue,
      });
    }

    return res.status(200).json(json);
  } catch (err) {
    console.error("scan-receipt API error:", err);
    return res.status(500).json({
      error: "Internal server error",
      message: err?.message ?? String(err),
    });
  }
}
