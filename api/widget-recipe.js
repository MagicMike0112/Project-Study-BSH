// api/widget-recipe.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const IMAGE_GEN_VERSION = "imggen_v3_no_response_format";

const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

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
  const prompt = `A clean, appetizing food photo of "${title}", soft natural light, top-down, minimal background. Ingredients: ${ingredients.join(", ")}.`;

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

async function handleWidgetRecipe(body, res) {
  const items = Array.isArray(body.items) ? body.items : [];
  const expiringItems = Array.isArray(body.expiringItems)
    ? body.expiringItems
    : [];
  const studentMode = Boolean(body.studentMode);

  const names = items
    .map((x) => (x?.name ?? "").toString().trim())
    .filter(Boolean);
  if (names.length === 0) {
    return res.status(400).json({ error: "No items provided" });
  }

  const expiringNames = expiringItems
    .map((x) => (x?.name ?? "").toString().trim())
    .filter(Boolean);

  const expiringBlock = expiringNames.length
    ? `Prioritize these expiring items first:\n${expiringNames.join(", ")}\n`
    : "There are no explicit expiring items.\n";

  const studentBlock = studentMode
    ? `
*** STUDENT MODE ACTIVATED ***
Rules:
1. CHEAP: budget-friendly ingredients.
2. FAST: under 20 mins preferred.
3. MINIMAL TOOLS: one-pan, microwave, or simple prep.
4. SIMPLE: 3-5 steps max.
`
    : "";

  const prompt = `
You are a cooking assistant helping reduce food waste.

Inventory items:
${names.join(", ")}

${expiringBlock}
${studentBlock}

Create ONE recipe. Requirements:
- Use at least 2 items, prioritize expiring items.
- Keep it realistic for a home kitchen.
- Short and clear steps.

Return ONLY JSON:
{
  "recipeId": "string",
  "title": "string",
  "timeLabel": "e.g. 20 min",
  "tools": ["pan","knife"],
  "expiringCount": 0,
  "ingredients": ["..."],
  "steps": ["..."],
  "description": "1-2 sentences",
  "appliances": ["Pan"],
  "ovenTempC": null
}
`;

  const response = await client.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "You are a precise JSON API. Return JSON only." },
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

  const title = String(data.title || "Recipe suggestion");
  const recipeId = String(data.recipeId || `w_${Date.now()}`);
  const timeLabel = String(data.timeLabel || "20 min");
  const expiringCount = clampInt(data.expiringCount, 0, 99, 0);
  const ingredients = Array.isArray(data.ingredients)
    ? data.ingredients.map((x) => String(x))
    : [];
  const steps = Array.isArray(data.steps) ? data.steps.map((x) => String(x)) : [];
  const description = typeof data.description === "string" ? data.description : "";
  const tools = normalizeTools(data.tools);
  const appliances = Array.isArray(data.appliances)
    ? data.appliances.map((x) => String(x))
    : [];
  const ovenTempC =
    data.ovenTempC == null ? null : clampInt(data.ovenTempC, 60, 260, null);

  const imageUrl = await generateRecipeImage(title, ingredients);

  return res.status(200).json({
    recipeId,
    title,
    timeLabel,
    expiringCount,
    ingredients,
    steps,
    description,
    tools,
    appliances,
    ovenTempC,
    imageUrl,
    imageGenVersion: IMAGE_GEN_VERSION,
  });
}

export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const body = await readBody(req);
    return await handleWidgetRecipe(body, res);
  } catch (err) {
    console.error("API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
