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
  // 兼容 data:image/...;base64,xxxxx
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
  // 有些版本会给 resp.output_text
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

// ---------- handler ----------
export default async function handler(req, res) {
  // CORS
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    if (!process.env.OPENAI_API_KEY) {
      return res.status(500).json({ error: "Missing OPENAI_API_KEY" });
    }

    const body = await readBody(req);

    const modeRaw = (body.mode || "receipt").toString().trim().toLowerCase();
    const mode = modeRaw === "fridge" ? "fridge" : "receipt";

    // 支持单张或多张
    const images = [];
    const one = toDataUrl(body.imageBase64);
    if (one) images.push(one);

    if (Array.isArray(body.imagesBase64)) {
      for (const b64 of body.imagesBase64) {
        const url = toDataUrl(b64);
        if (url) images.push(url);
      }
    }

    if (images.length === 0) {
      return res.status(400).json({ error: "Missing imageBase64" });
    }

    // 提示词：强制输出 JSON，且 storageLocation 必须在 3 个枚举里
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
2) Dry shelf-stable items SHOULD be "pantry". Examples: rice, noodles, pasta, flour, sugar, salt, spices, canned goods (unopened), sauces (unopened), snacks, soda cans/bottles.
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
      "unit": string,                  // e.g. pcs, g, kg, ml, L, pack, box
      "storageLocation": "fridge" | "freezer" | "pantry",
      "shelfLifeDays": integer,        // 1..365, counted FROM purchaseDate (or today if purchaseDate=null)
      "category": string,              // e.g. frozen, dairy, meat, produce, canned, dry, beverage, snack, other
      "confidence": number             // 0..1
    }
  ]
}

Constraints:
- Return ONLY valid JSON. No markdown. No commentary.
- "purchaseDate" MUST be null if not visible.
- Each item MUST have name. If unreadable, skip it.
- Merge duplicates if obviously the same product.
- shelfLifeDays must be conservative and realistic.
- Never exceed 365.
`;

    const input = [
      { role: "user", content: [{ type: "input_text", text: `mode=${mode}\n${instruction}` }] },
    ];

    // 附加图片（多张就多塞几个 input_image）
    for (const url of images) {
      input[0].content.push({ type: "input_image", image_url: url });
    }

    const resp = await client.responses.create({
      model: "gpt-4.1-mini",
      input,
      // 强制 JSON 输出（别用 text 类型，否则你之前会遇到 “No text output” 的坑）
      text: { format: { type: "json_object" } },
      max_output_tokens: 1200,
    });

    const raw = extractOutputText(resp);
    if (!raw) {
      return res.status(500).json({
        error: "No text output from model",
        raw: resp,
      });
    }

    let data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      return res.status(500).json({
        error: "Model returned invalid JSON",
        raw,
      });
    }

    // ---------- normalize purchaseDate ----------
    const todayOut = new Date();
    todayOut.setHours(0, 0, 0, 0);

    const purchaseDateParsed = parseYYYYMMDD(data?.purchaseDate);
    const purchaseDateOut = purchaseDateParsed ?? todayOut;

    // ---------- normalize items ----------
    const itemsIn = Array.isArray(data?.items) ? data.items : [];

    const fixedItems = itemsIn
      .map((it) => {
        const name = (it?.name ?? "").toString().trim();
        if (!name) return null;

        const quantity =
          typeof it.quantity === "number" && Number.isFinite(it.quantity) ? it.quantity : 1;

        const unit = (it?.unit ?? "pcs").toString().trim() || "pcs";

        let storageLocation = (it?.storageLocation ?? "fridge").toString().trim().toLowerCase();
        if (!["fridge", "freezer", "pantry"].includes(storageLocation)) {
          storageLocation = "fridge";
        }

        const shelfLifeDays = clampInt(it?.shelfLifeDays, 1, 365, 7);

        const confidence = clampFloat(it?.confidence, 0, 1, 0);

        const category = (it?.category ?? "other").toString().trim() || "other";

        // 以 purchaseDateOut 为基准推算 predictedExpiry（永不早于 purchaseDateOut）
        let predictedExpiryDate = addDays(purchaseDateOut, shelfLifeDays);
        if (predictedExpiryDate < purchaseDateOut) predictedExpiryDate = purchaseDateOut;

        return {
          name,
          quantity,
          unit,
          storageLocation,
          shelfLifeDays,
          predictedExpiry: ymd(predictedExpiryDate), // YYYY-MM-DD（Flutter DateTime.parse 能吃）
          category,
          confidence,
        };
      })
      .filter(Boolean);

    // 如果模型没识别出任何 item
    if (fixedItems.length === 0) {
      return res.status(200).json({
        purchaseDate: ymd(purchaseDateOut),
        items: [],
      });
    }

    return res.status(200).json({
      purchaseDate: ymd(purchaseDateOut), // 永远 YYYY-MM-DD
      items: fixedItems,
    });
  } catch (err) {
    console.error("scan-inventory API error:", err);
    return res.status(500).json({
      error: err?.message || "Internal server error",
    });
  }
}
