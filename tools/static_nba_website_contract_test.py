from __future__ import annotations

import json
import sqlite3
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path: str, *tokens: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    for token in tokens:
        if token not in text:
            raise AssertionError(f"{path} missing required static-data contract token: {token}")


def assert_not_contains(path: str, *tokens: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    for token in tokens:
        if token in text:
            raise AssertionError(f"{path} contains forbidden runtime-data token: {token}")


def _import_builder_module():
    import importlib.util

    path = ROOT / "tools" / "build_static_nba_website_data.py"
    spec = importlib.util.spec_from_file_location("static_builder_contract", path)
    if spec is None or spec.loader is None:
        raise AssertionError("Unable to import static NBA builder")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _schema_fixture() -> sqlite3.Connection:
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    db.executescript(
        """
        CREATE TABLE canon_dim_league (
          league_id TEXT PRIMARY KEY,
          league_name TEXT NOT NULL
        );
        INSERT INTO canon_dim_league VALUES ('NBA','National Basketball Association');

        CREATE TABLE canon_dim_team (
          team_key TEXT PRIMARY KEY,
          league_id TEXT NOT NULL,
          canonical_name TEXT NOT NULL,
          abbreviation TEXT,
          active_from_season_id TEXT,
          active_to_season_id TEXT,
          franchise_key TEXT
        );
        INSERT INTO canon_dim_team VALUES
          ('nba-home','NBA','NBA Home','NHO','2025-26',NULL,'home-franchise'),
          ('nba-away','NBA','NBA Away','NAW','2025-26',NULL,'away-franchise'),
          ('aba-home','ABA','ABA Home','AHO','1975-76','1975-76','aba-franchise');

        CREATE TABLE canon_dim_player (
          player_key TEXT PRIMARY KEY,
          league_id TEXT NOT NULL,
          canonical_name TEXT NOT NULL,
          bref_id TEXT,
          nba_id TEXT,
          primary_position TEXT
        );
        INSERT INTO canon_dim_player VALUES
          ('nba-player','NBA','NBA Player','nba01','1','SG'),
          ('aba-player','ABA','ABA Player','aba01','2','SF');

        CREATE TABLE canon_bridge_player_team_season (
          player_key TEXT NOT NULL,
          team_key TEXT NOT NULL,
          season_id TEXT NOT NULL,
          season_type TEXT NOT NULL,
          PRIMARY KEY(player_key,team_key,season_id,season_type)
        );
        INSERT INTO canon_bridge_player_team_season VALUES
          ('nba-player','nba-home','2025-26','regular'),
          ('aba-player','aba-home','1975-76','regular');

        CREATE TABLE canon_fact_player_season (
          player_key TEXT NOT NULL,
          team_key TEXT,
          season_id TEXT NOT NULL,
          season_type TEXT NOT NULL,
          games_played INTEGER,
          minutes REAL,
          points REAL,
          rebounds REAL,
          assists REAL,
          steals REAL,
          blocks REAL,
          turnovers REAL,
          personal_fouls REAL,
          fgm REAL,
          fga REAL,
          fg3m REAL,
          fg3a REAL,
          ftm REAL,
          fta REAL,
          source_key TEXT NOT NULL,
          provenance_json TEXT NOT NULL DEFAULT '{}',
          PRIMARY KEY(player_key,team_key,season_id,season_type,source_key)
        );
        INSERT INTO canon_fact_player_season VALUES
          ('nba-player','nba-home','2025-26','regular',82,2800,2000,500,400,100,40,200,180,700,1400,200,500,400,500,'fixture','{}'),
          ('aba-player','aba-home','1975-76','regular',84,3000,2100,600,300,80,30,220,190,750,1500,100,300,500,620,'fixture','{}');

        CREATE TABLE canon_fact_player_advanced (
          player_key TEXT NOT NULL,
          team_key TEXT,
          season_id TEXT NOT NULL,
          season_type TEXT NOT NULL,
          per REAL,
          ts_pct REAL,
          efg_pct REAL,
          usg_pct REAL,
          ows REAL,
          dws REAL,
          ws REAL,
          ws_per_48 REAL,
          obpm REAL,
          dbpm REAL,
          bpm REAL,
          vorp REAL,
          source_key TEXT NOT NULL,
          provenance_json TEXT NOT NULL DEFAULT '{}',
          PRIMARY KEY(player_key,team_key,season_id,season_type,source_key)
        );
        INSERT INTO canon_fact_player_advanced VALUES
          ('nba-player','nba-home','2025-26','regular',20,.60,.55,.25,5,3,8,.15,2,1,3,4,'fixture','{}'),
          ('aba-player','aba-home','1975-76','regular',19,.57,.52,.24,4,3,7,.14,1,1,2,3,'fixture','{}');

        CREATE TABLE canon_fact_team_season (
          team_key TEXT NOT NULL,
          season_id TEXT NOT NULL,
          season_type TEXT NOT NULL,
          games_played INTEGER,
          wins INTEGER,
          losses INTEGER,
          points REAL,
          rebounds REAL,
          assists REAL,
          steals REAL,
          blocks REAL,
          turnovers REAL,
          personal_fouls REAL,
          fgm REAL,
          fga REAL,
          fg3m REAL,
          fg3a REAL,
          ftm REAL,
          fta REAL,
          source_key TEXT NOT NULL,
          provenance_json TEXT NOT NULL DEFAULT '{}',
          PRIMARY KEY(team_key,season_id,season_type,source_key)
        );
        INSERT INTO canon_fact_team_season VALUES
          ('nba-home','2025-26','regular',82,50,32,9000,3500,2200,600,400,1100,1500,3300,7000,1000,2800,1400,1800,'fixture','{}'),
          ('aba-home','1975-76','regular',84,45,39,9100,3600,2100,550,350,1200,1600,3350,7100,200,600,1800,2300,'fixture','{}');
        """
    )
    return db


def test_league_scoping() -> None:
    builder = _import_builder_module()
    db = _schema_fixture()
    try:
        seasons = builder.season_rows(db)
        players = builder.player_index_rows(db)
        teams = builder.team_index_rows(db)
        snapshot = builder.historical_seed_snapshot(db, "2025-26", "regular")
    finally:
        db.close()
    assert seasons and all(row["season_id"] == "2025-26" for row in seasons), seasons
    assert [row["player_key"] for row in players] == ["nba-player"], players
    assert [row["team_key"] for row in teams] == ["nba-away", "nba-home"], teams
    assert [row["player_key"] for row in snapshot["players"]] == ["nba-player"], snapshot["players"]


def test_game_scoping() -> None:
    builder = _import_builder_module()
    game_rows = builder.game_rows
    team_rows = builder.team_game_rows
    with tempfile.TemporaryDirectory() as tmp:
        del tmp
        db = sqlite3.connect(":memory:")
        db.row_factory = sqlite3.Row
        db.executescript(
            """
            CREATE TABLE canon_dim_game (
              game_key TEXT PRIMARY KEY,league_id TEXT NOT NULL,season_id TEXT,season_type TEXT,game_date TEXT,
              nba_game_id TEXT,home_team_key TEXT,away_team_key TEXT,home_score REAL,away_score REAL,status_text TEXT,
              source_key TEXT NOT NULL DEFAULT 'fixture',provenance_json TEXT NOT NULL DEFAULT '{}'
            );
            CREATE TABLE canon_fact_team_game (
              game_key TEXT NOT NULL,team_key TEXT NOT NULL,opponent_team_key TEXT,is_home INTEGER NOT NULL,
              result TEXT,points REAL,opponent_points REAL,source_key TEXT NOT NULL,provenance_json TEXT NOT NULL DEFAULT '{}',
              PRIMARY KEY(game_key,team_key)
            );
            INSERT INTO canon_dim_game VALUES('nba-game','NBA','2025-26','regular','2025-10-20','001','nba-home','nba-away',110,100,'Final','fixture','{}');
            INSERT INTO canon_dim_game VALUES('aba-game','ABA','1975-76','regular','1976-01-01','002','aba-home','aba-away',120,118,'Final','fixture','{}');
            INSERT INTO canon_fact_team_game(game_key,team_key,opponent_team_key,is_home,result,points,opponent_points,source_key) VALUES
              ('nba-game','nba-home','nba-away',1,'W',110,100,'fixture'),
              ('nba-game','nba-away','nba-home',0,'L',100,110,'fixture'),
              ('aba-game','aba-home','aba-away',1,'W',120,118,'fixture');
            """
        )
        grouped = team_rows(db)
        games = game_rows(db)
    assert set(grouped) == {"nba-game"}, grouped
    assert [row["team_key"] for row in grouped["nba-game"]] == ["nba-home", "nba-away"]
    assert [row["game_key"] for row in games] == ["nba-game"], games


def test_static_runtime_contract() -> None:
    require(
        "scripts/open_terminal.sh",
        "build_static_nba_website_data_v2.py",
        "build_static_nba_game_data.py",
        "build_static_front_office_snapshot.py",
        "validate_static_nba_corpus",
        "dashboard/{latest}.json",
        "--materialize-pbp",
        "--skip-pbp",
        "web/data/nba_static",
        "Historical NBA pages are served from static files, not the API.",
    )
    require(
        "tools/build_static_nba_website_data_v2.py",
        "sports-terminal-static-nba-website-v5",
        "sports-terminal-static-dashboard-v2",
        "STATIC_SCHEMA_VERSION = 5",
        '"historical_http_api_required": False',
        '"sqlite_required_by_browser": False',
        '"live_overlay_supported": True',
        '"dashboard_precomputed": True',
        "team_leaders",
        "personal_fouls",
        "three_pointers_made",
        "repair_playoff_shards",
        "apply_award_supplement",
        "build_data_foundation",
        "build_research_catalog",
    )
    require(
        "tools/repair_static_nba_playoffs.py",
        "playoffs.json",
        "historical_seed_snapshot",
        "static_playoff_repair",
    )
    require(
        "tools/nba_awards_static_supplement.py",
        "user_supplied_awards_2026_09_10",
        "All-Star Game MVP",
        "All-NBA",
        "All-Defense",
        "All-Rookie",
    )
    require(
        "tools/nba_data_foundation.py",
        "sports-terminal-nba-data-foundation-v1",
        "canonical_warehouse",
        "nba_com_captures",
        "sportsdataverse_releases",
        "pbpstats_cache",
        "basketball_reference",
        "manual_awards",
    )
    require(
        "tools/nba_research_catalog.py",
        "sports-terminal-nba-research-catalog-v1",
        "runtime_network_required",
        "play_by_play",
        "possessions",
        "lineups",
        "shots",
    )
    require(
        "tools/build_static_nba_website_data.py",
        "NBA_FIRST_START_YEAR = 1946",
        "2025-26",
    )
    require(
        "lib/services/website_nba_static_repository.dart",
        "data/nba_static",
        "dataFoundation",
        "researchCatalog",
        "dashboard/",
        "players/index.json",
        "teams/index.json",
        "games/index.json",
        "history/awards.json",
    )
    assert_not_contains(
        "lib/services/website_nba_static_repository.dart",
        "127.0.0.1:8000",
        "stats.nba.com",
        "basketball-reference.com",
    )


def test_static_contract_constants() -> None:
    module = _import_builder_module()
    assert getattr(module, "NBA_FIRST_START_YEAR") == 1946


def test_static_json_shape_examples() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        manifest = {
            "schema": "sports-terminal-static-nba-website-v5",
            "contract": "sports-terminal-static-nba-website-v5",
            "latest_season": "2025-26",
            "runtime": {
                "historical_http_api_required": False,
                "sqlite_required_by_browser": False,
            },
        }
        (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        loaded = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
        assert loaded["contract"] == "sports-terminal-static-nba-website-v5"
        assert loaded["runtime"]["historical_http_api_required"] is False


def main() -> int:
    test_league_scoping()
    test_game_scoping()
    test_static_runtime_contract()
    test_static_contract_constants()
    test_static_json_shape_examples()
    print("Static NBA website contract test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
