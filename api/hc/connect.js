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
  // CORS + preflight
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    assertEnv();
    console.log("[hc/connect] hasAuth=", !!req.headers.authorization, "origin=", req.headers.origin);

    if (req.method !== "POST") {
      return res.status(405).json({ ok: false, error: "Method not allowed" });
    }

    const accessToken = getBearer(req);
    if (!accessToken) {
      return res.status(401).json({ ok: false, error: "Missing Bearer token" });
    }

    // 通过 Supabase 校验 access token，并拿到 userId（不需要 JWT secret）
    const userId = await getUserIdFromSupabase(accessToken);

    const body = await readJson(req);

    // scopes 默认：绑定 Oven（你要跑通就够了）
    const scopes =
      Array.isArray(body?.scopes) && body.scopes.length
        ? body.scopes
        : ["IdentifyAppliance", "Oven"];

    // 成功后回到你的前端
    const returnTo =
      body?.returnTo ||
      process.env.APP_RETURN_URL_DEFAULT ||
      "https://bshpwa.vercel.app/#/account?hc=connected";

    // state：把“这次 OAuth 绑定给哪个 userId”签名封装进去（防 CSRF/错绑）
    const state = signState({
      userId,
      returnTo,
      t: Date.now(),
    });

    const authorizeUrl =
      `${HC_HOST}/security/oauth/authorize` +
      `?response_type=code` +
      `&client_id=${encodeURIComponent(HC_CLIENT_ID)}` +
      `&redirect_uri=${encodeURIComponent(HC_REDIRECT_URI)}` +
      `&scope=${encodeURIComponent(scopes.join(" "))}` +
      `&state=${encodeURIComponent(state)}`;

    return res.status(200).json({ ok: true, authorizeUrl });
 } catch (e) {
  console.error("[hc/connect] error:", e);
  const status = e?.status && Number.isInteger(e.status) ? e.status : 500;
  return res.status(status).json({ ok: false, error: String(e?.message || e) });
}


}
