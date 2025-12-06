// api/recipe.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// --------- 小工具：解析 request body（兼容 JSON / 纯文本） ----------
async function readBody(req) {
  if (req.headers["content-type"]?.includes("application/json")) {
    return req.body ?? {};
  }
  // Vercel/Node 有时 body 还在 stream 里
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

// ========= 分支 A：保质期预测 =========
async function handleExpiryPrediction(body, res) {
  const name = (body.name || "").toString().trim();
  const location = (body.location || "").toString().trim();
  const purchasedDate = (body.purchasedDate || "").toString().trim();

  if (!name || !location || !purchasedDate) {
    return res.status(400).json({
      error: "Missing required fields. name, location, purchasedDate are required.",
    });
  }

  // 为了简单先用 rule-based，之后你想换成纯 GPT 再改这里就行
  const baseDate = new Date(purchasedDate);
  if (isNaN(baseDate.getTime())) {
    return res.status(400).json({
      error: "Invalid purchasedDate format. Must be ISO string.",
    });
  }

  let days = 7;
  const locLower = location.toLowerCase();
  const nameLower = name.toLowerCase();

  if (locLower.includes("freezer")) {
    days = 90;
  } else if (locLower.includes("pantry") || locLower.includes("cupboard")) {
    days = 14;
  } else {
    // fridge
    if (nameLower.includes("yogurt") || nameLower.includes("milk")) {
      days = 5;
    } else if (nameLower.includes("meat") || nameLower.includes("chicken")) {
      days = 3;
    } else if (nameLower.includes("leaf") || nameLower.includes("salad")) {
      days = 3;
    } else {
      days = 7;
    }
  }

  const predicted = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);

  // ⚠️ 前端就是在找这个字段： predictedExpiry
  return res.status(200).json({
    predictedExpiry: predicted.toISOString(),
  });
}

// ========= 分支 B：生成菜谱 =========
async function handleRecipeGeneration(body, res) {
  const ingredients = Array.isArray(body.ingredients) ? body.ingredients : [];
  const extraIngredients = Array.isArray(body.extraIngredients)
    ? body.extraIngredients
    : [];

  if (ingredients.length === 0 && extraIngredients.length === 0) {
    return res.status(400).json({ error: "No ingredients provided" });
  }

  const all = [...ingredients, ...extraIngredients].join(", ");

  const prompt = `
You are a cooking assistant that helps people reduce food waste.
User has these ingredients (some are expiring soon): ${all}.

Create 3 recipe ideas that:
- Prioritize using the expiring ingredients first.
- Are simple, realistic home-cooking recipes.

For EACH recipe, return a JSON object with fields:
- id (string, short unique id)
- title (short dish name)
- timeLabel (string, e.g. "20 min · 1 pan")
- expiringCount (integer, rough estimate of how many expiring ingredients are used)
- ingredients (string[] - human readable ingredient lines)
- steps (string[] - 4-6 concise steps)
- description (string, 1-2 short sentences)

Return ONLY a JSON object of this shape:
{
  "recipes": [ { ... }, { ... }, { ... } ]
}
No extra commentary.
`;

  const response = await client.chat.completions.create({
    model: "gpt-4.1-mini",
    messages: [
      {
        role: "system",
        content:
          "You are a precise JSON API. Always respond with valid JSON only.",
      },
      {
        role: "user",
        content: prompt,
      },
    ],
    response_format: { type: "json_object" },
  });

  const raw = response.choices[0]?.message?.content ?? "";
  let data;
  try {
    data = JSON.parse(raw);
  } catch (e) {
    console.error("JSON parse error:", e, raw);
    return res.status(500).json({ error: "LLM returned invalid JSON" });
  }

  const recipes = Array.isArray(data.recipes) ? data.recipes : [];
  return res.status(200).json({ recipes });
}

// ========= 主入口 =========
export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const body = await readBody(req);

    // 分支选择逻辑：
    // 只要前端传了 name/location/purchasedDate，就走“保质期预测”
    const hasExpiryPayload =
      typeof body?.name !== "undefined" &&
      typeof body?.location !== "undefined" &&
      typeof body?.purchasedDate !== "undefined";

    if (hasExpiryPayload) {
      return await handleExpiryPrediction(body, res);
    }

    // 否则当成菜谱生成
    return await handleRecipeGeneration(body, res);
  } catch (err) {
    console.error("API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
