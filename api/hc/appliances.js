// api/hc/appliances.js
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

    // Home Connect：列出所有设备
    const data = await hcFetchJson(userId, "/api/homeappliances", { method: "GET" });

    // data 一般长这样：{ data: { homeappliances: [...] } }
    const list =
      data?.data?.homeappliances ||
      data?.homeappliances ||
      [];

    return res.status(200).json({ ok: true, homeappliances: list });
  } catch (e) {
    const msg = String(e?.message || e);
    const code = e?.code;
    return res.status(code === "HC_NOT_CONNECTED" ? 409 : 500).json({ ok: false, error: msg });
  }
}
