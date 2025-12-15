// api/hc/connect.js
import {
  assertEnv,
  readJson,
  getBearer,
  getUserIdFromSupabase,
  signState,
  HC_HOST,
  HC_CLIENT_ID,
  HC_REDIRECT_URI,
} from "../_lib/hc.js";
import { applyCors, handleOptions } from "../_lib/cors.js";

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    assertEnv();
    if (req.method !== "POST") return res.status(405).end();

    const accessToken = getBearer(req);
    if (!accessToken) return res.status(401).json({ ok: false, error: "Missing Bearer token" });

    const userId = await getUserIdFromSupabase(accessToken);
    const body = await readJson(req);

    const scopes =
      Array.isArray(body.scopes) && body.scopes.length
        ? body.scopes
        : ["IdentifyAppliance", "Oven"]; // 默认够你做预热演示

    const returnTo =
      body.returnTo ||
      process.env.APP_RETURN_URL_DEFAULT ||
      "https://bshpwa.vercel.app/#/account?hc=connected";

    const state = signState({ userId, returnTo, t: Date.now() });

    const authorizeUrl =
      `${HC_HOST}/security/oauth/authorize` +
      `?response_type=code` +
      `&client_id=${encodeURIComponent(HC_CLIENT_ID)}` +
      `&redirect_uri=${encodeURIComponent(HC_REDIRECT_URI)}` +
      `&scope=${encodeURIComponent(scopes.join(" "))}` +
      `&state=${encodeURIComponent(state)}`;

    return res.status(200).json({ ok: true, authorizeUrl });
  } catch (e) {
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
}
