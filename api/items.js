import crypto from "crypto";

import { applyCors, handleOptions } from "./_lib/cors.js";
import { getBearer, getUserIdFromSupabase, readJson, supabaseAdmin } from "./_lib/hc.js";

function setMethodCors(res) {
  res.setHeader("Access-Control-Allow-Methods", "GET,POST,PATCH,DELETE,OPTIONS");
}

function nowIso() {
  return new Date().toISOString();
}

function sha256(text) {
  return crypto.createHash("sha256").update(text).digest("hex");
}

function normalizeType(raw) {
  const v = String(raw || "").trim().toLowerCase();
  if (v === "inventory" || v === "inventory_items") return "inventory_items";
  if (v === "shopping" || v === "shopping_items") return "shopping_items";
  return null;
}

function cleanString(v, fallback = "") {
  if (typeof v !== "string") return fallback;
  return v.trim();
}

async function getFamilyIdForUser(admin, userId) {
  const { data: member, error: memberErr } = await admin
    .from("family_members")
    .select("family_id")
    .eq("user_id", userId)
    .limit(1)
    .maybeSingle();
  if (memberErr) throw memberErr;
  if (member?.family_id) return member.family_id;

  const { data: profile, error: profileErr } = await admin
    .from("user_profiles")
    .select("family_id")
    .eq("id", userId)
    .limit(1)
    .maybeSingle();
  if (profileErr) throw profileErr;
  return profile?.family_id || null;
}

async function resolveUserIdFromBearer(admin, bearer) {
  try {
    const userId = await getUserIdFromSupabase(bearer);
    return { userId, authType: "supabase_jwt" };
  } catch (_) {
    const hash = sha256(bearer);
    const now = nowIso();
    const { data: keyRow, error } = await admin
      .from("api_keys")
      .select("id,user_id,revoked_at,expires_at")
      .eq("key_hash", hash)
      .maybeSingle();
    if (error) throw error;
    if (!keyRow || keyRow.revoked_at) {
      const err = new Error("Invalid API key");
      err.status = 401;
      throw err;
    }
    if (keyRow.expires_at && String(keyRow.expires_at) < now) {
      const err = new Error("API key expired");
      err.status = 401;
      throw err;
    }
    await admin
      .from("api_keys")
      .update({ last_used_at: now })
      .eq("id", keyRow.id);
    return { userId: keyRow.user_id, authType: "api_key" };
  }
}

function buildCreatePayload({ type, body, userId, familyId }) {
  const id = cleanString(body.id) || crypto.randomUUID();
  const name = cleanString(body.name);
  if (!name) throw new Error("Missing required field: name");

  if (type === "shopping_items") {
    return {
      id,
      family_id: familyId,
      user_id: userId,
      name,
      category: cleanString(body.category, "general") || "general",
      is_checked: Boolean(body.is_checked ?? body.isChecked ?? false),
      note: body.note == null ? null : String(body.note),
      created_at: nowIso(),
      updated_at: nowIso(),
    };
  }

  return {
    id,
    family_id: familyId,
    user_id: userId,
    name,
    generic_name: body.generic_name ?? body.genericName ?? null,
    location: cleanString(body.location, "fridge") || "fridge",
    quantity: Number.isFinite(Number(body.quantity)) ? Number(body.quantity) : 1,
    unit: cleanString(body.unit, "pcs") || "pcs",
    min_quantity: Number.isFinite(Number(body.min_quantity ?? body.minQuantity))
      ? Number(body.min_quantity ?? body.minQuantity)
      : null,
    purchased_date: body.purchased_date ?? body.purchasedDate ?? nowIso(),
    open_date: body.open_date ?? body.openDate ?? null,
    best_before_date: body.best_before_date ?? body.bestBeforeDate ?? null,
    predicted_expiry: body.predicted_expiry ?? body.predictedExpiry ?? null,
    status: cleanString(body.status, "good") || "good",
    category: body.category == null ? null : String(body.category),
    source: body.source == null ? "bot-api" : String(body.source),
    note: body.note == null ? null : String(body.note),
    is_private: Boolean(body.is_private ?? body.isPrivate ?? false),
    updated_at: nowIso(),
  };
}

function buildPatchPayload(type, patch) {
  const allowedShopping = new Set(["name", "category", "is_checked", "note"]);
  const allowedInventory = new Set([
    "name",
    "generic_name",
    "location",
    "quantity",
    "unit",
    "min_quantity",
    "purchased_date",
    "open_date",
    "best_before_date",
    "predicted_expiry",
    "status",
    "category",
    "source",
    "note",
    "is_private",
  ]);

  const allowed = type === "shopping_items" ? allowedShopping : allowedInventory;
  const out = {};
  for (const [k, v] of Object.entries(patch || {})) {
    if (allowed.has(k)) out[k] = v;
  }
  if ("isChecked" in (patch || {})) out.is_checked = Boolean(patch.isChecked);
  if ("genericName" in (patch || {})) out.generic_name = patch.genericName;
  if ("minQuantity" in (patch || {})) out.min_quantity = patch.minQuantity;
  if ("purchasedDate" in (patch || {})) out.purchased_date = patch.purchasedDate;
  if ("openDate" in (patch || {})) out.open_date = patch.openDate;
  if ("bestBeforeDate" in (patch || {})) out.best_before_date = patch.bestBeforeDate;
  if ("predictedExpiry" in (patch || {})) out.predicted_expiry = patch.predictedExpiry;
  if ("isPrivate" in (patch || {})) out.is_private = Boolean(patch.isPrivate);

  out.updated_at = nowIso();
  return out;
}

async function handleGet(req, res, admin, familyId) {
  const type = normalizeType(req.query?.type);
  if (!type) return res.status(400).json({ ok: false, error: "Query param 'type' is required" });
  const id = cleanString(req.query?.id);
  const limit = Math.min(200, Math.max(1, Number(req.query?.limit || 50)));

  let query = admin.from(type).select("*").eq("family_id", familyId).order("updated_at", { ascending: false });
  if (id) query = query.eq("id", id).limit(1);
  else query = query.limit(limit);

  const { data, error } = await query;
  if (error) return res.status(500).json({ ok: false, error: error.message || String(error) });
  if (id) return res.status(200).json({ ok: true, item: data?.[0] || null });
  return res.status(200).json({ ok: true, items: data || [] });
}

async function handlePost(req, res, admin, userId, familyId) {
  const body = await readJson(req);
  const type = normalizeType(body.type);
  if (!type) return res.status(400).json({ ok: false, error: "Body field 'type' is required" });

  let payload;
  try {
    payload = buildCreatePayload({ type, body, userId, familyId });
  } catch (e) {
    return res.status(400).json({ ok: false, error: e.message || String(e) });
  }

  const { data, error } = await admin.from(type).insert(payload).select("*").limit(1);
  if (error) return res.status(500).json({ ok: false, error: error.message || String(error) });
  return res.status(201).json({ ok: true, item: data?.[0] || payload });
}

async function handlePatch(req, res, admin, familyId) {
  const body = await readJson(req);
  const type = normalizeType(body.type);
  const id = cleanString(body.id);
  if (!type || !id) {
    return res.status(400).json({ ok: false, error: "Body fields 'type' and 'id' are required" });
  }
  const patch = buildPatchPayload(type, body.patch ?? body);
  delete patch.type;
  delete patch.id;
  delete patch.patch;

  const { data, error } = await admin
    .from(type)
    .update(patch)
    .eq("family_id", familyId)
    .eq("id", id)
    .select("*")
    .limit(1);
  if (error) return res.status(500).json({ ok: false, error: error.message || String(error) });
  return res.status(200).json({ ok: true, item: data?.[0] || null });
}

async function handleDelete(req, res, admin, familyId) {
  const body = req.method === "DELETE" ? await readJson(req).catch(() => ({})) : {};
  const type = normalizeType(req.query?.type || body.type);
  const id = cleanString(req.query?.id || body.id);
  if (!type || !id) {
    return res.status(400).json({ ok: false, error: "type and id are required" });
  }
  const { error } = await admin.from(type).delete().eq("family_id", familyId).eq("id", id);
  if (error) return res.status(500).json({ ok: false, error: error.message || String(error) });
  return res.status(200).json({ ok: true, deleted: { type, id } });
}

export default async function handler(req, res) {
  applyCors(req, res);
  setMethodCors(res);
  if (handleOptions(req, res)) return;

  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_ANON_KEY || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return res.status(500).json({ ok: false, error: "Missing Supabase environment variables" });
  }

  try {
    const admin = supabaseAdmin();
    const accessToken = getBearer(req);
    if (!accessToken) return res.status(401).json({ ok: false, error: "Missing Bearer token" });
    const { userId } = await resolveUserIdFromBearer(admin, accessToken);
    const familyId = await getFamilyIdForUser(admin, userId);
    if (!familyId) return res.status(403).json({ ok: false, error: "No family context found for user" });

    if (req.method === "GET") return await handleGet(req, res, admin, familyId);
    if (req.method === "POST") return await handlePost(req, res, admin, userId, familyId);
    if (req.method === "PATCH") return await handlePatch(req, res, admin, familyId);
    if (req.method === "DELETE") return await handleDelete(req, res, admin, familyId);

    return res.status(405).json({ ok: false, error: "Method not allowed" });
  } catch (e) {
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
}
