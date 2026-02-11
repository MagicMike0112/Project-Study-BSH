// api/recipe.js
import OpenAI from "openai";
import { languageName, resolveLocale, t } from "./_lib/i18n.js";

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


// ========= 分支 A：保质期预测 (Expiry Prediction - 整合冷冻修正版) =========
async function handleExpiryPrediction(body, res, locale) {
  const name = (body.name || "").toString().trim();
  // 🟢 接收 genericName
  const genericName = (body.genericName || "").toString().trim(); 
  const location = (body.location || "").toString().trim();
  const purchasedDate = (body.purchasedDate || "").toString().trim();
  const openDate = (body.openDate || "").toString().trim();
  const bestBeforeDate = (body.bestBeforeDate || "").toString().trim();

  if (!name || !location || !purchasedDate) {
    return res.status(400).json({
      error: t(locale, "missingRequiredFields"),
    });
  }

  const purchased = new Date(purchasedDate);
  if (isNaN(purchased.getTime())) {
    return res.status(400).json({
      error: t(locale, "invalidPurchasedDate"),
    });
  }

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

  // 1. 优先尝试规则匹配 (Rule-Based)
  // 🟢 优化：将 specific name 和 generic name 拼接后去匹配规则
  // 这样既能匹配到 "cooked" (in name) 也能匹配到 "rice" (in genericName)
  if (!hasOpenDate) {
    const ruleSearchText = (genericName + " " + name).trim();
    const ruleDays = getRuleBasedDays(ruleSearchText, location);
    
    if (Number.isFinite(ruleDays) && ruleDays > 0) {
      let adjustedDays = ruleDays;
      const bestBefore = bestBeforeDate ? new Date(bestBeforeDate) : null;
      // 注意：如果是冷冻，通常可以忽略 Best Before (因为冷冻暂停了腐败)
      const isFreezerRule = location.toLowerCase().includes("freezer");
      
      if (!isFreezerRule && bestBefore && !isNaN(bestBefore.getTime())) {
        const diffMs = bestBefore.getTime() - baseDate.getTime();
        const diffDays = Math.floor(diffMs / (24 * 60 * 60 * 1000));
        if (Number.isFinite(diffDays)) {
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

  // 2. AI 预测 (Prompt 针对 Freezer 进行了强化，并加入了 genericName)
  const prompt = `
You are a strict food safety expert.
Estimate the SAFE REMAINING SHELF LIFE in DAYS.

Input:
- Product Name: "${name}"
${genericName ? `- Ingredient Type: "${genericName}"` : ""}
- Location: "${location}"
- Status: ${hasOpenDate ? "OPENED" : "Sealed"}

CRITICAL RULES:
1. **USE INGREDIENT TYPE**: Use the "Ingredient Type" (if provided) to judge shelf life, as Brand Names can be misleading.
2. **CHECK LOCATION FIRST**:
   - If Location is **FREEZER**: The shelf life implies **MONTHS** (90-365 days). Do NOT give fridge-life (3-5 days) for frozen items.
   - If Location is **PANTRY**: Dry goods last months/years. Fresh produce lasts days.
   - If Location is **FRIDGE**: Meat (2-4 days), Veggies (1-2 weeks).

3. **OPENED vs SEALED**:
   - Opened items in Fridge expire fast.
   - Opened items in Freezer still last months (quality may drop, but safety is high).

4. **CONSERVATIVE ESTIMATE**:
   - If unsure, pick the lower bound of safety.

Output JSON: { "days": <integer> }
`;

  try {
    const response = await client.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: "You are a JSON API. If Location is Freezer, output days > 30." },
        { role: "user", content: prompt },
      ],
      response_format: { type: "json_object" },
      temperature: 0.1, 
    });

    const raw = response.choices[0]?.message?.content ?? "";
    let data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      return res.status(500).json({ error: t(locale, "llmJsonError") });
    }

    let days = Number.parseInt(data.days, 10);
    if (!Number.isFinite(days) || days <= 0) days = 3;

    // 🟢 关键功能：Freezer 强制修正逻辑 (Force Logic)
    // 解决“移动到冷冻室日期没变”的问题
    const locLower = location.toLowerCase();
    const isFreezer = locLower.includes("freezer") || locLower.includes("ice");

    if (isFreezer) {
      // 如果是在冷冻室，且 AI 预测小于 30 天，说明 AI 误判，强制修正为至少 3 个月
      if (days < 30) {
        days = Math.max(90, days * 10); 
      }
      // 设置上限防止过大
      if (days > 730) days = 730;
    } 

    const predictedExpiry = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);

    return res.status(200).json({
      predictedExpiry: predictedExpiry.toISOString(),
      days: days,
      referenceDate: baseDate.toISOString(),
      referenceType: baseDateLabel,
      source: "ai_v3_fixed",
    });

  } catch (err) {
    console.error("Prediction Error", err);
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

// ========= 分支 B：生成菜谱 (Recipe Generation - 动态数量版) =========
async function handleRecipeGeneration(body, res, locale) {
  const ingredients = Array.isArray(body.ingredients) ? body.ingredients : [];
  const extraIngredients = Array.isArray(body.extraIngredients)
    ? body.extraIngredients
    : [];

  const specialRequest =
    typeof body.specialRequest === "string" ? body.specialRequest.trim() : "";
  
  // 🟢 读取参数
  const studentMode = Boolean(body.studentMode);
  const servings = body.servings || 2; 

  // 🟢 动态菜谱数量支持 (1-5)
  let recipeCount = parseInt(body.recipeCount);
  if (isNaN(recipeCount) || recipeCount < 1) recipeCount = 3;
  if (recipeCount > 5) recipeCount = 5;

  const allList = [...ingredients, ...extraIngredients];
  if (allList.length === 0) {
    return res.status(400).json({ error: t(locale, "noIngredientsProvided") });
  }
  const outputLanguage = languageName(locale);

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

  // 🟢 优化 Prompt: 要求 AI 理解 ingredient 可能是具体的品牌名，但在生成步骤时使用通用名
  const prompt = `
You are a cooking assistant that helps people reduce food waste.

Available ingredients (today's pantry):
${all}
*(Note: Some ingredients may be listed by Brand Name. Please interpret them as their generic food type.)*

Cooking Context:
- Target Servings: ${servings} people (Adjust quantities in description/steps conceptually).
${studentBlock}

${preferenceBlock}

Your job:
- Propose ${recipeCount} different recipes.
- You do NOT need to use all ingredients in every recipe.
- Prioritize perishable/expiring ingredients in at least one recipe.
- Keep recipes realistic.
- Use ${outputLanguage} for human-facing text fields (title, description, ingredients, steps, pills).
- **IMPORTANT**: In the "ingredients" and "steps" fields, use GENERIC names (e.g., use "Milk", not "Horizon Organic Milk").

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
    return res.status(500).json({ error: t(locale, "modelReturnedInvalidJson") });
  }

  const recipes = Array.isArray(data.recipes) ? data.recipes : [];

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
    const durationMin = required ? clampInt(ovenPlanIn.durationMin, 1, 180, null) : null;
    const programKey = required ? String(ovenPlanIn.programKey || "Cooking.Oven.Program.HeatingMode.PreHeating") : null;
    const expiringCount = clampInt(m.expiringCount, 0, 99, 0);
    const ingredients = Array.isArray(m.ingredients) ? m.ingredients.map((x) => String(x)) : [];
    const steps = Array.isArray(m.steps) ? m.steps.map((x) => String(x)) : [];
    const description = typeof m.description === "string" ? m.description : "";

    return {
      id, title, timePill, toolPill, tools: tools2,
      ovenPlan: { required, tempC, programKey, durationMin },
      expiringCount, ingredients, steps, description,
    };
  });

  return res.status(200).json({ recipes: cleaned, imageGenVersion: IMAGE_GEN_VERSION });
}

// ========= 分支 C：周报分析与智能分类 (Diet Analysis - 智能补货优先级版) =========
async function handleDietAnalysis(body, res, locale) {
  const consumedItems = Array.isArray(body.consumed) ? body.consumed : [];
  const studentMode = Boolean(body.studentMode);
  const history = body.history && typeof body.history === "object" ? body.history : null;
  const weekContext = body.weekContext && typeof body.weekContext === "object" ? body.weekContext : {};
  const consumptionCounts = body.consumptionCounts && typeof body.consumptionCounts === "object" ? body.consumptionCounts : null;
  const plannedMealsNextWeek = Array.isArray(body.plannedMealsNextWeek) ? body.plannedMealsNextWeek : [];

  if (consumedItems.length === 0) {
    const fallbackInsight =
      locale === "zh"
        ? "你这周还没有记录用餐，开做第一顿，AI 建议就会出现。"
        : locale === "de"
        ? "Du hast diese Woche noch keine Mahlzeiten erfasst. Starte mit dem Kochen, dann kommen KI-Einblicke."
        : "It seems you haven't logged any meals this week. Start cooking to get AI insights!";
    return res.status(200).json({
      insight: fallbackInsight,
      suggestions: [],
      categorization: {} 
    });
  }
  const outputLanguage = languageName(locale);

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
    ? `\nConsumption History (Frequency): ${sortedConsumption
        .map(([name, count]) => `${name} (${count}x)`)
        .join(", ")}\n`
    : "\nConsumption History: Not provided.\n";

  const nextWeekPlanRaw = String(weekContext.nextWeek || "").trim();
  const nextWeekPlanBlock = nextWeekPlanRaw 
    ? `USER'S NEXT WEEK PLAN: "${nextWeekPlanRaw}"` 
    : "USER'S NEXT WEEK PLAN: None/Unspecified";

  const plannedNextWeekStructured = plannedMealsNextWeek
    .map(m => m.mealName || m.recipeName)
    .filter(Boolean)
    .join(", ");
  
  const structuredPlanBlock = plannedNextWeekStructured
    ? `Structured Meal Plan (Next Week): ${plannedNextWeekStructured}`
    : "";

  // 🟢 智能补货 Prompt：优先级逻辑 (计划 > 历史 > 平衡)
  const prompt = `
You are a highly intelligent Personal Grocery Assistant${studentMode ? " for a budget-conscious student" : ""}.

DATA CONTEXT:
1. **Items Consumed This Week**: "${itemsStr}"
2. ${consumptionBlock}
3. ${nextWeekPlanBlock}
4. ${structuredPlanBlock}

YOUR OBJECTIVES:

---
**TASK 1: INSIGHT (Analysis)**
Provide a brief, friendly 2-sentence observation about their diet this week based on the "Consumed Items".
- Did they eat a lot of one thing? Was it balanced?
- Keep it encouraging.
- Write this in ${outputLanguage}.

---
**TASK 2: SMART RESTOCK SUGGESTIONS (The Core Task)**
Suggest exactly 4-6 items to buy/restock. You MUST follow this priority order strictly:

* **PRIORITY 1 (Highest): THE NEXT WEEK PLAN.**
    * Look at the "USER'S NEXT WEEK PLAN" and "Structured Meal Plan".
    * Deconstruct these plans into necessary raw ingredients.
    * *Example:* If plan is "Making Sushi", you MUST suggest "Nori Sheets", "Sushi Rice", "Fish".
    * *Reason:* "Essential for your Sushi plan."

* **PRIORITY 2: REPLENISH STAPLES.**
    * Look at "Consumption History". Identify items consumed frequently (2x or more) that likely ran out (e.g., Milk, Eggs, Bread, Oil).
    * *Reason:* "You use this frequently."

* **PRIORITY 3: NUTRITIONAL BALANCE.**
    * If the plan is empty, suggest items to balance their recent diet (e.g., if they ate only carbs, suggest a versatile vegetable).

* **Logic Check:** Do NOT suggest items they likely still have (e.g., a bag of flour bought once) unless the plan explicitly requires a lot of it. Focus on perishables and high-turnover items.
- Keep "name" and "reason" in ${outputLanguage}. Keep "category" in English from this set:
  [Veggies, Fruits, Protein, Dairy, Carbs, Snacks, Drinks, Condiments, Other].

---
**TASK 3: CATEGORIZATION**
Map consumed items to: [Veggies, Fruits, Protein, Dairy, Carbs, Snacks, Drinks, Condiments, Other].

---
**OUTPUT JSON FORMAT:**
{
  "insight": "...",
  "suggestions": [
    { 
      "name": "Item Name", 
      "category": "Category", 
      "reason": "Specific reason linking to Plan or History." 
    }
  ],
  "nextWeekAdvice": [ "Short tip 1", "Short tip 2" ],
  "categorization": { "ItemName": "Category" }
}
`;

  try {
    const response = await client.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: "You are a helpful JSON API." },
        { role: "user", content: prompt },
      ],
      response_format: { type: "json_object" },
      temperature: 0.5,
    });

    const raw = response.choices[0]?.message?.content ?? "{}";
    const data = JSON.parse(raw);
    return res.status(200).json(data);
  } catch (e) {
    console.error("AI Parse Error", e);
    return res.status(500).json({ error: t(locale, "failedToParseAiResponse") });
  }
}

// ========= 主入口 (Main Handler) =========
export default async function handler(req, res) {
  // ---- CORS ----
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, Accept-Language, X-App-Locale");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") {
    return res.status(405).json({ error: t(resolveLocale(req, {}), "methodNotAllowed") });
  }

  try {
    const body = await readBody(req);
    const locale = resolveLocale(req, body);

    // 🟢 路由分发
    if (body.action === 'analyze_diet') {
      return await handleDietAnalysis(body, res, locale);
    }
    
    // 检查是否是保质期预测请求
    const hasExpiryPayload =
      typeof body?.name !== "undefined" &&
      typeof body?.location !== "undefined" &&
      typeof body?.purchasedDate !== "undefined";

    if (hasExpiryPayload) {
      return await handleExpiryPrediction(body, res, locale);
    }

    // 默认：生成菜谱
    return await handleRecipeGeneration(body, res, locale);
  } catch (err) {
    console.error("API error:", err);
    return res.status(500).json({ error: t(resolveLocale(req, {}), "internalServerError") });
  }
}
