// api/scan-inventory.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// 允许的前端域名
const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

// ---------- utils ----------
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

function toDataUrl(base64) {
  const b64 = (base64 || "").trim();
  if (!b64) return null;
  if (b64.startsWith("data:image/")) return b64;
  return `data:image/jpeg;base64,${b64}`;
}

function clampInt(n, min, max, fallback) {
  const x = Number.parseInt(n, 10);
  if (!Number.isFinite(x)) return fallback;
  return Math.max(min, Math.min(max, x));
}

function clampFloat(n, min, max, fallback) {
  const x = Number(n);
  if (!Number.isFinite(x)) return fallback;
  return Math.max(min, Math.min(max, x));
}

function parseYYYYMMDD(s) {
  if (typeof s !== "string") return null;
  const t = s.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(t)) return null;
  const d = new Date(`${t}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) return null;
  return d;
}

function ymd(date) {
  return date.toISOString().slice(0, 10);
}

function addDays(baseDate, days) {
  const ms = baseDate.getTime() + days * 24 * 60 * 60 * 1000;
  return new Date(ms);
}

function extractOutputText(resp) {
  // 适配标准 OpenAI SDK 的 chat.completions 结构
  if (resp.choices && Array.isArray(resp.choices) && resp.choices[0]?.message?.content) {
    return resp.choices[0].message.content.trim();
  }
  
  // 适配可能的旧代码或自定义结构
  if (typeof resp?.output_text === "string" && resp.output_text.trim()) {
    return resp.output_text.trim();
  }
  const out = resp?.output;
  if (!Array.isArray(out)) return "";
  for (const item of out) {
    if (item?.type === "message" && Array.isArray(item?.content)) {
      for (const c of item.content) {
        if (c?.type === "output_text" && typeof c?.text === "string") {
          const t = c.text.trim();
          if (t) return t;
        }
      }
    }
  }
  return "";
}

function sanitizeModelText(s) {
  let t = String(s ?? "");
  t = t.replace(/^\uFEFF/, "");
  t = t.replace(/^\s*```json\s*/i, "").replace(/^\s*```\s*/i, "").replace(/\s*```\s*$/i, "");
  t = t.replace(/[\u0000-\u001F\u007F]/g, " ");
  t = t.replace(/\s+/g, " ").trim();
  return t;
}

function extractLikelyJsonObject(text) {
  const s = String(text ?? "");
  const first = s.indexOf("{");
  const last = s.lastIndexOf("}");
  if (first >= 0 && last > first) return s.slice(first, last + 1);
  return s;
}

function removeTrailingCommas(jsonText) {
  return jsonText.replace(/,\s*([}\]])/g, "$1");
}

function safeJsonParse(raw) {
  const t0 = sanitizeModelText(raw);
  const t1 = extractLikelyJsonObject(t0);
  const t2 = removeTrailingCommas(t1);
  try {
    return { ok: true, data: JSON.parse(t2), used: t2 };
  } catch (e1) {
    let t3 = t2.trim();
    if ((t3.startsWith('"') && t3.endsWith('"')) || (t3.startsWith("'") && t3.endsWith("'"))) {
      t3 = t3.slice(1, -1);
    }
    t3 = removeTrailingCommas(extractLikelyJsonObject(t3));
    try {
      return { ok: true, data: JSON.parse(t3), used: t3 };
    } catch (e2) {
      return { ok: false, error: e2, used: t3 };
    }
  }
}

function normalizeName(s) {
  return String(s ?? "").replace(/[\u0000-\u001F\u007F]/g, " ").replace(/\s+/g, " ").trim();
}

function stripPackagingWords(s) {
  let t = String(s || "").trim();
  if (!t) return t;
  const patterns = [
    /\b(pack|box|bag|bottle|can|cup|pcs|piece|pieces)\b/gi,
    /\b(ml|l|g|kg)\b/gi,
    /\b(x|×)\s*\d+\b/gi,
  ];
  for (const p of patterns) t = t.replace(p, " ");
  return t.replace(/\s+/g, " ").trim();
}

function looksTooGeneric(name) {
  const n = String(name || "").toLowerCase().trim();
  const genericSet = new Set([
    "probiotic drink",
    "yogurt drink",
    "milk drink",
    "soft drink",
    "soda",
    "juice",
    "tea",
    "water",
    "snack",
    "chips",
    "cookie",
    "biscuit",
    "candy",
    "chocolate",
    "noodles",
  ]);
  return genericSet.has(n) || n.length <= 4;
}

function refineName(rawGeneric, rawSpecific) {
  const generic = String(rawGeneric || "").trim();
  const specific = stripPackagingWords(rawSpecific);

  if (generic && !looksTooGeneric(generic)) return generic;
  if (specific) return specific;
  return generic;
}

function normalizeUnit(s) {
  const u = String(s ?? "").trim().toLowerCase();
  if (!u) return "pcs";
  if (u === "piece" || u === "pieces" || u === "pc") return "pcs";
  if (u === "liter" || u === "litre") return "l";
  if (u === "milliliter" || u === "millilitre") return "ml";
  return u;
}

function normalizeStorageLocation(s) {
  const v = String(s ?? "fridge").trim().toLowerCase();
  if (v === "freezer") return "freezer";
  if (v === "pantry") return "pantry";
  return "fridge";
}

function looksNonFood(name) {
  const n = name.toLowerCase();
  const keywords = ["taschentuch", "tuch", "staubtuch", "reinigung", "putz", "müll", "tragetasche", "beutel", "haushalt", "clean", "tissue", "bag", "detergent", "soap", "shampoo", "toilet", "pfand", "deposit"];
  return keywords.some((k) => n.includes(k));
}

function mergeDuplicates(items) {
  const map = new Map();
  for (const it of items) {
    // 这里 Key 不再包含具体品牌名，因为 item.name 已经是 genericName 了，这有助于更好地合并同类项
    const key = `${it.name.toLowerCase()}|${it.unit}|${it.storageLocation}`;
    if (!map.has(key)) {
      map.set(key, { ...it });
      continue;
    }
    const prev = map.get(key);
    prev.quantity = (Number(prev.quantity) || 0) + (Number(it.quantity) || 0);
    prev.shelfLifeDays = Math.min(365, Math.max(1, Math.round((prev.shelfLifeDays + it.shelfLifeDays) / 2)));
    prev.confidence = Math.max(prev.confidence ?? 0, it.confidence ?? 0);
    if (it.predictedExpiry && prev.predictedExpiry) {
      prev.predictedExpiry = it.predictedExpiry < prev.predictedExpiry ? it.predictedExpiry : prev.predictedExpiry;
    }
    if (prev.category === "other" && it.category && it.category !== "other") {
      prev.category = it.category;
    }
    map.set(key, prev);
  }
  return Array.from(map.values());
}

async function repairJsonWithModel(rawText) {
  const repairPrompt = `
You are a strict JSON repair tool.
Task:
- Convert the following text into a VALID JSON object.
- Output ONLY the JSON object (no markdown, no comments).
- Keep this schema exactly:
{
  "purchaseDate": "YYYY-MM-DD" | null,
  "items": [
    {
      "name": string,
      "genericName": string,
      "quantity": number,
      "unit": string,
      "storageLocation": "fridge" | "freezer" | "pantry",
      "shelfLifeDays": integer,
      "category": string,
      "confidence": number
    }
  ]
}
Rules:
- No trailing commas.
- Remove any non-JSON text.
- If any item field is missing, fill conservatively.
`.trim();

  // 注意：这里改回了标准的 client.chat.completions.create，因为 client.responses.create 不是标准 SDK 方法
  // 如果你使用的是特殊 SDK 版本，请改回原样
  const resp = await client.chat.completions.create({
    model: "gpt-4o-mini", // 推荐使用 gpt-4o-mini 替代 gpt-4.1-mini
    messages: [
      { role: "system", content: repairPrompt },
      { role: "user", content: `TEXT_TO_REPAIR:\n${String(rawText ?? "").slice(0, 20000)}` },
    ],
    temperature: 0,
    response_format: { type: "json_object" },
    max_tokens: 2000,
  });
  return extractOutputText(resp);
}

// ---------- handler ----------
export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    if (!process.env.OPENAI_API_KEY) return res.status(500).json({ error: "Missing OPENAI_API_KEY" });

    const body = await readBody(req);
    const modeRaw = (body.mode || "receipt").toString().trim().toLowerCase();
    const mode = modeRaw === "fridge" ? "fridge" : "receipt";

    const images = [];
    const one = toDataUrl(body.imageBase64);
    if (one) images.push(one);
    if (Array.isArray(body.imagesBase64)) {
      for (const b64 of body.imagesBase64) {
        const url = toDataUrl(b64);
        if (url) images.push(url);
      }
    }
    if (typeof body.imageUrl === "string" && body.imageUrl.trim()) images.push(body.imageUrl.trim());
    if (Array.isArray(body.imageUrls)) {
      for (const u of body.imageUrls) {
        if (typeof u === "string" && u.trim()) images.push(u.trim());
      }
    }

    if (images.length === 0) return res.status(400).json({ error: "Missing imageBase64 / imageUrl" });

    const instruction = `
You are an OCR+inventory assistant.
Goal: Extract a clean inventory list from the image (mode="${mode}").

CRITICAL - NAME STANDARDIZATION:
For every item detected, you MUST populate "genericName" with the **generic ingredient name only**.
- REMOVE all brand names (e.g., "Haitian", "Heinz", "Nestle").
- REMOVE packaging types if irrelevant (e.g. "Pack of", "Bag").
- KEEP the core food identity.

Examples:
- "Haitian Light Soy Sauce" -> genericName: "Soy Sauce"
- "Organic Baby Spinach" -> genericName: "Spinach"
- "Coca Cola Zero Sugar" -> genericName: "Cola"
- "Lay's Potato Chips" -> genericName: "Potato Chips"
- "Kellogg's Corn Flakes" -> genericName: "Corn Flakes"

IMPORTANT:
- ONLY include edible FOOD and DRINK items.
- EXCLUDE household/non-food items (tissues, cleaning products, Pfand/deposit).

Accuracy rules:
1) Frozen items MUST be "freezer".
2) Dry shelf-stable items SHOULD be "pantry".
3) Fresh meat/fish/dairy SHOULD be "fridge".
4) If uncertain, choose the SAFER storage: frozen -> freezer; shelf-stable -> pantry; else -> fridge.

Output JSON ONLY with this exact shape:
{
  "purchaseDate": "YYYY-MM-DD" | null,
  "items": [
    {
      "name": string,         // The full text as seen on receipt/image (for reference)
      "genericName": string,  // THE CLEAN, BRAND-FREE INGREDIENT NAME
      "quantity": number,
      "unit": string,
      "storageLocation": "fridge" | "freezer" | "pantry",
      "shelfLifeDays": integer,
      "category": string,
      "confidence": number
    }
  ]
}

Constraints:
- Return ONLY valid JSON. No markdown or commentary.
- shelfLifeDays must be conservative (Max 365).
- HARD LIMIT: output at most 40 items.
`.trim();

    const messages = [
      {
        role: "user",
        content: [{ type: "text", text: instruction }],
      },
    ];

    for (const url of images) {
      messages[0].content.push({ type: "image_url", image_url: { url: url } });
    }

    // 使用标准的 chat.completions.create
    const resp = await client.chat.completions.create({
      model: "gpt-4o-mini", // 推荐使用最新的 mini 模型
      messages: messages,
      temperature: 0,
      response_format: { type: "json_object" },
      max_tokens: 2400,
    });

    let raw = extractOutputText(resp);
    if (!raw) return res.status(500).json({ error: "No text output from model" });

    let parsed = safeJsonParse(raw);
    if (!parsed.ok) {
      const repaired = await repairJsonWithModel(raw);
      if (repaired) {
        raw = repaired;
        parsed = safeJsonParse(raw);
      }
    }

    if (!parsed.ok) return res.status(500).json({ error: "Model returned invalid JSON" });

    const data = parsed.data;
    const todayOut = new Date();
    todayOut.setHours(0, 0, 0, 0);
    let purchaseDateOut = data?.purchaseDate ? (parseYYYYMMDD(data.purchaseDate) ?? todayOut) : todayOut;

    const itemsIn = Array.isArray(data?.items) ? data.items : [];
    let fixedItems = itemsIn
      .map((it) => {
        // 核心修改：优先使用 genericName (不带商标的名称) 作为最终的 name
        const rawGeneric = normalizeName(it?.genericName);
        const rawSpecific = normalizeName(it?.name);
        
        // 如果 AI 提取了通用名，就用通用名；否则回退到原始名称
        const finalName = refineName(rawGeneric, rawSpecific);

        if (!finalName || looksNonFood(finalName)) return null;

        const quantity = typeof it?.quantity === "number" && Number.isFinite(it.quantity) ? it.quantity : 1;
        const shelfLifeDays = clampInt(it?.shelfLifeDays, 1, 365, 7);
        let predictedExpiryDate = addDays(purchaseDateOut, shelfLifeDays);
        if (predictedExpiryDate < purchaseDateOut) predictedExpiryDate = purchaseDateOut;

        return {
          name: finalName, // 这里现在只包含无商标的食材名
          // genericName: rawGeneric, // 可选：如果前端不需要展示原始识别名，可以不返回
          quantity,
          unit: normalizeUnit(it?.unit),
          storageLocation: normalizeStorageLocation(it?.storageLocation),
          shelfLifeDays,
          predictedExpiry: ymd(predictedExpiryDate),
          category: normalizeName(it?.category) || "other",
          confidence: clampFloat(it?.confidence, 0, 1, 0.2),
        };
      })
      .filter(Boolean);

    fixedItems = mergeDuplicates(fixedItems);
    fixedItems.sort((a, b) => (b.confidence ?? 0) - (a.confidence ?? 0));
    fixedItems = fixedItems.slice(0, 60);

    return res.status(200).json({
      purchaseDate: ymd(purchaseDateOut),
      items: fixedItems,
    });
  } catch (err) {
    console.error("scan-inventory API error:", err);
    return res.status(500).json({ error: err?.message || "Internal server error" });
  }
}
