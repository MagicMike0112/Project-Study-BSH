// api/hc/status.js
import { applyCors, handleOptions } from "../_lib/cors.js";
import { assertEnv, getBearer, getUserIdFromSupabase, getTokensForUser } from "../_lib/hc.js";

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    assertEnv();
    if (req.method !== "GET") return res.status(405).end();

    const accessToken = getBearer(req);
    if (!accessToken) return res.status(401).json({ ok: false, error: "Missing Bearer token" });

    const userId = await getUserIdFromSupabase(accessToken);
    const row = await getTokensForUser(userId);

    return res.status(200).json({
      ok: true,
      connected: !!row?.access_token,
      info: row
        ? {
            hc_host: row.hc_host,
            scope: row.scope,
            expires_at: row.expires_at,
            updated_at: row.updated_at,
          }
        : null,
    });
  } catch (e) {
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
}
