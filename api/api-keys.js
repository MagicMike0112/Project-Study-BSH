import crypto from "crypto";

import { applyCors, handleOptions } from "./_lib/cors.js";
import { getBearer, getUserIdFromSupabase, readJson, supabaseAdmin } from "./_lib/hc.js";

function setMethodCors(res) {
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,DELETE,OPTIONS");
}

function sha256(text) {
  return crypto.createHash("sha256").update(text).digest("hex");
}

function generateApiKey() {
  const secret = crypto.randomBytes(24).toString("base64url");
  const prefix = `bsh_live_${secret.slice(0, 8)}`;
  return {
    plain: `bsh_live_${secret}`,
    prefix,
  };
}

export default async function handler(req, res) {
  applyCors(req, res);
  setMethodCors(res);
  if (handleOptions(req, res)) return;

  try {
    const bearer = getBearer(req);
    if (!bearer) return res.status(401).json({ ok: false, error: "Missing Bearer token" });
    const userId = await getUserIdFromSupabase(bearer);
    const admin = supabaseAdmin();

    if (req.method === "GET") {
      const { data, error } = await admin
        .from("api_keys")
        .select("id,key_prefix,created_at,last_used_at,revoked_at,expires_at,note")
        .eq("user_id", userId)
        .order("created_at", { ascending: false });
      if (error) return res.status(500).json({ ok: false, error: error.message || String(error) });
      return res.status(200).json({ ok: true, keys: data || [] });
    }

    if (req.method === "POST") {
      const body = await readJson(req);
      const { plain, prefix } = generateApiKey();
      const payload = {
        user_id: userId,
        key_hash: sha256(plain),
        key_prefix: prefix,
        note: body?.note == null ? null : String(body.note),
        expires_at: body?.expires_at ?? null,
      };
      const { data, error } = await admin
        .from("api_keys")
        .insert(payload)
        .select("id,key_prefix,created_at,expires_at,note")
        .limit(1);
      if (error) return res.status(500).json({ ok: false, error: error.message || String(error) });
      return res.status(201).json({
        ok: true,
        apiKey: plain, // show once
        key: data?.[0] || null,
      });
    }

    if (req.method === "DELETE") {
      const body = await readJson(req).catch(() => ({}));
      const id = String(req.query?.id || body?.id || "").trim();
      if (!id) return res.status(400).json({ ok: false, error: "Missing id" });

      const { error } = await admin
        .from("api_keys")
        .update({ revoked_at: new Date().toISOString() })
        .eq("id", id)
        .eq("user_id", userId)
        .is("revoked_at", null);
      if (error) return res.status(500).json({ ok: false, error: error.message || String(error) });
      return res.status(200).json({ ok: true });
    }

    return res.status(405).json({ ok: false, error: "Method not allowed" });
  } catch (e) {
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
}
