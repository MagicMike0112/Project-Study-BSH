const SUPPORTED = new Set(["en", "zh", "de"]);

const DICT = {
  en: {
    methodNotAllowed: "Method not allowed",
    missingOpenAiKey: "Missing OPENAI_API_KEY",
    textTooShort: "Text is too short",
    noResponseFromAi: "No response from AI",
    failedToParseAiResponse: "Failed to parse AI response",
    noValidItemParsed: "No valid item parsed",
    internalServerError: "Internal server error",
    missingImagePayload: "Missing imageBase64 / imageUrl",
    noTextOutputFromModel: "No text output from model",
    modelReturnedInvalidJson: "Model returned invalid JSON",
    llmJsonError: "LLM JSON Error",
    noIngredientsProvided: "No ingredients provided",
    missingRequiredFields: "Missing required fields. name, location, purchasedDate are required.",
    invalidPurchasedDate: "Invalid purchasedDate format. Must be ISO string.",
    failedComputeHei: "Failed to compute HEI score",
    missingSupabaseUrl: "Missing Supabase URL",
  },
  zh: {
    methodNotAllowed: "请求方法不支持",
    missingOpenAiKey: "缺少 OPENAI_API_KEY",
    textTooShort: "文本太短",
    noResponseFromAi: "AI 未返回内容",
    failedToParseAiResponse: "解析 AI 响应失败",
    noValidItemParsed: "未解析到有效条目",
    internalServerError: "服务器内部错误",
    missingImagePayload: "缺少 imageBase64 或 imageUrl",
    noTextOutputFromModel: "模型未输出文本",
    modelReturnedInvalidJson: "模型返回的 JSON 无效",
    llmJsonError: "LLM JSON 解析错误",
    noIngredientsProvided: "未提供食材",
    missingRequiredFields: "缺少必要字段：name、location、purchasedDate",
    invalidPurchasedDate: "purchasedDate 格式无效，需为 ISO 字符串",
    failedComputeHei: "HEI 分数计算失败",
    missingSupabaseUrl: "缺少 Supabase URL",
  },
  de: {
    methodNotAllowed: "Methode nicht erlaubt",
    missingOpenAiKey: "OPENAI_API_KEY fehlt",
    textTooShort: "Text ist zu kurz",
    noResponseFromAi: "Keine Antwort von der KI",
    failedToParseAiResponse: "KI-Antwort konnte nicht geparst werden",
    noValidItemParsed: "Kein gueltiger Eintrag erkannt",
    internalServerError: "Interner Serverfehler",
    missingImagePayload: "imageBase64 oder imageUrl fehlt",
    noTextOutputFromModel: "Modell hat keinen Text ausgegeben",
    modelReturnedInvalidJson: "Modell gab ungueltiges JSON zurueck",
    llmJsonError: "LLM-JSON-Fehler",
    noIngredientsProvided: "Keine Zutaten angegeben",
    missingRequiredFields: "Pflichtfelder fehlen: name, location, purchasedDate",
    invalidPurchasedDate: "Ungueltiges purchasedDate-Format (ISO erforderlich)",
    failedComputeHei: "HEI-Score konnte nicht berechnet werden",
    missingSupabaseUrl: "Supabase-URL fehlt",
  },
};

function fromAcceptLanguage(value) {
  const first = String(value || "").split(",")[0] || "";
  const base = first.trim().split(";")[0].split("-")[0].toLowerCase();
  return base;
}

export function normalizeLocale(input) {
  const raw = String(input || "").trim().toLowerCase();
  if (!raw) return "en";
  const base = raw.split("-")[0];
  return SUPPORTED.has(base) ? base : "en";
}

export function resolveLocale(req, body = {}) {
  const bodyLocale =
    body?.locale ||
    body?.language ||
    body?.lang;
  const headerLocale =
    req?.headers?.["x-app-locale"] ||
    req?.headers?.["accept-language"];
  const picked = bodyLocale || fromAcceptLanguage(headerLocale);
  return normalizeLocale(picked);
}

export function t(locale, key) {
  const safeLocale = normalizeLocale(locale);
  return (
    DICT[safeLocale]?.[key] ??
    DICT.en[key] ??
    key
  );
}

export function languageName(locale) {
  const safeLocale = normalizeLocale(locale);
  if (safeLocale === "zh") return "Simplified Chinese";
  if (safeLocale === "de") return "German";
  return "English";
}
