// api/shop-by-recipe.js
import OpenAI from "openai";

const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// ✅ 调大 body size：否则 base64 图一定炸
export const config = {
  api: {
    bodyParser: {
      sizeLimit: "10mb", // 你可以按需要调到 15mb，但别太夸张
    },
  },
};

// ✅ 允许的前端域名（按需改）
const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";

function setCors(res) {
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

function safeJsonParse(s) {
  try {
    return { ok: true, data: JSON.parse(s) };
  } catch (e) {
    return { ok: false, error: e?.message || "JSON parse failed", raw: s };
  }
}

function normalizeB64ToDataUrl(b64) {
  if (!b64) return null;
  const trimmed = String(b64).trim();
  if (!trimmed) return null;

  // 已经是 data URL 就原样返回（支持 png/jpeg/webp）
  if (trimmed.startsWith("data:image/")) return trimmed;

  // 否则默认当 jpeg（你也可以前端传 mime 再拼）
  return `data:image/jpeg;base64,${trimmed}`;
}

export default async function handler(req, res) {
  setCors(res);

  // ✅ 处理预检
  if (req.method === "OPTIONS") return res.status(200).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    if (!process.env.OPENAI_API_KEY) {
      return res.status(500).json({ error: "Missing OPENAI_API_KEY" });
    }

    const { text, imagesBase64, currentInventory } = req.body || {};

    // ✅ 基本输入校验
    const inventory = Array.isArray(currentInventory) ? currentInventory : [];
    const imagesArr = Array.isArray(imagesBase64) ? imagesBase64 : [];

    // ✅ 控制成本/稳定性：限制图片数量（强烈建议）
    const MAX_IMAGES = 3;
    const pickedImages = imagesArr.slice(0, MAX_IMAGES);

    // ✅ 控制库存长度：太长会浪费 token（按你数据规模调整）
    const MAX_INVENTORY_ITEMS = 200;
    const trimmedInventory = inventory.slice(0, MAX_INVENTORY_ITEMS);

    const systemPrompt = `
You are a culinary logistics assistant. Convert a recipe into a structured shopping list.

Inventory Awareness & Semantic Matching:
- You receive currentInventory: items in the user's kitchen.
- Compare recipe requirements with inventory using semantic understanding.
- Matching rules:
  - Brand names: "Haitian Soy Sauce" matches "Soy Sauce".
  - Specific types: "Whole Milk" matches "Milk".
  - Common seasonings (ONLY if clearly present in inventory): salt, sugar, olive oil, pepper, vinegar.
- Be conservative: if uncertain, set inStock=false.

Instructions:
1) Identify all necessary ingredients and seasonings from the recipe (text + images).
2) For each ingredient, decide if it's likely already in currentInventory.
3) Assign category: ONLY one of ["Vegetables","Meat","Dairy","Pantry","Grains","Other"].
4) reason must explicitly mention the matched inventory item when inStock=true.

Output JSON ONLY:
{
  "items": [
    {
      "name": "Ingredient Name",
      "category": "Vegetables|Meat|Dairy|Pantry|Grains|Other",
      "inStock": true/false,
      "reason": "..."
    }
  ]
}
`.trim();

    const userContent = [
      {
        type: "text",
        text: `Recipe Content: ${text?.trim() ? text.trim() : "Please see attached images"}`,
      },
      {
        type: "text",
        text: `Current Inventory (for matching): ${JSON.stringify(trimmedInventory)}`,
      },
    ];

    // ✅ 图片用 low detail：省 token、快、够用来读菜谱/食材
    for (const b64 of pickedImages) {
      const url = normalizeB64ToDataUrl(b64);
      if (!url) continue;
      userContent.push({
        type: "image_url",
        image_url: { url, detail: "low" },
      });
    }

    const response = await client.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userContent },
      ],
      temperature: 0.2,
      response_format: { type: "json_object" },
    });

    const content = response?.choices?.[0]?.message?.content ?? "{}";
    const parsed = safeJsonParse(content);

    if (!parsed.ok) {
      // ✅ 不要让 parse 失败变 500：把 raw 带回去便于你 debug
      return res.status(200).json({
        items: [],
        warning: "Model returned invalid JSON; check raw field.",
        raw: parsed.raw,
        parseError: parsed.error,
      });
    }

    return res.status(200).json(parsed.data);
  } catch (err) {
    // ✅ 更稳的错误输出
    return res.status(500).json({
      error: err?.message || "Unknown error",
    });
  }
}
