// api/parse-ingredient.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// ---------- 工具函数 ----------

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

function setCors(res) {
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

// ---------- 提示词生成器 (已升级) ----------

function getSystemPrompt(isListMode) {
  const commonRules = `
1. **Quantity**: If missing, default to 1. Extract numbers efficiently.
2. **Unit**: Normalize to one of: ["pcs", "kg", "g", "L", "ml", "pack", "box", "cup"].
   - If unit is implied (e.g. "3 apples"), use "pcs".
   - If unit is "liters", use "L".
3. **Storage Location**:
   - If user specifies (e.g. "put in freezer"), use that.
   - If NOT specified, INFER based on the 'genericName':
     - Frozen items -> "freezer"
     - Dry goods / Canned -> "pantry"
     - Fresh/Perishable -> "fridge"
4. **Name Extraction (CRITICAL)**:
   - "name": The user's specific input (e.g. "Lays Chips", "Organic Milk").
   - "genericName": The standardized ingredient type (e.g. "Potato Chips", "Milk"). 
     - **NO** general terms like "Snack", "Food", "Groceries". Be specific.
5. **Expiry Prediction**: intelligently ESTIMATE a "predictedExpiry" date (ISO 8601 format: YYYY-MM-DD) based on the 'genericName' and today's date (assume today is ${new Date().toISOString().split('T')[0]}).
   - Raw Meat/Fish: +2 days
   - Leftovers/Cooked: +3 days
   - Berries/Soft Fruit: +4 days
   - Milk: +7 days
   - Leafy Veg: +5 days
   - Yogurt/Cheese: +14 days
   - Eggs: +30 days
   - Frozen items: +90 days
   - Pantry (Chips, Canned, Rice): +365 days
`;

  if (isListMode) {
    return `
You are a smart kitchen assistant.
Parse user input into a LIST of structured food inventory items.

**Output Schema (JSON Only):**
{
  "items": [
    {
      "name": string,         // Specific text user said
      "genericName": string,  // Standardized category/ingredient name
      "quantity": number,
      "unit": string,
      "storageLocation": "fridge" | "freezer" | "pantry",
      "predictedExpiry": string // YYYY-MM-DD
    }
  ]
}

**Rules:**
${commonRules}

**Examples:**
- Input: "Bought 3 packs of Lays and 2 bottles of organic milk" 
  -> { "items": [
        {"name": "Lays", "genericName": "Potato Chips", "quantity": 3, "unit": "pack", "storageLocation": "pantry", "predictedExpiry": "2026-02-05"},
        {"name": "Organic Milk", "genericName": "Milk", "quantity": 2, "unit": "bottle", "storageLocation": "fridge", "predictedExpiry": "2025-02-14"}
      ]}
`;
  } else {
    // 单品模式
    return `
You are a smart kitchen assistant.
Parse user input into a SINGLE structured food inventory item.

**Output Schema (JSON Only):**
{
  "name": string,
  "genericName": string,
  "quantity": number,
  "unit": string,
  "storageLocation": "fridge" | "freezer" | "pantry",
  "predictedExpiry": string // YYYY-MM-DD
}

**Rules:**
${commonRules}
`;
  }
}

// ---------- 主处理逻辑 ----------

export default async function handler(req, res) {
  setCors(res);

  if (req.method === "OPTIONS") return res.status(204).end();
  
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    if (!process.env.OPENAI_API_KEY) {
      return res.status(500).json({ error: "Missing OPENAI_API_KEY" });
    }

    const body = await readBody(req);
    const text = (body.text || "").trim();
    // 🟢 获取前端传来的标志
    const expectList = body.expectList === true;

    if (!text || text.length < 2) {
      return res.status(400).json({ error: "Text is too short" });
    }

    // 🟢 根据模式选择提示词
    const systemPrompt = getSystemPrompt(expectList);

    const response = await client.chat.completions.create({
      model: "gpt-4o-mini", 
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: text },
      ],
      response_format: { type: "json_object" },
      temperature: 0.1,
      max_tokens: 500, // 稍微调大一点，以防列表很长
    });

    const content = response.choices[0]?.message?.content;
    if (!content) {
      throw new Error("No response from AI");
    }

    let result;
    try {
      result = JSON.parse(content);
    } catch (e) {
      console.error("JSON Parse Error:", content);
      return res.status(500).json({ error: "Failed to parse AI response" });
    }

    return res.status(200).json(result);

  } catch (err) {
    console.error("parse-ingredient API error:", err);
    return res.status(500).json({ error: err.message || "Internal server error" });
  }
}