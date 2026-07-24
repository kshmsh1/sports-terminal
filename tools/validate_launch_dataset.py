from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REQUIRED_FILES = [
    "manifest.json",
    "teams.json",
    "players.json",
    "games.json",
    "team_records.json",
    "team_game_logs.json",
    "player_season_totals.json",
    "player_leaders.json",
    "player_game_highs.json",
    "player_game_logs.json",
    "search_index.json",
    "data_dictionary.json",
    "validation_report.json",
    "release_manifest.json",
    "standings.json",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Certify the single-season NBA launch dataset before it is activated in Flutter."
    )
    parser.add_argument("--seed", required=True)
    parser.add_argument("--season", type=int, default=2026)
    parser.add_argument("--output")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def season_label(season_end_year: int) -> str:
    return f"{season_end_year - 1}-{str(season_end_year)[-2:]}"


def unique_count(rows: list[dict[str, Any]], key: str) -> int:
    return len({str(row.get(key) or "") for row in rows if row.get(key) not in {None, ""}})


def add_check(
    checks: list[dict[str, Any]],
    key: str,
    passed: bool,
    actual: Any,
    expected: Any,
    *,
    blocking: bool = True,
    details: str = "",
) -> None:
    checks.append(
        {
            "key": key,
            "status": "pass" if passed else "fail",
            "blocking": blocking,
            "actual": actual,
            "expected": expected,
            "details": details,
        }
    )


def main() -> int:
    args = parse_args()
    seed = Path(args.seed)
    output = Path(args.output) if args.output else seed / "launch_validation.json"
    checks: list[dict[str, Any]] = []

    missing = [name for name in REQUIRED_FILES if not (seed / name).exists()]
    add_check(checks, "required_files", not missing, missing, "no missing files")
    if missing:
        report = {
            "status": "fail",
            "season": season_label(args.season),
            "generatedAt": datetime.now(timezone.utc).isoformat(),
            "checks": checks,
        }
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))
        return 2

    manifest = load_json(seed / "manifest.json")
    teams = load_json(seed / "teams.json")
    players = load_json(seed / "players.json")
    games = load_json(seed / "games.json")
    team_records = load_json(seed / "team_records.json")
    team_logs = load_json(seed / "team_game_logs.json")
    season_totals = load_json(seed / "player_season_totals.json")
    player_logs = load_json(seed / "player_game_logs.json")
    search_index = load_json(seed / "search_index.json")
    standings = load_json(seed / "standings.json")
    pipeline_validation = load_json(seed / "validation_report.json")
    release = load_json(seed / "release_manifest.json")

    warehouse_build = manifest.get("warehouseBuild") if isinstance(manifest, dict) else {}
    if not isinstance(warehouse_build, dict):
        warehouse_build = {}
    add_check(
        checks,
        "season_end_year",
        warehouse_build.get("seasonEndYear") == args.season,
        warehouse_build.get("seasonEndYear"),
        args.season,
    )
    add_check(checks, "team_count", len(teams) == 30, len(teams), 30)
    add_check(checks, "unique_team_ids", unique_count(teams, "team_id") == 30, unique_count(teams, "team_id"), 30)
    add_check(checks, "team_record_count", len(team_records) == 30, len(team_records), 30)
    add_check(checks, "standings_count", len(standings) == 30, len(standings), 30)
    add_check(checks, "game_count", len(games) >= 1230, len(games), ">= 1230")
    add_check(checks, "unique_game_ids", unique_count(games, "game_id") == len(games), unique_count(games, "game_id"), len(games))
    add_check(checks, "team_game_log_reconciliation", len(team_logs) == len(games) * 2, len(team_logs), len(games) * 2)
    add_check(checks, "player_identity_count", len(players) >= 400, len(players), ">= 400")
    add_check(checks, "player_season_total_count", len(season_totals) >= 400, len(season_totals), ">= 400")
    add_check(checks, "complete_player_game_logs", len(player_logs) >= 10000, len(player_logs), ">= 10000")
    add_check(checks, "search_index_count", len(search_index) >= 430, len(search_index), ">= 430")
    add_check(
        checks,
        "pipeline_validation",
        str(pipeline_validation.get("status", "")).lower() == "pass",
        pipeline_validation.get("status"),
        "pass",
    )
    add_check(
        checks,
        "release_season",
        release.get("season") == season_label(args.season),
        release.get("season"),
        season_label(args.season),
    )
    add_check(
        checks,
        "release_candidate",
        release.get("status") in {"candidate", "validated", "published"},
        release.get("status"),
        "candidate or better",
    )

    invalid_scores = 0
    missing_dates = 0
    for game in games:
        if game.get("game_date") in {None, ""}:
            missing_dates += 1
        home = game.get("home_score")
        away = game.get("away_score")
        if not isinstance(home, (int, float)) or not isinstance(away, (int, float)) or home < 0 or away < 0:
            invalid_scores += 1
    add_check(checks, "game_dates", missing_dates == 0, missing_dates, 0)
    add_check(checks, "game_scores", invalid_scores == 0, invalid_scores, 0)

    duplicate_player_games = len(player_logs) - len(
        {
            (
                str(row.get("game_id") or ""),
                str(row.get("team_id") or ""),
                str(row.get("player_id") or row.get("player_label") or ""),
            )
            for row in player_logs
        }
    )
    add_check(checks, "duplicate_player_game_rows", duplicate_player_games == 0, duplicate_player_games, 0)

    failures = [check for check in checks if check["blocking"] and check["status"] != "pass"]
    report = {
        "status": "pass" if not failures else "fail",
        "season": season_label(args.season),
        "seasonEndYear": args.season,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "seed": str(seed),
        "counts": {
            "teams": len(teams),
            "players": len(players),
            "games": len(games),
            "teamGameLogs": len(team_logs),
            "playerSeasonTotals": len(season_totals),
            "playerGameLogs": len(player_logs),
            "searchIndex": len(search_index),
        },
        "checks": checks,
        "blockingFailures": [check["key"] for check in failures],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    if not failures:
        release["status"] = "validated"
        release["validation"] = report
        release["validatedAt"] = report["generatedAt"]
        (seed / "release_manifest.json").write_text(
            json.dumps(release, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if not failures else 2


if __name__ == "__main__":
    raise SystemExit(main())
