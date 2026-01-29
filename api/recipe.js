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

// --------- Expiry prediction rules (USDA/UK FSA based) ----------
const COOKED_KEYWORDS = [
  "cooked",
  "leftover",
  "leftovers",
  "roasted",
  "grilled",
  "fried",
  "baked",
  "steamed",
  "boiled",
  "stewed",
  "smoked",
];

function normalizeExpiryName(raw) {
  const lowered = String(raw || "").toLowerCase();
  const cleaned = lowered
    .replaceAll(/[_\-]/g, " ")
    .replaceAll(/[^a-z0-9\s]/g, " ")
    .replaceAll(/\s+/g, " ")
    .trim();
  const tokens = cleaned ? cleaned.split(" ").filter(Boolean) : [];
  return { cleaned, tokens };
}

function resolveLocationType(location) {
  const loc = String(location || "").toLowerCase();
  if (loc.includes("freezer")) return "freezer";
  if (loc.includes("fridge") || loc.includes("refrigerator")) return "fridge";
  if (loc.includes("pantry") || loc.includes("cupboard")) return "pantry";
  return "unknown";
}

function buildExpiryContext(name, location) {
  const normalized = normalizeExpiryName(name);
  const tokenSet = new Set(normalized.tokens);
  const has = (t) => tokenSet.has(t);
  const hasAny = (arr) => arr.some((t) => tokenSet.has(t));
  const hasAll = (arr) => arr.every((t) => tokenSet.has(t));
  const isCooked = hasAny(COOKED_KEYWORDS);
  return {
    tokens: normalized.tokens,
    has,
    hasAny,
    hasAll,
    isCooked,
    locationType: resolveLocationType(location),
  };
}

const EXPIRY_RULES = [
  {
    id: "leftovers_rice",
    match: (ctx) =>
      ctx.has("rice") && ctx.hasAny(["cooked", "leftover", "leftovers", "fried"]),
    fridgeDays: 1, // UK FSA: leftovers rice within 24 hours
  },
  {
    id: "leftovers_general",
    match: (ctx) => ctx.hasAny(["leftover", "leftovers"]) || ctx.isCooked,
    fridgeDays: 2, // UK FSA: eat leftovers within 48 hours
    freezerDays: 90, // USDA/FSIS: leftovers 2-3 months (quality)
  },
  {
    id: "raw_poultry",
    match: (ctx) =>
      !ctx.isCooked && ctx.hasAny(["chicken", "turkey", "poultry"]),
    fridgeDays: 2, // USDA/FSIS: 1-2 days
    freezerDays: 270, // USDA/FSIS: 9 months
  },
  {
    id: "ground_meat",
    match: (ctx) =>
      !ctx.isCooked &&
      ctx.hasAny(["ground", "minced", "mince", "burger", "hamburger"]) &&
      ctx.hasAny(["beef", "pork", "lamb", "veal", "turkey", "chicken"]),
    fridgeDays: 2, // USDA/FSIS: 1-2 days
    freezerDays: 120, // USDA/FSIS/FoodSafety.gov: 3-4 months
  },
  {
    id: "fresh_red_meat",
    match: (ctx) =>
      !ctx.isCooked &&
      ctx.hasAny(["beef", "pork", "lamb", "veal"]) &&
      ctx.hasAny(["steak", "steaks", "chop", "chops", "roast", "roasts"]),
    fridgeDays: 4, // USDA/FSIS: 3-5 days
    freezerDays: 240, // USDA/FSIS: 6-12 months (conservative)
  },
  {
    id: "fish_seafood",
    match: (ctx) =>
      !ctx.isCooked &&
      ctx.hasAny([
        "fish",
        "seafood",
        "salmon",
        "tuna",
        "cod",
        "shrimp",
        "prawn",
        "crab",
        "lobster",
        "shellfish",
      ]),
    fridgeDays: 2, // FoodSafety.gov: 1-3 days for fin fish
    freezerDays: 90, // FoodSafety.gov: 2-3 months for fatty fish
  },
  {
    id: "eggs",
    match: (ctx) => ctx.hasAny(["egg", "eggs"]),
    fridgeDays: 28, // FoodSafety.gov: 3-5 weeks
  },
];

function getRuleBasedDays(name, location) {
  const ctx = buildExpiryContext(name, location);
  if (ctx.locationType === "unknown") return null;
  for (const rule of EXPIRY_RULES) {
    if (!rule.match(ctx)) continue;
    const days =
      ctx.locationType === "freezer"
        ? rule.freezerDays
        : ctx.locationType === "fridge"
        ? rule.fridgeDays
        : rule.pantryDays;
    if (Number.isFinite(days) && days > 0) return Math.round(days);
  }
  return null;
}


// ========= 分支 A：保质期预测 (Expiry Prediction - 深度优化版) =========
async function handleExpiryPrediction(body, res) {
  const name = (body.name || "").toString().trim();
  const location = (body.location || "").toString().trim();
  const purchasedDate = (body.purchasedDate || "").toString().trim();
  const openDate = (body.openDate || "").toString().trim();
  const bestBeforeDate = (body.bestBeforeDate || "").toString().trim();

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

  // 确定计算的基准日期
  // 如果有开封日期，我们从开封日期开始算“开封后保质期”
  // 否则，我们从购买日期开始算“未开封保质期”
  let baseDate = purchased;
  let baseDateLabel = "purchase date";
  const hasOpenDate = Boolean(openDate);

  if (hasOpenDate) {
    const opened = new Date(openDate);
    if (!isNaN(opened.getTime())) {
      baseDate = opened;
      baseDateLabel = "open date";
    }
  }

  // 优先使用硬编码规则 (Rule-Based)
  // 注意：Rule-Based 主要针对未加工的生鲜，通常假设是从购买日开始算。
  // 如果已经开封，且规则没有特别处理开封逻辑，我们最好跳过规则，让 LLM 处理更复杂的“开封后”逻辑。
  if (!hasOpenDate) {
    const ruleDays = getRuleBasedDays(name, location);
    if (Number.isFinite(ruleDays) && ruleDays > 0) {
      let adjustedDays = ruleDays;
      const bestBefore = bestBeforeDate ? new Date(bestBeforeDate) : null;
      if (bestBefore && !isNaN(bestBefore.getTime())) {
        const diffMs = bestBefore.getTime() - baseDate.getTime();
        const diffDays = Math.floor(diffMs / (24 * 60 * 60 * 1000));
        if (Number.isFinite(diffDays)) {
          // 如果 best before 比规则更短，取较短的
          adjustedDays = Math.min(adjustedDays, Math.max(1, diffDays));
        }
      }

      const predictedExpiry = new Date(
        baseDate.getTime() + adjustedDays * 24 * 60 * 60 * 1000
      );

      return res.status(200).json({
        predictedExpiry: predictedExpiry.toISOString(),
        days: adjustedDays,
        referenceDate: baseDate.toISOString(),
        referenceType: baseDateLabel,
        source: "rule",
      });
    }
  }

  // 🟢 深度优化后的 Prompt：完全依赖 LLM 进行上下文理解
  const prompt = `
You are a strict food safety expert (USDA/UK FSA standards).
Estimate the SAFE REMAINING SHELF LIFE in DAYS for a specific food item.

Input Data:
- Product: "${name}"
- Storage Location: "${location}"
- Status: ${hasOpenDate ? `OPENED on ${openDate}` : "Sealed / Unopened"}
- Purchase Date: "${purchasedDate}"

CRITICAL ANALYSIS LOGIC:

1. **CONTEXT DISAMBIGUATION (Location is Key)**:
   - Identify the product form based on where it is stored.
   - Example: "Milk" in Pantry -> UHT/Powder (Long life). "Milk" in Fridge -> Fresh (Short life).
   - Example: "Pasta" in Fridge -> Cooked/Fresh (Short life). "Pasta" in Pantry -> Dried (Years).
   - If ambiguous, assume the **Perishable/Fresh** version for safety.

2. **OPENED vs UNOPENED**:
   - If Status is **OPENED**: You MUST predict the "Use-By after opening" period.
     - Example: Jar of Mayo (Unopened: 1 year, Opened: 2 months).
     - Example: Carton of Soup (Unopened: 1 year, Opened: 3-4 days).
   - If Status is **Sealed**: Predict the standard shelf life from the Purchase Date.

3. **STORAGE IMPACT**:
   - **Freezer**: Extends shelf life significantly (3-12 months for most items). If the item is frozen, ignore fridge rules.
   - **Fridge**: Standard for perishables (Meat: 2-5 days, Veg: 5-14 days).
   - **Pantry**: Only for shelf-stable items.

4. **SAFETY FIRST**:
   - Better to predict spoilage too early than too late.
   - For fresh meat/fish in fridge: Max 2-3 days unless specified otherwise.
   - For leftovers: Max 3-4 days.

OUTPUT REQUIREMENT:
Return ONLY a JSON object: { "days": <integer> }
- "days" represents how many days the item is safe to consume counting FROM the **${baseDateLabel}**.
`;

  try {
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
      temperature: 0.3, // 降低随机性，提高准确度
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
    // Fallback logic in case LLM fails or returns weird numbers
    if (!Number.isFinite(days) || days <= 0) days = 3; 

    // 对极端的数值做限制（防止 LLM 幻觉产生 100 年）
    if (days > 1000) days = 1000;

    // 如果有 Best Before Date，且未开封，可以用来辅助修正（取较小值以策安全）
    if (!hasOpenDate && bestBeforeDate) {
      const bestBefore = new Date(bestBeforeDate);
      if (!isNaN(bestBefore.getTime())) {
        const diffMs = bestBefore.getTime() - baseDate.getTime();
        const diffDays = Math.floor(diffMs / (24 * 60 * 60 * 1000));
        if (Number.isFinite(diffDays) && diffDays > 0) {
          // 如果 LLM 预测的比 best before 还要长很多，可能是不准确的，倾向于相信 best before
          // 但如果是 Freezer，则忽略 Best Before
          const isFreezer = location.toLowerCase().includes("freezer");
          if (!isFreezer) {
             days = Math.min(days, diffDays + 2); // 允许 Best Before 后宽限几天
          }
        }
      }
    }

    const predictedExpiry = new Date(
      baseDate.getTime() + days * 24 * 60 * 60 * 1000
    );

    return res.status(200).json({
      predictedExpiry: predictedExpiry.toISOString(),
      days: days,
      referenceDate: baseDate.toISOString(),
      referenceType: baseDateLabel,
      source: "ai_v2",
    });

  } catch (err) {
    console.error("AI Expiry Prediction Error", err);
    // 降级策略
    return res.status(200).json({
        predictedExpiry: new Date(baseDate.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
        days: 7,
        referenceDate: baseDate.toISOString(),
        referenceType: baseDateLabel,
        source: "fallback",
    });
  }
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