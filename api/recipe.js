// api/recipe.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const IMAGE_GEN_VERSION = "imggen_v3_no_response_format";

// 允许的前端域名（你的 PWA 域名）
const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// --------- 小工具：解析 request body（兼容 JSON / 纯文本） ----------
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

// ========= 分支 A：保质期预测 (Expiry Prediction - 优化版) =========
async function handleExpiryPrediction(body, res) {
  const name = (body.name || "").toString().trim();
  const location = (body.location || "").toString().trim();
  const purchasedDate = (body.purchasedDate || "").toString().trim();
  const openDate = (body.openDate || "").toString().trim();

  if (!name || !location || !purchasedDate) {
    return res.status(400).json({
      error:
        "Missing required fields. name, location, purchasedDate are required.",
    });
  }

  const purchased = new Date(purchasedDate);
  if (isNaN(purchased.getTime())) {
    return res.status(400).json({
      error: "Invalid purchasedDate format. Must be ISO string.",
    });
  }

  let baseDate = purchased;
  let baseDateLabel = "purchase date";

  if (openDate) {
    const opened = new Date(openDate);
    if (!isNaN(opened.getTime())) {
      baseDate = opened;
      baseDateLabel = "open date";
    }
  }

  // 🟢 优化后的 Prompt：增加上下文消歧义和安全原则
  const prompt = `
You are a strict food safety assistant.
Your task is to ESTIMATE a safe remaining shelf life in DAYS for a food item.

User Input:
- Product Name: "${name}"
- Storage Location: "${location}"
- Purchase Date: "${purchasedDate}"
- Open Date: "${openDate || "N/A"}"

CRITICAL LOGIC FOR ACCURACY:
1. **Disambiguation via Location (Context Awareness)**:
   Many food names are ambiguous. You MUST check the 'Storage Location' to decide what the item is.
   - Example: "Paprika" in **Fridge** = Fresh Bell Pepper (Max 1-2 weeks).
   - Example: "Paprika" in **Pantry** = Dried Spice Powder (1-2 years).
   - Example: "Milk" in **Fridge** = Fresh Milk (1 week). "Milk" in **Pantry** = UHT/Powder (Months).

2. **Safety First Principle**:
   - If the product could be either fresh (perishable) or dried (stable), and the location is unclear or ambiguous, **ALWAYS assume it is the FRESH/PERISHABLE version**.
   - It is better to predict a shorter date (safety) than a longer one (risk of food poisoning).

3. **Fresh Produce Rules**:
   - Fresh vegetables/fruits in a fridge typically last **3 to 14 days**. NEVER predict months for fresh produce unless frozen.

4. **Opened Status**:
   - If 'Open Date' is provided, ignore the standard shelf life and use the "after opening" limit (e.g., jarred sauce lasts 3-5 days after opening, even if expiry is next year).

Output format:
Return ONLY a JSON object: { "days": <integer> }
Constraints:
- "days" is counted FROM the ${baseDateLabel}.
`;

  const response = await client.chat.completions.create({
    model: "gpt-4o-mini", 
    messages: [
      {
        role: "system",
        content: "You are a precise JSON API. Always respond with valid JSON only.",
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
  if (!Number.isFinite(days) || days <= 0) days = 7; // 默认保底
  // 移除强制的 365 天上限，因为如果真的是干货（如判定为调料），确实可能超过一年，但在 Prompt 里已经做了鲜货的限制。
  // 仍然保留一个合理的上限防止数据溢出
  if (days > 730) days = 730; 

  const predictedExpiry = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);

  return res.status(200).json({
    predictedExpiry: predictedExpiry.toISOString(),
    days,
    referenceDate: baseDate.toISOString(),
    referenceType: baseDateLabel,
  });
}

function clampInt(n, min, max, fallback) {
  const x = Number.parseInt(n, 10);
  if (!Number.isFinite(x)) return fallback;
  return Math.max(min, Math.min(max, x));
}

function normalizeTools(tools) {
  const allowed = new Set([
    "oven",
    "pan",
    "pot",
    "knife",
    "microwave",
    "airfryer",
    "blender",
    "ricecooker",
  ]);

  const arr = Array.isArray(tools) ? tools : [];
  const out = [];
  for (const t of arr) {
    const s = String(t || "").trim().toLowerCase();
    if (allowed.has(s) && !out.includes(s)) out.push(s);
  }
  return out;
}

async function generateRecipeImage(title, ingredients) {
  const model = process.env.OPENAI_IMAGE_MODEL || "gpt-image-1";
  const rawSize = process.env.OPENAI_IMAGE_SIZE || "auto";
  const size = rawSize === "512x512" ? "auto" : rawSize;
  const rawQuality = process.env.OPENAI_IMAGE_QUALITY || "auto";
  const quality = rawQuality === "standard" ? "auto" : rawQuality;
  const prompt = `A clean, appetizing food photo of "${title}", soft natural light, top-down, minimal background. Ingredients: ${ingredients.join(", " )}.`;

  try {
    const resp = await client.images.generate({
      model,
      prompt,
      size,
      quality,
    });

    const b64 = resp?.data?.[0]?.b64_json;
    if (b64) return `data:image/png;base64,${b64}`;

    const url = resp?.data?.[0]?.url;
    if (url) return url;

    console.error("image gen empty", { title, version: IMAGE_GEN_VERSION });
    return null;
  } catch (err) {
    const status = err?.status || err?.response?.status;
    console.error("image gen failed", {
      title,
      status,
      message: err?.message,
      version: IMAGE_GEN_VERSION,
    });
    return null;
  }
}

// ========= 分支 B：生成菜谱 (Recipe Generation) =========
// 支持 Student Mode, Servings, Oven Plan
async function handleRecipeGeneration(body, res) {
  const ingredients = Array.isArray(body.ingredients) ? body.ingredients : [];
  const extraIngredients = Array.isArray(body.extraIngredients)
    ? body.extraIngredients
    : [];

  const specialRequest =
    typeof body.specialRequest === "string" ? body.specialRequest.trim() : "";
  
  // 🟢 读取参数
  const studentMode = Boolean(body.studentMode);
  const servings = body.servings || 2; 

  const allList = [...ingredients, ...extraIngredients];
  if (allList.length === 0) {
    return res.status(400).json({ error: "No ingredients provided" });
  }

  const all = allList.join(", ");

  const preferenceBlock = specialRequest
    ? `
User preferences / constraints:
- ${specialRequest}

Respect these constraints:
- Match cuisine style if mentioned.
- If dietary constraints are given, DO NOT use forbidden ingredients.
`
    : `
User did not specify extra constraints.
Keep recipes generic but realistic for a European home kitchen.
`;

  // 🟢 学生模式指令
  const studentBlock = studentMode
    ? `
*** STUDENT MODE ACTIVATED ***
The user is likely a student with limited budget, time, and equipment.
STRICT Rules for Student Mode:
1. CHEAP: Prioritize budget-friendly ingredients.
2. LAZY/FAST: Recipes should be very quick (under 20 mins preferred) or "dump and forget".
3. MINIMAL TOOLS: Prefer Microwave, Kettle, or One-Pot/One-Pan recipes.
4. SIMPLE: Maximum 3-5 main steps.
5. FILLING: Ensure high satiety per euro.
`
    : "";

  const prompt = `
You are a cooking assistant that helps people reduce food waste.

Available ingredients (today's pantry):
${all}

Cooking Context:
- Target Servings: ${servings} people (Adjust quantities in description/steps conceptually).
${studentBlock}

${preferenceBlock}

Your job:
- Propose 3 different recipes.
- You do NOT need to use all ingredients in every recipe.
- Prioritize perishable/expiring ingredients in at least one recipe.
- Keep recipes realistic.

IMPORTANT UI requirement:
- We show two separate pills in the app:
  1) timePill: time only (e.g. "25 min")
  2) toolPill: tools only (e.g. "1 pan", "Oven", "Oven + pan", "Microwave")

Oven integration requirement:
- If a recipe needs an oven, set ovenPlan.required=true and provide:
  - tempC (integer, typical 80–250)
  - programKey (string; use "Cooking.Oven.Program.HeatingMode.PreHeating" for preheat)
  - durationMin (optional integer; e.g. 8)
- If no oven needed, set ovenPlan.required=false.

For EACH recipe return fields:
- id (string, short unique id "r1"..."r3")
- title (short dish name)
- timePill (string, time only, e.g. "20 min")
- toolPill (string, tools only, e.g. "1 pan" / "Oven" / "Oven + pan")
- tools (string[] from this set: ["oven","pan","pot","knife","microwave","airfryer","blender","ricecooker"])
- ovenPlan (object):
  { "required": boolean, "tempC": integer|null, "programKey": string|null, "durationMin": integer|null }
- expiringCount (integer, rough estimate of expiring ingredients used)
- ingredients (string[] only what is actually used in THIS recipe)
- steps (string[] 4–6 concise steps; if ovenPlan.required=true, include a step to preheat to tempC)
- description (string 1–2 sentences, mentioning it serves ${servings})

Return ONLY JSON:
{
  "recipes": [ { ... }, { ... }, { ... } ]
}
No markdown, no extra text.
`;

  const response = await client.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content: "You are a precise JSON API. Always respond with valid JSON only.",
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
    console.error("JSON parse error:", e, raw);
    return res.status(500).json({ error: "LLM returned invalid JSON" });
  }

  const recipes = Array.isArray(data.recipes) ? data.recipes : [];

  // ---- 清洗数据 ----
  const cleaned = recipes.map((r, idx) => {
    const m = (r && typeof r === "object") ? r : {};

    const id = String(m.id || `r${idx + 1}`);
    const title = String(m.title || "Untitled");

    const timePill = String(m.timePill || m.timeLabel || "20 min"); 
    const toolPill = String(m.toolPill || "1 pan");

    const tools = normalizeTools(m.tools);

    const ovenPlanIn = (m.ovenPlan && typeof m.ovenPlan === "object") ? m.ovenPlan : {};
    const required = Boolean(ovenPlanIn.required);

    const tools2 = required && !tools.includes("oven") ? ["oven", ...tools] : tools;

    const tempC = required ? clampInt(ovenPlanIn.tempC, 60, 260, 200) : null;
    const durationMin = required
      ? clampInt(ovenPlanIn.durationMin, 1, 180, null)
      : null;

    const programKey = required
      ? String(ovenPlanIn.programKey || "Cooking.Oven.Program.HeatingMode.PreHeating")
      : null;

    const expiringCount = clampInt(m.expiringCount, 0, 99, 0);

    const ingredients = Array.isArray(m.ingredients)
      ? m.ingredients.map((x) => String(x))
      : [];

    const steps = Array.isArray(m.steps) ? m.steps.map((x) => String(x)) : [];

    const description = typeof m.description === "string" ? m.description : "";

    return {
      id,
      title,
      timePill,
      toolPill,
      tools: tools2,
      ovenPlan: {
        required,
        tempC,
        programKey,
        durationMin,
      },
      expiringCount,
      ingredients,
      steps,
      description,
    };
  });

  const includeImages = false;
  if (!includeImages) {
    return res.status(200).json({ recipes: cleaned, imageGenVersion: IMAGE_GEN_VERSION });
  }
}

// ========= 分支 C：周报分析与智能分类 (Diet Analysis) =========
async function handleDietAnalysis(body, res) {
  const consumedItems = Array.isArray(body.consumed) ? body.consumed : [];
  const studentMode = Boolean(body.studentMode);
  const history = body.history && typeof body.history === "object" ? body.history : null;
  const weekContext =
    body.weekContext && typeof body.weekContext === "object" ? body.weekContext : {};
  const consumptionCounts =
    body.consumptionCounts && typeof body.consumptionCounts === "object"
      ? body.consumptionCounts
      : null;
  const plannedMealsThisWeek = Array.isArray(body.plannedMealsThisWeek)
    ? body.plannedMealsThisWeek
    : [];
  const plannedMealsNextWeek = Array.isArray(body.plannedMealsNextWeek)
    ? body.plannedMealsNextWeek
    : [];

  if (consumedItems.length === 0) {
    return res.status(200).json({
      insight: "It seems you haven't logged any meals this week. Start cooking to get AI insights!",
      suggestions: [],
      categorization: {} 
    });
  }

  // 去重以节省 Token，但保留原始列表可能对频率分析有用（这里选择发去重版）
  const uniqueItems = [...new Set(consumedItems)];
  const itemsStr = uniqueItems.join(", ");
  const sortedConsumption = consumptionCounts
    ? Object.entries(consumptionCounts)
        .filter(([name, count]) => typeof name === "string" && Number.isFinite(Number(count)))
        .map(([name, count]) => [String(name), Number(count)])
        .sort((a, b) => b[1] - a[1])
        .slice(0, 12)
    : [];
  const consumptionBlock = sortedConsumption.length
    ? `\nConsumption frequency (top items): ${sortedConsumption
        .map(([name, count]) => `${name} (${count}x)`)
        .join(", ")}\n`
    : "\nConsumption frequency: Not provided.\n";

  const historyBlock = history
    ? `
Weekly comparison:
This week summary: ${JSON.stringify(history.thisWeek || {})}
Last week summary: ${JSON.stringify(history.lastWeek || {})}
`
    : "No history summary available.";

  const normalizePlanned = (list) =>
    list
      .map((m) => {
        const date = String(m?.date || "");
        const slot = String(m?.slot || "");
        const mealName = String(m?.mealName || "");
        const recipeName = String(m?.recipeName || "");
        const itemIds = Array.isArray(m?.itemIds) ? m.itemIds : [];
        return { date, slot, mealName, recipeName, itemIdsCount: itemIds.length };
      })
      .filter((m) => m.date || m.mealName || m.recipeName || m.slot);

  const plannedThisWeek = normalizePlanned(plannedMealsThisWeek);
  const plannedNextWeek = normalizePlanned(plannedMealsNextWeek);

  const plannedBlock = `
Planned meals (this week):
${plannedThisWeek.length ? JSON.stringify(plannedThisWeek) : "None"}

Planned meals (next week):
${plannedNextWeek.length ? JSON.stringify(plannedNextWeek) : "None"}
`;

  const prompt = `
You are a friendly, professional nutrition assistant${studentMode ? " for a busy student on a budget" : ""}.
The user has consumed the following items this week: "${itemsStr}".
${consumptionBlock}
${historyBlock}
${plannedBlock}

User's plan for planning restock:
- This week: "${String(weekContext.thisWeek || "").trim()}"
- Next week: "${String(weekContext.nextWeek || "").trim()}"

Your Tasks:
1. Insight: Provide a concise, friendly 2-3 sentence assessment focused on THIS WEEK. If last week data exists, mention 1-2 meaningful changes (e.g., less veggies, more snacks).
2. Suggestions: Suggest 3-5 ingredients to restock based on what they ACTUALLY consumed most, plus the user's plan for this/next week. Use the frequency list to prioritize staples they eat often, and add 1-2 complementary items to balance gaps (e.g., more veggies if diet is heavy in carbs). Keep reasons practical and encouraging.
3. Next week meal help: If next week's planned meals are provided, add 1-2 brief adjustments (ingredients or swaps) to make those meals more balanced or realistic.
4. Categorization (CRITICAL): Map EACH item in the input list to EXACTLY ONE of these categories for a pie chart:
   [Veggies, Fruits, Protein, Dairy, Carbs, Snacks, Drinks, Condiments, Other].
   
   Examples:
   - "Banana" -> "Fruits"
   - "Onion" -> "Veggies"
   - "Tofu" -> "Protein"
   - "Milk" -> "Dairy"
   - "Rice" -> "Carbs"
   - "Coke" -> "Drinks"

Return ONLY JSON:
{
  "insight": "Your analysis here.",
  "suggestions": [
    { "name": "Broccoli", "category": "Veggies", "reason": "More fiber needed!" },
    { "name": "Chicken", "category": "Protein", "reason": "Good protein source." }
  ],
  "nextWeekAdvice": [
    "Add a leafy green to your planned dinners to balance fiber.",
    "Swap one lunch carb for a protein-forward option."
  ],
  "categorization": {
    "Banana": "Fruits",
    "Onion": "Veggies",
    "Milk": "Dairy"
  }
}
`;

  const response = await client.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "You are a precise JSON API." },
      { role: "user", content: prompt },
    ],
    response_format: { type: "json_object" },
  });

  const raw = response.choices[0]?.message?.content ?? "{}";
  try {
    const data = JSON.parse(raw);
    return res.status(200).json(data);
  } catch (e) {
    console.error("AI Parse Error", e);
    return res.status(500).json({ error: "Failed to parse AI response" });
  }
}

// ========= 主入口 (Main Handler) =========
export default async function handler(req, res) {
  // ---- CORS ----
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    const body = await readBody(req);

    // 🟢 路由分发
    if (body.action === 'analyze_diet') {
      return await handleDietAnalysis(body, res);
    }
    
    // 检查是否是保质期预测请求
    const hasExpiryPayload =
      typeof body?.name !== "undefined" &&
      typeof body?.location !== "undefined" &&
      typeof body?.purchasedDate !== "undefined";

    if (hasExpiryPayload) {
      return await handleExpiryPrediction(body, res);
    }

    // 默认：生成菜谱
    return await handleRecipeGeneration(body, res);
  } catch (err) {
    console.error("API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
