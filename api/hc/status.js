// api/hc/status.js
import {
  assertEnv,
  getBearer,
  getUserIdFromSupabase,
  supabaseAdmin,
} from "../_lib/hc.js";
import { applyCors, handleOptions } from "../_lib/cors.js";

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  let step = "start";

  try {
    step = "assertEnv";
    assertEnv();

    step = "methodCheck";
    if (req.method !== "GET") {
      return res.status(405).json({ ok: false, error: "Method not allowed" });
    }

    step = "getBearer";
    const accessToken = getBearer(req);
    if (!accessToken) {
      return res.status(401).json({ ok: false, error: "Missing Bearer token" });
    }

    step = "getUserIdFromSupabase";
    const userId = await getUserIdFromSupabase(accessToken);

    step = "queryDB";
    const admin = supabaseAdmin();
    const { data, error } = await admin
      .from("homeconnect_tokens")
      .select("hc_host, scope, expires_at, updated_at")
      .eq("user_id", userId)
      .maybeSingle();

    if (error) {
      return res.status(500).json({ ok: false, step, error });
    }

    step = "done";
    return res.status(200).json({
      ok: true,
      connected: !!data,
      info: data || null,
    });
  } catch (e) {
    return res.status(500).json({
      ok: false,
      step,
      error: String(e?.message || e),
      stack: String(e?.stack || ""),
    });
  }
}
