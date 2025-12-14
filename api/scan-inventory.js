// api/scan-inventory.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// 允许的前端域名（按需加）
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

// 从 Responses API 里安全提取 output_text
function extractOutputText(resp) {
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

// 让“看起来像 JSON 但 parse 会炸”的输出尽量可解析
function sanitizeModelText(s) {
  let t = String(s ?? "");

  // 去 BOM
  t = t.replace(/^\uFEFF/, "");

  // 去代码块包裹
  t = t
    .replace(/^\s*```json\s*/i, "")
    .replace(/^\s*```\s*/i, "")
    .replace(/\s*```\s*$/i, "");

  // 移除所有控制字符（含换行/回车），避免 JSON.parse 被不可见字符搞崩
  t = t.replace(/[\u0000-\u001F\u007F]/g, " ");

  // 压缩多空格
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
  // 去掉 ,} 和 ,]
  return jsonText.replace(/,\s*([}\]])/g, "$1");
}

function safeJsonParse(raw) {
  const t0 = sanitizeModelText(raw);
  const t1 = extractLikelyJsonObject(t0);
  const t2 = removeTrailingCommas(t1);

  try {
    return { ok: true, data: JSON.parse(t2), used: t2 };
  } catch (e1) {
    // 再尝试一次：更“狠”的清理（有些模型会输出多余前后引号）
    let t3 = t2.trim();
    if (
      (t3.startsWith('"') && t3.endsWith('"')) ||
      (t3.startsWith("'") && t3.endsWith("'"))
    ) {
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
  return String(s ?? "")
    .replace(/[\u0000-\u001F\u007F]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeUnit(s) {
  const u = String(s ?? "").trim().toLowerCase();
  if (!u) return "pcs";
  if (u === "piece" || u === "pieces") return "pcs";
  if (u === "pc") return "pcs";
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
  // 电子小票里常见的非食物：纸巾/清洁/袋子/家居
  const keywords = [
    "taschentuch",
    "tuch",
    "staubtuch",
    "reinigung",
    "putz",
    "müll",
    "tragetasche",
    "beutel",
    "haushalt",
    "clean",
    "tissue",
    "bag",
    "detergent",
    "soap",
    "shampoo",
    "toilet",
    "pfand",
    "deposit",
  ];
  return keywords.some((k) => n.includes(k));
}

function mergeDuplicates(items) {
  // key: name+unit+location（name 用 lower）
  const map = new Map();
  for (const it of items) {
    const key = `${it.name.toLowerCase()}|${it.unit}|${it.storageLocation}`;
    if (!map.has(key)) {
      map.set(key, { ...it });
      continue;
    }
    const prev = map.get(key);
    prev.quantity = (Number(prev.quantity) || 0) + (Number(it.quantity) || 0);
    prev.shelfLifeDays = Math.min(
      365,
      Math.max(1, Math.round((prev.shelfLifeDays + it.shelfLifeDays) / 2))
    );
    prev.confidence = Math.max(prev.confidence ?? 0, it.confidence ?? 0);
    // predictedExpiry 用更“保守”(更早) 的那个
    if (it.predictedExpiry && prev.predictedExpiry) {
      prev.predictedExpiry =
        it.predictedExpiry < prev.predictedExpiry ? it.predictedExpiry : prev.predictedExpiry;
    }
    // category 保留更具体的（非 other）
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
- If purchaseDate is unknown, use null.
- If any item field is missing, fill conservatively (quantity=1, unit="pcs", storageLocation="fridge", shelfLifeDays=7, category="other", confidence=0.2).
- Names must not contain newlines; use normal spaces.
`.trim();

  const resp = await client.responses.create({
    model: "gpt-4.1-mini",
    input: [
      {
        role: "user",
        content: [
          { type: "input_text", text: repairPrompt },
          { type: "input_text", text: `TEXT_TO_REPAIR:\n${String(rawText ?? "").slice(0, 20000)}` },
        ],
      },
    ],
    temperature: 0,
    text: { format: { type: "json_object" } },
    max_output_tokens: 1800,
  });

  return extractOutputText(resp);
}

// ---------- handler ----------
export default async function handler(req, res) {
  // CORS
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    if (!process.env.OPENAI_API_KEY) {
      return res.status(500).json({ error: "Missing OPENAI_API_KEY" });
    }

    const body = await readBody(req);

    const modeRaw = (body.mode || "receipt").toString().trim().toLowerCase();
    const mode = modeRaw === "fridge" ? "fridge" : "receipt";

    // 支持单张或多张（base64）
    const images = [];
    const one = toDataUrl(body.imageBase64);
    if (one) images.push(one);

    if (Array.isArray(body.imagesBase64)) {
      for (const b64 of body.imagesBase64) {
        const url = toDataUrl(b64);
        if (url) images.push(url);
      }
    }

    // 兼容：直接传图片 URL（建议：先把图上传到 Supabase Storage，再传 URL，避免 413）
    if (typeof body.imageUrl === "string" && body.imageUrl.trim()) {
      images.push(body.imageUrl.trim());
    }
    if (Array.isArray(body.imageUrls)) {
      for (const u of body.imageUrls) {
        if (typeof u === "string" && u.trim()) images.push(u.trim());
      }
    }

    if (images.length === 0) {
      return res.status(400).json({ error: "Missing imageBase64 / imageUrl" });
    }

    // 提示词：更“短输出 + 更稳 JSON + 只要可食用”
    const instruction = `
You are an OCR+inventory assistant.

The user uploads an image.
- mode="receipt": a shopping receipt (may contain purchase date)
- mode="fridge": a photo of fridge/shelf contents (no purchase date on image usually)

Goal:
Extract a clean inventory list and recommend best storage location (fridge/freezer/pantry).
Also estimate shelf-life in DAYS counted FROM purchase date (receipt date) if available; otherwise from TODAY.

IMPORTANT:
- ONLY include edible FOOD and DRINK items.
- EXCLUDE household/non-food items (tissues, bags, cleaning products, etc.), and exclude deposit lines (Pfand/deposit).

Accuracy rules:
1) Frozen items MUST be "freezer". Examples: frozen, tiefkühl, TK, ice cream, frozen dumplings, frozen fish, frozen meat, frozen vegetables.
2) Dry shelf-stable items SHOULD be "pantry". Examples: rice, noodles, pasta, flour, sugar, salt, spices, canned goods (UNOPENED), sauces (UNOPENED), snacks, soda bottles/cans.
3) Fresh meat/fish/dairy/ready-to-eat chilled items SHOULD be "fridge" unless clearly frozen.
4) If uncertain, choose the SAFER storage:
   - If it looks like frozen -> freezer
   - Else if shelf-stable -> pantry
   - Else -> fridge

Output JSON ONLY with this exact shape:
{
  "purchaseDate": "YYYY-MM-DD" | null,
  "items": [
    {
      "name": string,
      "quantity": number,
      "unit": string,
      "storageLocation": "fridge" | "freezer" | "pantry",
      "shelfLifeDays": integer,   // 1..365
      "category": string,
      "confidence": number        // 0..1
    }
  ]
}

Constraints:
- Return ONLY valid JSON. No markdown. No commentary. No code fences.
- Do NOT include trailing commas.
- "purchaseDate" MUST be null if not visible.
- Each item MUST have a readable name. If unreadable, skip it.
- Merge duplicates if obviously the same product.
- shelfLifeDays must be conservative and realistic. Never exceed 365.
- Names must not contain newlines; use normal spaces.
- HARD LIMIT: output at most 40 items (keep the most confident 40 if more).
`.trim();

    const input = [
      {
        role: "user",
        content: [{ type: "input_text", text: `mode=${mode}\n${instruction}` }],
      },
    ];

    for (const url of images) {
      input[0].content.push({ type: "input_image", image_url: url });
    }

    const resp = await client.responses.create({
      model: "gpt-4.1-mini",
      input,
      temperature: 0,
      text: { format: { type: "json_object" } },
      // ⬆️ 你之前 1200 很容易被小票截断导致 JSON 不闭合 -> parse 必炸
      max_output_tokens: 2400,
    });

    let raw = extractOutputText(resp);
    if (!raw) {
      return res.status(500).json({ error: "No text output from model" });
    }

    // 1) 先本地容错 parse
    let parsed = safeJsonParse(raw);

    // 2) 失败就走“修 JSON”兜底（解决截断/伪 JSON/多余文本）
    if (!parsed.ok) {
      const repaired = await repairJsonWithModel(raw);
      if (repaired) {
        raw = repaired;
        parsed = safeJsonParse(raw);
      }
    }

    if (!parsed.ok) {
      return res.status(500).json({
        error: "Model returned invalid JSON",
        raw: String(raw).slice(0, 6000),
      });
    }

    const data = parsed.data;

    // ---------- normalize purchaseDate ----------
    const todayOut = new Date();
    todayOut.setHours(0, 0, 0, 0);

    let purchaseDateOut = todayOut;
    if (data?.purchaseDate === null) {
      purchaseDateOut = todayOut;
    } else {
      const purchaseDateParsed = parseYYYYMMDD(data?.purchaseDate);
      purchaseDateOut = purchaseDateParsed ?? todayOut;
    }

    // ---------- normalize items ----------
    const itemsIn = Array.isArray(data?.items) ? data.items : [];

    let fixedItems = itemsIn
      .map((it) => {
        const name = normalizeName(it?.name);
        if (!name) return null;

        // 最后再保险：服务端也过滤明显非食物
        if (looksNonFood(name)) return null;

        const quantity =
          typeof it?.quantity === "number" && Number.isFinite(it.quantity)
            ? it.quantity
            : 1;

        const unit = normalizeUnit(it?.unit);

        const storageLocation = normalizeStorageLocation(it?.storageLocation);

        const shelfLifeDays = clampInt(it?.shelfLifeDays, 1, 365, 7);
        const confidence = clampFloat(it?.confidence, 0, 1, 0.2);

        const category = normalizeName(it?.category) || "other";

        let predictedExpiryDate = addDays(purchaseDateOut, shelfLifeDays);
        if (predictedExpiryDate < purchaseDateOut) predictedExpiryDate = purchaseDateOut;

        return {
          name,
          quantity,
          unit,
          storageLocation,
          shelfLifeDays,
          predictedExpiry: ymd(predictedExpiryDate), // YYYY-MM-DD
          category,
          confidence,
        };
      })
      .filter(Boolean);

    // 合并重复项，减少 UI 冗余
    fixedItems = mergeDuplicates(fixedItems);

    // 兜底：最多返回 60 条（防止极端情况撑爆前端）
    fixedItems.sort((a, b) => (b.confidence ?? 0) - (a.confidence ?? 0));
    fixedItems = fixedItems.slice(0, 60);

    return res.status(200).json({
      purchaseDate: ymd(purchaseDateOut), // 永远 YYYY-MM-DD（前端也有兜底）
      items: fixedItems,
    });
  } catch (err) {
    console.error("scan-inventory API error:", err);
    return res.status(500).json({
      error: err?.message || "Internal server error",
    });
  }
}
