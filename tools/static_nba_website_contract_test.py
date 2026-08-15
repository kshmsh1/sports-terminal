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


def test_static_runtime_contract() -> None:
    require(
        "scripts/open_terminal.sh",
        "build_static_nba_website_data_v2.py",
        "web/data/nba_static",
        "Historical NBA pages are served from static files, not the API.",
    )
    require(
        "lib/services/website_nba_static_repository.dart",
        "data/nba_static",
        "seasonSnapshot",
        "playerDossier",
        "teamDossier",
        "searchEntities",
    )
    require(
        "lib/services/website_nba_api_service.dart",
        "historical_http_api_required",
        "WebsiteNbaStaticRepository",
        "No FastAPI request or runtime SQLite query is required",
    )
    reject(
        "lib/services/website_nba_api_service.dart",
        "http://127.0.0.1:8000",
        "/v2/nba/history/seed/",
        "LaunchBackendTransport",
    )
    require(
        ".gitignore",
        "/web/data/nba_static/",
    )


def main() -> int:
    test_season_catalog_has_no_fact_fanout()
    test_static_runtime_contract()
    print("static-nba-website-contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
