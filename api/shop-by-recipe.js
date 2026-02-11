// api/shop-by-recipe.js
import OpenAI from "openai";
import { applyCors, handleOptions } from "./_lib/cors.js";
import { languageName, resolveLocale, t } from "./_lib/i18n.js";
const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;
  const locale = resolveLocale(req, req.body);
  if (req.method !== "POST") return res.status(405).json({ error: t(locale, "methodNotAllowed") });

  const { text, imagesBase64, currentInventory } = req.body;
  const outputLanguage = languageName(locale);

  const systemPrompt = `
You are a culinary assistant. Your goal is to convert recipes into a structured shopping list and a structured recipe.

**Inventory Awareness & Semantic Matching:**
You will be provided with a list of items currently in the user's kitchen (currentInventory). 
Compare the recipe requirements with this inventory using SEMANTIC UNDERSTANDING.
Important matching rules:
- Brand names: "Haitian Soy Sauce" in inventory matches "Soy Sauce" in recipe.
- Specific types: "Whole Milk" matches "Milk".
- Common seasonings: If user has "Salt", "Sugar", "Olive Oil", mark them as inStock even if used in small amounts.

Instructions:
1. Identify all necessary ingredients and seasonings.
2. For each ingredient, determine if it's likely already in the 'currentInventory'.
3. Assign a category: "Vegetables", "Meat", "Dairy", "Pantry", "Grains", or "Other".
4. For each item, add "isSeasoning" (boolean): true for seasonings/condiments/spices/oils/sauces, false otherwise.
5. Generate a clear recipe using the provided text and any visible steps in images.
6. Infer appliances (e.g., ["oven", "stove", "microwave"]) and ovenTempC if mentioned.
7. Human-facing text fields (reason, title, description, ingredients, steps) must be in ${outputLanguage}.

Output Format (JSON ONLY):
{
  "items": [
    { 
      "name": "Ingredient Name", 
      "category": "Category",
      "isSeasoning": boolean,
      "inStock": boolean,
      "reason": string // e.g., "Found 'Haitian Light Soy Sauce' in inventory"
    }
  ],
  "recipe": {
    "title": "Dish Name",
    "description": "1-2 sentence summary",
    "timeLabel": "30 min",
    "ingredients": ["..."],
    "steps": ["..."],
    "appliances": ["oven"],
    "ovenTempC": 180
  }
}
`.trim();

  const seasoningHint = [
    "salt",
    "sugar",
    "pepper",
    "soy",
    "vinegar",
    "sauce",
    "oil",
    "sesame",
    "chili",
    "paprika",
    "cumin",
    "oregano",
    "basil",
    "spice",
    "seasoning",
    "garlic powder",
    "onion powder",
    "mustard",
    "ketchup",
    "mayonnaise",
    "酱",
    "盐",
    "糖",
    "油",
    "醋",
    "胡椒",
    "香料",
    "调味",
    "gewuerz",
    "gewürz",
    "soße",
    "sosse",
  ];

  function inferSeasoningFromText(name = "", category = "") {
    const n = String(name).toLowerCase();
    const c = String(category).toLowerCase();
    if (c.includes("season") || c.includes("spice") || c.includes("condiment")) return true;
    return seasoningHint.some((k) => n.includes(k));
  }

  function normalizeItems(items) {
    if (!Array.isArray(items)) return [];
    return items
      .map((x) => ({
        name: String(x?.name || "").trim(),
        category: String(x?.category || "Other").trim(),
        inStock: Boolean(x?.inStock),
        reason: String(x?.reason || ""),
        isSeasoning:
          typeof x?.isSeasoning === "boolean"
            ? x.isSeasoning
            : inferSeasoningFromText(x?.name, x?.category),
      }))
      .filter((x) => x.name.length > 0);
  }

  try {
    const userContent = [
      { type: "text", text: `Recipe Content: ${text || "Please see attached images"}` },
      { type: "text", text: `Current Inventory (for matching): ${JSON.stringify(currentInventory || [])}` }
    ];

    if (imagesBase64 && imagesBase64.length > 0) {
      for (const b64 of imagesBase64) {
        userContent.push({
          type: "image_url",
          image_url: { url: b64.startsWith("data:") ? b64 : `data:image/jpeg;base64,${b64}` }
        });
      }
    }

    const response = await client.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userContent }
      ],
      response_format: { type: "json_object" },
    });

    const parsed = JSON.parse(response.choices[0].message.content);
    parsed.items = normalizeItems(parsed.items);
    res.status(200).json(parsed);
  } catch (err) {
    res.status(500).json({ error: err.message || t(locale, "internalServerError") });
  }
}
