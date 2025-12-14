// api/_lib/hc.js
import crypto from "crypto";
import { createClient } from "@supabase/supabase-js";

export const HC_HOST =
  process.env.HC_HOST || "https://simulator.home-connect.com";

export const HC_CLIENT_ID = process.env.HC_CLIENT_ID;
export const HC_CLIENT_SECRET = process.env.HC_CLIENT_SECRET; // ✅ 必须有
export const HC_REDIRECT_URI = process.env.HC_REDIRECT_URI;
export const STATE_SECRET = process.env.HC_STATE_SECRET;

export const SUPABASE_URL = process.env.SUPABASE_URL;
export const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY; // sb_publishable_...
export const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY; // sb_secret_...

export function assertEnv() {
  const missing = [];
  for (const k of [
    "HC_CLIENT_ID",
    "HC_CLIENT_SECRET", // ✅
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
  if (req.headers["content-type"]?.includes("application/json")) {
    return req.body ?? {};
  }
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

// 更稳：把 Supabase 返回状态码和 body 都带上
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
  const sig = crypto
    .createHmac("sha256", STATE_SECRET)
    .update(payload)
    .digest("base64url");
  return `${payload}.${sig}`;
}

export function verifyState(state) {
  const [payload, sig] = String(state || "").split(".");
  const expect = crypto
    .createHmac("sha256", STATE_SECRET)
    .update(payload)
    .digest("base64url");
  if (!payload || sig !== expect) throw new Error("Bad state");
  return JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
}

export function supabaseAdmin() {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });
}
