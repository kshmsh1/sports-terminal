from __future__ import annotations

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
            CREATE TABLE historical_source_registry(
              source_key TEXT PRIMARY KEY,label TEXT,license TEXT,coverage TEXT,
              file_count INTEGER,table_count INTEGER,row_count INTEGER,priority INTEGER
            );
            INSERT INTO historical_source_registry VALUES
              ('wyatt_nbadb','Wyatt','CC BY-SA 4.0','1946-47 to present',1,16,14060690,10),
              ('sumitro_bref_history','Sumitro','CC0','1947 to present',22,22,270117,20),
              ('gonzalo_all_time','Gonzalo','MIT','1946-47 to 2023-24',141,141,8434399,30);

            CREATE TABLE canon_build_manifest(
              build_id TEXT PRIMARY KEY,schema_version TEXT,built_at TEXT,source_rows INTEGER,
              source_tables INTEGER,source_count INTEGER,canonical_counts_json TEXT,warnings_json TEXT
            );
            INSERT INTO canon_build_manifest VALUES
              ('compat-test','2026.08.07.1','2026-08-07T00:00:00Z',22765206,179,3,
               '{"players":2,"teams":2,"games":1}','[]');

            CREATE TABLE canon_dim_season(
              season_id TEXT PRIMARY KEY,start_year INTEGER,end_year INTEGER,label TEXT
            );
            INSERT INTO canon_dim_season VALUES ('2023-24',2023,2024,'2023-24');

            CREATE TABLE canon_dim_franchise(
              franchise_key TEXT PRIMARY KEY,canonical_name TEXT,current_abbreviation TEXT,source_count INTEGER
            );
            INSERT INTO canon_dim_franchise VALUES
              ('fr_a','Alpha Franchise','AAA',2),('fr_b','Beta Franchise','BBB',2);

            CREATE TABLE canon_dim_team(
              team_key TEXT PRIMARY KEY,franchise_key TEXT,canonical_name TEXT,abbreviation TEXT,league_id TEXT,
              active_from TEXT,active_to TEXT,nba_team_id TEXT,source_count INTEGER,provenance_json TEXT
            );
            INSERT INTO canon_dim_team VALUES
              ('t_a','fr_a','Alpha','AAA','NBA','2000-01',NULL,'10',2,'{}'),
              ('t_b','fr_b','Beta','BBB','NBA','2000-01',NULL,'20',2,'{}');

            CREATE TABLE canon_dim_player(
              player_key TEXT PRIMARY KEY,canonical_name TEXT,normalized_name TEXT,nba_id TEXT,bref_id TEXT,
              birth_date TEXT,birth_year INTEGER,primary_position TEXT,active_from TEXT,active_to TEXT,
              source_count INTEGER,identity_confidence REAL,provenance_json TEXT
            );
            INSERT INTO canon_dim_player VALUES
              ('p_star','Example Star','examplestar','100','star01',NULL,1995,'PG','2019-20','2024-25',3,1.0,'{}'),
              ('p_other','Other Player','otherplayer','200','other01',NULL,1994,'C','2018-19','2024-25',2,1.0,'{}');

            CREATE TABLE canon_fact_player_season(
              fact_key TEXT PRIMARY KEY,player_key TEXT,season_id TEXT,league_id TEXT,season_type TEXT,
              team_key TEXT,team_abbreviation TEXT,position TEXT,age REAL,games REAL,games_started REAL,
              minutes REAL,fgm REAL,fga REAL,fg_pct REAL,three_pm REAL,three_pa REAL,three_pct REAL,
              two_pm REAL,two_pa REAL,two_pct REAL,ftm REAL,fta REAL,ft_pct REAL,orb REAL,drb REAL,
              reb REAL,ast REAL,stl REAL,blk REAL,tov REAL,pf REAL,pts REAL,per REAL,ts_pct REAL,
              efg_pct REAL,ws REAL,ws48 REAL,obpm REAL,dbpm REAL,bpm REAL,vorp REAL,usg_pct REAL,
              ortg REAL,drtg REAL,primary_source TEXT,source_count INTEGER,provenance_json TEXT
            );
            INSERT INTO canon_fact_player_season VALUES
              ('ps1','p_star','2023-24','NBA','regular','t_a','AAA','PG',28,75,75,2700,
               700,1400,.500,180,480,.375,520,920,.565,320,390,.821,60,390,450,620,110,35,190,150,
               1900,25,.620,.564,11,.196,5.5,1.2,6.7,5.1,.30,123,112,'sumitro_bref_history',3,'{}'),
              ('ps2','p_other','2023-24','NBA','regular','t_b','BBB','C',29,76,76,2500,
               520,1000,.520,20,80,.250,500,920,.543,210,300,.700,180,590,770,220,55,120,140,210,
               1270,19,.580,.530,8,.154,1.2,1.6,2.8,2.9,.22,116,114,'sumitro_bref_history',2,'{}');

            CREATE TABLE canon_fact_team_season(
              fact_key TEXT PRIMARY KEY,team_key TEXT,team_abbreviation TEXT,team_name TEXT,season_id TEXT,
              league_id TEXT,season_type TEXT,games REAL,wins REAL,losses REAL,minutes REAL,pts REAL,
              opp_pts REAL,fgm REAL,fga REAL,three_pm REAL,three_pa REAL,ftm REAL,fta REAL,orb REAL,
              drb REAL,reb REAL,ast REAL,stl REAL,blk REAL,tov REAL,pf REAL,pace REAL,ortg REAL,drtg REAL,
              net_rtg REAL,srs REAL,primary_source TEXT,source_count INTEGER,provenance_json TEXT
            );
            INSERT INTO canon_fact_team_season VALUES
              ('ts1','t_a','AAA','Alpha','2023-24','NBA','regular',82,58,24,19800,9500,9000,
               NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,99,121,115,6,5.5,'sumitro_bref_history',2,'{}'),
              ('ts2','t_b','BBB','Beta','2023-24','NBA','regular',82,42,40,19800,9100,9080,
               NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,98,116,116,0,.2,'sumitro_bref_history',2,'{}');

            CREATE TABLE canon_dim_game(
              game_key TEXT PRIMARY KEY,nba_game_id TEXT,game_date TEXT,season_id TEXT,league_id TEXT,
              season_type TEXT,home_team_key TEXT,away_team_key TEXT,home_score REAL,away_score REAL,
              winner_team_key TEXT,status TEXT,source_count INTEGER,provenance_json TEXT
            );
            INSERT INTO canon_dim_game VALUES
              ('g1','G001','2024-01-01','2023-24','NBA','regular','t_a','t_b',112,104,'t_a','Final',2,'{}');

            CREATE TABLE canon_fact_team_game(
              game_key TEXT,team_key TEXT,opponent_team_key TEXT,is_home INTEGER,result TEXT,points REAL,
              opponent_points REAL,fgm REAL,fga REAL,three_pm REAL,three_pa REAL,ftm REAL,fta REAL,
              orb REAL,drb REAL,reb REAL,ast REAL,stl REAL,blk REAL,tov REAL,pf REAL,source_key TEXT,
              provenance_json TEXT,PRIMARY KEY(game_key,team_key)
            );
            INSERT INTO canon_fact_team_game VALUES
              ('g1','t_a','t_b',1,'W',112,104,42,84,14,35,14,18,10,34,44,28,8,5,12,18,'wyatt_nbadb','{}'),
              ('g1','t_b','t_a',0,'L',104,112,40,88,12,34,12,16,12,32,44,24,7,4,14,20,'wyatt_nbadb','{}');

            CREATE TABLE canon_fact_player_game(
              fact_key TEXT PRIMARY KEY,game_key TEXT,source_game_id TEXT,player_key TEXT,player_name TEXT,
              team_key TEXT,team_abbreviation TEXT,opponent_team_key TEXT,opponent_abbreviation TEXT,
              season_id TEXT,league_id TEXT,season_type TEXT,game_date TEXT,minutes REAL,pts REAL,reb REAL,
              ast REAL,stl REAL,blk REAL,tov REAL,pf REAL,ts_pct REAL,efg_pct REAL,usg_pct REAL,ortg REAL,
              drtg REAL,bpm REAL,source_key TEXT,source_table TEXT,source_row INTEGER,provenance_json TEXT
            );
            INSERT INTO canon_fact_player_game VALUES
              ('pg1','g1','G001','p_star','Example Star','t_a','AAA','t_b','BBB','2023-24','NBA','regular',
               '2024-01-01',36,32,8,10,2,1,3,2,.64,.58,.31,125,111,8,'gonzalo_all_time','advanced',1,'{}'),
              ('pg2','g1','G001','p_other','Other Player','t_b','BBB','t_a','AAA','2023-24','NBA','regular',
               '2024-01-01',34,24,9,4,1,2,2,3,.57,.52,.24,116,118,2,'gonzalo_all_time','advanced',2,'{}');

            CREATE TABLE canon_coverage(
              domain TEXT,league_id TEXT,season_id TEXT,row_count INTEGER,source_count INTEGER,sources_json TEXT
            );
            INSERT INTO canon_coverage VALUES
              ('player_season','NBA','2023-24',2,3,'["sumitro_bref_history","gonzalo_all_time","wyatt_nbadb"]'),
              ('play_by_play','NBA','2023-24',250000,1,'["wyatt_nbadb"]');
            """
        )
        db.commit()
    finally:
        db.close()


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="sports-terminal-seed-compat-") as temp:
        database = Path(temp) / "history.sqlite"
        seed(database)
        os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(database)
        sys.path.insert(0, str(repo_root / "backend"))

        from app import historical_nba_compat_api as compat  # noqa: PLC0415

        payload = compat.historical_seed_snapshot(
            season="2023-24",
            league="NBA",
            season_type="regular",
            include_game_logs=True,
            player_log_limit=50000,
        )
        assert payload["compatibility"]["contract"] == "nba-terminal-seed-v1", payload
        assert payload["compatibility"]["historical"] is True, payload
        assert payload["validation_report"]["status"] == "pass", payload
        assert payload["release_manifest"]["status"] == "historical-canonical", payload
        assert len(payload["players"]) == 2, payload["players"]
        assert len(payload["teams"]) == 2, payload["teams"]
        assert len(payload["games"]) == 1, payload["games"]
        assert len(payload["team_game_logs"]) == 2, payload["team_game_logs"]
        assert len(payload["player_game_logs_top"]) == 2, payload["player_game_logs_top"]
        star = next(row for row in payload["player_season_totals"] if row["player_label"] == "Example Star")
        assert star["points"] == 1900, star
        assert star["assists"] == 620, star
        assert star["team_ids"] == "AAA", star
        assert star["avg_bpm"] == 6.7, star
        assert payload["player_leaders"]["points"][0]["player_label"] == "Example Star", payload["player_leaders"]
        assert payload["player_game_highs"]["p_star"]["max_points"] == 32, payload["player_game_highs"]
        assert payload["manifest"]["warehouseBuild"]["playByPlayEventsNormalized"] == 250000, payload["manifest"]

        from app.main_launch import app  # noqa: PLC0415

        paths = {getattr(route, "path", "") for route in app.routes}
        assert "/v2/nba/history/seed/{season}" in paths, sorted(paths)

    print("Historical seed compatibility contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
