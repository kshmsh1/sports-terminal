from __future__ import annotations

import importlib.util
import json
import os
import sqlite3
import sys
import tempfile
from pathlib import Path


def load_fixture_module(repo_root: Path):
    path = repo_root / "backend" / "scripts" / "historical_research_contract_test.py"
    spec = importlib.util.spec_from_file_location("historical_entity_fixture", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load historical fixture: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def enrich(database: Path) -> None:
    db = sqlite3.connect(database)
    try:
        db.executescript(
            """
            CREATE TABLE canon_dim_season(
              season_id TEXT PRIMARY KEY,start_year INTEGER,end_year INTEGER,label TEXT
            );
            INSERT INTO canon_dim_season VALUES
              ('2022-23',2022,2023,'2022-23'),
              ('2023-24',2023,2024,'2023-24');

            CREATE TABLE canon_player_source_xref(
              source_key TEXT,source_table TEXT,source_id TEXT,source_name TEXT,player_key TEXT,
              match_method TEXT,confidence REAL,evidence_json TEXT
            );
            INSERT INTO canon_player_source_xref VALUES
              ('sumitro_bref_history','Player Totals','star01','Example Star','p_star','bref_id',1.0,'{}'),
              ('gonzalo_all_time','NBA_2023-2024_advanced','100','Example Star','p_star','nba_id',1.0,'{}');

            INSERT INTO canon_fact_award VALUES
              ('a1','p_star','Example Star','2023-24','NBA','Most Valuable Player','1',1,0.82,'gonzalo_all_time','{}');
            INSERT INTO canon_fact_all_star VALUES
              ('as1','p_star','Example Star','2023-24','NBA','East','gonzalo_all_time','{}');
            INSERT INTO canon_fact_draft VALUES
              ('d1','p_star','Example Star',2019,'NBA','1',3,'t_a','Alpha','gonzalo_all_time','{}');

            INSERT INTO canon_conflicts(
              entity_type,entity_key,field_name,selected_source,selected_value,
              alternate_source,alternate_value,severity,detected_at
            ) VALUES
              ('player','p_star','birth_year','sumitro_bref_history','1995',
               'gonzalo_all_time','1994','material','now');
            """
        )
        db.commit()
    finally:
        db.close()


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    fixture = load_fixture_module(repo_root)

    with tempfile.TemporaryDirectory(prefix="sports-terminal-entity-intel-") as temp:
        temp_root = Path(temp)
        database = temp_root / "history.sqlite"
        fixture.seed(database)
        enrich(database)
        os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(database)
        os.environ["SPORTS_TERMINAL_DB_PATH"] = str(temp_root / "launch.sqlite")
        sys.path.insert(0, str(repo_root / "backend"))

        from app import main_launch as launch  # noqa: PLC0415
        from app import historical_nba_entity_api as entity  # noqa: PLC0415
        from app import historical_nba_entity_search_api as entity_search  # noqa: PLC0415

        paths = {getattr(route, "path", "") for route in launch.app.routes}
        required = {
            "/v2/nba/history/entities/search",
            "/v2/nba/history/players/{player_key}/dossier",
            "/v2/nba/history/teams/{team_key}/dossier",
            "/v2/nba/history/seasons/{season_id}/command",
            "/v2/nba/history/franchises/{franchise_key}/dossier",
        }
        missing = sorted(required - paths)
        assert not missing, {
            "missing_routes": missing,
            "history_routes": sorted(path for path in paths if "/v2/nba/history" in path),
        }

        search = entity_search.historical_entity_search_fast(
            query="Example",
            league="NBA",
            kinds="player,team,franchise,season,game",
            limit_per_kind=20,
        )
        assert search["count"] >= 1, search
        assert search["search_strategy"] == "bounded-canonical-entity-search-v2", search
        assert search["groups"]["players"][0]["player_key"] == "p_star", search

        season_search = entity_search.historical_entity_search_fast(
            query="2023",
            league="NBA",
            kinds="season",
            limit_per_kind=20,
        )
        assert season_search["groups"]["seasons"][0]["season_id"] == "2023-24", season_search
        assert season_search["groups"]["seasons"][0]["players"] == 2, season_search
        assert season_search["groups"]["seasons"][0]["teams"] == 2, season_search
        assert season_search["groups"]["seasons"][0]["games"] == 1, season_search

        player = entity.historical_player_dossier(
            player_key="p_star",
            league="NBA",
            season_type="combined",
            recent_games=25,
        )
        assert player["profile"]["canonical_name"] == "Example Star", player
        assert player["summary"]["season_rows"] == 2, player
        assert player["summary"]["awards"] == 1, player
        assert player["summary"]["all_star_selections"] == 1, player
        assert player["draft"][0]["pick_number"] == 3, player
        assert player["summary"]["material_conflicts"] == 1, player

        team = entity.historical_team_dossier(
            team_key="t_a",
            league="NBA",
            season_type="regular",
            recent_games=25,
        )
        assert team["profile"]["canonical_name"] == "Alpha", team
        assert team["franchise"]["franchise_key"] == "fr_alpha", team
        assert team["seasons"][0]["wins"] == 58, team
        assert team["notable_players"][0]["player_name"] == "Example Star", team

        season = entity.historical_season_command(
            season_id="2023-24",
            league="NBA",
            season_type="regular",
            leader_limit=10,
        )
        assert season["summary"]["teams"] == 2, season
        assert season["summary"]["players"] == 2, season
        assert season["summary"]["games"] == 1, season
        assert season["teams"][0]["team_key"] == "t_a", season
        assert season["leaders"]["pts"][0]["player_key"] == "p_star", season
        assert season["awards"][0]["award"] == "Most Valuable Player", season
        assert season["all_star"][0]["player_key"] == "p_star", season
        assert len(season["coverage"]) == 3, season

        franchise = entity.historical_franchise_dossier(
            franchise_key="fr_alpha",
            league="NBA",
        )
        assert franchise["profile"]["canonical_name"] == "Alpha Franchise", franchise
        assert franchise["summary"]["team_identities"] == 1, franchise
        assert franchise["summary"]["seasons"] == 1, franchise

        print(
            json.dumps(
                {
                    "entity_routes": len(required),
                    "search_strategy": search["search_strategy"],
                    "search_results": search["count"],
                    "player": player["profile"]["canonical_name"],
                    "season": season["season"]["season_id"],
                    "season_leader": season["leaders"]["pts"][0]["player_name"],
                    "franchise": franchise["profile"]["canonical_name"],
                },
                indent=2,
            )
        )

    print("Historical NBA entity intelligence contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
