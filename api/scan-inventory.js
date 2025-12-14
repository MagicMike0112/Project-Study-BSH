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

  // 移除所有控制字符（含换行/回车），避免出现在 JSON string 内导致 JSON.parse 失败
  // 注意：会把“格式化换行”也去掉，但不影响 JSON 正确性
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
  // 统一常见写法
  if (u === "piece" || u === "pieces") return "pcs";
  if (u === "pc") return "pcs";
  if (u === "liter") return "l";
  if (u === "litre") return "l";
  if (u === "milliliter" || u === "millilitre") return "ml";
  return u;
}

// ---------- handler ----------
export default async function handler(req, res) {
  // CORS
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST")
    return res.status(405).json({ error: "Method not allowed" });

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

    // ✅ 额外兼容：直接传图片 URL（可用于你后续把图先上传到 Supabase Storage，避免 413）
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

    // 提示词：更严格，减少“伪 JSON”
    const instruction = `
You are an OCR+inventory assistant.

The user uploads an image.
- mode="receipt": a shopping receipt (may contain purchase date)
- mode="fridge": a photo of fridge/shelf contents (no purchase date on image usually)

Goal:
Extract a clean inventory list and recommend best storage location (fridge/freezer/pantry).
Also estimate shelf-life in DAYS counted FROM purchase date (receipt date) if available; otherwise from TODAY.

IMPORTANT accuracy rules:
1) Frozen items MUST be "freezer". Examples: frozen, tiefkühl, TK, ice cream, frozen dumplings, frozen fish, frozen meat, frozen vegetables.
2) Dry shelf-stable items SHOULD be "pantry". Examples: rice, noodles, pasta, flour, sugar, salt, spices, canned goods (UNOPENED), sauces (UNOPENED), snacks, soda cans/bottles.
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
      "shelfLifeDays": integer,
      "category": string,
      "confidence": number
    }
  ]
}

Constraints:
- Return ONLY valid JSON. No markdown. No commentary. No code fences.
- Do NOT include trailing commas.
- "purchaseDate" MUST be null if not visible.
- Each item MUST have a readable name. If unreadable, skip it.
- Merge duplicates if obviously the same product.
- shelfLifeDays must be conservative and realistic.
- Never exceed 365.
- Names must not contain newlines; use normal spaces.
`.trim();

    const input = [
      {
        role: "user",
        content: [
          { type: "input_text", text: `mode=${mode}\n${instruction}` },
        ],
      },
    ];

    // 附加图片（多张就多塞几个 input_image）
    for (const url of images) {
      input[0].content.push({ type: "input_image", image_url: url });
    }

    const resp = await client.responses.create({
      model: "gpt-4.1-mini",
      input,
      temperature: 0,
      // 强制 JSON 输出
      text: { format: { type: "json_object" } },
      max_output_tokens: 1200,
    });

    const raw = extractOutputText(resp);
    if (!raw) {
      return res.status(500).json({
        error: "No text output from model",
      });
    }

    const parsed = safeJsonParse(raw);
    if (!parsed.ok) {
      return res.status(500).json({
        error: "Model returned invalid JSON",
        raw: raw.slice(0, 6000),
      });
    }

    const data = parsed.data;

    // ---------- normalize purchaseDate ----------
    const todayOut = new Date();
    todayOut.setHours(0, 0, 0, 0);

    // 允许 purchaseDate=null
    let purchaseDateOut = todayOut;
    if (data?.purchaseDate === null) {
      purchaseDateOut = todayOut;
    } else {
      const purchaseDateParsed = parseYYYYMMDD(data?.purchaseDate);
      purchaseDateOut = purchaseDateParsed ?? todayOut;
    }

    // ---------- normalize items ----------
    const itemsIn = Array.isArray(data?.items) ? data.items : [];

    const fixedItems = itemsIn
      .map((it) => {
        const name = normalizeName(it?.name);
        if (!name) return null;

        const quantity =
          typeof it?.quantity === "number" && Number.isFinite(it.quantity)
            ? it.quantity
            : 1;

        const unit = normalizeUnit(it?.unit);

        let storageLocation = String(it?.storageLocation ?? "fridge")
          .trim()
          .toLowerCase();
        if (!["fridge", "freezer", "pantry"].includes(storageLocation)) {
          storageLocation = "fridge";
        }

        const shelfLifeDays = clampInt(it?.shelfLifeDays, 1, 365, 7);
        const confidence = clampFloat(it?.confidence, 0, 1, 0);

        const category = normalizeName(it?.category) || "other";

        // 以 purchaseDateOut 为基准推算 predictedExpiry（永不早于 purchaseDateOut）
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

    return res.status(200).json({
      purchaseDate: ymd(purchaseDateOut), // 永远 YYYY-MM-DD（Flutter 侧已有兜底）
      items: fixedItems,
    });
  } catch (err) {
    console.error("scan-inventory API error:", err);
    return res.status(500).json({
      error: err?.message || "Internal server error",
    });
  }
}
