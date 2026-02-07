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
  if (resp.choices && Array.isArray(resp.choices) && resp.choices[0]?.message?.content) {
    return resp.choices[0].message.content.trim();
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

// 检查是否是过于笼统的词，如果是，我们在后续逻辑中会倾向于替换它
function looksTooGeneric(name) {
  const n = String(name || "").toLowerCase().trim();
  const genericSet = new Set([
    "food", "item", "grocery", "groceries", "goods",
    "snack", "snacks", "beverage", "drink", "product"
  ]);
  return genericSet.has(n) || n.length < 2;
}

function normalizeUnit(s) {
  const u = String(s ?? "").trim().toLowerCase();
  if (!u) return "pcs";
  if (u === "piece" || u === "pieces" || u === "pc") return "pcs";
  if (u === "liter" || u === "litre") return "l";
  if (u === "milliliter" || u === "millilitre") return "ml";
  if (u === "gram" || u === "grams") return "g";
  if (u === "kilogram" || u === "kilograms") return "kg";
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
    // 使用具体名称+通用名作为 Key，确保不同品牌不被误合并，但完全相同的会被合并
    const key = `${it.name.toLowerCase()}|${it.genericName.toLowerCase()}|${it.unit}|${it.storageLocation}`;
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
- Convert the text into VALID JSON.
- Schema:
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
- Remove non-JSON text.
`.trim();

  const resp = await client.chat.completions.create({
    model: "gpt-4o-mini",
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

  // ---------------- PROMPT OPTIMIZATION ----------------
  const instruction = `
You are an advanced Inventory & Receipt Scanner AI.
Goal: Extract inventory items from the image (mode="${mode}").
Output Language: English ONLY. Translate if needed.

*** CRITICAL NAME EXTRACTION RULES ***
For each item, you MUST extract TWO fields:
1. "name": The SPECIFIC product name/brand exactly as seen (e.g., "Lays Classic", "Oreo Strawberry", "Heinz Ketchup").
2. "genericName": The GENERAL BUT SPECIFIC food type (e.g., "Potato Chips", "Sandwich Biscuit", "Tomato Ketchup").

*** FORBIDDEN GENERIC TERMS ***
Do NOT use lazy, high-level categories for "genericName".
- BAD: "Snack", "Food", "Item", "Drink", "Groceries", "Vegetable".
- GOOD: "Potato Chips", "Chocolate Bar", "Soda", "Orange Juice", "Spinach".

Examples:
- Input: "Doritos Nacho Cheese"
  -> name: "Doritos Nacho Cheese", genericName: "Tortilla Chips" (NOT "Snack")
- Input: "Tropicana Orange"
  -> name: "Tropicana Orange", genericName: "Orange Juice" (NOT "Drink")
- Input: "Ritz Crackers"
  -> name: "Ritz Crackers", genericName: "Crackers" (NOT "Biscuit" or "Snack")

Filtering:
- EXCLUDE non-food items (tissue, soap, bags, deposit/pfand).
- INCLUDE edible food and drinks.

Storage Rules:
- Frozen items -> "freezer"
- Dry/shelf-stable -> "pantry"
- Meat/Dairy/Fresh Veg -> "fridge"

Output JSON Structure:
{
  "purchaseDate": "YYYY-MM-DD" | null,
  "items": [
    {
      "name": string,         // Specific Name (Brand + Product)
      "genericName": string,  // Specific Category Name (No brands, no "Snack")
      "quantity": number,
      "unit": string,
      "storageLocation": "fridge" | "freezer" | "pantry",
      "shelfLifeDays": integer,
      "category": string,     // High level category (e.g. "Snacks", "Dairy")
      "confidence": number
    }
  ]
}
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

    const resp = await client.chat.completions.create({
      model: "gpt-4o-mini",
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
        // 提取名称
        const specificName = normalizeName(it?.name);
        let genericName = normalizeName(it?.genericName);

        // 如果 AI 还是返回了 "Snack" 这种词，或者是空的，尝试用 specificName 兜底（去掉品牌词逻辑太复杂，前端展示时用户可以改）
        if (!genericName || looksTooGeneric(genericName)) {
           // 如果 genericName 太泛，但 specificName 也是泛指（比如小票上就写着 "SNACK"），那也没办法
           // 否则，暂且用 specificName 充当 genericName，或者保持空让前端处理
           genericName = genericName || specificName;
        }

        // 最终检查：如果连 specificName 都没有，就跳过
        if (!specificName && !genericName) return null;
        
        // 最终 name 字段使用 AI 识别的具体名称
        const finalName = specificName || genericName; 
        // 最终 genericName 字段
        const finalGeneric = genericName;

        if (looksNonFood(finalName)) return null;

        const quantity = typeof it?.quantity === "number" && Number.isFinite(it.quantity) ? it.quantity : 1;
        const shelfLifeDays = clampInt(it?.shelfLifeDays, 1, 365, 7);
        let predictedExpiryDate = addDays(purchaseDateOut, shelfLifeDays);
        if (predictedExpiryDate < purchaseDateOut) predictedExpiryDate = purchaseDateOut;

        return {
          name: finalName,           // 具体名称 (Lays Classic)
          genericName: finalGeneric, // 通用名称 (Potato Chips)
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