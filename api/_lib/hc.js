// api/_lib/hc.js
import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";

export const HC_HOST = process.env.HC_HOST || "https://simulator.home-connect.com";
export const HC_CLIENT_ID = process.env.HC_CLIENT_ID;
export const HC_CLIENT_SECRET = process.env.HC_CLIENT_SECRET || "";
export const HC_REDIRECT_URI = process.env.HC_REDIRECT_URI;
export const STATE_SECRET = process.env.HC_STATE_SECRET;

export const SUPABASE_URL = process.env.SUPABASE_URL;
export const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
export const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

export function assertEnv() {
  const missing = [];
  for (const k of [
    "HC_HOST",
    "HC_CLIENT_ID",
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
  const txt = await r.text();
  if (!r.ok) throw new Error(`Invalid Supabase token: ${r.status} ${txt}`);
  const u = JSON.parse(txt);
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

export async function refreshHomeConnectToken(refreshToken) {
  const body = new URLSearchParams({
    grant_type: "refresh_token",
    refresh_token: String(refreshToken),
    client_id: HC_CLIENT_ID,
  });
  if (HC_CLIENT_SECRET) body.set("client_secret", HC_CLIENT_SECRET);

  const r = await fetch(`${HC_HOST}/security/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  const raw = await r.text();
  let json;
  try {
    json = JSON.parse(raw);
  } catch {
    json = { raw };
  }

  if (!r.ok) throw new Error(`HC refresh failed: ${r.status} ${raw}`);
  return json;
}

// 统一从 DB 拿 tokens
export async function getTokensForUser(userId) {
  const admin = supabaseAdmin();
  const { data, error } = await admin
    .from("homeconnect_tokens")
    .select("user_id,hc_host,scope,access_token,refresh_token,token_type,expires_at,created_at,updated_at")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw new Error(`DB read homeconnect_tokens failed: ${error.message || JSON.stringify(error)}`);
  return data; // 可能为 null
}

export async function saveTokensForUser(userId, patch) {
  const admin = supabaseAdmin();
  const now = new Date().toISOString();

  const payload = {
    user_id: userId,
    ...patch,
    updated_at: now,
  };

  const { error } = await admin
    .from("homeconnect_tokens")
    .upsert(payload, { onConflict: "user_id" });

  if (error) throw new Error(`DB upsert homeconnect_tokens failed: ${error.message || JSON.stringify(error)}`);
}

// 发起 Home Connect API 请求（自动 refresh）
export async function hcFetchJson(userId, path, init = {}) {
  const row = await getTokensForUser(userId);
  if (!row || !row.access_token) {
    const err = new Error("Home Connect not connected");
    err.code = "HC_NOT_CONNECTED";
    throw err;
  }

  const host = row.hc_host || HC_HOST;
  const url = `${host}${path}`;

  async function doFetch(accessToken) {
    const r = await fetch(url, {
      ...init,
      headers: {
        ...(init.headers || {}),
        Authorization: `Bearer ${accessToken}`,
        Accept: "application/json",
      },
    });
    const txt = await r.text();
    let json;
    try {
      json = txt ? JSON.parse(txt) : null;
    } catch {
      json = { raw: txt };
    }
    return { r, json, raw: txt };
  }

  // 如果 expires_at 已经过期，先 refresh
  if (row.expires_at) {
    const exp = new Date(row.expires_at).getTime();
    if (!Number.isNaN(exp) && Date.now() > exp - 10 * 1000 && row.refresh_token) {
      const nt = await refreshHomeConnectToken(row.refresh_token);
      const expiresAt = nt.expires_in
        ? new Date(Date.now() + Number(nt.expires_in) * 1000).toISOString()
        : row.expires_at;

      await saveTokensForUser(userId, {
        hc_host: host,
        scope: nt.scope ?? row.scope ?? null,
        access_token: nt.access_token ?? row.access_token,
        refresh_token: nt.refresh_token ?? row.refresh_token,
        token_type: nt.token_type ?? row.token_type ?? null,
        expires_at: expiresAt,
      });

      const second = await doFetch(nt.access_token ?? row.access_token);
      if (!second.r.ok) throw new Error(`HC API failed: ${second.r.status} ${second.raw}`);
      return second.json;
    }
  }

  // 正常请求一次
  const first = await doFetch(row.access_token);

  // token 失效 -> refresh -> 重试一次
  if ((first.r.status === 401 || first.r.status === 403) && row.refresh_token) {
    const nt = await refreshHomeConnectToken(row.refresh_token);
    const expiresAt = nt.expires_in
      ? new Date(Date.now() + Number(nt.expires_in) * 1000).toISOString()
      : row.expires_at;

    await saveTokensForUser(userId, {
      hc_host: host,
      scope: nt.scope ?? row.scope ?? null,
      access_token: nt.access_token ?? row.access_token,
      refresh_token: nt.refresh_token ?? row.refresh_token,
      token_type: nt.token_type ?? row.token_type ?? null,
      expires_at: expiresAt,
    });

    const second = await doFetch(nt.access_token ?? row.access_token);
    if (!second.r.ok) throw new Error(`HC API failed after refresh: ${second.r.status} ${second.raw}`);
    return second.json;
  }

  if (!first.r.ok) throw new Error(`HC API failed: ${first.r.status} ${first.raw}`);
  return first.json;
}
