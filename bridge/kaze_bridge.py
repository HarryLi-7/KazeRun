#!/usr/bin/env python3
"""KazeRun portable NDJSON stdio bridge wrapping garminconnect + garmin_mcp.

Designed to run either:
1. Inside a bundled PyInstaller / relocatable sidecar on any brand-new Mac, OR
2. Using a local Python venv during development.

Tokens and user config live in ~/Library/Application Support/KazeRun/ by default
(or $KAZERUN_DATA_DIR if overridden).
"""

from __future__ import annotations

import asyncio
from datetime import date, datetime, timedelta
import inspect
import json
import math
import os
from pathlib import Path
import shutil
import sys
import traceback
import zipfile
from typing import Any

# Ensure garmin_mcp is importable (supports optional custom source path via GARMIN_MCP_SRC)
try:
    import garmin_mcp
except ImportError:
    _custom_src = os.environ.get("GARMIN_MCP_SRC")
    if _custom_src:
        _src_path = Path(_custom_src).expanduser().resolve()
        if _src_path.exists():
            sys.path.insert(0, str(_src_path))
    import garmin_mcp

from garminconnect import (
    Garmin,
    GarminConnectAuthenticationError,
    GarminConnectConnectionError,
    GarminConnectTooManyRequestsError,
)
try:
    from garminconnect import GarminConnectNotFoundError
except ImportError:
    GarminConnectNotFoundError = None

from mcp.server.fastmcp import FastMCP
from garmin_mcp import (
    activity_management,
    calendar_events,
    challenges,
    devices,
    gear_management,
    health_wellness,
    training,
    user_profile,
    workouts,
)

APP_DATA_DIR = Path(
    os.environ.get(
        "KAZERUN_DATA_DIR",
        str(Path.home() / "Library" / "Application Support" / "KazeRun"),
    )
).expanduser().resolve()
TOKEN_DIR = APP_DATA_DIR / "tokens"
CONFIG_PATH = APP_DATA_DIR / "config.json"

# Optional dev-only convenience token import path (configured via KAZERUN_DEV_TOKENS)
_dev_tokens_env = os.environ.get("KAZERUN_DEV_TOKENS")
DEV_EXISTING_TOKENS = (
    Path(_dev_tokens_env).expanduser().resolve()
    if _dev_tokens_env
    else None
)

_client: Garmin | None = None
_mcp_app: FastMCP | None = None
_pending_mfa: dict[str, Any] | None = None


def _ensure_dirs() -> None:
    APP_DATA_DIR.mkdir(parents=True, exist_ok=True)
    TOKEN_DIR.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(TOKEN_DIR, 0o700)
    except OSError:
        pass


def _load_config() -> dict[str, Any]:
    if CONFIG_PATH.exists():
        try:
            return json.loads(CONFIG_PATH.read_text("utf-8"))
        except Exception:
            pass
    return {"is_cn": True, "display_name": None, "email": None}


def _save_config(cfg: dict[str, Any]) -> None:
    _ensure_dirs()
    tmp = CONFIG_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", "utf-8")
    try:
        os.chmod(tmp, 0o600)
    except OSError:
        pass
    os.replace(tmp, CONFIG_PATH)


def _has_tokens(path: Path = TOKEN_DIR) -> bool:
    if not path.exists():
        return False
    return (path / "garmin_tokens.json").exists() or (path / "oauth1_token.json").exists()


def _secure_tokens(path: Path = TOKEN_DIR) -> None:
    try:
        os.chmod(path, 0o700)
        for item in path.iterdir():
            if item.is_file():
                os.chmod(item, 0o600)
    except OSError:
        pass


def _classify_error(exc: Exception) -> dict[str, Any]:
    msg = str(exc) or exc.__class__.__name__
    lower = msg.lower()
    if isinstance(exc, GarminConnectTooManyRequestsError) or "429" in lower or "too many requests" in lower:
        code = "rate_limited"
    elif (
        isinstance(exc, GarminConnectAuthenticationError)
        or "401" in lower
        or "403" in lower
        or "unauthorized" in lower
        or "oauth" in lower
        or "login" in lower
    ):
        code = "auth_required"
    elif (GarminConnectNotFoundError and isinstance(exc, GarminConnectNotFoundError)) or "404" in lower or "not found" in lower:
        code = "not_found"
    elif isinstance(exc, GarminConnectConnectionError) or "timeout" in lower or "connection" in lower or "dns" in lower:
        code = "network_error"
    elif isinstance(exc, ValueError):
        code = "validation_error"
    else:
        code = "unknown_error"
    return {"error_code": code, "exception": type(exc).__name__, "message": msg}


def _reset_session() -> None:
    global _client, _mcp_app
    _client = None
    _mcp_app = None


def _get_session(force_reload: bool = False) -> tuple[Garmin, FastMCP]:
    global _client, _mcp_app
    if _client is not None and _mcp_app is not None and not force_reload:
        return _client, _mcp_app

    if not _has_tokens(TOKEN_DIR):
        raise GarminConnectAuthenticationError("No saved Garmin tokens. Please sign in.")

    cfg = _load_config()
    is_cn = bool(cfg.get("is_cn", True))

    client = Garmin(is_cn=is_cn)
    client.login(str(TOKEN_DIR))

    # Configure all garmin_mcp modules in-process
    modules = [
        activity_management,
        calendar_events,
        challenges,
        devices,
        gear_management,
        health_wellness,
        training,
        user_profile,
        workouts,
    ]
    app = FastMCP("kazerun-bridge")
    for mod in modules:
        mod.configure(client)
        mod.register_tools(app)

    _client = client
    _mcp_app = app
    return client, app


async def _call_mcp_tool(app: FastMCP, name: str, **kwargs: Any) -> Any:
    tools = app._tool_manager._tools
    tool = tools.get(name)
    if tool is None:
        raise RuntimeError(f"MCP tool not found: {name}")
    fn = tool.fn
    # Filter kwargs to accepted params
    sig = inspect.signature(fn)
    filtered = {k: v for k, v in kwargs.items() if k in sig.parameters and v is not None}
    if inspect.iscoroutinefunction(fn):
        raw = await fn(**filtered)
    else:
        raw = fn(**filtered)
    if isinstance(raw, str):
        text = raw.strip()
        if text.startswith("{") or text.startswith("["):
            try:
                return json.loads(text)
            except Exception:
                return {"raw_text": raw}
        return {"raw_text": raw}
    return raw


def _safe_section(coro_or_fn, *args, **kwargs):
    pass


async def _gather_section(label: str, app: FastMCP, tool_name: str, **kwargs: Any) -> tuple[str, Any, dict[str, Any] | None]:
    try:
        data = await _call_mcp_tool(app, tool_name, **kwargs)
        if isinstance(data, dict) and isinstance(data.get("raw_text"), str):
            txt = data["raw_text"]
            if txt.startswith("Error ") or "Authentication" in txt:
                return label, None, {"message": txt}
        return label, data, None
    except Exception as exc:
        return label, None, _classify_error(exc)


# ---- Auth Handlers ----

def handle_auth_status(_params: dict[str, Any]) -> dict[str, Any]:
    _ensure_dirs()
    cfg = _load_config()
    has_tok = _has_tokens(TOKEN_DIR)
    dev_importable = DEV_EXISTING_TOKENS is not None and _has_tokens(DEV_EXISTING_TOKENS)
    return {
        "authenticated": has_tok,
        "is_cn": bool(cfg.get("is_cn", True)),
        "display_name": cfg.get("display_name"),
        "email": cfg.get("email"),
        "token_dir": str(TOKEN_DIR),
        "dev_import_available": dev_importable,
        "dev_import_path": str(DEV_EXISTING_TOKENS) if dev_importable else None,
    }


def handle_auth_login(params: dict[str, Any]) -> dict[str, Any]:
    global _pending_mfa
    _ensure_dirs()
    email = (params.get("email") or "").strip()
    password = params.get("password") or ""
    is_cn = bool(params.get("is_cn", True))
    if not email or not password:
        raise ValueError("Email and password are required")

    _reset_session()
    garmin = Garmin(email=email, password=password, is_cn=is_cn, return_on_mfa=True)
    result1, result2 = garmin.client.login(email, password, return_on_mfa=True)
    if result1 == "needs_mfa":
        _pending_mfa = {
            "garmin": garmin,
            "client_state": result2,
            "email": email,
            "is_cn": is_cn,
        }
        return {"status": "needs_mfa", "is_cn": is_cn}

    return _finalize_login(garmin, email, is_cn)


def handle_auth_mfa(params: dict[str, Any]) -> dict[str, Any]:
    global _pending_mfa
    code = (params.get("mfa_code") or "").strip()
    if not _pending_mfa:
        raise ValueError("No pending MFA login session")
    if not code:
        raise ValueError("MFA code is required")

    garmin: Garmin = _pending_mfa["garmin"]
    client_state = _pending_mfa["client_state"]
    email = _pending_mfa["email"]
    is_cn = _pending_mfa["is_cn"]
    garmin.resume_login(client_state, code)
    _pending_mfa = None
    return _finalize_login(garmin, email, is_cn)


def _finalize_login(garmin: Garmin, email: str, is_cn: bool) -> dict[str, Any]:
    garmin.client.dump(str(TOKEN_DIR))
    _secure_tokens(TOKEN_DIR)

    # Verify independent token login
    verify = Garmin(is_cn=is_cn)
    verify.login(str(TOKEN_DIR))
    display_name = None
    try:
        display_name = verify.get_full_name() or verify.display_name
    except Exception:
        display_name = email

    _save_config({"is_cn": is_cn, "display_name": display_name, "email": email})
    _reset_session()
    return {
        "status": "authenticated",
        "is_cn": is_cn,
        "display_name": display_name,
        "email": email,
        "token_dir": str(TOKEN_DIR),
    }


def handle_auth_import_tokens(params: dict[str, Any]) -> dict[str, Any]:
    _ensure_dirs()
    src_arg = params.get("source_dir") or (str(DEV_EXISTING_TOKENS) if DEV_EXISTING_TOKENS else None)
    if not src_arg:
        raise ValueError("未指定 Token 导入目录，请提供有效路径")
    source = Path(src_arg).expanduser().resolve()
    is_cn = bool(params.get("is_cn", True))
    if not _has_tokens(source):
        raise ValueError(f"No valid Garmin tokens found at {source}")

    for item in source.iterdir():
        if item.is_file() and item.suffix in (".json", ".txt", ".b64"):
            shutil.copy2(item, TOKEN_DIR / item.name)
    _secure_tokens(TOKEN_DIR)

    verify = Garmin(is_cn=is_cn)
    verify.login(str(TOKEN_DIR))
    display_name = None
    try:
        display_name = verify.get_full_name() or verify.display_name
    except Exception:
        display_name = "Garmin User"

    cfg = _load_config()
    cfg.update({"is_cn": is_cn, "display_name": display_name})
    _save_config(cfg)
    _reset_session()
    return {
        "status": "authenticated",
        "is_cn": is_cn,
        "display_name": display_name,
        "token_dir": str(TOKEN_DIR),
    }


def handle_auth_logout(_params: dict[str, Any]) -> dict[str, Any]:
    global _pending_mfa
    _pending_mfa = None
    _reset_session()
    if TOKEN_DIR.exists():
        for item in TOKEN_DIR.iterdir():
            if item.is_file():
                item.unlink()
    cfg = _load_config()
    cfg["display_name"] = None
    _save_config(cfg)
    return {"status": "logged_out"}


# ---- Data Sync Handlers ----

def _normalize_hrv_trend(raw: dict[str, Any], start_date: str, end_date: str) -> dict[str, Any]:
    summaries = raw.get("hrvSummaries") or []
    trend = []
    nightly_values = []
    for s in summaries:
        d = s.get("calendarDate")
        ln = s.get("lastNightAvg")
        wk = s.get("weeklyAvg")
        st = s.get("status")
        if ln is not None:
            nightly_values.append(float(ln))
        trend.append({
            "date": str(d),
            "last_night_avg_hrv_ms": float(ln) if ln is not None else None,
            "weekly_avg_hrv_ms": float(wk) if wk is not None else None,
            "status": st,
        })
    period_avg = round(sum(nightly_values) / len(nightly_values), 1) if nightly_values else None
    return {
        "start_date": start_date,
        "end_date": end_date,
        "period_avg_hrv_ms": period_avg,
        "trend": trend,
    }


async def handle_sync_dashboard(params: dict[str, Any]) -> dict[str, Any]:
    target_date_str = params.get("date") or date.today().isoformat()
    days_trend = int(params.get("days_trend") or 30)
    target_d = date.fromisoformat(target_date_str)
    start_trend = (target_d - timedelta(days=days_trend - 1)).isoformat()
    cal_start = (target_d - timedelta(days=7)).isoformat()
    cal_end = (target_d + timedelta(days=30)).isoformat()

    client, app = _get_session()

    # Check profile display name if missing
    cfg = _load_config()
    if not cfg.get("display_name"):
        try:
            name = client.get_full_name() or client.display_name
            if name:
                cfg["display_name"] = name
                _save_config(cfg)
        except Exception:
            pass

    async def _fetch_hrv_trend() -> tuple[str, Any, dict[str, Any] | None]:
        try:
            raw = client.get_hrv_data_range(start_trend, target_date_str)
            if isinstance(raw, dict) and isinstance(raw.get("hrvSummaries"), list):
                norm = _normalize_hrv_trend(raw, start_trend, target_date_str)
                return "hrv_trend", norm, None
        except Exception as exc:
            error = _classify_error(exc)
            if error["error_code"] in {"auth_required", "rate_limited", "network_error"}:
                return "hrv_trend", None, error
        # The MCP endpoint accepts at most 30 days; join adjacent windows without
        # dropping older observations when a 60-day range was requested.
        cursor = date.fromisoformat(start_trend)
        by_date: dict[str, Any] = {}
        while cursor <= target_d:
            end = min(cursor + timedelta(days=29), target_d)
            _, data, error = await _gather_section(
                "hrv_trend", app, "get_hrv_trend",
                start_date=cursor.isoformat(), end_date=end.isoformat(),
            )
            if error:
                return "hrv_trend", None, error
            if isinstance(data, dict) and "raw_text" in data:
                if not data["raw_text"].startswith("No HRV data found"):
                    return "hrv_trend", None, {"message": data["raw_text"]}
            elif isinstance(data, dict) and isinstance(data.get("trend"), list):
                for point in data["trend"]:
                    if isinstance(point, dict) and point.get("date"):
                        by_date[point["date"]] = point
            else:
                return "hrv_trend", None, {"message": "Invalid HRV trend response"}
            cursor = end + timedelta(days=1)
        trend = [by_date[d] for d in sorted(by_date)]
        values = [p["last_night_avg_hrv_ms"] for p in trend if p.get("last_night_avg_hrv_ms") is not None]
        return "hrv_trend", {
            "start_date": start_trend, "end_date": target_date_str,
            "period_avg_hrv_ms": round(sum(values) / len(values), 1) if values else None,
            "trend": trend,
        }, None

    tasks = [
        _gather_section("sleep_summary", app, "get_sleep_summary", date=target_date_str),
        _gather_section("hrv_data", app, "get_hrv_data", date=target_date_str, return_timeseries=True),
        _fetch_hrv_trend(),
        _gather_section("rhr_day", app, "get_rhr_day", date=target_date_str),
        _gather_section("stats", app, "get_stats", date=target_date_str),
        _gather_section("body_battery", app, "get_body_battery", start_date=target_date_str, end_date=target_date_str),
        _gather_section("stress_summary", app, "get_stress_summary", date=target_date_str),
        _gather_section("respiration_summary", app, "get_respiration_summary", date=target_date_str),
        _gather_section("spo2_data", app, "get_spo2_data", date=target_date_str),
        _gather_section("training_status", app, "get_training_status", date=target_date_str),
        _gather_section("training_load_balance", app, "get_training_load_balance", date=target_date_str),
        _gather_section("vo2max_trend", app, "get_vo2max_trend", start_date=start_trend, end_date=target_date_str),
        _gather_section("lactate_threshold", app, "get_lactate_threshold"),
        _gather_section("race_predictions", app, "get_race_predictions"),
        _gather_section("personal_record", app, "get_personal_record"),
        _gather_section("heart_rate_zones", app, "get_heart_rate_zones"),
        _gather_section("gear", app, "get_gear"),
        _gather_section("devices", app, "get_devices"),
        _gather_section("device_last_used", app, "get_device_last_used"),
        _gather_section("workouts", app, "get_workouts", start=0, limit=50),
        _gather_section("garmin_coach_workouts", app, "get_garmin_coach_workouts", calendar_date=target_date_str),
        _gather_section("scheduled_workouts", app, "get_scheduled_workouts", start_date=cal_start, end_date=cal_end),
        _gather_section("calendar_events", app, "get_calendar_events", start_date=cal_start, end_date=cal_end),
    ]

    results = await asyncio.gather(*tasks)
    payload: dict[str, Any] = {
        "captured_at": datetime.now().astimezone().isoformat(),
        "date": target_date_str,
        "display_name": cfg.get("display_name"),
        "is_cn": bool(cfg.get("is_cn", True)),
        "errors": {},
    }
    for key, val, err in results:
        payload[key] = val
        if err is not None:
            payload["errors"][key] = err
    return payload


async def handle_fetch_activities(params: dict[str, Any]) -> dict[str, Any]:
    start = int(params.get("start") or 0)
    limit = int(params.get("limit") or 30)
    _, app = _get_session()
    data = await _call_mcp_tool(app, "get_activities", start=start, limit=limit)
    if isinstance(data, dict) and "activities" in data:
        return data
    return {"activities": data if isinstance(data, list) else [], "start": start, "limit": limit, "count": 0, "has_more": False}


async def handle_fetch_activity_bundle(params: dict[str, Any]) -> dict[str, Any]:
    activity_id = int(params["activity_id"])
    client, _ = _get_session()

    def _call(method_name: str, **kwargs):
        try:
            fn = getattr(client, method_name)
            return fn(activity_id, **kwargs), None
        except Exception as exc:
            return None, _classify_error(exc)

    summary, err_sum = _call("get_activity")
    splits, err_spl = _call("get_activity_splits")
    typed_splits, err_tspl = _call("get_activity_typed_splits")
    details, err_det = _call("get_activity_details", maxchart=20000, maxpoly=4000)
    weather, err_wea = _call("get_activity_weather")
    hr_zones, err_hrz = _call("get_activity_hr_in_timezones")
    gear, err_gear = _call("get_activity_gear")
    exercise_sets, err_sets = _call("get_activity_exercise_sets")

    # Normalize time series & polyline from details for lightweight Swift Charts + MapKit rendering
    telemetry_points = _extract_telemetry_points(details)
    polyline = _extract_polyline(details)

    errors = {}
    for k, e in [
        ("summary", err_sum),
        ("splits", err_spl),
        ("typed_splits", err_tspl),
        ("details", err_det),
        ("weather", err_wea),
        ("hr_zones", err_hrz),
        ("gear", err_gear),
        ("exercise_sets", err_sets),
    ]:
        if e is not None:
            errors[k] = e

    return {
        "activity_id": activity_id,
        "fetched_at": datetime.now().astimezone().isoformat(),
        "summary": summary,
        "splits": splits,
        "typed_splits": typed_splits,
        "weather": weather,
        "hr_zones": hr_zones,
        "gear": gear,
        "exercise_sets": exercise_sets,
        "telemetry_points": telemetry_points,
        "polyline": polyline,
        "errors": errors,
    }


def _extract_telemetry_points(details: Any) -> list[dict[str, Any]]:
    if not isinstance(details, dict):
        return []
    descriptors = details.get("metricDescriptors") or []
    metrics_rows = details.get("activityDetailMetrics") or []
    if not descriptors or not metrics_rows:
        return []

    idx_map: dict[str, int] = {}
    for d in descriptors:
        key = d.get("key")
        idx = d.get("metricsIndex")
        if isinstance(key, str) and isinstance(idx, int):
            idx_map[key] = idx

    # Downsample if huge so UI charts stay 60fps
    step = max(1, len(metrics_rows) // 450)
    points: list[dict[str, Any]] = []
    for i in range(0, len(metrics_rows), step):
        row = metrics_rows[i].get("metrics") if isinstance(metrics_rows[i], dict) else None
        if not isinstance(row, list):
            continue

        def _val(k: str) -> float | None:
            idx = idx_map.get(k)
            if idx is None or idx >= len(row):
                return None
            v = row[idx]
            if isinstance(v, (int, float)) and math.isfinite(v):
                return float(v)
            return None

        t_sec = _val("sumDuration") or _val("sumMovingDuration") or float(i)
        speed = _val("directSpeed")
        pace_sec_per_km = None
        if speed is not None and speed > 0.3:
            p = 1000.0 / speed
            if 120.0 <= p <= 1200.0:
                pace_sec_per_km = round(p, 2)

        hr = _val("directHeartRate")
        cadence = _val("directDoubleCadence") or _val("directRunCadence")
        elev = _val("directElevation")
        power = _val("directPower")
        dist = _val("sumDistance")
        lat = _val("directLatitude")
        lon = _val("directLongitude")

        points.append({
            "t": round(t_sec, 1),
            "dist": round(dist, 1) if dist is not None else None,
            "hr": round(hr, 1) if hr is not None else None,
            "pace": pace_sec_per_km,
            "speed": round(speed, 3) if speed is not None else None,
            "cadence": round(cadence, 1) if cadence is not None else None,
            "elev": round(elev, 1) if elev is not None else None,
            "power": round(power, 1) if power is not None else None,
            "lat": lat,
            "lon": lon,
        })
    return points


def _extract_polyline(details: Any) -> list[list[float]]:
    if not isinstance(details, dict):
        return []
    geo = details.get("geoPolylineDTO") or {}
    poly = geo.get("polyline") or []
    coords: list[list[float]] = []
    step = max(1, len(poly) // 800) if poly else 1
    for i in range(0, len(poly), step):
        pt = poly[i]
        if isinstance(pt, dict):
            lat = pt.get("lat")
            lon = pt.get("lon")
            if isinstance(lat, (int, float)) and isinstance(lon, (int, float)) and math.isfinite(lat) and math.isfinite(lon):
                coords.append([float(lat), float(lon)])
    return coords


def handle_download_activity_fit(params: dict[str, Any]) -> dict[str, Any]:
    activity_id = int(params["activity_id"])
    dest_dir = Path(params.get("dest_dir") or str(Path.home() / "Downloads"))
    dest_dir.mkdir(parents=True, exist_ok=True)
    client, _ = _get_session()
    raw = client.download_activity(activity_id, dl_fmt=Garmin.ActivityDownloadFormat.ORIGINAL)
    if not raw:
        raise RuntimeError("Empty FIT/ZIP response from Garmin")

    zip_path = dest_dir / f"{activity_id}_ORIGINAL.zip"
    zip_path.write_bytes(bytes(raw))
    extracted: list[str] = []
    try:
        with zipfile.ZipFile(zip_path, "r") as zf:
            for member in zf.infolist():
                if not member.is_dir() and member.filename.lower().endswith(".fit"):
                    out_name = f"{activity_id}_{Path(member.filename).name}"
                    out_path = dest_dir / out_name
                    out_path.write_bytes(zf.read(member.filename))
                    extracted.append(str(out_path))
    except zipfile.BadZipFile:
        fit_path = dest_dir / f"{activity_id}_ACTIVITY.fit"
        zip_path.rename(fit_path)
        extracted.append(str(fit_path))

    return {"activity_id": activity_id, "zip_path": str(zip_path), "extracted_files": extracted}


async def handle_set_activity_gear(params: dict[str, Any]) -> dict[str, Any]:
    activity_id = int(params["activity_id"])
    gear_uuid = str(params["gear_uuid"])
    action = params.get("action", "add")
    _, app = _get_session()
    tool_name = "add_gear_to_activity" if action == "add" else "remove_gear_from_activity"
    res = await _call_mcp_tool(app, tool_name, gear_uuid=gear_uuid, activity_id=activity_id)
    return {"status": "ok", "result": res}


# ---- Workout Studio Handlers (Works for ANY user account) ----

KINDS = {"warmup": 1, "cooldown": 2, "interval": 3, "recovery": 4, "rest": 5}
SPORT = {"sportTypeId": 1, "sportTypeKey": "running"}


def _build_leaf_step(data: dict[str, Any], index: int) -> dict[str, Any]:
    kind = data.get("kind")
    if kind not in KINDS:
        raise ValueError(f"Unsupported step kind: {kind}")

    end_type = data.get("end_type", "time")
    if end_type == "lap_button":
        end_condition = {"conditionTypeId": 1, "conditionTypeKey": "lap.button"}
        end_value = None
    elif end_type == "distance":
        meters = float(data["meters"])
        if meters <= 0:
            raise ValueError("Distance must be positive")
        end_condition = {"conditionTypeId": 3, "conditionTypeKey": "distance"}
        end_value = meters
    else:
        seconds = float(data["seconds"])
        if seconds <= 0 or seconds > 86400:
            raise ValueError("Duration must be between 1 and 86400 seconds")
        end_condition = {"conditionTypeId": 2, "conditionTypeKey": "time"}
        end_value = seconds

    step_dto: dict[str, Any] = {
        "type": "ExecutableStepDTO",
        "stepOrder": index,
        "stepType": {"stepTypeId": KINDS[kind], "stepTypeKey": kind},
        "endCondition": end_condition,
        "endConditionValue": end_value,
        "description": str(data.get("note") or "")[:512],
        "targetType": {"workoutTargetTypeId": 1, "workoutTargetTypeKey": "no.target"},
    }

    target_type = data.get("target_type", "none")
    if target_type == "pace":
        fast = float(data["pace_fast_sec"])
        slow = float(data["pace_slow_sec"])
        if fast <= 0 or slow <= 0 or fast > slow:
            raise ValueError("Invalid pace range (fast <= slow required)")
        step_dto["targetType"] = {"workoutTargetTypeId": 6, "workoutTargetTypeKey": "pace.zone"}
        step_dto["targetValueOne"] = 1000.0 / slow
        step_dto["targetValueTwo"] = 1000.0 / fast
    elif target_type == "hr":
        low = float(data["hr_low"])
        high = float(data["hr_high"])
        if low <= 0 or high <= 0 or low > high:
            raise ValueError("Invalid HR range (low <= high required)")
        step_dto["targetType"] = {"workoutTargetTypeId": 4, "workoutTargetTypeKey": "heart.rate.zone"}
        step_dto["targetValueOne"] = low
        step_dto["targetValueTwo"] = high

    return step_dto


def _build_workout_dto(spec: dict[str, Any]) -> dict[str, Any]:
    name = (spec.get("name") or "").strip()
    if not name:
        raise ValueError("Workout name is required")
    description = (spec.get("description") or "").strip()
    steps_in = spec.get("steps") or []
    if not steps_in:
        raise ValueError("At least one step is required")

    dtos: list[dict[str, Any]] = []
    order = 1
    known_seconds = 0.0
    has_unknown_duration = False

    for item in steps_in:
        if item.get("kind") == "repeat":
            iterations = int(item.get("iterations") or 1)
            if not 1 <= iterations <= 99:
                raise ValueError("Repeat iterations must be 1..99")
            group_order = order
            order += 1
            children = []
            for child in item.get("steps") or []:
                leaf = _build_leaf_step(child, order)
                children.append(leaf)
                order += 1
                if leaf["endCondition"]["conditionTypeKey"] == "time":
                    known_seconds += float(leaf["endConditionValue"]) * iterations
                else:
                    has_unknown_duration = True
            dtos.append({
                "type": "RepeatGroupDTO",
                "stepOrder": group_order,
                "stepType": {"stepTypeId": 6, "stepTypeKey": "repeat"},
                "numberOfIterations": iterations,
                "smartRepeat": False,
                "endCondition": {"conditionTypeId": 7, "conditionTypeKey": "iterations"},
                "endConditionValue": float(iterations),
                "workoutSteps": children,
            })
        else:
            leaf = _build_leaf_step(item, order)
            dtos.append(leaf)
            order += 1
            if leaf["endCondition"]["conditionTypeKey"] == "time":
                known_seconds += float(leaf["endConditionValue"])
            else:
                has_unknown_duration = True

    return {
        "workoutName": name[:255],
        "description": description[:1024],
        "sportType": SPORT,
        "estimatedDurationInSecs": int(round(known_seconds)) if not has_unknown_duration and known_seconds > 0 else 0,
        "workoutSegments": [
            {
                "segmentOrder": 1,
                "sportType": SPORT,
                "workoutSteps": dtos,
            }
        ],
    }


def _parse_workout_steps(raw_dto: dict[str, Any]) -> list[dict[str, Any]]:
    segments = raw_dto.get("workoutSegments") or []
    if not segments:
        return []
    raw_steps = segments[0].get("workoutSteps") or []

    def _parse_leaf(s: dict[str, Any]) -> dict[str, Any]:
        kind = (s.get("stepType") or {}).get("stepTypeKey") or "interval"
        ec = s.get("endCondition") or {}
        eck = ec.get("conditionTypeKey") or "time"
        ecv = s.get("endConditionValue")
        end_type = "lap_button" if eck == "lap.button" else ("distance" if eck == "distance" else "time")

        tt = s.get("targetType") or {}
        ttk = tt.get("workoutTargetTypeKey") or "no.target"
        v1 = s.get("targetValueOne")
        v2 = s.get("targetValueTwo")

        out: dict[str, Any] = {
            "kind": kind,
            "end_type": end_type,
            "seconds": int(round(ecv)) if end_type == "time" and isinstance(ecv, (int, float)) else 300,
            "meters": int(round(ecv)) if end_type == "distance" and isinstance(ecv, (int, float)) else 1000,
            "note": s.get("description") or "",
            "target_type": "none",
        }
        if ttk == "pace.zone" and isinstance(v1, (int, float)) and isinstance(v2, (int, float)) and v1 > 0 and v2 > 0:
            slow_sec = round(1000.0 / min(v1, v2))
            fast_sec = round(1000.0 / max(v1, v2))
            out["target_type"] = "pace"
            out["pace_fast_sec"] = fast_sec
            out["pace_slow_sec"] = slow_sec
        elif ttk == "heart.rate.zone" and isinstance(v1, (int, float)) and isinstance(v2, (int, float)):
            out["target_type"] = "hr"
            out["hr_low"] = int(round(min(v1, v2)))
            out["hr_high"] = int(round(max(v1, v2)))
        return out

    parsed: list[dict[str, Any]] = []
    for s in raw_steps:
        if s.get("type") == "RepeatGroupDTO" or (s.get("stepType") or {}).get("stepTypeKey") == "repeat":
            parsed.append({
                "kind": "repeat",
                "iterations": int(s.get("numberOfIterations") or 2),
                "steps": [_parse_leaf(c) for c in (s.get("workoutSteps") or [])],
            })
        else:
            parsed.append(_parse_leaf(s))
    return parsed


def handle_workout_inspect(params: dict[str, Any]) -> dict[str, Any]:
    workout_id = int(params["workout_id"])
    client, _ = _get_session()
    raw = client.get_workout_by_id(workout_id)
    return {
        "workout_id": workout_id,
        "name": raw.get("workoutName"),
        "description": raw.get("description") or "",
        "sport": (raw.get("sportType") or {}).get("sportTypeKey") or "running",
        "estimated_duration_seconds": raw.get("estimatedDurationInSecs"),
        "steps": _parse_workout_steps(raw),
        "raw": raw,
    }


def handle_workout_create(params: dict[str, Any]) -> dict[str, Any]:
    spec = params["spec"]
    send_to_watch = bool(params.get("send", False))
    schedule_date = params.get("schedule_date")
    client, _ = _get_session()
    dto = _build_workout_dto(spec)
    created = client.upload_workout(dto)
    workout_id = int(created["workoutId"])

    schedule_res = None
    if schedule_date:
        schedule_res = client.connectapi(
            f"/workout-service/schedule/{workout_id}",
            method="POST",
            json={"date": schedule_date},
        )

    send_res = None
    if send_to_watch:
        send_res = _send_workout_to_primary_device(client, workout_id)

    return {
        "status": "created",
        "workout_id": workout_id,
        "name": created.get("workoutName"),
        "scheduled": schedule_res,
        "sent": send_res,
    }


def handle_workout_update(params: dict[str, Any]) -> dict[str, Any]:
    workout_id = int(params["workout_id"])
    spec = params["spec"]
    send_to_watch = bool(params.get("send", False))
    client, _ = _get_session()
    existing = client.get_workout_by_id(workout_id)
    dto = _build_workout_dto(spec)
    dto["workoutId"] = workout_id
    if "ownerId" in existing:
        dto["ownerId"] = existing["ownerId"]
    client.connectapi(
        f"/workout-service/workout/{workout_id}",
        method="PUT",
        json=dto,
    )
    send_res = _send_workout_to_primary_device(client, workout_id) if send_to_watch else None
    return {"status": "updated", "workout_id": workout_id, "name": dto["workoutName"], "sent": send_res}


def _send_workout_to_primary_device(client: Garmin, workout_id: int) -> dict[str, Any]:
    last_used = client.get_device_last_used() or {}
    device_id = last_used.get("userDeviceId")
    if not device_id:
        devs = client.get_devices() or []
        if devs:
            device_id = devs[0].get("deviceId")
    if not device_id:
        raise RuntimeError("No Garmin device found for this account")

    # Check pending queue for duplicate workoutId to avoid collision
    try:
        queue = client.connectapi(f"/device-service/devicemessage/messages/{device_id}")
        if isinstance(queue, list):
            for msg in queue:
                if str(msg.get("messageStatus")).lower() == "new" and str(msg.get("metaDataId")) == str(workout_id):
                    return {"status": "already_queued", "device_id": device_id, "message_id": msg.get("messageId")}
    except Exception:
        pass

    res = client.connectapi(
        "/device-service/devicemessage/messages",
        method="POST",
        json=[{
            "deviceId": int(device_id),
            "messageType": "workouts",
            "messageUrl": f"workout-service/workout/FIT/{workout_id}",
            "messageName": f"workout-{workout_id}",
            "priority": 1,
            "metaDataId": int(workout_id),
        }],
    )
    return {"status": "queued", "device_id": device_id, "response": res}


def handle_workout_send(params: dict[str, Any]) -> dict[str, Any]:
    workout_id = int(params["workout_id"])
    client, _ = _get_session()
    return _send_workout_to_primary_device(client, workout_id)


def handle_workout_delete(params: dict[str, Any]) -> dict[str, Any]:
    workout_id = int(params["workout_id"])
    client, _ = _get_session()
    client.delete_workout(workout_id)
    return {"status": "deleted", "workout_id": workout_id}


async def handle_workout_schedule(params: dict[str, Any]) -> dict[str, Any]:
    workout_id = int(params["workout_id"])
    date_str = str(params["date"])
    _, app = _get_session()
    res = await _call_mcp_tool(app, "schedule_workout", workout_id=workout_id, date=date_str)
    return {"status": "scheduled", "result": res}


HANDLERS = {
    "ping": lambda _p: {"ok": True, "version": "1.0.0"},
    "auth_status": handle_auth_status,
    "auth_login": handle_auth_login,
    "auth_mfa": handle_auth_mfa,
    "auth_import_tokens": handle_auth_import_tokens,
    "auth_logout": handle_auth_logout,
    "sync_dashboard": handle_sync_dashboard,
    "fetch_activities": handle_fetch_activities,
    "fetch_activity_bundle": handle_fetch_activity_bundle,
    "download_activity_fit": handle_download_activity_fit,
    "set_activity_gear": handle_set_activity_gear,
    "workout_inspect": handle_workout_inspect,
    "workout_create": handle_workout_create,
    "workout_update": handle_workout_update,
    "workout_send": handle_workout_send,
    "workout_delete": handle_workout_delete,
    "workout_schedule": handle_workout_schedule,
}


async def _dispatch(req: dict[str, Any]) -> dict[str, Any]:
    req_id = req.get("id")
    method = req.get("method")
    params = req.get("params") or {}
    handler = HANDLERS.get(method)
    if handler is None:
        return {"id": req_id, "ok": False, "error": {"error_code": "unknown_method", "message": f"Unknown method: {method}"}}
    try:
        if inspect.iscoroutinefunction(handler):
            result = await handler(params)
        else:
            result = handler(params)
        return {"id": req_id, "ok": True, "result": result}
    except Exception as exc:
        err = _classify_error(exc)
        err["traceback"] = traceback.format_exc(limit=4)
        return {"id": req_id, "ok": False, "error": err}


async def main_loop() -> None:
    _ensure_dirs()
    loop = asyncio.get_running_loop()
    while True:
        line = await loop.run_in_executor(None, sys.stdin.readline)
        if not line:
            break
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except Exception as exc:
            resp = {"id": None, "ok": False, "error": {"error_code": "invalid_json", "message": str(exc)}}
            sys.stdout.write(json.dumps(resp, ensure_ascii=False) + "\n")
            sys.stdout.flush()
            continue

        resp = await _dispatch(req)
        sys.stdout.write(json.dumps(resp, ensure_ascii=False, allow_nan=False, default=str) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    asyncio.run(main_loop())
