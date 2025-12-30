import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// 允许的前端域名
const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// ---------- 工具函数 ----------

// 读取请求体
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

// 简单的 CORS 设置
function setCors(res) {
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

// ---------- 主处理逻辑 ----------

export default async function handler(req, res) {
  setCors(res);

  // 处理预检请求
  if (req.method === "OPTIONS") return res.status(204).end();
  
  // 只允许 POST
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    if (!process.env.OPENAI_API_KEY) {
      return res.status(500).json({ error: "Missing OPENAI_API_KEY" });
    }

    const body = await readBody(req);
    const text = (body.text || "").trim();

    if (!text || text.length < 2) {
      return res.status(400).json({ error: "Text is too short" });
    }

    // 定义系统提示词，指导 AI 如何提取数据
    const systemPrompt = `
You are a smart kitchen assistant.
Your goal is to parse user input (text or voice transcript) into structured food inventory data.

**Output Schema (JSON Only):**
{
  "name": string,           // Food name (e.g., "Milk", "Chicken Breast")
  "quantity": number,       // Numeric amount (e.g., 1, 0.5, 500)
  "unit": string,           // Unit (standardized)
  "storageLocation": string // "fridge", "freezer", or "pantry"
}

**Rules:**
1. **Quantity**: If missing, default to 1. Extract numbers efficiently.
2. **Unit**: Normalize to one of: ["pcs", "kg", "g", "L", "ml", "pack", "box", "cup"].
   - If unit is implied (e.g. "3 apples"), use "pcs".
   - If unit is "liters", use "L".
3. **Storage Location**:
   - If user specifies (e.g. "put in freezer"), use that.
   - If NOT specified, INFER based on the item type:
     - Frozen items (ice cream, frozen peas) -> "freezer"
     - Dry goods (rice, pasta, cans) -> "pantry"
     - Fresh/Perishable (milk, meat, vegetables) -> "fridge"
4. **Name**: Keep it clean and concise.

**Examples:**
- Input: "Bought 500g of ground beef" -> {"name": "Ground Beef", "quantity": 500, "unit": "g", "storageLocation": "fridge"}
- Input: "Ice cream in the freezer" -> {"name": "Ice Cream", "quantity": 1, "unit": "pcs", "storageLocation": "freezer"}
- Input: "3 bags of rice" -> {"name": "Rice", "quantity": 3, "unit": "pack", "storageLocation": "pantry"}
`;

    // 调用 OpenAI
    const response = await client.chat.completions.create({
      model: "gpt-4o-mini", // 使用 mini 模型速度快且足够聪明
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: text },
      ],
      response_format: { type: "json_object" },
      temperature: 0.1, // 低温度以保证输出格式稳定
      max_tokens: 200,
    });

    const content = response.choices[0]?.message?.content;
    if (!content) {
      throw new Error("No response from AI");
    }

    // 解析 JSON
    let result;
    try {
      result = JSON.parse(content);
    } catch (e) {
      // 简单的容错处理
      console.error("JSON Parse Error:", content);
      return res.status(500).json({ error: "Failed to parse AI response" });
    }

    // 返回结果
    return res.status(200).json(result);

  } catch (err) {
    console.error("parse-ingredient API error:", err);
    return res.status(500).json({ error: err.message || "Internal server error" });
  }
}