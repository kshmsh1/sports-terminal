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


def test_season_catalog_has_no_fact_fanout() -> None:
    from build_static_nba_website_data_v2 import season_catalog

    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "nba.sqlite"
        with sqlite3.connect(path) as db:
            db.executescript(
                """
                CREATE TABLE canon_dim_season(season_id TEXT PRIMARY KEY,start_year INTEGER,end_year INTEGER,label TEXT);
                CREATE TABLE canon_fact_player_season(season_id TEXT,league_id TEXT,player_key TEXT);
                CREATE TABLE canon_fact_team_season(season_id TEXT,league_id TEXT,team_key TEXT);
                CREATE TABLE canon_dim_game(season_id TEXT,league_id TEXT,game_key TEXT);
                INSERT INTO canon_dim_season VALUES('2025-26',2025,2026,'2025-26');
                INSERT INTO canon_fact_player_season VALUES
                  ('2025-26','NBA','p1'),('2025-26','NBA','p2'),('2025-26','NBA','p2');
                INSERT INTO canon_fact_team_season VALUES
                  ('2025-26','NBA','t1'),('2025-26','NBA','t2');
                INSERT INTO canon_dim_game VALUES
                  ('2025-26','NBA','g1'),('2025-26','NBA','g2'),('2025-26','NBA','g3');
                """
            )
            row = season_catalog(db)[0]
        assert row["players"] == 2, row
        assert row["teams"] == 2, row
        assert row["games"] == 3, row


def test_dashboard_payload_is_small_and_deterministic() -> None:
    from build_static_nba_website_data_v2 import dashboard_payload

    season = {
        "player_season_totals": [
            {
                "player_id": "p1",
                "player_name": "Alpha Guard",
                "team_id": "t1",
                "team_ids": "AAA",
                "position": "PG",
                "games": 10,
                "points": 250,
                "rebounds": 40,
                "assists": 90,
                "steals": 12,
                "blocks": 2,
            },
            {
                "player_id": "p2",
                "player_name": "Beta Wing",
                "team_id": "t2",
                "team_ids": "BBB",
                "position": "SF",
                "games": 10,
                "points": 200,
                "rebounds": 80,
                "assists": 30,
                "steals": 8,
                "blocks": 6,
            },
        ],
        "teams": [{"team_id": "t1"}, {"team_id": "t2"}],
        "team_records": [{"team_id": "t1", "wins": 7, "losses": 3}],
        "games": [
            {
                "game_id": "g1",
                "game_date": "2026-04-01",
                "home_score": 110,
                "away_score": 100,
            },
            {
                "game_id": "future",
                "game_date": "2026-04-02",
                "home_score": None,
                "away_score": None,
            },
        ],
        "player_game_logs": [{"game_id": str(i)} for i in range(1000)],
        "play_by_play": [{"event": i} for i in range(1000)],
    }
    payload = dashboard_payload("2025-26", season)
    assert payload["runtime_api_required"] is False
    assert payload["leaders"]["points"][0]["player_id"] == "p1"
    assert payload["leaders"]["points"][0]["value"] == 25.0
    assert payload["leaders"]["rebounds"][0]["player_id"] == "p2"
    assert len(payload["recent_games"]) == 1
    assert "player_game_logs" not in payload
    assert "play_by_play" not in payload


def test_team_game_materializer_scopes_league_through_game_dimension() -> None:
    from build_static_nba_game_data import team_rows

    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp) / "nba.sqlite"
        with sqlite3.connect(path) as db:
            db.row_factory = sqlite3.Row
            db.executescript(
                """
                CREATE TABLE canon_dim_game(
                  game_key TEXT PRIMARY KEY,
                  league_id TEXT NOT NULL
                );
                CREATE TABLE canon_fact_team_game(
                  game_key TEXT NOT NULL,
                  team_key TEXT NOT NULL,
                  opponent_team_key TEXT,
                  is_home INTEGER NOT NULL,
                  result TEXT,
                  points REAL,
                  opponent_points REAL,
                  source_key TEXT NOT NULL,
                  provenance_json TEXT NOT NULL DEFAULT '{}',
                  PRIMARY KEY(game_key,team_key)
                );
                INSERT INTO canon_dim_game VALUES('nba-game','NBA');
                INSERT INTO canon_dim_game VALUES('aba-game','ABA');
                INSERT INTO canon_fact_team_game
                  (game_key,team_key,opponent_team_key,is_home,result,points,opponent_points,source_key)
                VALUES
                  ('nba-game','nba-home','nba-away',1,'W',110,100,'fixture'),
                  ('nba-game','nba-away','nba-home',0,'L',100,110,'fixture'),
                  ('aba-game','aba-home','aba-away',1,'W',120,118,'fixture');
                """
            )
            grouped = team_rows(db)

        assert set(grouped) == {"nba-game"}, grouped
        assert [row["team_key"] for row in grouped["nba-game"]] == [
            "nba-home",
            "nba-away",
        ]
        assert all("league_id" not in row for row in grouped["nba-game"])


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
        "sports-terminal-static-nba-website-v3",
        "sports-terminal-static-dashboard-v1",
        '"historical_http_api_required": False',
        '"sqlite_required_by_browser": False',
        '"live_overlay_supported": True',
        '"dashboard_precomputed": True',
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
        "tools/build_static_front_office_snapshot.py",
        "contracts.json",
        "draft_assets.json",
        "team_positions.json",
    )
    require(
        "lib/services/website_nba_static_repository.dart",
        "data/nba_static",
        "seasonDashboard",
        "seasonSnapshot",
        "playerDossier",
        "teamDossier",
        "gameDetail",
        "gamePlayByPlay",
        "searchEntities",
    )
    require(
        "lib/services/website_nba_api_service.dart",
        "WebsiteNbaStaticRepository",
        "Historical basketball data is now a static website concern",
        "FastAPI request",
        "runtime SQLite query",
        "seasonDashboard",
    )
    reject(
        "lib/services/website_nba_api_service.dart",
        "http://127.0.0.1:8000",
        "/v2/nba/history/seed/",
        "LaunchBackendTransport",
        "loadHistoricalSeason(",
        "package:http/http.dart",
    )
    require(
        "lib/screens/website_nba_home_dashboard.dart",
        "seasonDashboard",
        "No runtime NBA API is required",
    )
    require(
        "lib/services/front_office_registry_service.dart",
        "Cache-first product read",
        "loadRemote",
        "loadCached",
    )
    require(
        "lib/services/front_office_static_snapshot_repository.dart",
        "data/nba_static/front_office",
        "contracts.json",
        "draft_assets.json",
        "team_positions.json",
    )
    require(
        ".gitignore",
        "/web/data/nba_static/",
    )
    require(
        "docs/static_nba_website_architecture.md",
        "static base + live overlay",
        "--materialize-pbp",
        "does not claim possession-level PBP",
    )


def main() -> int:
    test_season_catalog_has_no_fact_fanout()
    test_dashboard_payload_is_small_and_deterministic()
    test_team_game_materializer_scopes_league_through_game_dimension()
    test_static_runtime_contract()
    print("static-nba-website-contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
