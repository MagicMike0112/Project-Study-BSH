// api/hc/disconnect.js
import { assertEnv, getBearer, getUserIdFromSupabase, supabaseAdmin } from "../_lib/hc.js";

export default async function handler(req, res) {
  try {
    assertEnv();
    if (req.method !== "DELETE") return res.status(405).end();

    const accessToken = getBearer(req);
    if (!accessToken) return res.status(401).json({ ok: false, error: "Missing Bearer token" });

    const userId = await getUserIdFromSupabase(accessToken);

    const admin = supabaseAdmin();
    const { error } = await admin.from("homeconnect_tokens").delete().eq("user_id", userId);
    if (error) return res.status(500).json({ ok: false, error });

    return res.status(200).json({ ok: true });
  } catch (e) {
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
}
