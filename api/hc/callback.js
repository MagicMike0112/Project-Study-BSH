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

function redirect(res, url) {
  res.statusCode = 302;
  res.setHeader("Location", url);
  res.end();
}

function safeStr(x) {
  return typeof x === "string" ? x : "";
}

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    assertEnv();

    // ✅ 不依赖 req.query，自己 parse
    const base = `https://${req.headers.host}`;
    const u = new URL(req.url, base);
    const code = u.searchParams.get("code");
    const state = u.searchParams.get("state");

    if (!code || !state) {
      return res.status(400).send("missing code/state");
    }

    const st = verifyState(state);

    // 10 分钟过期
    if (!st.t || Date.now() - Number(st.t) > 10 * 60 * 1000) {
      const back = safeStr(st.returnTo) || "https://bshpwa.vercel.app/#/account";
      return redirect(res, `${back}?hc=error&reason=state_expired`);
    }

    // 用 code 换 token（必须带 client_secret）
    const body = new URLSearchParams();
    body.set("grant_type", "authorization_code");
    body.set("client_id", HC_CLIENT_ID);
    body.set("client_secret", HC_CLIENT_SECRET);
    body.set("redirect_uri", HC_REDIRECT_URI);
    body.set("code", code);

    const tokenRes = await fetch(`${HC_HOST}/security/oauth/token`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });

    const raw = await tokenRes.text();
    let token;
    try {
      token = JSON.parse(raw);
    } catch {
      token = { raw };
    }

    if (!tokenRes.ok) {
      // ✅ 失败也回 PWA（别让用户卡在后端）
      const back = safeStr(st.returnTo) || "https://bshpwa.vercel.app/#/account";
      const msg = encodeURIComponent(
        token?.error_description || token?.error || "token_exchange_failed"
      );
      return redirect(res, `${back}?hc=error&reason=${msg}`);
    }

    const expiresAt = token.expires_in
      ? new Date(Date.now() + Number(token.expires_in) * 1000).toISOString()
      : null;

    // 写入数据库
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
        { onConflict: "user_id" }
      );

    if (error) {
      const back = safeStr(st.returnTo) || "https://bshpwa.vercel.app/#/account";
      const msg = encodeURIComponent(
        error.message || JSON.stringify(error) || "db_upsert_failed"
      );
      return redirect(res, `${back}?hc=error&reason=${msg}`);
    }

    // ✅ 成功：回到 PWA
    const returnTo =
      safeStr(st.returnTo) || "https://bshpwa.vercel.app/#/account?hc=connected";
    return redirect(res, returnTo);
  } catch (e) {
    // 最后兜底：也尽量回 PWA
    const msg = encodeURIComponent(String(e?.message || e));
    return redirect(res, `https://bshpwa.vercel.app/#/account?hc=error&reason=${msg}`);
  }
}
