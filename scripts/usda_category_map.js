// scripts/usda_category_map.js
// Usage:
//   $env:USDA_FDC_API_KEY="YOUR_KEY"; node scripts/usda_category_map.js
// Optional:
//   $env:FDC_PAGE_SIZE=200; $env:FDC_MAX_PAGES=0
// Notes:
// - FDC categories differ by dataType; this script gathers distinct categories and suggests app mappings.

import fs from "fs";
import path from "path";

const API_KEY = process.env.USDA_FDC_API_KEY;
const PAGE_SIZE = Number(process.env.FDC_PAGE_SIZE || 200);
const MAX_PAGES = Number(process.env.FDC_MAX_PAGES || 0); // 0 = no limit
const BASE_URL = "https://api.nal.usda.gov/fdc/v1";

if (!API_KEY) {
  console.error("Missing USDA_FDC_API_KEY env var.");
  process.exit(1);
}

const appCategories = [
  "produce",
  "dairy",
  "meat",
  "seafood",
  "bakery",
  "frozen",
  "beverage",
  "pantry",
  "snacks",
  "household",
  "pet",
  "other",
];

const keywordRules = [
  { key: "produce", match: ["fruit", "vegetable", "greens", "produce", "salad"] },
  { key: "dairy", match: ["dairy", "milk", "cheese", "yogurt", "egg"] },
  { key: "meat", match: ["meat", "poultry", "beef", "pork", "lamb", "turkey", "chicken"] },
  { key: "seafood", match: ["seafood", "fish", "shellfish"] },
  { key: "bakery", match: ["bakery", "bread", "pastry", "baked", "cake"] },
  { key: "frozen", match: ["frozen"] },
  { key: "beverage", match: ["beverage", "drink", "juice", "coffee", "tea", "water"] },
  { key: "snacks", match: ["snack", "candy", "chips", "dessert", "sweet"] },
  { key: "pantry", match: ["grain", "cereal", "pasta", "rice", "flour", "condiment", "oil", "spice", "legume", "nut", "seed"] },
];

function suggestCategory(categoryName) {
  const name = String(categoryName || "").toLowerCase();
  for (const rule of keywordRules) {
    if (rule.match.some((m) => name.includes(m))) {
      return rule.key;
    }
  }
  return "other";
}

async function fetchJson(url, options = {}) {
  const res = await fetch(url, options);
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${text}`);
  }
  return text ? JSON.parse(text) : null;
}

async function fetchAllCategories() {
  const categories = new Map(); // name -> { count, dataTypes: {} }
  let page = 1;
  while (true) {
    if (MAX_PAGES > 0 && page > MAX_PAGES) break;
    const url = `${BASE_URL}/foods/list?api_key=${API_KEY}&pageNumber=${page}&pageSize=${PAGE_SIZE}`;
    const data = await fetchJson(url);
    const foods = Array.isArray(data) ? data : [];
    if (!foods.length) break;

    for (const food of foods) {
      const cat = food.foodCategory || "Unknown";
      const dataType = food.dataType || "Unknown";
      if (!categories.has(cat)) {
        categories.set(cat, { count: 0, dataTypes: {} });
      }
      const entry = categories.get(cat);
      entry.count += 1;
      entry.dataTypes[dataType] = (entry.dataTypes[dataType] || 0) + 1;
    }

    if (foods.length < PAGE_SIZE) break;
    page += 1;
  }
  return categories;
}

async function main() {
  console.log("Fetching USDA FDC categories...");
  const categories = await fetchAllCategories();
  const out = [];

  for (const [name, meta] of categories.entries()) {
    out.push({
      foodCategory: name,
      count: meta.count,
      dataTypes: meta.dataTypes,
      suggestedCategory: suggestCategory(name),
    });
  }

  out.sort((a, b) => b.count - a.count);

  const result = {
    generatedAt: new Date().toISOString(),
    appCategories,
    totalCategories: out.length,
    categories: out,
  };

  const outPath = path.join(process.cwd(), "scripts", "usda_category_mapping.json");
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2), "utf8");
  console.log(`Done. Wrote ${out.length} categories to ${outPath}`);
}

main().catch((err) => {
  console.error("Failed:", err.message || err);
  process.exit(1);
});
