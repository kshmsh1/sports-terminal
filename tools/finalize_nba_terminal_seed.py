from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_WAREHOUSE = "data/warehouse/nba_2025.sqlite"
DEFAULT_SEED = "data/terminal_seed/nba_2025"
EXPECTED_SEED_FILES = [
    "manifest.json",
    "teams.json",
    "players.json",
    "games.json",
    "team_records.json",
    "team_game_logs.json",
    "player_season_totals.json",
    "player_leaders.json",
    "player_game_highs.json",
    "player_game_logs_top.json",
    "search_index.json",
    "data_dictionary.json",
]
EXPECTED_LEADER_KEYS = {
    "points",
    "points_per_game",
    "rebounds",
    "rebounds_per_game",
    "assists",
    "assists_per_game",
    "steals",
    "blocks",
    "avg_bpm",
}
EXPECTED_HIGH_KEYS = {"points", "rebounds", "assists", "steals", "blocks", "plus_minus"}
MOJIBAKE_MARKERS = ("Ã", "Â", "Ä", "Å", "â", "€", "™", "œ", "�")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Repair and validate compact Sports Terminal seed JSON files. "
            "This makes no network requests and is safe to rerun."
        )
    )
    parser.add_argument("--warehouse", default=DEFAULT_WAREHOUSE)
    parser.add_argument("--seed", default=DEFAULT_SEED)
    parser.add_argument("--season", type=int, default=2025)
    parser.add_argument("--no-write", action="store_true", help="Validate repaired documents without rewriting seed files.")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, document: Any) -> None:
    path.write_text(json.dumps(document, indent=2, ensure_ascii=False, default=str) + "\n", encoding="utf-8")


def c1_control_count(text: str) -> int:
    return sum(1 for char in text if 0x80 <= ord(char) <= 0x9F)


def mojibake_score(text: str) -> int:
    marker_score = sum(text.count(marker) for marker in MOJIBAKE_MARKERS)
    return marker_score + 5 * c1_control_count(text)


def repair_text(text: str) -> str:
    if mojibake_score(text) == 0:
        return text
    best = text
    best_score = mojibake_score(text)
    for encoding in ("latin1", "cp1252"):
        try:
            candidate = text.encode(encoding).decode("utf-8")
        except UnicodeError:
            continue
        score = mojibake_score(candidate)
        if score < best_score:
            best = candidate
            best_score = score
    return best


def repair_document(value: Any) -> tuple[Any, int]:
    if isinstance(value, str):
        repaired = repair_text(value)
        return repaired, 1 if repaired != value else 0
    if isinstance(value, list):
        output = []
        changes = 0
        for item in value:
            repaired, item_changes = repair_document(item)
            output.append(repaired)
            changes += item_changes
        return output, changes
    if isinstance(value, dict):
        output = {}
        changes = 0
        for key, item in value.items():
            repaired_key, key_changes = repair_document(key)
            repaired_item, item_changes = repair_document(item)
            output[repaired_key] = repaired_item
            changes += key_changes + item_changes
        return output, changes
    return value, 0


def scan_bad_text(value: Any, path: str = "$", hits: list[dict[str, str]] | None = None) -> list[dict[str, str]]:
    if hits is None:
        hits = []
    if isinstance(value, str):
        if mojibake_score(value) > 0:
            hits.append({"path": path, "value": value[:160]})
        return hits
    if isinstance(value, list):
        for index, item in enumerate(value):
            scan_bad_text(item, f"{path}[{index}]", hits)
        return hits
    if isinstance(value, dict):
        for key, item in value.items():
            scan_bad_text(item, f"{path}.{key}", hits)
        return hits
    return hits


def check(name: str, passed: bool, actual: Any, expected: Any, *, severity: str = "fail") -> dict[str, Any]:
    return {
        "name": name,
        "status": "pass" if passed else severity,
        "actual": actual,
        "expected": expected,
    }


def table_count(db: sqlite3.Connection, table: str, where: str = "1 = 1") -> int:
    return int(db.execute(f"SELECT COUNT(*) FROM {table} WHERE {where}").fetchone()[0])


def exact_count_check(db: sqlite3.Connection, name: str, table: str, expected: int, where: str = "1 = 1") -> dict[str, Any]:
    actual = table_count(db, table, where)
    return check(name, actual == expected, actual, expected)


def minimum_count_check(db: sqlite3.Connection, name: str, table: str, expected: int, where: str = "1 = 1") -> dict[str, Any]:
    actual = table_count(db, table, where)
    return check(name, actual >= expected, actual, f">= {expected}")


def warehouse_checks(path: Path, season: int) -> list[dict[str, Any]]:
    if not path.exists():
        return [check("warehouse_exists", False, str(path), "existing SQLite warehouse")]
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    try:
        quality = [dict(row) for row in db.execute("SELECT check_name, status, expected, actual FROM warehouse_quality_checks ORDER BY check_name")]
        return [
            check("warehouse_exists", True, str(path), "existing SQLite warehouse"),
            check("warehouse_quality_checks_all_pass", all(row["status"] == "pass" for row in quality), quality, "all pass"),
            exact_count_check(db, "warehouse_games", "games", 1314),
            exact_count_check(db, "warehouse_team_game_stats", "team_game_stats", 2628),
            exact_count_check(db, "warehouse_line_score_totals_present", "game_line_scores", 2628, "total IS NOT NULL"),
            minimum_count_check(db, "warehouse_players", "players", 600),
            minimum_count_check(db, "warehouse_player_game_stats", "player_game_stats", 30000),
            minimum_count_check(db, "warehouse_normalized_pbp", "play_by_play_events_normalized", 100000),
        ]
    finally:
        db.close()


def validate_seed(seed: Path, documents: dict[str, Any], warehouse: Path, season: int) -> list[dict[str, Any]]:
    checks: list[dict[str, Any]] = []
    expected_files = sorted(EXPECTED_SEED_FILES)
    actual_files = sorted(documents)
    checks.append(check("seed_directory_exists", seed.exists(), str(seed), "existing directory"))
    checks.append(check("seed_files_present", actual_files == expected_files, actual_files, expected_files))

    teams = documents.get("teams.json", [])
    players = documents.get("players.json", [])
    games = documents.get("games.json", [])
    team_records = documents.get("team_records.json", [])
    team_game_logs = documents.get("team_game_logs.json", [])
    player_season_totals = documents.get("player_season_totals.json", [])
    leaders = documents.get("player_leaders.json", {})
    highs = documents.get("player_game_highs.json", {})
    player_game_logs_top = documents.get("player_game_logs_top.json", [])
    search_index = documents.get("search_index.json", [])
    data_dictionary = documents.get("data_dictionary.json", {})

    checks.extend(
        [
            check("seed_teams", len(teams) == 30, len(teams), 30),
            check("seed_players", len(players) >= 600, len(players), ">= 600"),
            check("seed_games", len(games) == 1314, len(games), 1314),
            check("seed_team_records", len(team_records) == 30, len(team_records), 30),
            check("seed_team_game_logs", len(team_game_logs) == 2628, len(team_game_logs), 2628),
            check("seed_player_season_totals", len(player_season_totals) >= 500, len(player_season_totals), ">= 500 active player summaries"),
            check("seed_player_game_logs_top", len(player_game_logs_top) >= 100, len(player_game_logs_top), ">= 100"),
            check("seed_search_index", len(search_index) == len(teams) + len(players), len(search_index), len(teams) + len(players)),
            check("leaderboard_keys", set(leaders) == EXPECTED_LEADER_KEYS, sorted(leaders), sorted(EXPECTED_LEADER_KEYS)),
            check("game_high_keys", set(highs) == EXPECTED_HIGH_KEYS, sorted(highs), sorted(EXPECTED_HIGH_KEYS)),
            check("leaderboards_nonempty", all(isinstance(value, list) and value for value in leaders.values()), {key: len(value) for key, value in leaders.items()}, "every leaderboard nonempty"),
            check("game_highs_nonempty", all(isinstance(value, list) and value for value in highs.values()), {key: len(value) for key, value in highs.items()}, "every highs list nonempty"),
            check("data_dictionary_present", isinstance(data_dictionary, dict) and "files" in data_dictionary, sorted(data_dictionary) if isinstance(data_dictionary, dict) else type(data_dictionary).__name__, "files map present"),
        ]
    )

    bad_text = []
    for filename, document in documents.items():
        bad_text.extend({"file": filename, **hit} for hit in scan_bad_text(document)[:20])
    checks.append(check("seed_text_encoding_clean", len(bad_text) == 0, bad_text[:20], "no mojibake markers"))
    checks.extend(warehouse_checks(warehouse, season))
    return checks


def main() -> int:
    args = parse_args()
    seed = Path(args.seed)
    warehouse = Path(args.warehouse)
    missing = [name for name in EXPECTED_SEED_FILES if not (seed / name).exists()]
    if missing:
        print(json.dumps({"status": "fail", "missingFiles": missing}, indent=2), file=sys.stderr)
        return 1

    documents: dict[str, Any] = {}
    repair_counts: dict[str, int] = {}
    for filename in EXPECTED_SEED_FILES:
        document = load_json(seed / filename)
        repaired, changes = repair_document(document)
        documents[filename] = repaired
        repair_counts[filename] = changes
        if changes and not args.no_write:
            write_json(seed / filename, repaired)

    checks = validate_seed(seed, documents, warehouse, args.season)
    status = "pass" if all(item["status"] == "pass" for item in checks) else "fail"
    report = {
        "status": status,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "seed": str(seed),
        "warehouse": str(warehouse),
        "seasonEndYear": args.season,
        "textRepairs": repair_counts,
        "checks": checks,
    }
    write_json(seed / "validation_report.json", report)
    print(json.dumps(report, indent=2, ensure_ascii=False, default=str))
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
