// api/_lib/hc.js
import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";

export const HC_HOST = process.env.HC_HOST || "https://simulator.home-connect.com";
export const HC_CLIENT_ID = process.env.HC_CLIENT_ID;
export const HC_CLIENT_SECRET = process.env.HC_CLIENT_SECRET; // callback uses this
export const HC_REDIRECT_URI = process.env.HC_REDIRECT_URI;
export const STATE_SECRET = process.env.HC_STATE_SECRET;

export const SUPABASE_URL = process.env.SUPABASE_URL;
export const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;
export const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Home Connect required media type
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

// Supabase user lookup from access token
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
 * Read Home Connect tokens for user
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

async function refreshTokens(userId, row) {
  if (!row?.refresh_token) {
    const err = new Error("Home Connect token expired and no refresh_token");
    err.code = "HC_TOKEN_EXPIRED";
    throw err;
  }

  const body = new URLSearchParams({
    grant_type: "refresh_token",
    client_id: HC_CLIENT_ID,
    refresh_token: row.refresh_token,
  });
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

  if (!r.ok) {
    const err = new Error(`HC refresh failed: ${r.status} ${raw}`);
    err.status = r.status;
    throw err;
  }

  const expiresAt = token.expires_in
    ? new Date(Date.now() + Number(token.expires_in) * 1000).toISOString()
    : row.expires_at || null;

  const admin = supabaseAdmin();
  const { error } = await admin
    .from("homeconnect_tokens")
    .update({
      access_token: token.access_token || row.access_token,
      refresh_token: token.refresh_token || row.refresh_token,
      token_type: token.token_type || row.token_type,
      scope: token.scope || row.scope,
      expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    })
    .eq("user_id", userId);

  if (error) {
    throw new Error(`Supabase refresh update failed: ${JSON.stringify(error)}`);
  }

  return {
    ...row,
    access_token: token.access_token || row.access_token,
    refresh_token: token.refresh_token || row.refresh_token,
    token_type: token.token_type || row.token_type,
    scope: token.scope || row.scope,
    expires_at: expiresAt,
  };
}

/**
 * Call Home Connect API using saved token
 * @param {string} userId
 * @param {string} path e.g. "/api/homeappliances"
 * @param {object} options { method, body, headers }
 */
export async function hcFetchJson(userId, path, options = {}) {
  let row = await getTokensForUser(userId);
  if (!row?.access_token) {
    const err = new Error("Home Connect not connected");
    err.code = "HC_NOT_CONNECTED";
    throw err;
  }

  const base = row.hc_host || HC_HOST;
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

  let r = await fetch(url, init);
  let text = await r.text();

  if (r.status === 401 || r.status === 403) {
    row = await refreshTokens(userId, row);
    headers.Authorization = `Bearer ${row.access_token}`;
    r = await fetch(url, init);
    text = await r.text();
  }

  if (!r.ok) {
    const err = new Error(`HC API failed: ${r.status} ${text}`);
    err.status = r.status;
    throw err;
  }

  if (!text) return null;

  try {
    return JSON.parse(text);
  } catch (_) {
    return { raw: text };
  }
}