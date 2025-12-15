// api/hc/oven_programs_available.js
import { applyCors, handleOptions } from "../_lib/cors.js";
import { assertEnv, getBearer, getUserIdFromSupabase, hcFetchJson } from "../_lib/hc.js";

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    assertEnv();
    if (req.method !== "GET") return res.status(405).end();

    const accessToken = getBearer(req);
    if (!accessToken) return res.status(401).json({ ok: false, error: "Missing Bearer token" });

    const userId = await getUserIdFromSupabase(accessToken);

    const haId = req.query?.haId ? String(req.query.haId) : "";
    if (!haId) return res.status(400).json({ ok: false, error: "Missing query param: haId" });

    const data = await hcFetchJson(
      userId,
      `/api/homeappliances/${encodeURIComponent(haId)}/programs/available`,
      { method: "GET" }
    );

    // Home Connect 结构可能是 { data: { programs: [...] } }
    const programs =
      (data && data.data && Array.isArray(data.data.programs) ? data.data.programs : null) ||
      (data && Array.isArray(data.programs) ? data.programs : null) ||
      [];

    return res.status(200).json({ ok: true, haId, programs, raw: data });
  } catch (e) {
    const msg = String(e?.message || e);
    const status = e?.status || 500;
    return res.status(status).json({ ok: false, error: msg });
  }
}
