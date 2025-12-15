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

// ========= 分支 A：保质期预测（AI 版，支持 openDate） =========
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

  const prompt = `
You are a food shelf-life safety assistant.
Your task is to ESTIMATE a safe remaining shelf life in DAYS for a food item,
based on its product name, storage location, purchase date, and optional open date.

User input:
- product name: "${name}"
- storage location: "${location}"
- purchase date: "${purchasedDate}"
- open date (may be empty): "${openDate || "N/A"}"

Reference date rules:
- If an OPEN DATE is provided and valid, you MUST use the OPEN DATE as the reference date.
- Otherwise, use the PURCHASE DATE as the reference date.
- In this case, the reference date is the ${baseDateLabel}.

Assumptions:
- Ordinary household in Europe, normal domestic fridge/freezer.
- Opened items shorten shelf life significantly.
- Be conservative. When unsure, choose a shorter, safer time.

Output format (IMPORTANT):
Return ONLY a JSON object, with NO extra text:
{ "days": <positive integer> }

Constraints:
- "days" is counted FROM the reference date.
- NEVER exceed 365 days.
`;

  const response = await client.chat.completions.create({
    model: "gpt-4.1-mini",
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
  if (!Number.isFinite(days) || days <= 0) days = 7;
  if (days > 365) days = 365;

  const predicted = new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);

  return res.status(200).json({
    predictedExpiry: predicted.toISOString(),
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

// ========= 分支 B：生成菜谱（+ 打通 oven：输出 ovenPlan） =========
async function handleRecipeGeneration(body, res) {
  const ingredients = Array.isArray(body.ingredients) ? body.ingredients : [];
  const extraIngredients = Array.isArray(body.extraIngredients)
    ? body.extraIngredients
    : [];

  const specialRequest =
    typeof body.specialRequest === "string" ? body.specialRequest.trim() : "";

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

  const prompt = `
You are a cooking assistant that helps people reduce food waste.

Available ingredients (today's pantry):
${all}

${preferenceBlock}

Your job:
- Propose 3 different recipes.
- You do NOT need to use all ingredients in every recipe.
- Prioritize perishable/expiring ingredients in at least one recipe.
- Keep recipes realistic and not too complex.

IMPORTANT UI requirement:
- We show two separate pills in the app:
  1) timePill: time only (e.g. "25 min")
  2) toolPill: tools only (e.g. "1 pan", "Oven", "Oven + pan")

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
- description (string 1–2 sentences)

Return ONLY JSON:
{
  "recipes": [ { ... }, { ... }, { ... } ]
}
No markdown, no extra text.
`;

  const response = await client.chat.completions.create({
    model: "gpt-4.1-mini",
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

  // ---- 轻度清洗：确保 ovenPlan / pills / tools 可用，避免前端炸 ----
  const cleaned = recipes.map((r, idx) => {
    const m = (r && typeof r === "object") ? r : {};

    const id = String(m.id || `r${idx + 1}`);
    const title = String(m.title || "Untitled");

    const timePill = String(m.timePill || m.timeLabel || "20 min"); // 兼容旧字段
    const toolPill = String(m.toolPill || "1 pan");

    const tools = normalizeTools(m.tools);

    const ovenPlanIn = (m.ovenPlan && typeof m.ovenPlan === "object") ? m.ovenPlan : {};
    const required = Boolean(ovenPlanIn.required);

    // 如果 AI 说 required=true 但 tools 里没 oven，补上
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

  return res.status(200).json({ recipes: cleaned });
}

// ========= 主入口 =========
export default async function handler(req, res) {
  // ---- CORS ----
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    const body = await readBody(req);

    const hasExpiryPayload =
      typeof body?.name !== "undefined" &&
      typeof body?.location !== "undefined" &&
      typeof body?.purchasedDate !== "undefined";

    if (hasExpiryPayload) {
      return await handleExpiryPrediction(body, res);
    }

    return await handleRecipeGeneration(body, res);
  } catch (err) {
    console.error("API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
