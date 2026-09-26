from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlencode

try:
    from curl_cffi import requests as chrome_requests
except ImportError:  # optional one-time acquisition dependency
    chrome_requests = None

ROOT = Path(__file__).resolve().parents[1] if Path(__file__).resolve().parent.name == "tools" else Path.cwd()
DEFAULT_PLAN = ROOT / "assets/data/nba/metadata/nba_com_capture_plan_part1.json"
DEFAULT_OUTPUT = ROOT / "raw/nba_com_stats"
BASE = "https://stats.nba.com/stats"
NBA_HOME = "https://www.nba.com/"
NBA_STATS_HOME = "https://www.nba.com/stats"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36"
)
REQUEST_HEADERS = {
    "Accept": "*/*",
    "Accept-Language": "en-US,en;q=0.9",
    "Origin": "https://www.nba.com",
    "Referer": "https://www.nba.com/",
    "User-Agent": USER_AGENT,
    "Sec-Fetch-Dest": "empty",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Site": "same-site",
    "sec-ch-ua": '"Not=A?Brand";v="99", "Google Chrome";v="151", "Chromium";v="151"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": '"macOS"',
}
CONTRACT = "sports-terminal-nba-com-historical-capture-v1"


class ScopeUnavailable(RuntimeError):
    """The request contract is valid, but NBA.com does not expose this historical scope."""



@dataclass(frozen=True)
class Variant:
    key: str
    params: dict[str, str]


@dataclass(frozen=True)
class Surface:
    key: str
    endpoint: str
    resource: str
    result_set: str
    grain: str
    season_parameter: str
    params: dict[str, str]
    variants: tuple[Variant, ...]
    row_ceiling_regular: int
    row_ceiling_playoffs: int
    grouped_headers: bool = False


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def season_start(season: str) -> int:
    match = re.fullmatch(r"(\d{4})-(\d{2}|\d{4})", season.strip())
    if not match:
        raise ValueError(f"Invalid NBA season label: {season}")
    return int(match.group(1))


def season_label(year: int) -> str:
    return f"{year:04d}-{(year + 1) % 100:02d}"


def seasons_between(start: str, end: str, *, newest_first: bool = True) -> list[str]:
    first, last = season_start(start), season_start(end)
    if first > last:
        first, last = last, first
    values = [season_label(year) for year in range(first, last + 1)]
    return list(reversed(values)) if newest_first else values


def season_type_key(label: str) -> str:
    return "playoffs" if "play" in label.lower() else "regular"


def season_type_folder(label: str) -> str:
    return season_type_key(label)


def load_plan(path: Path) -> tuple[dict[str, Any], list[Surface]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    raw_surfaces = payload.get("surfaces")
    if not isinstance(raw_surfaces, list):
        raise RuntimeError(f"Capture plan has no surfaces list: {path}")
    surfaces: list[Surface] = []
    seen_keys: set[str] = set()
    for raw in raw_surfaces:
        if not isinstance(raw, dict):
            continue
        key = str(raw.get("key") or "").strip()
        if not key or key in seen_keys:
            raise RuntimeError(f"Capture plan surface key is missing/duplicated: {key!r}")
        seen_keys.add(key)
        variants: list[Variant] = []
        variant_keys: set[str] = set()
        for item in raw.get("variants") or [{"key": "default", "params": {}}]:
            if not isinstance(item, dict):
                continue
            variant_key = str(item.get("key") or "default").strip()
            if variant_key in variant_keys:
                raise RuntimeError(f"Duplicate variant key {key}/{variant_key}")
            variant_keys.add(variant_key)
            variants.append(
                Variant(
                    key=variant_key,
                    params={str(k): str(v) for k, v in dict(item.get("params") or {}).items()},
                )
            )
        ceilings = raw.get("row_ceiling") or {}
        surfaces.append(
            Surface(
                key=key,
                endpoint=str(raw.get("endpoint") or ""),
                resource=str(raw.get("resource") or ""),
                result_set=str(raw.get("result_set") or ""),
                grain=str(raw.get("grain") or ""),
                season_parameter=str(raw.get("season_parameter") or "Season"),
                params={str(k): str(v) for k, v in dict(raw.get("params") or {}).items()},
                variants=tuple(variants),
                row_ceiling_regular=int(ceilings.get("regular") or 0),
                row_ceiling_playoffs=int(ceilings.get("playoffs") or 0),
                grouped_headers=bool(raw.get("grouped_headers")),
            )
        )
    return payload, surfaces


def request_params(surface: Surface, variant: Variant, season: str, season_type: str) -> dict[str, str]:
    params = dict(surface.params)
    params.update(variant.params)
    params[surface.season_parameter] = season
    params["SeasonType"] = season_type
    return params


def request_url(surface: Surface, variant: Variant, season: str, season_type: str) -> str:
    return f"{BASE}/{surface.endpoint}?{urlencode(request_params(surface, variant, season, season_type))}"


def build_chrome_session(timeout: int):
    if chrome_requests is None:
        return None
    session = chrome_requests.Session(impersonate="chrome")
    for url in (NBA_HOME, NBA_STATS_HOME):
        try:
            session.get(
                url,
                headers={"User-Agent": USER_AGENT, "Accept-Language": "en-US,en;q=0.9"},
                timeout=min(max(timeout, 5), 20),
                allow_redirects=True,
            )
        except Exception:
            pass
    return session


def _decode_payload(raw: bytes) -> dict[str, Any]:
    payload = json.loads(raw.decode("utf-8"))
    if not isinstance(payload, dict):
        raise RuntimeError("NBA.com returned JSON that was not an object")
    return payload


def fetch_json_chrome(session: Any, url: str, timeout: int, retries: int) -> tuple[bytes, dict[str, Any]]:
    last_error = ""
    for attempt in range(retries + 1):
        try:
            response = session.get(url, headers=REQUEST_HEADERS, timeout=timeout, allow_redirects=True)
            status = int(response.status_code)
            if status == 429 or status >= 500:
                last_error = f"HTTP {status}"
            elif status in {400, 404, 410, 422}:
                raise ScopeUnavailable(f"HTTP {status}")
            elif status >= 400:
                raise RuntimeError(f"HTTP {status}")
            else:
                raw = bytes(response.content)
                return raw, _decode_payload(raw)
        except ScopeUnavailable:
            raise
        except RuntimeError:
            raise
        except Exception as exc:
            last_error = str(exc)
        if attempt < retries:
            time.sleep(min(12.0, max(1.0, 1.5 * (2**attempt))))
    raise RuntimeError(last_error or "NBA.com Chrome-like request failed")


def fetch_json_curl(url: str, timeout: int, retries: int) -> tuple[bytes, dict[str, Any]]:
    cmd = [
        "curl", "--fail", "--silent", "--show-error", "--location", "--compressed", "--http1.1",
        "--connect-timeout", str(min(10, timeout)), "--max-time", str(timeout), url,
    ]
    for key, value in REQUEST_HEADERS.items():
        cmd.extend(["-H", f"{key}: {value}"])
    last_error = ""
    for attempt in range(retries + 1):
        completed = subprocess.run(cmd, capture_output=True)
        if completed.returncode == 0:
            try:
                return completed.stdout, _decode_payload(completed.stdout)
            except Exception as exc:
                last_error = f"NBA.com returned non-JSON content: {exc}"
        else:
            last_error = completed.stderr.decode("utf-8", errors="replace").strip() or f"curl exit {completed.returncode}"
        if attempt < retries:
            time.sleep(min(12.0, max(1.0, 1.5 * (2**attempt))))
    raise RuntimeError(last_error or "NBA.com curl request failed")


def fetch_json(url: str, timeout: int, retries: int, *, transport: str, chrome_session: Any) -> tuple[bytes, dict[str, Any]]:
    if transport in {"auto", "chrome"}:
        if chrome_session is not None:
            try:
                return fetch_json_chrome(chrome_session, url, timeout, retries)
            except ScopeUnavailable:
                raise
            except Exception:
                if transport == "chrome":
                    raise
        elif transport == "chrome":
            raise RuntimeError("Chrome transport requires curl-cffi; use the repository wrapper script.")
    return fetch_json_curl(url, timeout, retries)


def _result_sets(payload: dict[str, Any]) -> list[dict[str, Any]]:
    raw = payload.get("resultSets")
    if raw is None:
        raw = payload.get("resultSet")
    if isinstance(raw, dict):
        raw = [raw]
    if not isinstance(raw, list):
        return []
    return [dict(item) for item in raw if isinstance(item, dict)]


def _flatten_grouped_headers(headers: list[Any]) -> list[str]:
    """Flatten NBA grouped headers (notably LeagueDashPlayerShotLocations).

    Example source shape has one grouping object with columnsToSkip=6,
    columnSpan=3 and zone names, plus a columns object whose columnNames are
    PLAYER_ID... followed by repeated FGM/FGA/FG_PCT. The flattened schema keeps
    identity fields as-is and prefixes repeated metric fields with their zone.
    """
    objects = [item for item in headers if isinstance(item, dict)]
    if not objects:
        return [str(item) for item in headers]
    columns_obj = next((item for item in objects if str(item.get("name") or "").lower() == "columns"), None)
    if columns_obj is None:
        columns_obj = max(objects, key=lambda item: len(item.get("columnNames") or []) if isinstance(item.get("columnNames"), list) else 0)
    columns = [str(value) for value in (columns_obj.get("columnNames") or [])]
    grouping = next((item for item in objects if item is not columns_obj and isinstance(item.get("columnNames"), list)), None)
    if grouping is None or not columns:
        return columns
    groups = [str(value) for value in grouping.get("columnNames") or []]
    skip = int(grouping.get("columnsToSkip") or 0)
    span = max(1, int(grouping.get("columnSpan") or 1))
    flattened: list[str] = []
    for index, column in enumerate(columns):
        if index < skip:
            flattened.append(column)
            continue
        group_index = (index - skip) // span
        group = groups[group_index] if group_index < len(groups) else f"group_{group_index + 1}"
        flattened.append(f"{group}__{column}")
    return flattened


def normalize_result_set(result_set: dict[str, Any]) -> dict[str, Any]:
    source_headers = result_set.get("headers") or []
    if isinstance(source_headers, list) and source_headers and isinstance(source_headers[0], dict):
        headers = _flatten_grouped_headers(source_headers)
    elif isinstance(source_headers, list):
        headers = [str(value) for value in source_headers]
    else:
        headers = []
    raw_rows = result_set.get("rowSet")
    if raw_rows is None:
        raw_rows = result_set.get("rowset")
    if raw_rows is None:
        raw_rows = result_set.get("rows")
    rows: list[dict[str, Any]] = []
    if isinstance(raw_rows, list):
        for raw_row in raw_rows:
            if isinstance(raw_row, dict):
                rows.append({str(k): v for k, v in raw_row.items()})
            elif isinstance(raw_row, (list, tuple)):
                rows.append({headers[i] if i < len(headers) else f"column_{i}": value for i, value in enumerate(raw_row)})
    if not headers and rows:
        headers = list(rows[0])
    return {
        "name": str(result_set.get("name") or result_set.get("resultSetName") or "ResultSet"),
        "headers": headers,
        "source_headers": source_headers,
        "rows": rows,
    }


def normalize_payload(payload: dict[str, Any]) -> list[dict[str, Any]]:
    return [normalize_result_set(item) for item in _result_sets(payload)]


def schema_sha256(tables: list[dict[str, Any]]) -> str:
    schema = [{"name": table.get("name"), "headers": table.get("headers")} for table in tables]
    return hashlib.sha256(json.dumps(schema, sort_keys=True, separators=(",", ":"), default=str).encode("utf-8")).hexdigest()


def validate_capture(surface: Surface, season_type: str, payload: dict[str, Any], tables: list[dict[str, Any]]) -> dict[str, Any]:
    result_names = {str(table.get("name") or "") for table in tables}
    row_count = sum(len(table.get("rows") or []) for table in tables)
    ceiling = surface.row_ceiling_playoffs if season_type_key(season_type) == "playoffs" else surface.row_ceiling_regular
    errors: list[str] = []
    warnings: list[str] = []
    if surface.result_set and surface.result_set not in result_names:
        errors.append(f"expected result set {surface.result_set!r}; received {sorted(result_names)}")
    if ceiling > 0 and row_count > ceiling:
        errors.append(f"row count {row_count} exceeds user-supplied ceiling {ceiling}")
    if ceiling > 0 and row_count >= int(ceiling * 0.95):
        warnings.append(f"row count {row_count} is within 5% of ceiling {ceiling}; inspect for possible truncation")
    resource = str(payload.get("resource") or "")
    if surface.resource and resource and resource != surface.resource:
        warnings.append(f"resource changed from captured {surface.resource!r} to {resource!r}")
    status = "invalid" if errors else ("empty" if row_count == 0 else "success")
    return {"status": status, "row_count": row_count, "row_ceiling": ceiling, "errors": errors, "warnings": warnings}


def capture_dir(output: Path, surface: Surface, variant: Variant, season: str, season_type: str) -> Path:
    return output / surface.key / variant.key / season / season_type_folder(season_type)


def existing_valid(folder: Path) -> bool:
    metadata = folder / "metadata.json"
    normalized = folder / "normalized.json"
    if not metadata.is_file() or not normalized.is_file():
        return False
    try:
        payload = json.loads(metadata.read_text(encoding="utf-8"))
    except Exception:
        return False
    return payload.get("validation_status") in {"success", "empty", "unavailable"}


def write_capture(*, output: Path, surface: Surface, variant: Variant, season: str, season_type: str, url: str, raw: bytes, payload: dict[str, Any]) -> dict[str, Any]:
    folder = capture_dir(output, surface, variant, season, season_type)
    folder.mkdir(parents=True, exist_ok=True)
    tables = normalize_payload(payload)
    validation = validate_capture(surface, season_type, payload, tables)
    digest = hashlib.sha256(raw).hexdigest()
    schema_digest = schema_sha256(tables)
    (folder / "source.json").write_bytes(raw)
    normalized = {
        "contract": CONTRACT,
        "surface": surface.key,
        "variant": variant.key,
        "grain": surface.grain,
        "season": season,
        "season_type": season_type,
        "resource": payload.get("resource"),
        "parameters": payload.get("parameters") or request_params(surface, variant, season, season_type),
        "schema_sha256": schema_digest,
        "tables": tables,
    }
    (folder / "normalized.json").write_text(json.dumps(normalized, ensure_ascii=False, separators=(",", ":"), default=str), encoding="utf-8")
    metadata = {
        "contract": CONTRACT,
        "captured_at": now_iso(),
        "source_url": url,
        "source_sha256": digest,
        "schema_sha256": schema_digest,
        "rights": "NBA.com endpoint response captured locally; redistribution rights are not inferred",
        "surface": surface.key,
        "variant": variant.key,
        "endpoint": surface.endpoint,
        "grain": surface.grain,
        "season": season,
        "season_type": season_type,
        "result_set": surface.result_set,
        "row_count": validation["row_count"],
        "row_ceiling": validation["row_ceiling"],
        "validation_status": validation["status"],
        "validation_errors": validation["errors"],
        "validation_warnings": validation["warnings"],
    }
    (folder / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, separators=(",", ":"), default=str), encoding="utf-8")
    return metadata


def write_unavailable(*, output: Path, surface: Surface, variant: Variant, season: str, season_type: str, url: str, reason: str) -> dict[str, Any]:
    folder = capture_dir(output, surface, variant, season, season_type)
    folder.mkdir(parents=True, exist_ok=True)
    metadata = {
        "contract": CONTRACT,
        "captured_at": now_iso(),
        "source_url": url,
        "surface": surface.key,
        "variant": variant.key,
        "endpoint": surface.endpoint,
        "grain": surface.grain,
        "season": season,
        "season_type": season_type,
        "result_set": surface.result_set,
        "row_count": 0,
        "row_ceiling": surface.row_ceiling_playoffs if season_type_key(season_type) == "playoffs" else surface.row_ceiling_regular,
        "validation_status": "unavailable",
        "unavailable_reason": reason,
    }
    (folder / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    return metadata


def write_failure(*, output: Path, surface: Surface, variant: Variant, season: str, season_type: str, url: str, error: str) -> dict[str, Any]:
    folder = capture_dir(output, surface, variant, season, season_type)
    folder.mkdir(parents=True, exist_ok=True)
    metadata = {
        "contract": CONTRACT,
        "captured_at": now_iso(),
        "source_url": url,
        "surface": surface.key,
        "variant": variant.key,
        "endpoint": surface.endpoint,
        "grain": surface.grain,
        "season": season,
        "season_type": season_type,
        "result_set": surface.result_set,
        "row_count": 0,
        "row_ceiling": surface.row_ceiling_playoffs if season_type_key(season_type) == "playoffs" else surface.row_ceiling_regular,
        "validation_status": "failure",
        "error": error,
    }
    (folder / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    return metadata


def coverage_key(surface: Surface, variant: Variant, season: str, season_type: str) -> str:
    return f"{surface.key}/{variant.key}/{season}/{season_type_folder(season_type)}"


def load_coverage(path: Path) -> dict[str, Any]:
    if path.is_file():
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                return payload
        except Exception:
            pass
    return {"contract": CONTRACT, "updated_at": now_iso(), "scopes": {}}


def save_coverage(path: Path, coverage: dict[str, Any], *, plan_path: Path) -> None:
    scopes = coverage.get("scopes") if isinstance(coverage.get("scopes"), dict) else {}
    status_counts: dict[str, int] = {}
    rows = 0
    for item in scopes.values():
        if not isinstance(item, dict):
            continue
        status = str(item.get("validation_status") or "unknown")
        status_counts[status] = status_counts.get(status, 0) + 1
        rows += int(item.get("row_count") or 0)
    coverage["updated_at"] = now_iso()
    coverage["plan"] = str(plan_path)
    coverage["summary"] = {"scope_count": len(scopes), "status_counts": status_counts, "row_count": rows}
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(".json.tmp")
    temp.write_text(json.dumps(coverage, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
    temp.replace(path)


def plan_summary(plan_payload: dict[str, Any], surfaces: list[Surface]) -> dict[str, Any]:
    season_range = plan_payload.get("season_range") or {}
    seasons = seasons_between(str(season_range.get("from") or "1946-47"), str(season_range.get("to") or "2025-26"))
    variants = sum(len(surface.variants) for surface in surfaces)
    season_types = list(plan_payload.get("season_types") or ["Regular Season", "Playoffs"])
    return {
        "contract": CONTRACT,
        "surfaces": len(surfaces),
        "variants": variants,
        "seasons": len(seasons),
        "season_types": season_types,
        "planned_scopes": variants * len(seasons) * len(season_types),
        "first_season": seasons[-1] if seasons else None,
        "last_season": seasons[0] if seasons else None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Capture every configured historical NBA.com Stats scope into immutable local source + normalized files.")
    parser.add_argument("--plan", type=Path, default=DEFAULT_PLAN)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--start", default="")
    parser.add_argument("--end", default="")
    parser.add_argument("--season", action="append", default=[])
    parser.add_argument("--season-type", choices=("regular", "playoffs", "both"), default="both")
    parser.add_argument("--surface", action="append", default=[])
    parser.add_argument("--variant", action="append", default=[])
    parser.add_argument("--transport", choices=("auto", "chrome", "curl"), default="auto")
    parser.add_argument("--delay", type=float, default=2.5)
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("--retries", type=int, default=3)
    parser.add_argument("--recovery-retries", type=int, default=3, help="Fresh-session recovery cycles after a scope exhausts normal retries.")
    parser.add_argument("--recovery-cooldown", type=float, default=30.0, help="Base seconds to cool down before rebuilding the NBA.com session.")
    parser.add_argument("--abort-after", type=int, default=5)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--oldest-first", action="store_true")
    parser.add_argument("--probe-only", action="store_true")
    parser.add_argument("--plan-summary", action="store_true")
    args = parser.parse_args()

    plan_path = args.plan.expanduser().resolve()
    output = args.output.expanduser().resolve()
    plan_payload, surfaces = load_plan(plan_path)
    if args.surface:
        selected = set(args.surface)
        unknown = selected - {surface.key for surface in surfaces}
        if unknown:
            parser.error(f"Unknown --surface values: {', '.join(sorted(unknown))}")
        surfaces = [surface for surface in surfaces if surface.key in selected]
    if args.plan_summary:
        print(json.dumps(plan_summary(plan_payload, surfaces), indent=2))
        return 0

    bounds = plan_payload.get("season_range") or {}
    start = args.start or str(bounds.get("from") or "1946-47")
    end = args.end or str(bounds.get("to") or "2025-26")
    seasons = list(dict.fromkeys(args.season)) if args.season else seasons_between(start, end, newest_first=not args.oldest_first)
    season_types = ["Regular Season", "Playoffs"] if args.season_type == "both" else ["Playoffs" if args.season_type == "playoffs" else "Regular Season"]
    selected_variants = set(args.variant)

    chrome_session = None
    if args.transport in {"auto", "chrome"} and chrome_requests is not None:
        print("==> Initializing Chrome-like NBA.com session")
        chrome_session = build_chrome_session(args.timeout)
    elif args.transport == "chrome":
        raise SystemExit("curl-cffi is not installed. Use scripts/fetch_nba_com_historical_stats.sh.")

    coverage_path = output / "coverage.json"
    coverage = load_coverage(coverage_path)
    scopes = coverage.setdefault("scopes", {})
    counters = {"attempted": 0, "success": 0, "empty": 0, "unavailable": 0, "invalid": 0, "failure": 0, "skipped": 0, "rows": 0}
    consecutive_failures = 0
    last_request_at = 0.0
    stop = False

    for season in seasons:
        for surface in surfaces:
            for variant in surface.variants:
                if selected_variants and variant.key not in selected_variants and f"{surface.key}/{variant.key}" not in selected_variants:
                    continue
                for season_type in season_types:
                    folder = capture_dir(output, surface, variant, season, season_type)
                    key = coverage_key(surface, variant, season, season_type)
                    if not args.force and existing_valid(folder):
                        counters["skipped"] += 1
                        metadata = json.loads((folder / "metadata.json").read_text(encoding="utf-8"))
                        scopes[key] = metadata
                        continue
                    url = request_url(surface, variant, season, season_type)
                    counters["attempted"] += 1
                    label = f"{surface.key}/{variant.key} {season} {season_type}"
                    print(f"Fetching {label}")
                    elapsed = time.monotonic() - last_request_at
                    if elapsed < max(0.0, args.delay):
                        time.sleep(max(0.0, args.delay) - elapsed)
                    try:
                        last_request_at = time.monotonic()
                        recovery_cycle = 0
                        while True:
                            try:
                                raw, payload = fetch_json(url, args.timeout, max(0, args.retries), transport=args.transport, chrome_session=chrome_session)
                                break
                            except ScopeUnavailable:
                                raise
                            except Exception as exc:
                                if recovery_cycle >= max(0, args.recovery_retries):
                                    raise
                                recovery_cycle += 1
                                cooldown = max(0.0, args.recovery_cooldown) * (2 ** (recovery_cycle - 1))
                                print(
                                    f"  transient transport failure: {exc}\n"
                                    f"  cooling down {cooldown:.0f}s, rebuilding session, then retrying "
                                    f"(recovery {recovery_cycle}/{args.recovery_retries})"
                                )
                                time.sleep(cooldown)
                                if args.transport in {"auto", "chrome"} and chrome_requests is not None:
                                    try:
                                        if chrome_session is not None:
                                            chrome_session.close()
                                    except Exception:
                                        pass
                                    chrome_session = build_chrome_session(args.timeout)
                                last_request_at = time.monotonic()
                        metadata = write_capture(output=output, surface=surface, variant=variant, season=season, season_type=season_type, url=url, raw=raw, payload=payload)
                        status = str(metadata["validation_status"])
                        counters[status] = counters.get(status, 0) + 1
                        counters["rows"] += int(metadata.get("row_count") or 0)
                        consecutive_failures = 0 if status != "invalid" else consecutive_failures
                        print(f"  {status}: {metadata['row_count']} rows (ceiling {metadata['row_ceiling']})")
                        for warning in metadata.get("validation_warnings") or []:
                            print(f"  WARNING: {warning}")
                    except ScopeUnavailable as exc:
                        metadata = write_unavailable(output=output, surface=surface, variant=variant, season=season, season_type=season_type, url=url, reason=str(exc))
                        counters["unavailable"] += 1
                        consecutive_failures = 0
                        print(f"  unavailable: {exc}")
                    except Exception as exc:
                        metadata = write_failure(output=output, surface=surface, variant=variant, season=season, season_type=season_type, url=url, error=f"{type(exc).__name__}: {exc}")
                        counters["failure"] += 1
                        consecutive_failures += 1
                        print(f"  FAILED: {exc}")
                    scopes[key] = metadata
                    save_coverage(coverage_path, coverage, plan_path=plan_path)
                    if args.probe_only:
                        stop = True
                        break
                    if args.abort_after > 0 and consecutive_failures >= args.abort_after:
                        print(f"Aborting after {consecutive_failures} consecutive failures; likely transport/session rejection.")
                        stop = True
                        break
                if stop:
                    break
            if stop:
                break
        if stop:
            break

    save_coverage(coverage_path, coverage, plan_path=plan_path)
    print(json.dumps({"contract": CONTRACT, **counters, "coverage": str(coverage_path)}, indent=2))
    return 0 if counters["invalid"] == 0 and (counters["failure"] == 0 or counters["success"] + counters["empty"] + counters["unavailable"] + counters["skipped"] > 0) else 1


if __name__ == "__main__":
    raise SystemExit(main())
