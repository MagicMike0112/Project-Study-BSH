// api/predict-expiry.js
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export default async function handler(req, res) {
  if (req.method && req.method !== "POST") {
    res.statusCode = 405;
    res.setHeader("Allow", "POST");
    res.end("Method not allowed");
    return;
  }

  // 兼容：在 Vercel 上 req.body 通常已经是 object；
  // 本地 node 直跑时可能是字符串或 undefined
  let body = req.body || {};
  try {
    if (typeof body === "string") {
      body = JSON.parse(body || "{}");
    }
  } catch (e) {
    res.statusCode = 400;
    res.end("Invalid JSON body");
    return;
  }

  const {
    name,
    location,
    purchasedDate,
    openedDate,
    bestBeforeDate,
  } = body;

  if (!name || !location || !purchasedDate) {
    res.statusCode = 400;
    res.setHeader("Content-Type", "application/json");
    res.end(
      JSON.stringify({
        error:
          "Missing required fields. name, location, purchasedDate are required.",
      })
    );
    return;
  }

  try {
    const systemPrompt = `
You are a cautious food safety assistant.
User will give you:
- ingredient name
- storage location (fridge, freezer, pantry)
- purchased date
- optionally opened date and best-before date

Your task:
1. Estimate a conservative but realistic "suggested expiry" date for HOME USE (not restaurant).
2. Always be STRICTER than the package best-before date if you have doubts (earlier date is safer).
3. Take into account:
   - ingredient type (e.g. raw meat vs. dried pasta)
   - storage location
   - whether it is opened
   - time since purchase

CRITICAL RULES:
- Output ONLY valid JSON, no markdown, no comments.
- The JSON MUST be of the exact shape:
  {
    "suggestedExpiry": "YYYY-MM-DD",
    "reason": "short explanation"
  }
- "suggestedExpiry" MUST be a calendar date string in ISO format (YYYY-MM-DD).
- If the input already contains a clear best-before date but your estimate would be later,
  you should prefer EARLIER of the two dates (i.e., be more conservative) when deciding "suggestedExpiry".
`;

    const userPayload = {
      name,
      location,
      purchasedDate,
      openedDate: openedDate || null,
      bestBeforeDate: bestBeforeDate || null,
    };

    const response = await client.responses.create({
      model: "gpt-4.1-mini",
      input: [
        {
          role: "system",
          content: systemPrompt,
        },
        {
          role: "user",
          content:
            "Here is the food item info in JSON. Respond ONLY with the JSON as specified:\n" +
            JSON.stringify(userPayload),
        },
      ],
    });

    // 新版 SDK：结果在 output[0].content[0].text
    const output = response.output?.[0]?.content?.[0]?.text;
    if (!output) {
      throw new Error("No text output from model");
    }

    let parsed;
    try {
      parsed = JSON.parse(output);
    } catch (e) {
      throw new Error("Model did not return valid JSON: " + output);
    }

    // 基础校验
    if (
      !parsed ||
      typeof parsed.suggestedExpiry !== "string" ||
      !parsed.suggestedExpiry.match(/^\d{4}-\d{2}-\d{2}$/)
    ) {
      throw new Error("suggestedExpiry is missing or invalid: " + output);
    }

    res.statusCode = 200;
    res.setHeader("Content-Type", "application/json");
    res.end(
      JSON.stringify({
        suggestedExpiry: parsed.suggestedExpiry,
        reason: parsed.reason || "",
      })
    );
  } catch (err) {
    console.error("predict-expiry error:", err);
    res.statusCode = 500;
    res.setHeader("Content-Type", "application/json");
    res.end(
      JSON.stringify({
        error: "Failed to predict expiry",
        detail: String(err),
      })
    );
  }
}
