// api/hc.js
import { applyCors, handleOptions } from "./_lib/cors.js";
import {
  assertEnv,
  getBearer,
  getUserIdFromSupabase,
  supabaseAdmin,
  hcFetchJson,
  readJson,
  signState,
  HC_HOST,
  HC_CLIENT_ID,
  HC_REDIRECT_URI,
  SUPABASE_URL
} from "./_lib/hc.js";

// --- Sub-handlers ---

async function handleStatus(req, res, userId) {
  if (req.method !== "GET") return res.status(405).end();
  const admin = supabaseAdmin();
  const { data, error } = await admin
    .from("homeconnect_tokens")
    .select("hc_host, scope, expires_at, updated_at")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) return res.status(500).json({ ok: false, error });
  return res.status(200).json({ ok: true, connected: !!data, info: data || null });
}

async function handleConnect(req, res, userId) {
  if (req.method !== "POST") return res.status(405).end();
  const body = await readJson(req);
  const scopes = Array.isArray(body.scopes) && body.scopes.length ? body.scopes : ["IdentifyAppliance", "Oven"];
  const returnTo = body.returnTo || process.env.APP_RETURN_URL_DEFAULT || "https://bshpwa.vercel.app/#/account?hc=connected";
  const state = signState({ userId, returnTo, t: Date.now() });

  const authorizeUrl =
    `${HC_HOST}/security/oauth/authorize` +
    `?response_type=code` +
    `&client_id=${encodeURIComponent(HC_CLIENT_ID)}` +
    `&redirect_uri=${encodeURIComponent(HC_REDIRECT_URI)}` +
    `&scope=${encodeURIComponent(scopes.join(" "))}` +
    `&state=${encodeURIComponent(state)}`;

  return res.status(200).json({ ok: true, authorizeUrl });
}

async function handleDisconnect(req, res, userId) {
  if (req.method !== "DELETE") return res.status(405).end();
  const admin = supabaseAdmin();
  const { error } = await admin.from("homeconnect_tokens").delete().eq("user_id", userId);
  if (error) return res.status(500).json({ ok: false, error });
  return res.status(200).json({ ok: true });
}

async function handleAppliances(req, res, userId) {
  if (req.method !== "GET") return res.status(405).end();
  try {
    const data = await hcFetchJson(userId, "/api/homeappliances", { method: "GET" });
    const list = data?.data?.homeappliances || data?.homeappliances || [];
    return res.status(200).json({ ok: true, homeappliances: list });
  } catch (e) {
    const code = e?.code;
    return res.status(code === "HC_NOT_CONNECTED" ? 409 : 500).json({ ok: false, error: String(e?.message || e) });
  }
}

async function handlePreheat(req, res, userId) {
  if (req.method !== "POST") return res.status(405).end();
  const body = await readJson(req);
  let haId = body?.haId || null;
  const temperatureC = Number(body?.temperatureC);

  if (!Number.isFinite(temperatureC)) {
    return res.status(400).json({ ok: false, error: "Missing/invalid temperatureC" });
  }

  // Auto-find oven if not provided
  if (!haId) {
    const listResp = await hcFetchJson(userId, "/api/homeappliances", { method: "GET" });
    const list = listResp?.data?.homeappliances || listResp?.homeappliances || [];
    const oven = list.find((x) => String(x?.type || "").toLowerCase() === "oven");
    if (!oven?.haId) return res.status(400).json({ ok: false, error: "No oven found" });
    haId = oven.haId;
  }

  const programKey = body?.programKey || "Cooking.Oven.Program.HeatingMode.PreHeating";
  const options = [{ key: "Cooking.Oven.Option.SetpointTemperature", value: temperatureC, unit: "C" }];
  
  if (typeof body?.fastPreHeat === "boolean") {
    options.push({ key: "Cooking.Oven.Option.FastPreHeat", value: body.fastPreHeat });
  }
  if (Number.isFinite(Number(body?.durationSeconds))) {
    options.push({ key: "BSH.Common.Option.Duration", value: Number(body.durationSeconds), unit: "seconds" });
  }

  const path = `/api/homeappliances/${encodeURIComponent(haId)}/programs/active`;
  const raw = await hcFetchJson(userId, path, { method: "PUT", body: { data: { key: programKey, options } } });
  return res.status(200).json({ ok: true, haId, programKey, options, raw });
}

async function handleProgramsAvailable(req, res, userId) {
  if (req.method !== "GET") return res.status(405).end();
  const haId = req.query?.haId ? String(req.query.haId) : "";
  if (!haId) return res.status(400).json({ ok: false, error: "Missing query param: haId" });

  const data = await hcFetchJson(userId, `/api/homeappliances/${encodeURIComponent(haId)}/programs/available`, { method: "GET" });
  const programs = (data?.data?.programs) || (data?.programs) || [];
  return res.status(200).json({ ok: true, haId, programs, raw: data });
}

async function handlePingSupabase(req, res) {
  // Ping doesn't need userId
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), 8000);
  try {
    const r = await fetch(SUPABASE_URL, { method: "GET", signal: controller.signal });
    clearTimeout(t);
    const text = await r.text();
    return res.status(200).json({ ok: true, supabaseUrl: SUPABASE_URL, status: r.status, sample: text.slice(0, 120) });
  } catch (e) {
    clearTimeout(t);
    return res.status(500).json({ ok: false, error: String(e?.message || e) });
  }
}

// --- Main Handler ---

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    const { action } = req.query; // Dispatch based on ?action=...
    
    // Public actions (no auth needed)
    if (action === 'ping') return await handlePingSupabase(req, res);

    // Auth actions
    assertEnv();
    const accessToken = getBearer(req);
    if (!accessToken) return res.status(401).json({ ok: false, error: "Missing Bearer token" });
    const userId = await getUserIdFromSupabase(accessToken);

    switch (action) {
      case 'status': return await handleStatus(req, res, userId);
      case 'connect': return await handleConnect(req, res, userId);
      case 'disconnect': return await handleDisconnect(req, res, userId);
      case 'appliances': return await handleAppliances(req, res, userId);
      case 'preheat': return await handlePreheat(req, res, userId);
      case 'programs': return await handleProgramsAvailable(req, res, userId);
      default: return res.status(400).json({ ok: false, error: `Unknown action: ${action}` });
    }
  } catch (e) {
    const msg = String(e?.message || e);
    const status = Number.isFinite(e?.status) ? e.status : 500;
    return res.status(status).json({ ok: false, error: msg });
  }
}