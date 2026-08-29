from __future__ import annotations

import sqlite3
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path: str, *tokens: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    for token in tokens:
        if token not in text:
            raise AssertionError(f"{path} missing required static-data contract token: {token}")


def reject(path: str, *tokens: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    for token in tokens:
        if token in text:
            raise AssertionError(f"{path} still contains forbidden runtime historical dependency: {token}")


def _season_fixture(db: sqlite3.Connection) -> None:
    db.executescript(
        """
        CREATE TABLE canon_dim_season(season_id TEXT PRIMARY KEY,start_year INTEGER,end_year INTEGER,label TEXT);
        CREATE TABLE canon_fact_player_season(season_id TEXT,league_id TEXT,player_key TEXT);
        CREATE TABLE canon_fact_team_season(
          season_id TEXT,league_id TEXT,season_type TEXT,team_key TEXT,games REAL,
          pts REAL,reb REAL,ast REAL,stl REAL,blk REAL,tov REAL,pf REAL,fgm REAL,three_pm REAL,ftm REAL
        );
        CREATE TABLE canon_dim_game(season_id TEXT,league_id TEXT,game_key TEXT);
        CREATE TABLE canon_dim_team(team_key TEXT PRIMARY KEY,canonical_name TEXT,abbreviation TEXT);
        INSERT INTO canon_dim_season VALUES('2025-26',2025,2026,'2025-26');
        INSERT INTO canon_fact_player_season VALUES
          ('2025-26','NBA','p1'),('2025-26','NBA','p2'),('2025-26','NBA','p2');
        INSERT INTO canon_dim_team VALUES('t1','Alpha Team','AAA'),('t2','Beta Team','BBB');
        INSERT INTO canon_fact_team_season VALUES
          ('2025-26','NBA','regular','t1',10,1100,400,250,80,40,120,180,420,120,200),
          ('2025-26','NBA','regular','t2',10,1050,450,220,70,55,130,170,400,100,220);
        INSERT INTO canon_dim_game VALUES
          ('2025-26','NBA','g1'),('2025-26','NBA','g2'),('2025-26','NBA','g3');
        """
    )


def test_season_catalog_has_no_fact_fanout() -> None:
    from build_static_nba_website_data_v2 import season_catalog

    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "nba.sqlite"
        with sqlite3.connect(path) as db:
            _season_fixture(db)
            row = season_catalog(db)[0]
        assert row["season_id"] == "2025-26", row
        assert row["players"] == 2, row
        assert row["teams"] == 2, row
        assert row["games"] == 3, row


def test_malformed_season_aliases_collapse() -> None:
    from build_static_nba_website_data import normalize_season_rows

    normalized = normalize_season_rows(
        [
            {"season_id": "2023-20", "season_type": "regular", "team_key": "bos", "team_abbreviation": "BOS", "games": 70, "pts": 1600},
            {"season_id": "2023-24", "season_type": "regular", "team_key": "bos", "team_abbreviation": "BOS", "games": 70, "pts": 1600},
        ],
        identity_fields=("season_type", "team_key", "team_abbreviation"),
    )
    assert len(normalized) == 1, normalized
    assert normalized[0]["season_id"] == "2023-24", normalized
    assert "source_season_id" not in normalized[0], normalized


def test_dashboard_payload_is_small_and_deterministic() -> None:
    from build_static_nba_website_data_v2 import dashboard_payload

    season = {
        "player_season_totals": [
            {
                "player_id": "p1", "player_name": "Alpha Guard", "team_id": "t1", "team_ids": "AAA", "position": "PG",
                "games": 10, "points": 250, "rebounds": 40, "assists": 90, "steals": 12, "blocks": 2,
                "turnovers": 30, "personal_fouls": 20, "field_goals_made": 90, "three_pointers_made": 30, "free_throws_made": 40,
            },
            {
                "player_id": "p2", "player_name": "Beta Wing", "team_id": "t2", "team_ids": "BBB", "position": "SF",
                "games": 10, "points": 200, "rebounds": 80, "assists": 30, "steals": 8, "blocks": 6,
                "turnovers": 20, "personal_fouls": 25, "field_goals_made": 75, "three_pointers_made": 25, "free_throws_made": 25,
            },
        ],
        "teams": [{"team_id": "t1"}, {"team_id": "t2"}],
        "team_records": [{"team_id": "t1", "wins": 7, "losses": 3}],
        "games": [
            {"game_id": "g1", "game_date": "2026-04-01", "home_score": 110, "away_score": 100},
            {"game_id": "future", "game_date": "2026-04-02", "home_score": None, "away_score": None},
        ],
        "player_game_logs": [{"game_id": str(i)} for i in range(1000)],
        "play_by_play": [{"event": i} for i in range(1000)],
    }
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "nba.sqlite"
        with sqlite3.connect(path) as db:
            _season_fixture(db)
            payload = dashboard_payload(db, "2025-26", "2025-26", season)
    assert payload["runtime_api_required"] is False
    assert payload["leaders"]["points"][0]["player_id"] == "p1"
    assert payload["leaders"]["points"][0]["value"] == 25.0
    assert payload["leaders"]["rebounds"][0]["player_id"] == "p2"
    assert payload["team_leaders"]["points"][0]["team_key"] == "t1"
    assert len(payload["recent_games"]) == 1
    assert "player_game_logs" not in payload
    assert "play_by_play" not in payload
    assert len(payload["leaders"]) == 10
    assert len(payload["team_leaders"]) == 10


def test_team_game_materializer_scopes_league_through_game_dimension() -> None:
    from build_static_nba_game_data import team_rows

    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "nba.sqlite"
        with sqlite3.connect(path) as db:
            db.row_factory = sqlite3.Row
            db.executescript(
                """
                CREATE TABLE canon_dim_game(game_key TEXT PRIMARY KEY,league_id TEXT NOT NULL);
                CREATE TABLE canon_fact_team_game(
                  game_key TEXT NOT NULL,team_key TEXT NOT NULL,opponent_team_key TEXT,is_home INTEGER NOT NULL,
                  result TEXT,points REAL,opponent_points REAL,source_key TEXT NOT NULL,provenance_json TEXT NOT NULL DEFAULT '{}',
                  PRIMARY KEY(game_key,team_key)
                );
                INSERT INTO canon_dim_game VALUES('nba-game','NBA'),('aba-game','ABA');
                INSERT INTO canon_fact_team_game(game_key,team_key,opponent_team_key,is_home,result,points,opponent_points,source_key) VALUES
                  ('nba-game','nba-home','nba-away',1,'W',110,100,'fixture'),
                  ('nba-game','nba-away','nba-home',0,'L',100,110,'fixture'),
                  ('aba-game','aba-home','aba-away',1,'W',120,118,'fixture');
                """
            )
            grouped = team_rows(db)
        assert set(grouped) == {"nba-game"}, grouped
        assert [row["team_key"] for row in grouped["nba-game"]] == ["nba-home", "nba-away"]


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
        "sports-terminal-static-nba-website-v4",
        "sports-terminal-static-dashboard-v2",
        "STATIC_SCHEMA_VERSION = 4",
        '"historical_http_api_required": False',
        '"sqlite_required_by_browser": False',
        '"live_overlay_supported": True',
        '"dashboard_precomputed": True',
        "team_leaders",
        "personal_fouls",
        "three_pointers_made",
    )
    require(
        "tools/build_static_nba_website_data.py",
        "NBA_FIRST_START_YEAR = 1946",
        "NBA_LAST_START_YEAR = 2025",
        "normalize_season_rows",
        "canonical_season_id",
    )
    require(
        "tools/build_static_nba_game_data.py",
        "canon_fact_play_by_play",
        "sports-terminal-static-game-v1",
        "sports-terminal-static-pbp-v1",
        '"runtime_api_required": False',
        '"coverage_is_source_bounded": True',
        "JOIN canon_dim_game g ON g.game_key=tg.game_key",
        "WHERE g.league_id='NBA'",
    )
    require(
        "lib/services/website_nba_static_repository.dart",
        "data/nba_static", "seasonDashboard", "seasonSnapshot", "playerDossier", "teamDossier", "gameDetail", "gamePlayByPlay", "searchEntities", "resolveTeamKey",
    )
    require(
        "lib/services/website_nba_api_service.dart",
        "WebsiteNbaStaticRepository",
        "Historical basketball data is now a static website concern",
        "FastAPI request", "runtime SQLite query", "seasonDashboard",
    )
    reject(
        "lib/services/website_nba_api_service.dart",
        "http://127.0.0.1:8000", "/v2/nba/history/seed/", "LaunchBackendTransport", "loadHistoricalSeason(", "package:http/http.dart",
    )
    require(
        "lib/screens/website_nba_home_dashboard.dart",
        "seasonDashboard", "Player leaders · Top 10", "Team leaders · Top 10", "No runtime NBA API is required",
    )
    require(
        "lib/screens/website_nba_stats_screen.dart",
        "Conventional NBA player statistics", "_StatColumn('pf', 'PF')", "_matchesPosition",
        "values: const [0, 65, 60, 50, 40, 30]", "values: const [0, 20, 15, 10]",
    )
    require(
        "lib/screens/website_nba_advanced_stats_screen.dart",
        "_matchesPosition", "Gravity & Spacing", "Clutch",
        "'three_pct': ['fg3_pct', 'three_pct']", "'three_dfg_pct': ['three_dfg_pct']",
    )
    require(
        "lib/screens/website_nba_entity_pages.dart",
        "Regular Season", "Playoffs", "Advanced statistics", "Awards & honors", "Second-Team All-NBA", "3PM Leader",
    )
    require(
        "lib/widgets/traditional_website_shell_v2.dart",
        "Front Office", "Research", "Community", "Python Lab", "Excel Workspace", "Coming later",
    )
    require(
        "lib/widgets/traditional_website_shell_impl.dart",
        "Lineup Analysis", "Search Sports Terminal", "Python Lab · detached", "Excel Workspace · detached",
    )
    require(
        "lib/screens/website_nba_lineup_analysis_screen.dart",
        "LeagueDashLineups", "data/nba_static/lineups/", "WebsiteStickyStatsTable",
    )
    require(".gitignore", "/web/data/nba_static/")


def main() -> int:
    test_season_catalog_has_no_fact_fanout()
    test_malformed_season_aliases_collapse()
    test_dashboard_payload_is_small_and_deterministic()
    test_team_game_materializer_scopes_league_through_game_dimension()
    test_static_runtime_contract()
    print("static-nba-website-contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
