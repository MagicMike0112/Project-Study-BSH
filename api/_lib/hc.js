// api/_lib/hc.js
import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";

export const HC_HOST = process.env.HC_HOST || "https://simulator.home-connect.com";
export const HC_CLIENT_ID = process.env.HC_CLIENT_ID;
export const HC_CLIENT_SECRET = process.env.HC_CLIENT_SECRET;
export const HC_REDIRECT_URI = process.env.HC_REDIRECT_URI;
export const STATE_SECRET = process.env.HC_STATE_SECRET;

export const SUPABASE_URL = process.env.SUPABASE_URL;
export const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
export const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Home Connect API 要求的媒体类型
export const HC_MEDIA = "application/vnd.bsh.sdk.v1+json";

export function assertEnv() {
  const missing = [];
  for (const k of [
    "HC_CLIENT_ID",
    "HC_CLIENT_SECRET",
    "HC_REDIRECT_URI",
    "HC_STATE_SECRET",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
  ]) {
    if (!process.env[k]) missing.push(k);
  }
  if (missing.length) throw new Error(`Missing env: ${missing.join(", ")}`);
}

export async function readJson(req) {
  if (req.headers["content-type"]?.includes("application/json")) return req.body ?? {};
  return await new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (c) => (data += c));
    req.on("end", () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on("error", reject);
  });
}

export function getBearer(req) {
  const auth = req.headers.authorization || "";
  return auth.startsWith("Bearer ") ? auth.slice(7) : null;
}

// 用 Supabase 官方接口验证 access token，并拿 userId
export async function getUserIdFromSupabase(accessToken) {
  const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${accessToken}`,
    },
  });

  const text = await r.text();
  if (!r.ok) {
    const err = new Error(`Supabase /auth/v1/user ${r.status}: ${text}`);
    err.status = r.status;
    throw err;
  }

  const u = JSON.parse(text);
  return u.id;
}

export function signState(obj) {
  const payload = Buffer.from(JSON.stringify(obj)).toString("base64url");
  const sig = crypto.createHmac("sha256", STATE_SECRET).update(payload).digest("base64url");
  return `${payload}.${sig}`;
}

export function verifyState(state) {
  const [payload, sig] = String(state || "").split(".");
  const expect = crypto.createHmac("sha256", STATE_SECRET).update(payload).digest("base64url");
  if (!payload || sig !== expect) throw new Error("Bad state");
  return JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
}

export function supabaseAdmin() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });
}

function isExpiredSoon(expiresAtIso, skewSeconds = 60) {
  if (!expiresAtIso) return false;
  const t = Date.parse(expiresAtIso);
  if (!Number.isFinite(t)) return false;
  return t <= Date.now() + skewSeconds * 1000;
}

async function refreshHcToken({ hcHost, refreshToken }) {
  const form = new URLSearchParams();
  form.set("grant_type", "refresh_token");
  form.set("client_id", HC_CLIENT_ID);
  form.set("client_secret", HC_CLIENT_SECRET);
  form.set("refresh_token", refreshToken);

  const r = await fetch(`${hcHost}/security/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form.toString(),
  });

  const text = await r.text();
  if (!r.ok) {
    const err = new Error(`HC refresh failed ${r.status}: ${text}`);
    err.status = r.status;
    throw err;
  }
  return JSON.parse(text);
}

// ✅ 关键函数：从 DB 取 HC token，必要时 refresh，然后带正确 headers 调 HC API
export async function hcFetchJson(userId, path, { method = "GET", body } = {}) {
  const admin = supabaseAdmin();

  // 1) 取 token
  const { data: row, error } = await admin
    .from("homeconnect_tokens")
    .select("hc_host, access_token, refresh_token, token_type, scope, expires_at")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw new Error(`DB read homeconnect_tokens failed: ${JSON.stringify(error)}`);
  if (!row?.access_token) {
    const e = new Error("Home Connect not connected");
    e.code = "HC_NOT_CONNECTED";
    throw e;
  }

  let hcHost = row.hc_host || HC_HOST;
  let accessToken = row.access_token;
  let refreshToken = row.refresh_token;
  let expiresAt = row.expires_at;

  // 2) 快过期就 refresh
  if (refreshToken && isExpiredSoon(expiresAt)) {
    const t = await refreshHcToken({ hcHost, refreshToken });

    accessToken = t.access_token;
    refreshToken = t.refresh_token || refreshToken;
    expiresAt = new Date(Date.now() + (t.expires_in || 3600) * 1000).toISOString();

    await admin.from("homeconnect_tokens").update({
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: t.token_type || "Bearer",
      scope: t.scope || row.scope || null,
      expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    }).eq("user_id", userId);
  }

  // 3) 调 HC API（带 Accept）
  const url = `${hcHost}${path}`;
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    Accept: HC_MEDIA,
  };

  const init = { method, headers };

  if (body != null) {
    headers["Content-Type"] = HC_MEDIA;
    init.body = typeof body === "string" ? body : JSON.stringify(body);
  }

  let r = await fetch(url, init);
  let text = await r.text();

  // 4) 如果 401 invalid_token，且有 refresh_token，再 refresh 重试一次
  if (r.status === 401 && refreshToken) {
    const t = await refreshHcToken({ hcHost, refreshToken });

    accessToken = t.access_token;
    refreshToken = t.refresh_token || refreshToken;
    expiresAt = new Date(Date.now() + (t.expires_in || 3600) * 1000).toISOString();

    await admin.from("homeconnect_tokens").update({
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: t.token_type || "Bearer",
      scope: t.scope || row.scope || null,
      expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    }).eq("user_id", userId);

    // 重试
    init.headers.Authorization = `Bearer ${accessToken}`;
    r = await fetch(url, init);
    text = await r.text();
  }

  if (!r.ok) {
    const err = new Error(`HC API failed: ${r.status} ${text}`);
    err.status = r.status;
    throw err;
  }

  return text ? JSON.parse(text) : null;
}
