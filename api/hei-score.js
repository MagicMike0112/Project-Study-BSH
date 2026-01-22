// api/hei-score.js
import { supabaseAdmin } from "./_lib/hc.js";

const ALLOWED_ORIGIN = "https://bshpwa.vercel.app";
const FDC_BASE = "https://api.nal.usda.gov/fdc/v1";
const FDC_API_KEY = process.env.USDA_FDC_API_KEY;

const DATA_TYPE_PRIORITY = {
  Foundation: 1,
  "SR Legacy": 2,
  "Survey (FNDDS)": 3,
  Branded: 4,
};

const GRAM_PER_CUP_FRUIT = 150;
const GRAM_PER_CUP_VEG = 150;
const GRAM_PER_CUP_DAIRY = 245;
const GRAM_PER_OZ_GRAIN = 28;
const GRAM_PER_OZ_PROTEIN = 28;

function normalizeQuery(q) {
  return String(q || "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");
}

function hasAny(haystack, needles) {
  return needles.some((n) => haystack.includes(n));
}

async function readBody(req) {
  if (req.headers["content-type"]?.includes("application/json")) return req.body ?? {};
  return await new Promise((resolve, reject) => {
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

async function fetchJson(url, options = {}) {
  const res = await fetch(url, options);
  const text = await res.text();
  if (!res.ok) {
    const err = new Error(`HTTP ${res.status}: ${text}`);
    err.status = res.status;
    throw err;
  }
  return text ? JSON.parse(text) : null;
}

function pickBestFood(foods) {
  if (!Array.isArray(foods) || foods.length === 0) return null;
  return foods
    .slice()
    .sort((a, b) => {
      const pa = DATA_TYPE_PRIORITY[a.dataType] ?? 99;
      const pb = DATA_TYPE_PRIORITY[b.dataType] ?? 99;
      if (pa !== pb) return pa - pb;
      return (b.score ?? 0) - (a.score ?? 0);
    })[0];
}

function getNutrientAmount(food, names) {
  const nutrients = Array.isArray(food?.foodNutrients) ? food.foodNutrients : [];
  for (const n of nutrients) {
    const name = String(n?.nutrient?.name || n?.nutrientName || "").toLowerCase();
    if (!name) continue;
    if (!names.some((k) => name.includes(k))) continue;
    const raw = n?.amount ?? n?.value;
    const unit = String(n?.nutrient?.unitName || n?.unitName || "").toUpperCase();
    if (raw == null || !Number.isFinite(Number(raw))) continue;
    return { amount: Number(raw), unit };
  }
  return null;
}

function toKcal(amount, unit) {
  if (!Number.isFinite(amount)) return 0;
  if (unit === "KCAL") return amount;
  if (unit === "KJ") return amount / 4.184;
  return amount;
}

function toGrams(amount, unit) {
  if (!Number.isFinite(amount)) return 0;
  if (unit === "G") return amount;
  if (unit === "MG") return amount / 1000;
  if (unit === "UG") return amount / 1000000;
  return amount;
}

function classifyFood({ name, category }) {
  const n = String(name || "").toLowerCase();
  const c = String(category || "").toLowerCase();

  const isJuice = hasAny(n, ["juice", "smoothie"]);
  const isFruit =
    hasAny(n, [
      "apple",
      "banana",
      "berry",
      "orange",
      "grape",
      "pear",
      "peach",
      "mango",
      "pineapple",
      "melon",
      "kiwi",
      "cherry",
      "plum",
      "citrus",
    ]) || c.includes("fruit");

  const isVeg =
    hasAny(n, [
      "broccoli",
      "spinach",
      "kale",
      "lettuce",
      "salad",
      "carrot",
      "tomato",
      "pepper",
      "onion",
      "cabbage",
      "cucumber",
      "zucchini",
      "eggplant",
      "cauliflower",
      "celery",
      "squash",
      "potato",
      "sweet potato",
      "mushroom",
    ]) || c.includes("vegetable");

  const isGreensBeans = hasAny(n, [
    "spinach",
    "kale",
    "lettuce",
    "arugula",
    "chard",
    "collard",
    "bean",
    "lentil",
    "chickpea",
    "pea",
    "edamame",
  ]);

  const isWholeGrain = hasAny(n, [
    "whole",
    "oat",
    "oats",
    "quinoa",
    "barley",
    "brown rice",
    "whole wheat",
    "bulgur",
    "farro",
  ]);

  const isGrain = hasAny(n, ["bread", "rice", "pasta", "noodle", "tortilla", "cereal", "cracker"]);
  const isRefinedGrain = !isWholeGrain && isGrain;

  const isDairy =
    hasAny(n, ["milk", "cheese", "yogurt", "kefir", "cream", "curd", "buttermilk"]) ||
    c.includes("dairy");

  const isProtein = hasAny(n, [
    "beef",
    "chicken",
    "pork",
    "egg",
    "tofu",
    "tempeh",
    "fish",
    "salmon",
    "tuna",
    "shrimp",
    "turkey",
    "lamb",
    "bean",
    "lentil",
    "chickpea",
    "nut",
    "seed",
  ]);

  const isSeafoodPlant = hasAny(n, [
    "fish",
    "salmon",
    "tuna",
    "shrimp",
    "shellfish",
    "tofu",
    "tempeh",
    "bean",
    "lentil",
    "chickpea",
    "nut",
    "seed",
  ]);

  return {
    isFruit,
    isWholeFruit: isFruit && !isJuice,
    isVeg,
    isGreensBeans,
    isWholeGrain,
    isRefinedGrain,
    isDairy,
    isProtein,
    isSeafoodPlant,
  };
}

function scoreAdequacy(value, maxStandard, maxScore) {
  if (value <= 0) return 0;
  if (value >= maxStandard) return maxScore;
  return (value / maxStandard) * maxScore;
}

function scoreModeration(value, maxStandard, minStandard, maxScore) {
  if (value <= maxStandard) return maxScore;
  if (value >= minStandard) return 0;
  return ((minStandard - value) / (minStandard - maxStandard)) * maxScore;
}

function scoreRatio(value, minStandard, maxStandard, maxScore) {
  if (value <= minStandard) return 0;
  if (value >= maxStandard) return maxScore;
  return ((value - minStandard) / (maxStandard - minStandard)) * maxScore;
}

async function fetchFoodData(query) {
  if (!FDC_API_KEY) {
    const err = new Error("Missing USDA_FDC_API_KEY");
    err.status = 500;
    throw err;
  }

  const searchUrl = `${FDC_BASE}/foods/search?api_key=${FDC_API_KEY}`;
  const searchBody = JSON.stringify({
    query,
    pageSize: 6,
    dataType: ["Foundation", "SR Legacy", "Survey (FNDDS)", "Branded"],
  });

  const search = await fetchJson(searchUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: searchBody,
  });

  const best = pickBestFood(search?.foods || []);
  if (!best?.fdcId) return null;

  const detailUrl = `${FDC_BASE}/food/${best.fdcId}?api_key=${FDC_API_KEY}`;
  const detail = await fetchJson(detailUrl);
  if (!detail) return null;

  const energy = getNutrientAmount(detail, ["energy"]);
  const sodium = getNutrientAmount(detail, ["sodium"]);
  const addedSugar = getNutrientAmount(detail, ["sugars, added", "added sugars"]);
  const satFat = getNutrientAmount(detail, ["fatty acids, total saturated", "saturated"]);
  const monoFat = getNutrientAmount(detail, ["fatty acids, total monounsaturated", "monounsaturated"]);
  const polyFat = getNutrientAmount(detail, ["fatty acids, total polyunsaturated", "polyunsaturated"]);

  const payload = {
    fdcId: best.fdcId,
    name: detail.description || best.description || query,
    category:
      detail.foodCategory?.description ||
      detail.foodCategory ||
      best.foodCategory ||
      "",
    dataType: detail.dataType || best.dataType || "",
    nutrients: {
      energyKcal: energy ? toKcal(energy.amount, energy.unit) : 0,
      sodiumMg: sodium ? (sodium.unit === "MG" ? sodium.amount : toGrams(sodium.amount, sodium.unit) * 1000) : 0,
      addedSugarG: addedSugar ? toGrams(addedSugar.amount, addedSugar.unit) : 0,
      satFatG: satFat ? toGrams(satFat.amount, satFat.unit) : 0,
      monoFatG: monoFat ? toGrams(monoFat.amount, monoFat.unit) : 0,
      polyFatG: polyFat ? toGrams(polyFat.amount, polyFat.unit) : 0,
    },
  };

  return payload;
}

async function loadCache(queries) {
  const admin = supabaseAdmin();
  try {
    const { data, error } = await admin
      .from("food_nutrition_cache")
      .select("query,payload")
      .in("query", queries);
    if (error) throw error;
    const map = new Map();
    for (const row of data || []) {
      map.set(row.query, row.payload);
    }
    return map;
  } catch (err) {
    console.warn("nutrition cache read failed:", err?.message || err);
    return new Map();
  }
}

async function saveCache(rows) {
  if (!rows.length) return;
  const admin = supabaseAdmin();
  try {
    await admin
      .from("food_nutrition_cache")
      .upsert(
        rows.map((r) => ({
          query: r.query,
          payload: r.payload,
          updated_at: new Date().toISOString(),
        })),
        { onConflict: "query" }
      );
  } catch (err) {
    console.warn("nutrition cache write failed:", err?.message || err);
  }
}

function computeHeiScore(foods, counts) {
  let totalKcal = 0;
  let totalFruitCups = 0;
  let wholeFruitCups = 0;
  let totalVegCups = 0;
  let greensBeansCups = 0;
  let wholeGrainOz = 0;
  let refinedGrainOz = 0;
  let dairyCups = 0;
  let proteinOz = 0;
  let seafoodPlantOz = 0;
  let sodiumMg = 0;
  let addedSugarG = 0;
  let satFatG = 0;
  let monoFatG = 0;
  let polyFatG = 0;

  for (const food of foods) {
    const count = counts[food.query] || 1;
    const grams = 100 * count;
    const nutrients = food.payload?.nutrients || {};
    const kcal = (nutrients.energyKcal || 0) * (grams / 100);

    totalKcal += kcal;
    sodiumMg += (nutrients.sodiumMg || 0) * (grams / 100);
    addedSugarG += (nutrients.addedSugarG || 0) * (grams / 100);
    satFatG += (nutrients.satFatG || 0) * (grams / 100);
    monoFatG += (nutrients.monoFatG || 0) * (grams / 100);
    polyFatG += (nutrients.polyFatG || 0) * (grams / 100);

    const cls = classifyFood({
      name: food.payload?.name || food.query,
      category: food.payload?.category || "",
    });

    if (cls.isFruit) totalFruitCups += grams / GRAM_PER_CUP_FRUIT;
    if (cls.isWholeFruit) wholeFruitCups += grams / GRAM_PER_CUP_FRUIT;
    if (cls.isVeg) totalVegCups += grams / GRAM_PER_CUP_VEG;
    if (cls.isGreensBeans) greensBeansCups += grams / GRAM_PER_CUP_VEG;
    if (cls.isWholeGrain) wholeGrainOz += grams / GRAM_PER_OZ_GRAIN;
    if (cls.isRefinedGrain) refinedGrainOz += grams / GRAM_PER_OZ_GRAIN;
    if (cls.isDairy) dairyCups += grams / GRAM_PER_CUP_DAIRY;
    if (cls.isProtein) proteinOz += grams / GRAM_PER_OZ_PROTEIN;
    if (cls.isSeafoodPlant) seafoodPlantOz += grams / GRAM_PER_OZ_PROTEIN;
  }

  if (totalKcal <= 0) return { score: 0, totalKcal: 0 };

  const kcalPer1000 = totalKcal / 1000;
  const fruitPer1000 = totalFruitCups / kcalPer1000;
  const wholeFruitPer1000 = wholeFruitCups / kcalPer1000;
  const vegPer1000 = totalVegCups / kcalPer1000;
  const greensBeansPer1000 = greensBeansCups / kcalPer1000;
  const wholeGrainPer1000 = wholeGrainOz / kcalPer1000;
  const dairyPer1000 = dairyCups / kcalPer1000;
  const proteinPer1000 = proteinOz / kcalPer1000;
  const seafoodPlantPer1000 = seafoodPlantOz / kcalPer1000;

  const refinedPer1000 = refinedGrainOz / kcalPer1000;
  const sodiumPer1000 = (sodiumMg / 1000) / kcalPer1000;

  const addedSugarKcal = addedSugarG * 4;
  const satFatKcal = satFatG * 9;
  const addedSugarPct = totalKcal > 0 ? (addedSugarKcal / totalKcal) * 100 : 0;
  const satFatPct = totalKcal > 0 ? (satFatKcal / totalKcal) * 100 : 0;
  const fattyAcidRatio = satFatG > 0 ? (monoFatG + polyFatG) / satFatG : 0;

  const scores = {
    totalFruits: scoreAdequacy(fruitPer1000, 0.8, 5),
    wholeFruits: scoreAdequacy(wholeFruitPer1000, 0.4, 5),
    totalVegetables: scoreAdequacy(vegPer1000, 1.1, 5),
    greensBeans: scoreAdequacy(greensBeansPer1000, 0.2, 5),
    wholeGrains: scoreAdequacy(wholeGrainPer1000, 1.5, 10),
    dairy: scoreAdequacy(dairyPer1000, 1.3, 10),
    totalProtein: scoreAdequacy(proteinPer1000, 2.5, 5),
    seafoodPlant: scoreAdequacy(seafoodPlantPer1000, 0.8, 5),
    fattyAcids: scoreRatio(fattyAcidRatio, 1.2, 2.5, 10),
    refinedGrains: scoreModeration(refinedPer1000, 1.8, 4.3, 10),
    sodium: scoreModeration(sodiumPer1000, 1.1, 2.0, 10),
    addedSugars: scoreModeration(addedSugarPct, 6.5, 26, 10),
    saturatedFat: scoreModeration(satFatPct, 8, 16, 10),
  };

  const totalScore = Object.values(scores).reduce((sum, v) => sum + v, 0);
  return {
    score: Math.max(0, Math.min(100, totalScore)),
    totalKcal,
    scores,
  };
}

export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", ALLOWED_ORIGIN);
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  try {
    const body = await readBody(req);
    const rawItems = Array.isArray(body.items) ? body.items : [];
    const items = rawItems
      .map((it) => {
        if (typeof it === "string") return { name: it, count: 1 };
        return { name: it?.name, count: it?.count ?? 1 };
      })
      .filter((it) => it.name && String(it.name).trim().length > 1);

    if (items.length === 0) {
      return res.status(200).json({ heiScore: 0, items: [] });
    }

    const queries = items.map((i) => normalizeQuery(i.name));
    const counts = {};
    for (const item of items) {
      const q = normalizeQuery(item.name);
      counts[q] = (counts[q] || 0) + Number(item.count || 1);
    }

    const cache = await loadCache(queries);
    const results = [];
    const toCache = [];

    for (const q of queries) {
      const cached = cache.get(q);
      if (cached) {
        results.push({ query: q, payload: cached });
        continue;
      }
      const payload = await fetchFoodData(q);
      if (payload) {
        results.push({ query: q, payload });
        toCache.push({ query: q, payload });
      } else {
        results.push({ query: q, payload: { name: q, nutrients: {} } });
      }
    }

    await saveCache(toCache);

    const summary = computeHeiScore(results, counts);

    return res.status(200).json({
      heiScore: summary.score,
      totalKcal: summary.totalKcal,
      componentScores: summary.scores,
      items: results.map((r) => ({
        query: r.query,
        name: r.payload?.name || r.query,
        category: r.payload?.category || "",
      })),
    });
  } catch (err) {
    console.error("hei-score error:", err);
    return res.status(500).json({ error: "Failed to compute HEI score" });
  }
}
