from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path
from typing import Any
from urllib.parse import urlencode

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "raw" / "nba_com_stats"
BASE = "https://stats.nba.com/stats"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36"
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


def season_start(season: str) -> int:
    return int(season.split("-", 1)[0])


def seasons_between(start: str, end: str) -> list[str]:
    a = season_start(start)
    b = season_start(end)
    if a > b:
        a, b = b, a
    return [f"{year}-{str((year + 1) % 100).zfill(2)}" for year in range(a, b + 1)]


def season_type_folder(season_type: str) -> str:
    return "playoffs" if "play" in season_type.lower() else "regular"


def common_params(season: str, season_type: str) -> dict[str, Any]:
    return {
        "College": "",
        "Conference": "",
        "Country": "",
        "DateFrom": "",
        "DateTo": "",
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


def hustle_params(season: str, season_type: str) -> dict[str, Any]:
    params = common_params(season, season_type)
    params.update(
        {
            "GameScope": "",
            "PaceAdjust": "N",
            "PlusMinus": "N",
            "Rank": "N",
        }
    )
    # This endpoint reports SeasonYear in its response even though the request
    # parameter accepted by NBA.com is Season.
    return params


def defense_params(season: str, season_type: str, category: str) -> dict[str, Any]:
    params = common_params(season, season_type)
    params["DefenseCategory"] = category
    return params


def fetch_json(url: str, timeout: int, retries: int) -> tuple[bytes, dict[str, Any]]:
    cmd = [
        "curl",
        "--fail",
        "--silent",
        "--show-error",
        "--location",
        "--max-time",
        str(timeout),
        url,
        "-H",
        "Accept: */*",
        "-H",
        "Accept-Language: en-US,en;q=0.9",
        "-H",
        "Origin: https://www.nba.com",
        "-H",
        "Referer: https://www.nba.com/",
        "-H",
        f"User-Agent: {USER_AGENT}",
        "-H",
        "Sec-Fetch-Dest: empty",
        "-H",
        "Sec-Fetch-Mode: cors",
        "-H",
        "Sec-Fetch-Site: same-site",
    ]
    last_error: str | None = None
    for attempt in range(retries + 1):
        completed = subprocess.run(cmd, capture_output=True)
        if completed.returncode == 0:
            raw = completed.stdout
            try:
                payload = json.loads(raw.decode("utf-8"))
            except Exception as exc:
                last_error = f"NBA.com returned non-JSON content: {exc}"
            else:
                if isinstance(payload, dict):
                    return raw, payload
                last_error = "NBA.com returned JSON that was not an object"
        else:
            last_error = completed.stderr.decode("utf-8", errors="replace").strip() or f"curl exit {completed.returncode}"
        if attempt < retries:
            time.sleep(min(8.0, 1.5 * (attempt + 1)))
    raise RuntimeError(last_error or "NBA.com request failed")


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
    parser.add_argument("--delay", type=float, default=1.0, help="Seconds to wait between successful requests.")
    parser.add_argument("--timeout", type=int, default=45)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    output = Path(args.output).expanduser().resolve()
    selected = args.surface or list(SURFACES)
    season_types = (
        ["Regular Season", "Playoffs"]
        if args.season_type == "both"
        else ["Playoffs" if args.season_type == "playoffs" else "Regular Season"]
    )

    requests_made = 0
    rows_written = 0
    skipped = 0
    failures: list[str] = []

    for season in seasons_between(args.start, args.end):
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
                try:
                    raw, payload = fetch_json(url, timeout=args.timeout, retries=args.retries)
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
                    failures.append(f"{label}: {exc}")
                    print(f"  FAILED: {exc}")
                    continue
                requests_made += 1
                rows_written += count
                print(f"  {count} rows")
                if args.delay > 0:
                    time.sleep(args.delay)

    print(
        f"NBA.com fetch summary: requests={requests_made}, rows={rows_written}, "
        f"skipped={skipped}, failures={len(failures)}"
    )
    if failures:
        print("Failures:")
        for failure in failures:
            print(f"  - {failure}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
