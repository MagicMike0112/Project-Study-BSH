// api/shop-by-recipe.js
import OpenAI from "openai";
const client = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export default async function handler(req, res) {
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { text, imagesBase64, currentInventory } = req.body;

  const systemPrompt = `
You are a culinary logistics assistant. Your goal is to convert recipes into a structured shopping list.

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

Output Format (JSON ONLY):
{
  "items": [
    { 
      "name": "Ingredient Name", 
      "category": "Category",
      "inStock": boolean,
      "reason": string // e.g., "Found 'Haitian Light Soy Sauce' in inventory"
    }
  ]
}
`.trim();

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

    res.status(200).json(JSON.parse(response.choices[0].message.content));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}