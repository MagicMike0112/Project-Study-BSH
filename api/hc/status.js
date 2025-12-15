// api/hc/status.js
import { applyCors, handleOptions } from "../_lib/cors.js";
import { assertEnv, getBearer, getUserIdFromSupabase, supabaseAdmin } from "../_lib/hc.js";

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    assertEnv();
    if (req.method !== "GET") return res.status(405).end();

    const accessToken = getBearer(req);
    if (!accessToken) return res.status(401).json({ ok: false, error: "Missing Bearer token" });

    const userId = await getUserIdFromSupabase(accessToken);

    const admin = supabaseAdmin();
    const { data, error } = await admin
      .from("homeconnect_tokens")
      .select("hc_host, scope, expires_at, updated_at")
      .eq("user_id", userId)
      .maybeSingle();

    if (error) return res.status(500).json({ ok: false, error });

    return res.status(200).json({
      ok: true,
      connected: !!data,
      info: data || null,
    });
  } catch (e) {
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
}
