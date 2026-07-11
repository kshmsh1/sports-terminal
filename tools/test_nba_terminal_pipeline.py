from __future__ import annotations

import json
import py_compile
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
EXPECTED_LEADER_KEYS = [
    "points",
    "points_per_game",
    "rebounds",
    "rebounds_per_game",
    "assists",
    "assists_per_game",
    "steals",
    "blocks",
    "avg_bpm",
]
EXPECTED_HIGH_KEYS = ["points", "rebounds", "assists", "steals", "blocks", "plus_minus"]


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def make_warehouse(path: Path) -> None:
    db = sqlite3.connect(path)
    db.executescript(
        """
        CREATE TABLE warehouse_quality_checks(check_name TEXT, status TEXT, expected INTEGER, actual INTEGER);
        CREATE TABLE games(id INTEGER PRIMARY KEY);
        CREATE TABLE team_game_stats(id INTEGER PRIMARY KEY);
        CREATE TABLE game_line_scores(id INTEGER PRIMARY KEY, total INTEGER);
        CREATE TABLE players(id INTEGER PRIMARY KEY);
        CREATE TABLE player_game_stats(id INTEGER PRIMARY KEY);
        CREATE TABLE play_by_play_events_normalized(id INTEGER PRIMARY KEY);
        """
    )
    db.executemany(
        "INSERT INTO warehouse_quality_checks(check_name, status, expected, actual) VALUES (?, 'pass', ?, ?)",
        [("games", 1314, 1314), ("team_game_stats", 2628, 2628)],
    )
    db.executemany("INSERT INTO games(id) VALUES (?)", [(i,) for i in range(1314)])
    db.executemany("INSERT INTO team_game_stats(id) VALUES (?)", [(i,) for i in range(2628)])
    db.executemany("INSERT INTO game_line_scores(id, total) VALUES (?, 100)", [(i,) for i in range(2628)])
    db.executemany("INSERT INTO players(id) VALUES (?)", [(i,) for i in range(600)])
    db.executemany("INSERT INTO player_game_stats(id) VALUES (?)", [(i,) for i in range(30000)])
    db.executemany("INSERT INTO play_by_play_events_normalized(id) VALUES (?)", [(i,) for i in range(100000)])
    db.commit()
    db.close()


def make_seed(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    write_json(path / "manifest.json", {"warehouseBuild": {"generatedAt": "2026-01-01T00:00:00Z"}})
    write_json(path / "teams.json", [{"team_id": f"T{i:02d}"} for i in range(30)])
    write_json(path / "players.json", [{"player_id": f"p{i}", "player_name": "Nikola JokiÄ‡" if i == 0 else f"Player {i}"} for i in range(600)])
    write_json(path / "games.json", [{"game_id": f"G{i}"} for i in range(1314)])
    write_json(path / "team_records.json", [{"team_id": f"T{i:02d}"} for i in range(30)])
    write_json(path / "player_leaders.json", {key: [{"player_label": "Example"}] for key in EXPECTED_LEADER_KEYS})
    write_json(path / "player_game_highs.json", {key: [{"player_label": "Example"}] for key in EXPECTED_HIGH_KEYS})
    write_json(path / "search_index.json", [{"type": "team", "id": f"T{i:02d}"} for i in range(30)] + [{"type": "player", "id": f"p{i}"} for i in range(600)])


def test_scripts_compile() -> None:
    for relative in [
        "build_nba_warehouse.py",
        "export_nba_terminal_seed.py",
        "finalize_nba_terminal_seed.py",
        "sync_nba_terminal_assets.py",
        "run_nba_terminal_data_pipeline.py",
    ]:
        py_compile.compile(str(TOOLS / relative), doraise=True)


def test_finalize_and_sync_seed() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        warehouse = root / "warehouse.sqlite"
        seed = root / "seed"
        assets = root / "assets"
        make_warehouse(warehouse)
        make_seed(seed)

        finalize = subprocess.run(
            [
                sys.executable,
                str(TOOLS / "finalize_nba_terminal_seed.py"),
                "--warehouse",
                str(warehouse),
                "--seed",
                str(seed),
                "--season",
                "2025",
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        assert finalize.returncode == 0, finalize.stderr or finalize.stdout
        report = json.loads((seed / "validation_report.json").read_text(encoding="utf-8"))
        assert report["status"] == "pass"
        players = json.loads((seed / "players.json").read_text(encoding="utf-8"))
        assert players[0]["player_name"] == "Nikola Jokić"

        sync = subprocess.run(
            [
                sys.executable,
                str(TOOLS / "sync_nba_terminal_assets.py"),
                "--seed",
                str(seed),
                "--asset-output",
                str(assets),
                "--clean",
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        assert sync.returncode == 0, sync.stderr or sync.stdout
        assert (assets / "players.json").exists()
        assert (assets / "validation_report.json").exists()
        assert (assets / "asset_manifest.json").exists()


def main() -> int:
    test_scripts_compile()
    test_finalize_and_sync_seed()
    print("NBA terminal pipeline offline tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
