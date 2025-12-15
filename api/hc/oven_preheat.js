// api/hc/oven_preheat.js
import { applyCors, handleOptions } from "../_lib/cors.js";
import { assertEnv, readJson, getBearer, getUserIdFromSupabase, hcFetchJson } from "../_lib/hc.js";

function pickProgram(programs, preferredKey) {
  if (!Array.isArray(programs)) return null;

  if (preferredKey) {
    const hit = programs.find((p) => p?.key === preferredKey);
    if (hit) return hit;
  }

  // 常见优先级（不保证每台都一样）
  const priority = [
    "Cooking.Oven.Program.HeatingMode.HotAir",
    "Cooking.Oven.Program.HeatingMode.TopBottomHeating",
    "Cooking.Oven.Program.HeatingMode.TopBottomHeat",
    "Cooking.Oven.Program.HeatingMode.BottomHeat",
    "Cooking.Oven.Program.HeatingMode.PizzaSetting",
  ];

  for (const k of priority) {
    const hit = programs.find((p) => p?.key === k);
    if (hit) return hit;
  }

  // 兜底：随便找一个看起来像加热模式的
  const fuzzy = programs.find((p) => String(p?.key || "").includes("Cooking.Oven.Program"));
  return fuzzy || programs[0] || null;
}

function findOptionKey(program, includesText) {
  const opts = Array.isArray(program?.options) ? program.options : [];
  return opts.find((o) => String(o?.key || "").includes(includesText))?.key || null;
}

export default async function handler(req, res) {
  applyCors(req, res);
  if (handleOptions(req, res)) return;

  try {
    assertEnv();
    if (req.method !== "POST") return res.status(405).end();

    const accessToken = getBearer(req);
    if (!accessToken) return res.status(401).json({ ok: false, error: "Missing Bearer token" });

    const userId = await getUserIdFromSupabase(accessToken);

    const body = await readJson(req);

    const haId = String(body?.haId || "");
    const temperatureC = Number(body?.temperatureC);
    const programKey = body?.programKey ? String(body.programKey) : null;

    // 可选：如果某些机型要求 duration，不传就给默认 3600 秒
    const durationSec = body?.durationSec != null ? Number(body.durationSec) : 3600;

    if (!haId) return res.status(400).json({ ok: false, error: "Missing body.haId" });
    if (!Number.isFinite(temperatureC)) {
      return res.status(400).json({ ok: false, error: "Missing/invalid body.temperatureC" });
    }

    // 1) 先拿 available programs，保证你选的 program / option key 真存在
    const availableRaw = await hcFetchJson(
      userId,
      `/api/homeappliances/${encodeURIComponent(haId)}/programs/available`,
      { method: "GET" }
    );

    const programs =
      (availableRaw && availableRaw.data && Array.isArray(availableRaw.data.programs) ? availableRaw.data.programs : null) ||
      (availableRaw && Array.isArray(availableRaw.programs) ? availableRaw.programs : null) ||
      [];

    if (!programs.length) {
      return res.status(409).json({ ok: false, error: "No available oven programs returned (device offline?)" });
    }

    const program = pickProgram(programs, programKey);
    if (!program?.key) {
      return res.status(409).json({ ok: false, error: "Could not select an oven program" });
    }

    // 2) 找温度 option key（不同机型 key 可能不同）
    const tempKey =
      findOptionKey(program, "SetpointTemperature") ||
      findOptionKey(program, "Temperature");

    if (!tempKey) {
      return res.status(409).json({
        ok: false,
        error: `Selected program has no temperature option. program=${program.key}`,
      });
    }

    const options = [
      { key: tempKey, value: temperatureC, unit: "°C" },
    ];

    // 3) 如果该 program 提供 Duration（有些设备会需要），我们也顺手给一个默认
    const durKey =
      findOptionKey(program, "Duration") ||
      findOptionKey(program, "duration");

    if (durKey) {
      options.push({ key: durKey, value: durationSec, unit: "seconds" });
    }

    // 4) 启动：PUT /programs/active
    const payload = {
      data: {
        key: program.key,
        options,
      },
    };

    const result = await hcFetchJson(
      userId,
      `/api/homeappliances/${encodeURIComponent(haId)}/programs/active`,
      { method: "PUT", body: payload }
    );

    return res.status(200).json({
      ok: true,
      haId,
      startedProgram: program.key,
      options,
      hcResult: result ?? null,
    });
  } catch (e) {
    const msg = String(e?.message || e);
    const status = e?.status || 500;
    return res.status(status).json({ ok: false, error: msg });
  }
}
