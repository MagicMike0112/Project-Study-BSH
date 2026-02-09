// api/parse-ingredient.js
import OpenAI from "openai";
import { applyCors, handleOptions } from "./_lib/cors.js";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const OPENAI_TIMEOUT_MS = 15000;
const ALLOWED_UNITS = new Set(["pcs", "kg", "g", "L", "ml", "pack", "box", "cup"]);

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

function normalizeUnit(raw) {
  const unit = String(raw ?? "pcs").trim().toLowerCase();
  switch (unit) {
    case "l":
    case "liter":
    case "litre":
    case "liters":
    case "litres":
      return "L";
    case "ml":
      return "ml";
    case "kg":
      return "kg";
    case "g":
    case "gram":
    case "grams":
      return "g";
    case "pack":
    case "packs":
      return "pack";
    case "box":
    case "boxes":
      return "box";
    case "cup":
    case "cups":
      return "cup";
    case "pc":
    case "piece":
    case "pieces":
    case "pcs":
    default:
      return "pcs";
  }
}

function normalizeLocation(raw) {
  const v = String(raw ?? "fridge").trim().toLowerCase();
  if (v === "freezer") return "freezer";
  if (v === "pantry") return "pantry";
  return "fridge";
}

function normalizeDate(raw) {
  if (typeof raw !== "string") return null;
  const v = raw.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(v)) return null;
  return v;
}

function sanitizeItem(item) {
  const name = String(item?.name ?? "").trim();
  if (!name) return null;
  const genericName = String(item?.genericName ?? name).trim();
  const quantityNum = Number(item?.quantity);
  const quantity = Number.isFinite(quantityNum) && quantityNum > 0 ? quantityNum : 1;
  const unit = normalizeUnit(item?.unit);
  const storageLocation = normalizeLocation(item?.storageLocation);
  const predictedExpiry = normalizeDate(item?.predictedExpiry);
  return {
    name,
    genericName,
    quantity,
    unit: ALLOWED_UNITS.has(unit) ? unit : "pcs",
    storageLocation,
    predictedExpiry,
  };
}

function sanitizeSingle(payload) {
  const item = sanitizeItem(payload);
  if (!item) return null;
  return item;
}

function pickItemArray(payload) {
  if (Array.isArray(payload)) return payload;
  if (!payload || typeof payload !== "object") return [];

  const directKeys = ["items", "inventoryList", "list", "ingredients", "ingredientList"];
  for (const key of directKeys) {
    if (Array.isArray(payload[key])) return payload[key];
  }

  const nested = payload.data;
  if (nested && typeof nested === "object") {
    for (const key of directKeys) {
      if (Array.isArray(nested[key])) return nested[key];
    }
  }

  return [];
}

function sanitizeList(payload) {
  const arr = pickItemArray(payload);
  const items = arr.map(sanitizeItem).filter(Boolean);
  return {
    items,
    // compatibility field for older/frontends expecting this key
    inventoryList: items,
  };
}

function getSystemPrompt(isListMode) {
  const today = new Date().toISOString().slice(0, 10);
  const commonRules = `
1. Quantity defaults to 1 when missing.
2. Unit must be one of: ["pcs", "kg", "g", "L", "ml", "pack", "box", "cup"].
3. Storage location must be one of: "fridge" | "freezer" | "pantry".
4. Keep "name" as user-facing item text and "genericName" as normalized ingredient type.
5. Predict "predictedExpiry" using YYYY-MM-DD format and today's date (${today}).
`;

  if (isListMode) {
    return `
You are a kitchen inventory parser.
Return STRICT JSON with this shape:
{
  "items": [
    {
      "name": string,
      "genericName": string,
      "quantity": number,
      "unit": "pcs" | "kg" | "g" | "L" | "ml" | "pack" | "box" | "cup",
      "storageLocation": "fridge" | "freezer" | "pantry",
      "predictedExpiry": "YYYY-MM-DD"
    }
  ]
}
${commonRules}
`;
  }

  return `
You are a kitchen inventory parser.
Return STRICT JSON with this shape:
{
  "name": string,
  "genericName": string,
  "quantity": number,
  "unit": "pcs" | "kg" | "g" | "L" | "ml" | "pack" | "box" | "cup",
  "storageLocation": "fridge" | "freezer" | "pantry",
  "predictedExpiry": "YYYY-MM-DD"
}
${commonRules}
`;
}

function withTimeout(promise, timeoutMs) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error("OpenAI request timeout")), timeoutMs),
    ),
  ]);
}

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    if (!process.env.OPENAI_API_KEY) {
      return res.status(500).json({ error: "Missing OPENAI_API_KEY" });
    }

    const body = await readBody(req);
    const text = String(body?.text ?? "").trim();
    const expectList = body?.expectList === true;

    if (!text || text.length < 2) {
      return res.status(400).json({ error: "Text is too short" });
    }

    const response = await withTimeout(
      client.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: getSystemPrompt(expectList) },
          { role: "user", content: text },
        ],
        response_format: { type: "json_object" },
        temperature: 0.1,
        max_tokens: expectList ? 700 : 350,
      }),
      OPENAI_TIMEOUT_MS,
    );

    const content = response.choices?.[0]?.message?.content;
    if (!content) {
      return res.status(502).json({ error: "No response from AI" });
    }

    let parsed;
    try {
      parsed = JSON.parse(content);
    } catch {
      return res.status(502).json({ error: "Failed to parse AI response" });
    }

    if (expectList) {
      const out = sanitizeList(parsed);
      return res.status(200).json(out);
    }

    const single = sanitizeSingle(parsed);
    if (!single) {
      return res.status(422).json({ error: "No valid item parsed" });
    }
    return res.status(200).json(single);
  } catch (err) {
    const message = err?.message || "Internal server error";
    const status = message.includes("timeout") ? 504 : 500;
    console.error("parse-ingredient API error:", err);
    return res.status(status).json({ error: message });
  }
}
