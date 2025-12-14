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

  let step = "start";

  try {
    step = "assertEnv";
    assertEnv();

    step = "methodCheck";
    if (req.method !== "POST") {
      return res.status(405).json({ ok: false, error: "Method not allowed" });
    }

    step = "getBearer";
    const accessToken = getBearer(req);
    if (!accessToken) {
      return res.status(401).json({ ok: false, error: "Missing Bearer token" });
    }

    step = "getUserIdFromSupabase";
    const userId = await getUserIdFromSupabase(accessToken);

    step = "readBody";
    const body = await readJson(req);

    step = "buildScopes";
    const scopes =
      Array.isArray(body?.scopes) && body.scopes.length
        ? body.scopes
        : ["IdentifyAppliance", "Oven"];

    step = "buildReturnTo";
    const returnTo =
      body?.returnTo ||
      process.env.APP_RETURN_URL_DEFAULT ||
      "https://bshpwa.vercel.app/#/account?hc=connected";

    step = "signState";
    const state = signState({ userId, returnTo, t: Date.now() });

    step = "buildAuthorizeUrl";
    const authorizeUrl =
      `${HC_HOST}/security/oauth/authorize` +
      `?response_type=code` +
      `&client_id=${encodeURIComponent(HC_CLIENT_ID)}` +
      `&redirect_uri=${encodeURIComponent(HC_REDIRECT_URI)}` +
      `&scope=${encodeURIComponent(scopes.join(" "))}` +
      `&state=${encodeURIComponent(state)}`;

    step = "done";
    return res.status(200).json({ ok: true, authorizeUrl });
  } catch (e) {
    // ⚠️ 调试用：把 stack 返回给你看。跑通后记得去掉 stack
    return res.status(500).json({
      ok: false,
      step,
      error: String(e?.message || e),
      stack: String(e?.stack || ""),
    });
  }
}
