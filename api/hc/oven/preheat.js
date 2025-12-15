// api/hc/oven/preheat.js
import { applyCors, handleOptions } from "../_lib/cors.js";
import {
  assertEnv,
  readJson,
  getBearer,
  getUserIdFromSupabase,
  hcFetchJson,
} from "../_lib/hc.js";

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

    const haId = body.haId;
    const temperatureC = Number(body.temperatureC);

    if (!haId) return res.status(400).json({ ok: false, error: "Missing haId" });
    if (!Number.isFinite(temperatureC))
      return res.status(400).json({ ok: false, error: "Missing/invalid temperatureC" });

    // 预热程序 key（你 programs/available 里已经看到它）
    const programKey = body.programKey || "Cooking.Oven.Program.HeatingMode.PreHeating";

    // options：不同设备可能约束不同，但常见是 SetpointTemperature
    const options = [
      {
        key: "Cooking.Oven.Option.SetpointTemperature",
        value: temperatureC,
        unit: "°C",
      },
    ];

    // 可选：FastPreHeat / Duration（有些机型才支持）
    if (typeof body.fastPreHeat === "boolean") {
      options.push({
        key: "Cooking.Oven.Option.FastPreHeat",
        value: body.fastPreHeat,
      });
    }
    if (Number.isFinite(Number(body.durationSeconds))) {
      options.push({
        key: "BSH.Common.Option.Duration",
        value: Number(body.durationSeconds),
        unit: "seconds",
      });
    }

    // 设置 active program（Home Connect 标准做法）
    const path = `/api/homeappliances/${encodeURIComponent(haId)}/programs/active`;

    const payload = {
      data: {
        key: programKey,
        options,
      },
    };

    const raw = await hcFetchJson(userId, path, { method: "PUT", body: payload });

    return res.status(200).json({ ok: true, haId, programKey, options, raw });
  } catch (e) {
    const msg = String(e?.message || e);
    return res.status(500).json({ ok: false, error: msg });
  }
}
