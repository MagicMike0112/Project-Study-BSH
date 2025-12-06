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
    const { ingredients, extraIngredients } = req.body;

    if (!ingredients || !Array.isArray(ingredients)) {
      return res.status(400).json({ error: "ingredients must be an array" });
    }

    const allIngredients = [
      ...ingredients,
      ...(extraIngredients || []),
    ].join(", ");

    const prompt = `
You are a cooking assistant that helps reduce food waste.
User has these ingredients (some are expiring soon): ${allIngredients}.
Create 3 recipe ideas.

For each recipe, return a JSON object with:
- id (string)
- title (short dish name)
- timeLabel (e.g. "15 min · 1 pan")
- expiringCount (integer, how many expiring ingredients are used, estimate)
- ingredients (string[] - human readable ingredient lines)
- steps (string[] - 4-6 short steps)
- description (1-2 sentence explanation)

Return ONLY valid JSON array, no extra text.
`;

    const response = await client.chat.completions.create({
      model: "gpt-4.1-mini",
      messages: [
        {
          role: "user",
          content: prompt,
        },
      ],
      response_format: { type: "json_object" },
    });

    const raw = response.choices[0].message.content;
    // 期望 raw 类似： {"recipes":[{...},{...}]}
    let data;
    try {
      data = JSON.parse(raw);
    } catch (e) {
      console.error("JSON parse error:", e, raw);
      return res.status(500).json({ error: "LLM returned invalid JSON" });
    }

    const recipes = data.recipes || data || [];

    return res.status(200).json({ recipes });
  } catch (err) {
    console.error("API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
