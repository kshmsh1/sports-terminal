from __future__ import annotations

import json
import os
import sqlite3
import sys
import tempfile
from pathlib import Path


def seed(database: Path) -> None:
    db = sqlite3.connect(database)
    try:
        db.executescript(
            """
            CREATE TABLE canon_build_manifest(
              build_id TEXT PRIMARY KEY, schema_version TEXT, built_at TEXT,
              source_rows INTEGER, source_tables INTEGER, source_count INTEGER,
              canonical_counts_json TEXT, warnings_json TEXT
            );
            INSERT INTO canon_build_manifest VALUES ('test','1','now',0,0,0,'{}','[]');

            CREATE TABLE canon_dim_player(
              player_key TEXT PRIMARY KEY, canonical_name TEXT, normalized_name TEXT,
              nba_id TEXT, bref_id TEXT, birth_date TEXT, birth_year INTEGER,
              primary_position TEXT, active_from TEXT, active_to TEXT,
              source_count INTEGER, identity_confidence REAL, provenance_json TEXT
            );
            INSERT INTO canon_dim_player VALUES
              ('p_star','Example Star','examplestar','100','star01',NULL,1995,'G','2016-17','2025-26',2,1.0,'{}'),
              ('p_other','Other Player','otherplayer','200','other01',NULL,1994,'F','2015-16','2025-26',2,1.0,'{}');

            CREATE TABLE canon_dim_team(
              team_key TEXT PRIMARY KEY, franchise_key TEXT, canonical_name TEXT,
              abbreviation TEXT, league_id TEXT, active_from TEXT, active_to TEXT,
              nba_team_id TEXT, source_count INTEGER, provenance_json TEXT
            );
            INSERT INTO canon_dim_team VALUES
              ('t_a','fr_a','Alpha','AAA','NBA',NULL,NULL,'10',1,'{}'),
              ('t_b','fr_b','Beta','BBB','NBA',NULL,NULL,'20',1,'{}');

            CREATE TABLE canon_fact_player_season(
              fact_key TEXT PRIMARY KEY, player_key TEXT, season_id TEXT, league_id TEXT,
              season_type TEXT, team_key TEXT, team_abbreviation TEXT, position TEXT, age REAL,
              games REAL, games_started REAL, minutes REAL, fgm REAL, fga REAL, fg_pct REAL,
              three_pm REAL, three_pa REAL, three_pct REAL, two_pm REAL, two_pa REAL, two_pct REAL,
              ftm REAL, fta REAL, ft_pct REAL, orb REAL, drb REAL, reb REAL, ast REAL, stl REAL,
              blk REAL, tov REAL, pf REAL, pts REAL, per REAL, ts_pct REAL, efg_pct REAL,
              ws REAL, ws48 REAL, obpm REAL, dbpm REAL, bpm REAL, vorp REAL, usg_pct REAL,
              ortg REAL, drtg REAL, primary_source TEXT, source_count INTEGER, provenance_json TEXT
            );

            -- 2023-24 has explicit 2TM total plus individual stints.
            INSERT INTO canon_fact_player_season VALUES
              ('star_total','p_star','2023-24','NBA','regular',NULL,'2TM','G',28,70,70,2400,700,1400,.500,140,400,.350,560,1000,.560,350,420,.833,50,350,400,500,100,30,180,140,1890,24,.610,.550,10,.200,5,1,6,5,.29,120,111,'sumitro_bref_history',2,'{}'),
              ('star_a','p_star','2023-24','NBA','regular','t_a','AAA','G',28,30,30,1000,300,600,.500,60,170,.353,240,430,.558,140,170,.824,20,150,170,210,40,12,75,60,800,23,.605,.550,4,.190,4.8,.8,5.6,2,.28,119,112,'sumitro_bref_history',1,'{}'),
              ('star_b','p_star','2023-24','NBA','regular','t_b','BBB','G',28,40,40,1400,400,800,.500,80,230,.348,320,570,.561,210,250,.840,30,200,230,290,60,18,105,80,1090,25,.615,.550,6,.207,5.2,1.2,6.4,3,.30,121,110,'sumitro_bref_history',1,'{}'),
              ('other_2324','p_other','2023-24','NBA','regular','t_a','AAA','F',29,72,72,2500,650,1300,.500,100,300,.333,550,1000,.550,250,320,.781,100,500,600,300,80,70,150,190,1650,18,.570,.538,7,.134,2,0,2,3,.22,112,113,'sumitro_bref_history',1,'{}');

            -- 2022-23 deliberately has no aggregate row. Each stint is below a 50 GP cutoff,
            -- but the synthesized full season is 60 games and must qualify.
            INSERT INTO canon_fact_player_season VALUES
              ('star_22a','p_star','2022-23','NBA','regular','t_a','AAA','G',27,30,30,1050,310,620,.500,65,180,.361,245,440,.557,150,180,.833,22,145,167,220,45,10,70,55,835,22,.608,.552,4,.183,4.5,.7,5.2,2,.27,118,112,'sumitro_bref_history',1,'{}'),
              ('star_22b','p_star','2022-23','NBA','regular','t_b','BBB','G',27,30,30,1080,320,640,.500,70,190,.368,250,450,.556,155,185,.838,25,150,175,225,48,12,72,58,865,23,.612,.555,4.2,.187,4.7,.9,5.6,2.2,.28,119,111,'sumitro_bref_history',1,'{}'),
              ('other_2223','p_other','2022-23','NBA','regular','t_a','AAA','F',28,65,65,2200,550,1150,.478,90,280,.321,460,870,.529,220,280,.786,90,420,510,260,70,60,140,175,1410,17,.555,.517,6,.131,1.5,-.2,1.3,2,.21,109,114,'sumitro_bref_history',1,'{}');
            """
        )
        db.commit()
    finally:
        db.close()


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="sports-terminal-leaderboard-") as temp:
        database = Path(temp) / "history.sqlite"
        seed(database)
        os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(database)
        sys.path.insert(0, str(repo_root / "backend"))
        from app import historical_nba_api  # noqa: PLC0415

        explicit = historical_nba_api.history_leaderboard(
            season="2023-24",
            metric="pts",
            basis="per_game",
            league="NBA",
            season_type="regular",
            team="",
            min_games=0,
            min_minutes=0,
            offset=0,
            limit=100,
        )
        star_rows = [row for row in explicit["rows"] if row["player_key"] == "p_star"]
        assert len(star_rows) == 1, explicit
        assert star_rows[0]["fact_key"] == "star_total", star_rows[0]
        assert star_rows[0]["team_abbreviation"] == "2TM", star_rows[0]
        assert abs(star_rows[0]["metric_value"] - 27.0) < 1e-9, star_rows[0]

        team_filtered = historical_nba_api.history_leaderboard(
            season="2023-24",
            metric="pts",
            basis="per_game",
            league="NBA",
            season_type="regular",
            team="AAA",
            min_games=0,
            min_minutes=0,
            offset=0,
            limit=100,
        )
        star_team = [row for row in team_filtered["rows"] if row["player_key"] == "p_star"]
        assert len(star_team) == 1 and star_team[0]["fact_key"] == "star_a", team_filtered

        synthesized = historical_nba_api.history_leaderboard(
            season="2022-23",
            metric="pts",
            basis="per_game",
            league="NBA",
            season_type="regular",
            team="",
            min_games=50,
            min_minutes=0,
            offset=0,
            limit=100,
        )
        star_synth = [row for row in synthesized["rows"] if row["player_key"] == "p_star"]
        assert len(star_synth) == 1, synthesized
        assert star_synth[0]["synthetic_aggregate"] is True, star_synth[0]
        assert star_synth[0]["games"] == 60.0, star_synth[0]
        assert star_synth[0]["pts"] == 1700.0, star_synth[0]
        assert abs(star_synth[0]["metric_value"] - (1700 / 60)) < 1e-9, star_synth[0]
        assert star_synth[0]["fact_key"] == "", star_synth[0]

        # The peer population must also be player-unique; era normalization relies on it.
        assert len({row["player_key"] for row in synthesized["rows"]}) == len(synthesized["rows"]), synthesized

        print(json.dumps({
            "explicit_total_rows": explicit["matched_rows"],
            "synthesized_rows": synthesized["matched_rows"],
            "star_2022_23_ppg": star_synth[0]["metric_value"],
        }, indent=2))

    print("Historical traded-player leaderboard contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
