from __future__ import annotations

import csv
import json
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


def write_registry(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "version": 1,
                "sources": [
                    {
                        "key": "synthetic_history",
                        "label": "Synthetic Historical Source",
                        "dataset": "example/synthetic",
                        "datasetUrl": "https://example.invalid/synthetic",
                        "origin": "contract-test",
                        "license": "test-only",
                        "priority": 1,
                        "role": "contract validation",
                        "coverage": "1947-2026",
                        "redistributionNote": "test-only",
                    }
                ],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def write_sqlite(path: Path) -> None:
    db = sqlite3.connect(path)
    try:
        db.executescript(
            """
            CREATE TABLE player_season_stats(
              player_id TEXT,
              season TEXT,
              games INTEGER,
              points REAL
            );
            INSERT INTO player_season_stats VALUES
              ('p1', '1947-48', 40, 12.5),
              ('p2', '2025-26', 82, 28.1);

            CREATE TABLE play_by_play(
              game_id TEXT,
              season TEXT,
              event_num INTEGER,
              description TEXT
            );
            INSERT INTO play_by_play VALUES
              ('g1', '2025-26', 1, 'jump ball'),
              ('g1', '2025-26', 2, 'made field goal');
            """
        )
        db.commit()
    finally:
        db.close()


def write_csv(path: Path) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["Season", "Player", "Award"])
        writer.writerow(["2024-25", "Player One", "MVP"])
        writer.writerow(["2025-26", "Player Two", "DPOY"])


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    importer = repo_root / "tools" / "import_historical_nba_sources.py"
    with tempfile.TemporaryDirectory(prefix="sports-terminal-history-") as temp:
        root = Path(temp)
        registry = root / "registry.json"
        source_root = root / "raw"
        package = source_root / "synthetic_history"
        output = root / "nba_history.sqlite"
        report = root / "report.json"
        package.mkdir(parents=True)
        write_registry(registry)
        write_sqlite(package / "history.sqlite")
        write_csv(package / "awards.csv")

        result = subprocess.run(
            [
                sys.executable,
                str(importer),
                "--registry",
                str(registry),
                "--source-root",
                str(source_root),
                "--output",
                str(output),
                "--report",
                str(report),
                "--replace",
                "--include-csv-with-sqlite",
            ],
            cwd=repo_root,
            text=True,
            capture_output=True,
        )
        if result.returncode != 0:
            print(result.stdout)
            print(result.stderr, file=sys.stderr)
            raise AssertionError(f"historical importer exited {result.returncode}")

        payload = json.loads(report.read_text(encoding="utf-8"))
        assert payload["status"] == "pass", payload
        assert payload["summary"]["importedSources"] == 1, payload
        assert payload["summary"]["tables"] == 3, payload
        assert payload["summary"]["rows"] == 6, payload

        db = sqlite3.connect(output)
        try:
            inventory = db.execute(
                "SELECT source_table, domain, grain, row_count, min_season, max_season "
                "FROM historical_table_inventory ORDER BY source_table"
            ).fetchall()
            assert len(inventory) == 3, inventory
            by_table = {row[0]: row for row in inventory}
            assert by_table["player_season_stats"][1] == "player_season", by_table
            assert by_table["player_season_stats"][2] == "player_season", by_table
            assert by_table["player_season_stats"][4:] == ("1947-48", "2025-26"), by_table
            assert by_table["play_by_play"][1] == "play_by_play", by_table
            assert by_table["play_by_play"][2] == "event", by_table
            assert by_table["awards"][1] == "award", by_table

            source = db.execute(
                "SELECT file_count, table_count, row_count FROM historical_source_registry "
                "WHERE source_key = 'synthetic_history'"
            ).fetchone()
            assert source == (2, 3, 6), source

            coverage = db.execute(
                "SELECT SUM(table_count), SUM(row_count) FROM historical_source_coverage "
                "WHERE source_key = 'synthetic_history'"
            ).fetchone()
            assert coverage == (3, 6), coverage
        finally:
            db.close()

    print("Historical NBA import contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
