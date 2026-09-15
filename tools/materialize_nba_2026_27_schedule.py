from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "web/data/nba_live/schedule_2026_27.json"
SCHEDULE_ENDPOINTS = (
    "https://cdn.nba.com/static/json/staticData/scheduleLeagueV2_1.json",
    "https://cdn.nba.com/static/json/staticData/scheduleLeagueV2.json",
)
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Referer": "https://www.nba.com/",
    "Origin": "https://www.nba.com",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Materialize the official NBA 2026-27 schedule into a same-origin "
            "Sports Terminal JSON snapshot. This is an acquisition step, not a "
            "page-runtime dependency."
        )
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--strict", action="store_true")
    return parser.parse_args()


def _fetch_json(url: str) -> dict[str, Any]:
    request = Request(url, headers=HEADERS)
    with urlopen(request, timeout=25) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("NBA schedule endpoint returned a non-object payload")
    return payload


def _list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _map(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _text(value: Any) -> str:
    return str(value or "").strip()


def _int(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _date_key(value: str) -> str:
    value = value.strip()
    if not value:
        return ""
    for fmt in (
        "%m/%d/%Y %H:%M:%S",
        "%m/%d/%Y",
        "%Y-%m-%dT%H:%M:%SZ",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d",
    ):
        try:
            return datetime.strptime(value[:19], fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    match = re.search(r"(20\d{2})-(\d{2})-(\d{2})", value)
    return match.group(0) if match else ""


def _team(team: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": _text(team.get("teamId") or team.get("teamID")),
        "name": _text(team.get("teamName")),
        "city": _text(team.get("teamCity")),
        "tricode": _text(team.get("teamTricode") or team.get("teamCode")),
    }


def _extract_schedule(payload: dict[str, Any]) -> list[dict[str, Any]]:
    league = _map(payload.get("leagueSchedule") or payload.get("scheduleLeague"))
    date_groups = _list(league.get("gameDates") or payload.get("gameDates"))
    games: list[dict[str, Any]] = []
    for group in date_groups:
        if not isinstance(group, dict):
            continue
        group_date = _date_key(_text(group.get("gameDate") or group.get("date")))
        for raw in _list(group.get("games")):
            if not isinstance(raw, dict):
                continue
            game_id = _text(raw.get("gameId") or raw.get("gameID"))
            game_date = _date_key(
                _text(raw.get("gameDateTimeUTC") or raw.get("gameDateTimeEst"))
            ) or group_date
            if not game_date:
                continue
            home = _team(_map(raw.get("homeTeam")))
            away = _team(_map(raw.get("awayTeam")))
            label = f"{away['tricode'] or away['name']} at {home['tricode'] or home['name']}"
            games.append(
                {
                    "game_id": game_id,
                    "date": game_date,
                    "datetime_utc": _text(raw.get("gameDateTimeUTC")),
                    "datetime_et": _text(raw.get("gameDateTimeEst")),
                    "time_et": _text(raw.get("gameTimeEst") or raw.get("gameTimeUTC")),
                    "game_label": label,
                    "home_team": home,
                    "away_team": away,
                    "arena": _text(raw.get("arenaName")),
                    "city": _text(raw.get("arenaCity")),
                    "state": _text(raw.get("arenaState")),
                    "status": _int(raw.get("gameStatus")),
                    "status_text": _text(raw.get("gameStatusText")),
                    "national_tv": _text(
                        raw.get("nationalTvBroadcaster")
                        or raw.get("nationalTVBroadcaster")
                    ),
                    "sequence": _int(raw.get("gameSequence")),
                    "week_name": _text(raw.get("weekName")),
                    "if_necessary": bool(raw.get("ifNecessary")),
                }
            )
    games.sort(key=lambda row: (row["date"], row.get("datetime_utc") or "", row["game_id"]))
    return games


def _looks_2026_27(games: list[dict[str, Any]]) -> bool:
    dates = [str(row.get("date") or "") for row in games]
    opening = sum(1 for value in dates if value.startswith("2026-10"))
    ending = sum(1 for value in dates if value.startswith("2027-04"))
    return len(games) >= 1000 and opening > 0 and ending > 0


def _write(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    temp.replace(path)


def main() -> int:
    args = parse_args()
    output = Path(args.output).expanduser().resolve()
    if output.is_file() and output.stat().st_size > 1000 and not args.force:
        print(f"2026-27 NBA schedule snapshot already exists: {output}")
        return 0

    last_error: Exception | None = None
    for endpoint in SCHEDULE_ENDPOINTS:
        try:
            raw = _fetch_json(endpoint)
            games = _extract_schedule(raw)
            if not _looks_2026_27(games):
                raise ValueError(
                    f"endpoint did not expose a complete 2026-27 schedule ({len(games)} games)"
                )
            dates = sorted({row["date"] for row in games})
            payload = {
                "contract": "sports-terminal-nba-schedule-v1",
                "league": "NBA",
                "season": "2026-27",
                "source": endpoint,
                "source_authority": "NBA.com",
                "official_release_date": "2026-08-13",
                "subject_to_change": True,
                "materialized_at": datetime.now(timezone.utc).isoformat(),
                "runtime_api_required_for_schedule": False,
                "game_count": len(games),
                "dates": dates,
                "games": games,
            }
            _write(output, payload)
            print(
                f"Materialized {len(games)} official 2026-27 NBA schedule rows "
                f"across {len(dates)} dates -> {output}"
            )
            return 0
        except (HTTPError, URLError, TimeoutError, ValueError, json.JSONDecodeError) as error:
            last_error = error
            print(f"Schedule source unavailable ({endpoint}): {error}", file=sys.stderr)

    if output.is_file() and output.stat().st_size > 1000:
        print(
            "Official schedule refresh failed; preserving the existing local snapshot.",
            file=sys.stderr,
        )
        return 0

    message = (
        "Could not materialize the official NBA 2026-27 schedule. "
        f"Last error: {last_error}"
    )
    if args.strict:
        raise SystemExit(message)
    print(message, file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
