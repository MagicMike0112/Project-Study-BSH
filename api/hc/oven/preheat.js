// api/hc/oven/preheat.js
import { applyCors, handleOptions } from "../../_lib/cors.js";
import {
  assertEnv,
  readJson,
  getBearer,
  getUserIdFromSupabase,
  hcFetchJson,
} from "../../_lib/hc.js";

const DEFAULT_PROGRAM_KEY = "Cooking.Oven.Program.HeatingMode.PreHeating";

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

    let haId = body?.haId || null;
    const temperatureC = Number(body?.temperatureC);

    if (!Number.isFinite(temperatureC)) {
      return res.status(400).json({ ok: false, error: "Missing/invalid temperatureC" });
    }

    // 不传 haId：自动找第一个 oven（跑通最省事）
    if (!haId) {
      const listResp = await hcFetchJson(userId, "/api/homeappliances", { method: "GET" });
      const list = listResp?.data?.homeappliances || listResp?.homeappliances || [];
      const oven = list.find((x) => String(x?.type || "").toLowerCase() === "oven");
      if (!oven?.haId) {
        return res.status(400).json({ ok: false, error: "No oven found in homeappliances" });
      }
      haId = oven.haId;
    }

    const programKey = body?.programKey || DEFAULT_PROGRAM_KEY;

    const options = [
      {
        key: "Cooking.Oven.Option.SetpointTemperature",
        value: temperatureC,
        unit: "C", // 比 "°C" 更稳
      },
    ];

    if (typeof body?.fastPreHeat === "boolean") {
      options.push({
        key: "Cooking.Oven.Option.FastPreHeat",
        value: body.fastPreHeat,
      });
    }
    if (Number.isFinite(Number(body?.durationSeconds))) {
      options.push({
        key: "BSH.Common.Option.Duration",
        value: Number(body.durationSeconds),
        unit: "seconds",
      });
    }

    const path = `/api/homeappliances/${encodeURIComponent(haId)}/programs/active`;
    const payload = { data: { key: programKey, options } };

    const raw = await hcFetchJson(userId, path, { method: "PUT", body: payload });

    return res.status(200).json({ ok: true, haId, programKey, options, raw });
  } catch (e) {
    const msg = String(e?.message || e);
    const status = Number.isFinite(e?.status) ? e.status : 500;
    return res.status(status).json({ ok: false, error: msg });
  }
}
