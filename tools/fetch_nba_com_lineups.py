from __future__ import annotations

import argparse
import json
import random
import sys
import time
from pathlib import Path
from typing import Any

try:
    from curl_cffi import requests
except ImportError as exc:  # pragma: no cover - local operator guidance
    raise SystemExit(
        "curl-cffi is required. Run scripts/fetch_nba_com_lineups.sh so Sports Terminal can install it into .venv."
    ) from exc

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_ROOT = ROOT / "raw/nba_com_stats"
ENDPOINT = "https://stats.nba.com/stats/leaguedashlineups"
WARMUP = "https://www.nba.com/stats/lineups/advanced"

SURFACES = {
    "lineups_advanced": "Advanced",
    "lineups_base": "Base",
}
GROUP_QUANTITIES = (2, 3, 4, 5)


def _season(start_year: int) -> str:
    return f"{start_year}-{str(start_year + 1)[-2:]}"


def _season_start(value: str) -> int:
    try:
        return int(value.split("-", 1)[0])
    except Exception as exc:
        raise argparse.ArgumentTypeError(f"Invalid season: {value}") from exc


def _params(
    season: str,
    season_type: str,
    measure_type: str,
    group_quantity: int,
) -> dict[str, str | int]:
    return {
        "Conference": "",
        "DateFrom": "",
        "DateTo": "",
        "Division": "",
        "GameSegment": "",
        "GroupQuantity": group_quantity,
        "ISTRound": "",
        "LastNGames": 0,
        "LeagueID": "00",
        "Location": "",
        "MeasureType": measure_type,
        "Month": 0,
        "OpponentTeamID": 0,
        "Outcome": "",
        "PORound": 0,
        "PaceAdjust": "N",
        "PerMode": "Totals",
        "Period": 0,
        "PlusMinus": "N",
        "Rank": "N",
        "Season": season,
        "SeasonSegment": "",
        "SeasonType": season_type,
        "ShotClockRange": "",
        "TeamID": 0,
        "VsConference": "",
        "VsDivision": "",
    }


def _normalize(payload: dict[str, Any], group_quantity: int) -> dict[str, Any]:
    tables: list[dict[str, Any]] = []
    result_sets = payload.get("resultSets")
    if isinstance(result_sets, dict):
        result_sets = [result_sets]
    if not isinstance(result_sets, list):
        one = payload.get("resultSet")
        result_sets = [one] if isinstance(one, dict) else []

    for result in result_sets:
        if not isinstance(result, dict):
            continue
        headers = result.get("headers")
        row_set = result.get("rowSet")
        if not isinstance(headers, list) or not isinstance(row_set, list):
            continue
        names = [str(item) for item in headers]
        rows = []
        for raw in row_set:
            if not isinstance(raw, list):
                continue
            rows.append({name: raw[index] if index < len(raw) else None for index, name in enumerate(names)})
        tables.append(
            {
                "name": str(result.get("name") or "Lineups"),
                "headers": names,
                "rows": rows,
            }
        )

    return {
        "contract": "sports-terminal-nba-com-normalized-capture-v1",
        "resource": payload.get("resource"),
        "parameters": payload.get("parameters"),
        "group_quantity": group_quantity,
        "tables": tables,
    }


def _row_count(normalized: dict[str, Any]) -> int:
    total = 0
    for table in normalized.get("tables", []):
        if isinstance(table, dict) and isinstance(table.get("rows"), list):
            total += len(table["rows"])
    return total


def _folder(season_type: str) -> str:
    return "playoffs" if "play" in season_type.lower() else "regular-season"


def _surface_folder(surface: str, group_quantity: int) -> str:
    # Preserve the existing five-man capture path so every already-downloaded
    # lineup dataset remains valid. Smaller unit sizes live in parallel roots.
    return surface if group_quantity == 5 else f"{surface}_q{group_quantity}"


def _session() -> requests.Session:
    session = requests.Session(impersonate="chrome")
    session.headers.update(
        {
            "Accept": "*/*",
            "Accept-Language": "en-US,en;q=0.9",
            "Origin": "https://www.nba.com",
            "Referer": "https://www.nba.com/",
        }
    )
    return session


def _warm(session: requests.Session, timeout: float) -> None:
    response = session.get(WARMUP, timeout=timeout)
    if response.status_code >= 400:
        raise RuntimeError(f"NBA.com session warm-up returned HTTP {response.status_code}")


def _fetch(
    session: requests.Session,
    *,
    params: dict[str, str | int],
    timeout: float,
    retries: int,
) -> dict[str, Any]:
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            response = session.get(ENDPOINT, params=params, timeout=timeout)
            if response.status_code != 200:
                raise RuntimeError(f"HTTP {response.status_code}")
            payload = response.json()
            if not isinstance(payload, dict):
                raise RuntimeError("NBA.com returned a non-object JSON payload")
            return payload
        except Exception as exc:  # noqa: BLE001 - command-line acquisition boundary
            last_error = exc
            if attempt >= retries:
                break
            time.sleep(1.5 + attempt * 1.5 + random.random())
    raise RuntimeError(str(last_error or "unknown NBA.com response failure"))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Capture NBA.com 2-, 3-, 4- and 5-player lineup tables into Sports Terminal raw storage."
    )
    parser.add_argument("--start", default="1996-97", help="Oldest season to attempt, e.g. 1996-97")
    parser.add_argument("--end", default="2025-26", help="Newest season to attempt, e.g. 2025-26")
    parser.add_argument("--season-type", choices=("regular", "playoffs", "both"), default="both")
    parser.add_argument("--surface", choices=(*SURFACES.keys(), "all"), default="all")
    parser.add_argument(
        "--group-quantity",
        choices=("2", "3", "4", "5", "all"),
        default="5",
        help="Number of players in each unit. Five-man remains the default for backward compatibility.",
    )
    parser.add_argument("--raw-root", type=Path, default=DEFAULT_RAW_ROOT)
    parser.add_argument("--timeout", type=float, default=25.0)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--delay", type=float, default=0.85)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--probe-only", action="store_true")
    args = parser.parse_args()

    start = _season_start(args.start)
    end = _season_start(args.end)
    if start > end:
        parser.error("--start must not be newer than --end")

    surfaces = list(SURFACES) if args.surface == "all" else [args.surface]
    season_types = (
        ["Regular Season", "Playoffs"]
        if args.season_type == "both"
        else ["Playoffs" if args.season_type == "playoffs" else "Regular Season"]
    )
    group_quantities = list(GROUP_QUANTITIES) if args.group_quantity == "all" else [int(args.group_quantity)]
    seasons = [_season(year) for year in range(end, start - 1, -1)]
    raw_root = args.raw_root.expanduser().resolve()
    raw_root.mkdir(parents=True, exist_ok=True)

    session = _session()
    print("Initializing Chrome-like NBA.com session")
    try:
        _warm(session, args.timeout)
    except Exception as exc:  # noqa: BLE001
        print(f"Session warm-up failed: {exc}", file=sys.stderr)
        return 2

    requests_attempted = 0
    captures = 0
    rows_total = 0
    failures = 0

    for season in seasons:
        for season_type in season_types:
            for group_quantity in group_quantities:
                for surface in surfaces:
                    destination = (
                        raw_root
                        / _surface_folder(surface, group_quantity)
                        / season
                        / _folder(season_type)
                    )
                    normalized_path = destination / "normalized.json"
                    if normalized_path.is_file() and not args.force:
                        try:
                            existing = json.loads(normalized_path.read_text(encoding="utf-8"))
                            count = _row_count(existing) if isinstance(existing, dict) else 0
                        except Exception:
                            count = 0
                        if count:
                            print(
                                f"Skipping {surface} q{group_quantity} {season} {season_type}: "
                                f"{count} rows already captured"
                            )
                            if args.probe_only:
                                return 0
                            continue

                    print(f"Fetching {surface} q{group_quantity} {season} {season_type}")
                    requests_attempted += 1
                    try:
                        payload = _fetch(
                            session,
                            params=_params(
                                season,
                                season_type,
                                SURFACES[surface],
                                group_quantity,
                            ),
                            timeout=args.timeout,
                            retries=args.retries,
                        )
                        normalized = _normalize(payload, group_quantity)
                        count = _row_count(normalized)
                        destination.mkdir(parents=True, exist_ok=True)
                        (destination / "response.json").write_text(
                            json.dumps(payload, ensure_ascii=False),
                            encoding="utf-8",
                        )
                        normalized_path.write_text(
                            json.dumps(normalized, ensure_ascii=False, indent=2),
                            encoding="utf-8",
                        )
                        (destination / "metadata.json").write_text(
                            json.dumps(
                                {
                                    "source": "NBA.com",
                                    "endpoint": "leaguedashlineups",
                                    "surface": surface,
                                    "season": season,
                                    "season_type": season_type,
                                    "measure_type": SURFACES[surface],
                                    "group_quantity": group_quantity,
                                    "rows": count,
                                    "transport": "curl_cffi chrome impersonation",
                                },
                                indent=2,
                            ),
                            encoding="utf-8",
                        )
                        captures += 1
                        rows_total += count
                        print(f"  {count} rows")
                    except Exception as exc:  # noqa: BLE001
                        failures += 1
                        print(f"  FAILED: {exc}", file=sys.stderr)
                        # If the very first probe cannot reach NBA.com, stop quickly
                        # instead of wasting minutes on every historical sample.
                        if requests_attempted == 1 and captures == 0:
                            print("First lineup request failed; aborting this run early.", file=sys.stderr)
                            return 3

                    if args.probe_only:
                        return 0 if captures else 3
                    time.sleep(max(0.0, args.delay) + random.random() * 0.25)

    print(
        f"NBA.com lineup fetch summary: requests={requests_attempted}, "
        f"captures={captures}, rows={rows_total}, failures={failures}"
    )
    return 0 if captures or requests_attempted == 0 else 3


if __name__ == "__main__":
    raise SystemExit(main())
