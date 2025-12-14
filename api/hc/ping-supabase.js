// api/hc/ping-supabase.js
import { applyCors, handleOptions } from "../_lib/cors.js";
import { SUPABASE_URL } from "../_lib/hc.js";

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    const url = `${SUPABASE_URL}`; // 先 ping 根域名即可
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), 8000);

    const r = await fetch(url, { method: "GET", signal: controller.signal });
    clearTimeout(t);

    const text = await r.text();
    return res.status(200).json({
      ok: true,
      supabaseUrl: SUPABASE_URL,
      status: r.status,
      sample: text.slice(0, 120),
    });
  } catch (e) {
    return res.status(500).json({
      ok: false,
      supabaseUrl: SUPABASE_URL,
      error: String(e?.message || e),
      stack: String(e?.stack || ""),
    });
  }
}
