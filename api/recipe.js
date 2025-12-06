// api/recipe.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const body = req.body || {};
    const ingredients = Array.isArray(body.ingredients) ? body.ingredients : [];
    const extraIngredients = Array.isArray(body.extraIngredients)
      ? body.extraIngredients
      : [];

    if (ingredients.length === 0 && extraIngredients.length === 0) {
      return res.status(400).json({ error: "No ingredients provided" });
    }

    const all = [...ingredients, ...extraIngredients].join(", ");

    const prompt = `
You are a cooking assistant that helps people reduce food waste.
User has these ingredients (some are expiring soon): ${all}.

Create 3 recipe ideas that:
- Prioritize using the expiring ingredients first.
- Are simple, realistic home-cooking recipes.

For EACH recipe, return a JSON object with fields:
- id (string, short unique id)
- title (short dish name)
- timeLabel (string, e.g. "20 min · 1 pan")
- expiringCount (integer, rough estimate of how many expiring ingredients are used)
- ingredients (string[] - human readable ingredient lines)
- steps (string[] - 4-6 concise steps)
- description (string, 1-2 short sentences)

Return ONLY a JSON object of this shape:
{
  "recipes": [ { ... }, { ... }, { ... } ]
}
No extra commentary.
`;

    const response = await client.chat.completions.create({
      model: "gpt-4.1-mini",
      messages: [
        {
          role: "system",
          content:
            "You are a precise JSON API. Always respond with valid JSON only.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
      response_format: { type: "json_object" },
    });

    const raw = response.choices[0].message.content;
    let data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      console.error("JSON parse error:", e, raw);
      return res.status(500).json({ error: "LLM returned invalid JSON" });
    }

    const recipes = Array.isArray(data.recipes) ? data.recipes : [];

    return res.status(200).json({ recipes });
  } catch (err) {
    console.error("API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
