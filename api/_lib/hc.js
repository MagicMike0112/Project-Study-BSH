// api/_lib/hc.js
import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";

export const HC_HOST = process.env.HC_HOST || "https://simulator.home-connect.com";
export const HC_CLIENT_ID = process.env.HC_CLIENT_ID;
export const HC_CLIENT_SECRET = process.env.HC_CLIENT_SECRET; // callback 会用到
export const HC_REDIRECT_URI = process.env.HC_REDIRECT_URI;
export const STATE_SECRET = process.env.HC_STATE_SECRET;

export const SUPABASE_URL = process.env.SUPABASE_URL;
export const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
export const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Home Connect 要求的媒体类型（不带就 406）
export const HC_ACCEPT = "application/vnd.bsh.sdk.v1+json";

export function assertEnv() {
  const missing = [];
  for (const k of [
    "HC_CLIENT_ID",
    "HC_REDIRECT_URI",
    "HC_STATE_SECRET",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
    // HC_CLIENT_SECRET 不一定必须（取决于你 flow），但你现在 callback 里会用到，建议也配置
    "HC_CLIENT_SECRET",
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
  const url = `${SUPABASE_URL}/auth/v1/user`;

  const r = await fetch(url, {
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

/**
 * 取用户保存的 Home Connect token
 */
export async function getTokensForUser(userId) {
  const admin = supabaseAdmin();
  const { data, error } = await admin
    .from("homeconnect_tokens")
    .select("user_id,hc_host,scope,access_token,refresh_token,token_type,expires_at,updated_at")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) throw new Error(`Supabase read homeconnect_tokens failed: ${JSON.stringify(error)}`);
  return data || null;
}

/**
 * 用已绑定的 token 调 Home Connect API（自动加 Accept / Content-Type）
 * @param {string} userId
 * @param {string} path e.g. "/api/homeappliances"
 * @param {object} options { method, body, headers }
 */
export async function hcFetchJson(userId, path, options = {}) {
  const row = await getTokensForUser(userId);
  if (!row?.access_token) {
    const err = new Error("Home Connect not connected");
    err.code = "HC_NOT_CONNECTED";
    throw err;
  }

  const base = row.hc_host || HC_HOST; // 绑定时保存的 host 优先
  const url = `${base}${path}`;

  const method = (options.method || "GET").toUpperCase();
  const headers = {
    Authorization: `Bearer ${row.access_token}`,
    Accept: HC_ACCEPT,
    ...(options.headers || {}),
  };

  const init = { method, headers };

  if (options.body != null) {
    headers["Content-Type"] = HC_ACCEPT;
    init.body = typeof options.body === "string" ? options.body : JSON.stringify(options.body);
  }

  const r = await fetch(url, init);
  const text = await r.text();

  if (!r.ok) {
    // 直接把 HC 的错误原样抛出，前端能看到 406/401 等细节
    const err = new Error(`HC API failed: ${r.status} ${text}`);
    err.status = r.status;
    throw err;
  }

  // 有些接口可能返回空 body
  if (!text) return null;

  try {
    return JSON.parse(text);
  } catch (_) {
    return { raw: text };
  }
}
