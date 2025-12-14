// api/hc/callback.js
import { applyCors, handleOptions } from "../_lib/cors.js";
import {
  assertEnv,
  verifyState,
  supabaseAdmin,
  HC_HOST,
  HC_CLIENT_ID,
  HC_CLIENT_SECRET,
  HC_REDIRECT_URI,
} from "../_lib/hc.js";

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    assertEnv();

    const { code, state } = req.query;
    if (!code || !state) return res.status(400).send("missing code/state");

    const st = verifyState(state);

    // 10 分钟过期
    if (!st.t || Date.now() - st.t > 10 * 60 * 1000) {
      return res.status(400).send("state expired");
    }

    const body = new URLSearchParams({
      grant_type: "authorization_code",
      client_id: HC_CLIENT_ID,
      redirect_uri: HC_REDIRECT_URI,
      code: String(code),
    });

    // real 必带；simulator 可选，但带上也可以
    if (HC_CLIENT_SECRET) body.set("client_secret", HC_CLIENT_SECRET);

    const r = await fetch(`${HC_HOST}/security/oauth/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });

    const raw = await r.text();
    let token;
    try {
      token = JSON.parse(raw);
    } catch (_) {
      token = { raw };
    }

    if (!r.ok) return res.status(400).json({ ok: false, token });

    const expiresAt = token.expires_in
      ? new Date(Date.now() + Number(token.expires_in) * 1000).toISOString()
      : null;

    const admin = supabaseAdmin();
    const now = new Date().toISOString();

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
          // created_at 有默认值，不用手动写；但 upsert 时最好不覆盖
          updated_at: now,
        },
        { onConflict: "user_id" },
      );

    if (error) return res.status(500).json({ ok: false, error });

    const returnTo = st.returnTo || "https://bshpwa.vercel.app/#/account?hc=connected";
    res.writeHead(302, { Location: returnTo });
    res.end();
  } catch (e) {
    return res.status(500).send(String(e?.message || e));
  }
}
