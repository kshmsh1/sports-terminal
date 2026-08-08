from __future__ import annotations

import importlib.util
import json
import os
import sqlite3
import sys
import tempfile
from pathlib import Path


def load_fixture(repo_root: Path):
    path = repo_root / "backend" / "scripts" / "historical_entity_intelligence_contract_test.py"
    spec = importlib.util.spec_from_file_location("nba_terminal_fixture", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load fixture: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def add_terminal_dimensions(database: Path) -> None:
    db = sqlite3.connect(database)
    try:
        db.executescript(
            """
            CREATE TABLE canon_dim_league(
              league_id TEXT PRIMARY KEY,league_name TEXT,first_season TEXT,last_season TEXT
            );
            INSERT INTO canon_dim_league VALUES
              ('NBA','National Basketball Association','1949-50','2023-24'),
              ('BAA','Basketball Association of America','1946-47','1948-49');
            """
        )
        db.commit()
    finally:
        db.close()


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    fixture = load_fixture(repo_root)

    with tempfile.TemporaryDirectory(prefix="sports-terminal-command-contract-") as temp:
        root = Path(temp)
        database = root / "history.sqlite"
        base_fixture = fixture.load_fixture_module(repo_root)
        base_fixture.seed(database)
        fixture.enrich(database)
        add_terminal_dimensions(database)

        os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(database)
        os.environ["SPORTS_TERMINAL_DB_PATH"] = str(root / "launch.sqlite")
        sys.path.insert(0, str(repo_root / "backend"))

        from app import main_launch as launch  # noqa: PLC0415
        from app import nba_terminal_api as terminal  # noqa: PLC0415

        paths = {getattr(route, "path", "") for route in launch.app.routes}
        required = {
            "/v2/nba/terminal/manifest",
            "/v2/nba/terminal/seasons",
            "/v2/nba/terminal/commands",
        }
        missing = sorted(required - paths)
        assert not missing, {"missing": missing, "terminal_paths": sorted(p for p in paths if "/v2/nba/terminal" in p)}

        manifest = terminal.nba_terminal_manifest()
        assert manifest["terminal_schema_version"] == "2.0", manifest
        assert manifest["primary_league"] == "NBA", manifest
        assert manifest["counts"]["players"] == 2, manifest
        assert manifest["counts"]["teams"] == 2, manifest
        assert manifest["counts"]["franchises"] == 2, manifest
        assert manifest["counts"]["games"] == 1, manifest
        assert manifest["counts"]["player_seasons"] == 4, manifest
        assert manifest["counts"]["awards"] == 1, manifest
        assert manifest["counts"]["all_star_selections"] == 1, manifest
        assert manifest["counts"]["draft_rows"] == 1, manifest
        assert manifest["season_span"]["first"] == "2022-23", manifest
        assert manifest["season_span"]["last"] == "2023-24", manifest
        assert manifest["integrity"]["fabricates_missing_era_fields"] is False, manifest
        assert len(manifest["commands"]) >= 10, manifest

        seasons = terminal.nba_terminal_seasons(
            league="NBA",
            query="2023",
            offset=0,
            limit=100,
        )
        assert seasons["matched_rows"] == 1, seasons
        assert seasons["rows"][0]["season_id"] == "2023-24", seasons
        assert seasons["rows"][0]["teams"] == 2, seasons
        assert seasons["rows"][0]["players"] == 2, seasons
        assert seasons["rows"][0]["games"] == 1, seasons
        assert seasons["rows"][0]["awards"] == 1, seasons

        commands = terminal.nba_terminal_commands(query="history")
        assert commands["count"] >= 1, commands
        assert any(row["id"] == "history" for row in commands["rows"]), commands

        print(
            json.dumps(
                {
                    "launch_version": launch.app.version,
                    "terminal_routes": len(required),
                    "players": manifest["counts"]["players"],
                    "season_span": manifest["season_span"],
                    "command_count": len(manifest["commands"]),
                },
                indent=2,
            )
        )

    print("Unified NBA terminal contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
