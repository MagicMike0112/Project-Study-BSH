// api/hc/callback.js
import { applyCors, handleOptions } from "../_lib/cors.js";
import {
  assertEnv,
  verifyState,
  supabaseAdmin,
  HC_HOST,
  HC_CLIENT_ID,
  HC_REDIRECT_URI,
} from "../_lib/hc.js";

export default async function handler(req, res) {
  // callback 主要是浏览器跳转，不是 fetch；但加 CORS 不会坏
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    assertEnv();

    const { code, state } = req.query;
    if (!code || !state) return res.status(400).send("missing code/state");

    const st = verifyState(state);

    // state 过期保护（10分钟）
    if (!st.t || Date.now() - st.t > 10 * 60 * 1000) {
      return res.status(400).send("state expired");
    }

    const body = new URLSearchParams({
      grant_type: "authorization_code",
      client_id: HC_CLIENT_ID,
      redirect_uri: HC_REDIRECT_URI,
      code: String(code),
    });

    // 真机时才会需要
    if (process.env.HC_CLIENT_SECRET) {
      body.set("client_secret", process.env.HC_CLIENT_SECRET);
    }

    const r = await fetch(`${HC_HOST}/security/oauth/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    });

    const token = await r.json();
    if (!r.ok) {
      return res.status(400).json({ ok: false, token });
    }

    const expiresAt = token.expires_in
      ? new Date(Date.now() + Number(token.expires_in) * 1000).toISOString()
      : null;

    const admin = supabaseAdmin();
    const { error } = await admin
      .from("homeconnect_tokens")
      .upsert(
        {
          user_id: st.userId,
          hc_host: HC_HOST,
          scope: token.scope || null,
          access_token: token.access_token || null,
          refresh_token: token.refresh_token || null,
          token_type: token.token_type || null,
          expires_at: expiresAt,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" },
      );

    if (error) {
      return res.status(500).json({ ok: false, error });
    }

    const returnTo =
      st.returnTo || "https://bshpwa.vercel.app/#/account?hc=connected";
    res.writeHead(302, { Location: returnTo });
    res.end();
  } catch (e) {
    return res.status(500).send(String(e?.message || e));
  }
}
