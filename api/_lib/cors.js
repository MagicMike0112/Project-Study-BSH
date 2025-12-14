// api/_lib/cors.js
const ALLOWED_ORIGINS = new Set([
  "https://bshpwa.vercel.app",
  "http://localhost:5173",
  "http://localhost:3000",
  "http://localhost:8080",
]);

export function applyCors(req, res) {
  const origin = req.headers.origin;

  // 如果你懒得管白名单，开发阶段也可以直接用 "*"
  // 但我建议先按白名单来
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Vary", "Origin");
  }

  res.setHeader("Access-Control-Allow-Methods", "GET,POST,DELETE,OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
  res.setHeader("Access-Control-Max-Age", "86400");
}

export function handleOptions(req, res) {
  if (req.method === "OPTIONS") {
    res.statusCode = 204;
    res.end();
    return true;
  }
  return false;
}
