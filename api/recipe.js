// api/recipe.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// 允许的前端域名（你的 PWA 域名）
const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// --------- 小工具：解析 request body（兼容 JSON / 纯文本） ----------
async function readBody(req) {
  if (req.headers["content-type"]?.includes("application/json")) {
    // 在 Vercel/Node 里，如果用了 body parser，中间件可能已经把 body 挂在 req.body 上
    return req.body ?? {};
  }

  // 否则从 stream 自己读
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

// ========= 分支 A：保质期预测（AI 版） =========
async function handleExpiryPrediction(body, res) {
  const name = (body.name || "").toString().trim();
  const location = (body.location || "").toString().trim();
  const purchasedDate = (body.purchasedDate || "").toString().trim();

  if (!name || !location || !purchasedDate) {
    return res.status(400).json({
      error:
        "Missing required fields. name, location, purchasedDate are required.",
    });
  }

  const baseDate = new Date(purchasedDate);
  if (isNaN(baseDate.getTime())) {
    return res.status(400).json({
      error: "Invalid purchasedDate format. Must be ISO string.",
    });
  }

  const prompt = `
You are a food shelf-life safety assistant.
Your task is to ESTIMATE a safe remaining shelf life in DAYS for a food item,
based on its product name, storage location, and purchase date.

User input:
- product name: "${name}"
- storage location: "${location}"
- purchase date: "${purchasedDate}"

Assumptions:
- The user is an ordinary household in Europe, with a normal domestic fridge/freezer.
- If the product is canned, jarred, pickled or fermented (e.g. kimchi, pickles, canned peaches),
  assume it has ALREADY BEEN OPENED.
- You must be conservative: when unsure, choose a SHORTER, safer time.
- Consider:
  * Fresh fruit like apples, berries, bananas, grapes.
  * Leafy greens and salads.
  * Meat, fish, poultry.
  * Dairy products (milk, yogurt, cheese).
  * Cooked leftovers.
  * Canned or jarred fruit (e.g. canned peaches).
  * Fermented/pickled foods (e.g. kimchi, sauerkraut, pickles).
  * Pantry vs fridge vs freezer:
    - Freezer >> Fridge >> Pantry in shelf life.
- In the FRIDGE:
  * Fresh leafy greens and salads: usually only a few days.
  * Fresh berries: very short (2–5 days).
  * Whole apples: longer than most fruits (e.g. 7–21 days).
  * Opened canned fruit (e.g. canned peaches once opened): roughly 3–7 days.
  * Fermented foods like kimchi or pickles: can last weeks, but still cap it within about 30–60 days.
- In the FREEZER:
  * You may give clearly longer times (e.g. 30–180 days), but not more than 365 days.

Output format (IMPORTANT):
Return ONLY a JSON object, with NO extra text, exactly like this:
{
  "days": <integer, number of days from PURCHASE date>
}

Constraints:
- "days" must be a positive integer.
- If you are very unsure, choose a smaller number of days.
- NEVER exceed 365 days.
`;

  const response = await client.chat.completions.create({
    model: "gpt-4.1-mini",
    messages: [
      {
        role: "system",
        content:
          "You are a precise JSON API. Always respond with valid JSON only.",
      },
      { role: "user", content: prompt },
    ],
    response_format: { type: "json_object" },
  });

  const raw = response.choices[0]?.message?.content ?? "";
  let data;
  try {
    data = JSON.parse(raw);
  } catch (e) {
    console.error("expiry JSON parse error:", e, raw);
    return res.status(500).json({ error: "LLM returned invalid JSON" });
  }

  let days = Number.parseInt(data.days, 10);
  if (!Number.isFinite(days) || days <= 0) {
    days = 7; // fallback
  }
  if (days > 365) {
    days = 365;
  }

  const predicted = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);

  return res.status(200).json({
    predictedExpiry: predicted.toISOString(),
    days,
  });
}

// ========= 分支 B：生成菜谱（支持 specialRequest） =========
async function handleRecipeGeneration(body, res) {
  const ingredients = Array.isArray(body.ingredients) ? body.ingredients : [];
  const extraIngredients = Array.isArray(body.extraIngredients)
    ? body.extraIngredients
    : [];

  // 新增：特殊要求 / 约束，例如 "Chinese, vegan, spicy", "vegan, no nuts" 等
  const specialRequest =
    typeof body.specialRequest === "string"
      ? body.specialRequest.trim()
      : "";

  const allList = [...ingredients, ...extraIngredients];

  if (allList.length === 0) {
    return res.status(400).json({ error: "No ingredients provided" });
  }

  const all = allList.join(", ");

  const preferenceBlock = specialRequest
    ? `
User preferences / constraints:
- ${specialRequest}

Respect these constraints as much as reasonably possible:
- Match the desired cuisine style if mentioned (e.g. Chinese, Italian, Mexican).
- If dietary constraints are given (e.g. vegan, vegetarian, no pork, no nuts, gluten-free),
  DO NOT use forbidden ingredients.
`
    : `
User did not specify extra constraints.
Keep recipes generic, but still realistic for a European home kitchen.
`;

  const prompt = `
You are a cooking assistant that helps people reduce food waste.

The user has the following available ingredients (this is their pantry for today):
${all}

${preferenceBlock}

Your job:
- Propose 3 different recipes (they can be main dishes, side dishes, soups, etc.).
- You DO NOT need to use all ingredients in every recipe.
- Treat the ingredients list as a pantry:
  * Distribute the ingredients across the recipes.
  * It is OK if some ingredients are used in only 1 recipe or in multiple recipes.
  * It is OK if a few ingredients remain unused, as long as you prioritize using
    the most perishable or expiring ones.
- Prioritize using ingredients that are likely to expire sooner (leafy greens, fresh fruit,
  fresh meat/fish, dairy, cooked leftovers, etc.), especially in at least one recipe.
- Keep recipes realistic for a home kitchen and not too long or complex.

For EACH recipe, return a JSON object with fields:
- id (string, short unique id, e.g. "r1", "r2", "r3")
- title (short dish name)
- timeLabel (string, e.g. "20 min · 1 pan")
- expiringCount (integer, rough estimate of how many perishable / expiring ingredients are used)
- ingredients (string[] - human readable ingredient lines, listing only what is actually used in THIS recipe)
- steps (string[] - 4–6 concise steps)
- description (string, 1–2 short sentences; mention if it focuses on using expiring items or respects the dietary constraint)

Return ONLY a JSON object of this shape:
{
  "recipes": [ { ... }, { ... }, { ... } ]
}
No extra commentary, no markdown, only JSON.
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
  // ---- CORS：允许 PWA 域名访问 ----
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  // 处理预检请求
  if (req.method === "OPTIONS") {
    return res.status(204).end();
  }
  // ---------------------------------

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const body = await readBody(req);

    // 只要有 name/location/purchasedDate，就走保质期预测
    const hasExpiryPayload =
      typeof body?.name !== "undefined" &&
      typeof body?.location !== "undefined" &&
      typeof body?.purchasedDate !== "undefined";

    if (hasExpiryPayload) {
      return await handleExpiryPrediction(body, res);
    }

    // 否则走菜谱生成
    return await handleRecipeGeneration(body, res);
  } catch (err) {
    console.error("API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
