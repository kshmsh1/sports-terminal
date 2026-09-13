from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

try:
    from curl_cffi import requests as chrome_requests
except ImportError:  # Optional one-time acquisition dependency.
    chrome_requests = None

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "raw" / "nba_com_stats"
BASE = "https://stats.nba.com/stats"
NBA_HOME = "https://www.nba.com/"
NBA_STATS_HOME = "https://www.nba.com/stats"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36"
)

SURFACES: dict[str, dict[str, Any]] = {
    "players_hustle": {
        "endpoint": "leaguehustlestatsplayer",
        "category": None,
        "first_season": "2015-16",
    },
    "players_defense_dashboard": {
        "endpoint": "leaguedashptdefend",
        "category": "Overall",
        "first_season": "2013-14",
    },
    "players_defense_dashboard_3pt": {
        "endpoint": "leaguedashptdefend",
        "category": "3 Pointers",
        "first_season": "2013-14",
    },
    "players_defense_dashboard_2pt": {
        "endpoint": "leaguedashptdefend",
        "category": "2 Pointers",
        "first_season": "2013-14",
    },
    "players_defense_dashboard_lt6ft": {
        "endpoint": "leaguedashptdefend",
        "category": "Less Than 6Ft",
        "first_season": "2013-14",
    },
}

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


def season_start(season: str) -> int:
    return int(season.split("-", 1)[0])


def seasons_between(start: str, end: str, *, newest_first: bool = True) -> list[str]:
    a = season_start(start)
    b = season_start(end)
    if a > b:
        a, b = b, a
    values = [f"{year}-{str((year + 1) % 100).zfill(2)}" for year in range(a, b + 1)]
    return list(reversed(values)) if newest_first else values


def season_type_folder(season_type: str) -> str:
    return "playoffs" if "play" in season_type.lower() else "regular"


def hustle_params(season: str, season_type: str) -> dict[str, Any]:
    # Matches the request shape captured from NBA.com's Players > Hustle page.
    return {
        "College": "",
        "Conference": "",
        "Country": "",
        "DateFrom": "",
        "DateTo": "",
        "Division": "",
        "DraftPick": "",
        "DraftYear": "",
        "GameScope": "",
        "Height": "",
        "ISTRound": "",
        "LastNGames": 0,
        "LeagueID": "00",
        "Location": "",
        "Month": 0,
        "OpponentTeamID": 0,
        "Outcome": "",
        "PORound": 0,
        "PaceAdjust": "N",
        "PerMode": "Totals",
        "PlayerExperience": "",
        "PlayerPosition": "",
        "PlusMinus": "N",
        "Rank": "N",
        "Season": season,
        "SeasonSegment": "",
        "SeasonType": season_type,
        "TeamID": 0,
        "VsConference": "",
        "VsDivision": "",
        "Weight": "",
    }


def defense_params(season: str, season_type: str, category: str) -> dict[str, Any]:
    # Matches the request shape captured from NBA.com's Players > Defense Dashboard page.
    return {
        "College": "",
        "Conference": "",
        "Country": "",
        "DateFrom": "",
        "DateTo": "",
        "DefenseCategory": category,
        "Division": "",
        "DraftPick": "",
        "DraftYear": "",
        "GameSegment": "",
        "Height": "",
        "ISTRound": "",
        "LastNGames": 0,
        "LeagueID": "00",
        "Location": "",
        "Month": 0,
        "OpponentTeamID": 0,
        "Outcome": "",
        "PORound": 0,
        "PerMode": "Totals",
        "Period": 0,
        "PlayerExperience": "",
        "PlayerPosition": "",
        "Season": season,
        "SeasonSegment": "",
        "SeasonType": season_type,
        "StarterBench": "",
        "TeamID": 0,
        "VsConference": "",
        "VsDivision": "",
        "Weight": "",
    }


def _payload_from_bytes(raw: bytes) -> dict[str, Any]:
    payload = json.loads(raw.decode("utf-8"))
    if not isinstance(payload, dict):
        raise RuntimeError("NBA.com returned JSON that was not an object")
    return payload


def build_chrome_session(timeout: int):
    if chrome_requests is None:
        return None
    session = chrome_requests.Session(impersonate="chrome")
    # Establish NBA/Akamai cookies in the same browser-like session before the
    # stats subdomain request. Warm-up failures are non-fatal; the API request
    # still gets a chance to succeed.
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


def fetch_json_chrome(session: Any, url: str, timeout: int, retries: int) -> tuple[bytes, dict[str, Any]]:
    last_error: str | None = None
    for attempt in range(retries + 1):
        try:
            response = session.get(
                url,
                headers=REQUEST_HEADERS,
                timeout=timeout,
                allow_redirects=True,
            )
            if response.status_code >= 400:
                last_error = f"HTTP {response.status_code}"
            else:
                raw = bytes(response.content)
                try:
                    return raw, _payload_from_bytes(raw)
                except Exception as exc:
                    last_error = f"NBA.com returned non-JSON content: {exc}"
        except Exception as exc:
            last_error = str(exc)
        if attempt < retries:
            time.sleep(min(6.0, 1.25 * (attempt + 1)))
    raise RuntimeError(last_error or "NBA.com Chrome-like request failed")


def fetch_json_curl(url: str, timeout: int, retries: int) -> tuple[bytes, dict[str, Any]]:
    cmd = [
        "curl",
        "--fail",
        "--silent",
        "--show-error",
        "--location",
        "--compressed",
        "--http1.1",
        "--connect-timeout",
        str(min(10, timeout)),
        "--max-time",
        str(timeout),
        url,
    ]
    for key, value in REQUEST_HEADERS.items():
        cmd.extend(["-H", f"{key}: {value}"])
    cmd.extend(["-H", "priority: u=1, i"])

    last_error: str | None = None
    for attempt in range(retries + 1):
        completed = subprocess.run(cmd, capture_output=True)
        if completed.returncode == 0:
            raw = completed.stdout
            try:
                return raw, _payload_from_bytes(raw)
            except Exception as exc:
                last_error = f"NBA.com returned non-JSON content: {exc}"
        else:
            last_error = (
                completed.stderr.decode("utf-8", errors="replace").strip()
                or f"curl exit {completed.returncode}"
            )
        if attempt < retries:
            time.sleep(min(6.0, 1.25 * (attempt + 1)))
    raise RuntimeError(last_error or "NBA.com curl request failed")


def fetch_json(
    url: str,
    timeout: int,
    retries: int,
    *,
    transport: str,
    chrome_session: Any,
) -> tuple[bytes, dict[str, Any]]:
    if transport in {"auto", "chrome"}:
        if chrome_session is not None:
            try:
                return fetch_json_chrome(chrome_session, url, timeout, retries)
            except Exception:
                if transport == "chrome":
                    raise
        elif transport == "chrome":
            raise RuntimeError(
                "Chrome transport requires curl-cffi. Run the repository wrapper "
                "scripts/fetch_nba_com_hustle_defense.sh, which installs the one-time fetch dependency."
            )
    return fetch_json_curl(url, timeout, retries)


def normalize_result_sets(payload: dict[str, Any]) -> list[dict[str, Any]]:
    raw_sets = payload.get("resultSets")
    if raw_sets is None:
        raw_sets = payload.get("resultSet")
    if isinstance(raw_sets, dict):
        raw_sets = [raw_sets]
    if not isinstance(raw_sets, list):
        return []
    tables: list[dict[str, Any]] = []
    for result_set in raw_sets:
        if not isinstance(result_set, dict):
            continue
        headers = result_set.get("headers")
        rows = result_set.get("rowSet") or result_set.get("rowset") or []
        if not isinstance(headers, list) or not isinstance(rows, list):
            continue
        normalized_rows: list[dict[str, Any]] = []
        for raw_row in rows:
            if isinstance(raw_row, dict):
                normalized_rows.append({str(k): v for k, v in raw_row.items()})
            elif isinstance(raw_row, list):
                normalized_rows.append(
                    {str(headers[i]): raw_row[i] for i in range(min(len(headers), len(raw_row)))}
                )
        tables.append(
            {
                "name": result_set.get("name") or "ResultSet",
                "headers": [str(v) for v in headers],
                "rows": normalized_rows,
            }
        )
    return tables


def write_capture(
    *,
    output: Path,
    surface: str,
    season: str,
    season_type: str,
    url: str,
    raw: bytes,
    payload: dict[str, Any],
) -> int:
    folder = output / surface / season / season_type_folder(season_type)
    folder.mkdir(parents=True, exist_ok=True)
    raw_path = folder / "source.json"
    raw_path.write_bytes(raw)
    digest = hashlib.sha256(raw).hexdigest()
    tables = normalize_result_sets(payload)
    normalized = {
        "contract": "sports-terminal-nba-com-normalized-capture-v1",
        "surface": surface,
        "season": season,
        "season_type": season_type,
        "resource": payload.get("resource"),
        "parameters": payload.get("parameters") or {},
        "tables": tables,
    }
    (folder / "normalized.json").write_text(
        json.dumps(normalized, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    metadata = {
        "source_url": url,
        "source_sha256": digest,
        "rights": "NBA.com endpoint response captured locally; redistribution rights not inferred",
        "surface": surface,
        "season": season,
        "season_type": season_type,
        "row_count": sum(len(table["rows"]) for table in tables),
    }
    (folder / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    return int(metadata["row_count"])


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "One-time local fetch of NBA.com player hustle and defense-dashboard history. "
            "Responses are stored as immutable local source JSON plus normalized captures; "
            "the Sports Terminal browser does not call NBA.com at runtime."
        )
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--start", default="2013-14")
    parser.add_argument("--end", default="2025-26")
    parser.add_argument(
        "--surface",
        action="append",
        choices=sorted(SURFACES),
        help="Fetch only this normalized surface. Repeatable; default is all supported surfaces.",
    )
    parser.add_argument(
        "--season-type",
        choices=("regular", "playoffs", "both"),
        default="both",
    )
    parser.add_argument(
        "--transport",
        choices=("auto", "chrome", "curl"),
        default="auto",
        help="auto prefers Chrome-impersonating curl-cffi and falls back to curl.",
    )
    parser.add_argument("--delay", type=float, default=1.25, help="Seconds to wait between successful requests.")
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--retries", type=int, default=1)
    parser.add_argument(
        "--abort-after",
        type=int,
        default=3,
        help="Abort after this many consecutive failures instead of burning through the entire history; 0 disables.",
    )
    parser.add_argument("--oldest-first", action="store_true", help="Fetch oldest seasons first; newest-first is the default.")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--probe-only", action="store_true", help="Attempt only the first eligible request and stop.")
    args = parser.parse_args()

    output = Path(args.output).expanduser().resolve()
    selected = args.surface or list(SURFACES)
    season_types = (
        ["Regular Season", "Playoffs"]
        if args.season_type == "both"
        else ["Playoffs" if args.season_type == "playoffs" else "Regular Season"]
    )

    chrome_session = None
    if args.transport in {"auto", "chrome"} and chrome_requests is not None:
        print("==> Initializing Chrome-like NBA.com session")
        chrome_session = build_chrome_session(args.timeout)
    elif args.transport == "chrome":
        raise SystemExit(
            "curl-cffi is not installed. Use: bash scripts/fetch_nba_com_hustle_defense.sh --probe-only"
        )
    elif args.transport == "auto" and chrome_requests is None:
        print("curl-cffi is not installed; falling back to plain curl (NBA.com may reject this transport).")

    requests_made = 0
    rows_written = 0
    skipped = 0
    consecutive_failures = 0
    failures: list[str] = []
    attempted = 0

    for season in seasons_between(args.start, args.end, newest_first=not args.oldest_first):
        for surface in selected:
            config = SURFACES[surface]
            if season_start(season) < season_start(str(config["first_season"])):
                continue
            for season_type in season_types:
                folder = output / surface / season / season_type_folder(season_type)
                if not args.force and (folder / "normalized.json").is_file():
                    skipped += 1
                    continue
                category = config.get("category")
                params = (
                    hustle_params(season, season_type)
                    if category is None
                    else defense_params(season, season_type, str(category))
                )
                url = f"{BASE}/{config['endpoint']}?{urlencode(params)}"
                label = f"{surface} {season} {season_type}"
                print(f"Fetching {label}")
                attempted += 1
                try:
                    raw, payload = fetch_json(
                        url,
                        timeout=args.timeout,
                        retries=args.retries,
                        transport=args.transport,
                        chrome_session=chrome_session,
                    )
                    count = write_capture(
                        output=output,
                        surface=surface,
                        season=season,
                        season_type=season_type,
                        url=url,
                        raw=raw,
                        payload=payload,
                    )
                except Exception as exc:
                    consecutive_failures += 1
                    failures.append(f"{label}: {exc}")
                    print(f"  FAILED: {exc}")
                    if args.probe_only:
                        break
                    if args.abort_after > 0 and consecutive_failures >= args.abort_after:
                        print(
                            f"Aborting after {consecutive_failures} consecutive failures. "
                            "This usually means NBA.com is rejecting the current transport/session."
                        )
                        break
                    continue
                consecutive_failures = 0
                requests_made += 1
                rows_written += count
                print(f"  {count} rows")
                if args.probe_only:
                    break
                if args.delay > 0:
                    time.sleep(args.delay)
            if args.probe_only and attempted:
                break
            if args.abort_after > 0 and consecutive_failures >= args.abort_after:
                break
        if args.probe_only and attempted:
            break
        if args.abort_after > 0 and consecutive_failures >= args.abort_after:
            break

    print(
        f"NBA.com fetch summary: requests={requests_made}, rows={rows_written}, "
        f"skipped={skipped}, failures={len(failures)}"
    )
    if failures:
        print("Failures:")
        for failure in failures:
            print(f"  - {failure}")
    return 0 if requests_made > 0 or (attempted == 0 and skipped > 0) else 1


if __name__ == "__main__":
    raise SystemExit(main())
