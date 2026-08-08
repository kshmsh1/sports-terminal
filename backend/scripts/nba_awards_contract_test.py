from __future__ import annotations

import json
import os
import sqlite3
import tempfile
from pathlib import Path


def make_history_database(path: Path) -> None:
    db = sqlite3.connect(path)
    db.executescript(
        """
        CREATE TABLE canon_build_manifest(
          build_id TEXT PRIMARY KEY,
          schema_version TEXT,
          built_at TEXT,
          source_rows INTEGER,
          source_tables INTEGER,
          source_count INTEGER,
          canonical_counts_json TEXT,
          warnings_json TEXT
        );
        CREATE TABLE canon_dim_player(
          player_key TEXT PRIMARY KEY,
          canonical_name TEXT,
          normalized_name TEXT,
          nba_id TEXT,
          bref_id TEXT,
          birth_date TEXT,
          birth_year INTEGER,
          primary_position TEXT,
          active_from TEXT,
          active_to TEXT,
          source_count INTEGER,
          identity_confidence REAL,
          provenance_json TEXT
        );
        CREATE TABLE canon_fact_award(
          award_key TEXT PRIMARY KEY,
          player_key TEXT,
          player_name TEXT,
          season_id TEXT,
          league_id TEXT,
          award TEXT NOT NULL,
          rank_text TEXT,
          winner INTEGER,
          share REAL,
          source_key TEXT NOT NULL,
          payload_json TEXT NOT NULL
        );
        CREATE TABLE canon_fact_all_star(
          selection_key TEXT PRIMARY KEY,
          player_key TEXT,
          player_name TEXT,
          season_id TEXT,
          league_id TEXT,
          team_text TEXT,
          source_key TEXT NOT NULL,
          payload_json TEXT NOT NULL
        );
        """
    )
    db.execute(
        "INSERT INTO canon_build_manifest VALUES (?,?,?,?,?,?,?,?)",
        ("test", "1", "2026-08-08", 10, 2, 1, "{}", "[]"),
    )
    db.executemany(
        "INSERT INTO canon_dim_player VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [
            (
                "p_alpha",
                "Alpha Star",
                "alphastar",
                "1",
                "alpha01",
                None,
                1990,
                "F",
                "2010-11",
                "2024-25",
                1,
                1.0,
                "{}",
            ),
            (
                "p_beta",
                "Beta Guard",
                "betaguard",
                "2",
                "beta01",
                None,
                1994,
                "G",
                "2014-15",
                "2024-25",
                1,
                1.0,
                "{}",
            ),
        ],
    )
    db.executemany(
        "INSERT INTO canon_fact_award VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        [
            (
                "a1",
                "p_alpha",
                "Alpha Star",
                "2023-24",
                "NBA",
                "NBA MVP",
                "1",
                1,
                0.72,
                "sumitro_bref_history",
                json.dumps({"Award": "NBA MVP", "Pts Won": 720}),
            ),
            (
                "a2",
                "p_beta",
                "Beta Guard",
                "2023-24",
                "NBA",
                "NBA MVP",
                "2",
                0,
                0.21,
                "sumitro_bref_history",
                json.dumps({"Award": "NBA MVP", "Pts Won": 210}),
            ),
            (
                "a3",
                "p_alpha",
                "Alpha Star",
                "2023-24",
                "NBA",
                "All-NBA First Team",
                None,
                1,
                None,
                "sumitro_bref_history",
                json.dumps({"Team": "All-NBA First Team"}),
            ),
        ],
    )
    db.execute(
        "INSERT INTO canon_fact_all_star VALUES (?,?,?,?,?,?,?,?)",
        (
            "as1",
            "p_beta",
            "Beta Guard",
            "2023-24",
            "NBA",
            "East",
            "sumitro_bref_history",
            json.dumps({"Team": "East"}),
        ),
    )
    db.commit()
    db.close()


with tempfile.TemporaryDirectory(prefix="sports-terminal-awards-") as temp_dir:
    root = Path(temp_dir)
    history_path = root / "history.sqlite"
    make_history_database(history_path)
    os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(history_path)
    os.environ["SPORTS_TERMINAL_DB_PATH"] = str(root / "launch.sqlite")

    from app import main_launch
    from app.nba_awards_api import (
        award_history,
        awards_catalog,
        player_awards,
        season_awards,
    )

    catalog = awards_catalog()
    by_key = {item["key"]: item for item in catalog["catalog"]}
    assert by_key["mvp"]["records"] == 2
    assert by_key["mvp"]["winners"] == 1
    assert by_key["mvp"]["has_voting"] is True
    assert by_key["all_nba_1"]["records"] == 1
    assert by_key["all_star"]["records"] == 1

    mvp = award_history("mvp")
    assert mvp["matched_rows"] == 2
    assert mvp["rows"][0]["player_name"] == "Alpha Star"
    assert mvp["rows"][0]["winner"] == 1

    season = season_awards("2023-24")
    assert season["records"] == 4
    assert {item["award"]["key"] for item in season["awards"]} >= {
        "mvp",
        "all_nba_1",
        "all_star",
    }

    player = player_awards("p_alpha")
    assert player["player"]["canonical_name"] == "Alpha Star"
    assert player["records"] == 2

    paths = {getattr(route, "path", "") for route in main_launch.app.routes}
    expected = {
        "/v2/nba/awards/catalog",
        "/v2/nba/awards/history/{award_key}",
        "/v2/nba/awards/season/{season_id}",
        "/v2/nba/awards/player/{player_key}",
    }
    assert expected <= paths, (expected - paths, sorted(paths))

print("NBA awards and voting contract test passed.")
