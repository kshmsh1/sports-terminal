from __future__ import annotations

import json
import os
import sqlite3
import sys
import tempfile
from pathlib import Path


def insert_player_season(
    db: sqlite3.Connection,
    *,
    fact_key: str,
    player_key: str,
    season: str,
    team_key: str,
    team_abbr: str,
    games: float,
    minutes: float,
    pts: float,
    reb: float,
    ast: float,
    ws: float,
    bpm: float,
) -> None:
    fga = pts * 0.62
    fgm = fga * 0.50
    fta = pts * 0.20
    ftm = fta * 0.82
    three_pa = fga * 0.35
    three_pm = three_pa * 0.37
    db.execute(
        """
        INSERT INTO canon_fact_player_season(
          fact_key,player_key,season_id,league_id,season_type,team_key,team_abbreviation,
          position,age,games,games_started,minutes,fgm,fga,fg_pct,three_pm,three_pa,three_pct,
          ftm,fta,ft_pct,reb,ast,pts,ts_pct,efg_pct,ws,bpm,primary_source,source_count,provenance_json
        ) VALUES (?,?,?,'NBA','regular',?,?,'G',28,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,
                  'sumitro_bref_history',2,'{}')
        """,
        (
            fact_key,
            player_key,
            season,
            team_key,
            team_abbr,
            games,
            games,
            minutes,
            fgm,
            fga,
            fgm / fga,
            three_pm,
            three_pa,
            three_pm / three_pa,
            ftm,
            fta,
            ftm / fta,
            reb,
            ast,
            pts,
            pts / (2 * (fga + 0.44 * fta)),
            (fgm + 0.5 * three_pm) / fga,
            ws,
            bpm,
        ),
    )


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
              ('canon-test','1.0','2026-08-07T00:00:00Z',22765206,179,3,
               '{"players":2,"games":1,"playerGames":2}','[]');

            CREATE TABLE canon_dim_player(
              player_key TEXT PRIMARY KEY,canonical_name TEXT,normalized_name TEXT,nba_id TEXT,bref_id TEXT,
              birth_date TEXT,birth_year INTEGER,primary_position TEXT,active_from TEXT,active_to TEXT,
              source_count INTEGER,identity_confidence REAL,provenance_json TEXT
            );
            INSERT INTO canon_dim_player VALUES
              ('p_star','Example Star','examplestar','100','star01',NULL,1995,'G','2019-20','2024-25',3,1.0,'{}'),
              ('p_other','Other Player','otherplayer','200','other01',NULL,1994,'F','2018-19','2024-25',2,1.0,'{}');

            CREATE TABLE canon_dim_franchise(
              franchise_key TEXT PRIMARY KEY,canonical_name TEXT,current_abbreviation TEXT,source_count INTEGER
            );
            INSERT INTO canon_dim_franchise VALUES
              ('fr_alpha','Alpha Franchise','AAA',3),('fr_beta','Beta Franchise','BBB',2);

            CREATE TABLE canon_dim_team(
              team_key TEXT PRIMARY KEY,franchise_key TEXT,canonical_name TEXT,abbreviation TEXT,league_id TEXT,
              active_from TEXT,active_to TEXT,nba_team_id TEXT,source_count INTEGER,provenance_json TEXT
            );
            INSERT INTO canon_dim_team VALUES
              ('t_a','fr_alpha','Alpha','AAA','NBA','2010-11',NULL,'10',3,'{}'),
              ('t_b','fr_beta','Beta','BBB','NBA','2010-11',NULL,'20',2,'{}');

            CREATE TABLE canon_fact_player_season(
              fact_key TEXT PRIMARY KEY,player_key TEXT,season_id TEXT,league_id TEXT,season_type TEXT,
              team_key TEXT,team_abbreviation TEXT,position TEXT,age REAL,games REAL,games_started REAL,
              minutes REAL,fgm REAL,fga REAL,fg_pct REAL,three_pm REAL,three_pa REAL,three_pct REAL,
              two_pm REAL,two_pa REAL,two_pct REAL,ftm REAL,fta REAL,ft_pct REAL,orb REAL,drb REAL,
              reb REAL,ast REAL,stl REAL,blk REAL,tov REAL,pf REAL,pts REAL,per REAL,ts_pct REAL,
              efg_pct REAL,ws REAL,ws48 REAL,obpm REAL,dbpm REAL,bpm REAL,vorp REAL,usg_pct REAL,
              ortg REAL,drtg REAL,primary_source TEXT,source_count INTEGER,provenance_json TEXT
            );

            CREATE TABLE canon_fact_team_season(
              fact_key TEXT PRIMARY KEY,team_key TEXT,team_abbreviation TEXT,team_name TEXT,season_id TEXT,
              league_id TEXT,season_type TEXT,games REAL,wins REAL,losses REAL,minutes REAL,pts REAL,
              opp_pts REAL,fgm REAL,fga REAL,three_pm REAL,three_pa REAL,ftm REAL,fta REAL,orb REAL,
              drb REAL,reb REAL,ast REAL,stl REAL,blk REAL,tov REAL,pf REAL,pace REAL,ortg REAL,drtg REAL,
              net_rtg REAL,srs REAL,primary_source TEXT,source_count INTEGER,provenance_json TEXT
            );
            INSERT INTO canon_fact_team_season(
              fact_key,team_key,team_abbreviation,team_name,season_id,league_id,season_type,games,wins,losses,
              pts,opp_pts,pace,ortg,drtg,net_rtg,srs,primary_source,source_count,provenance_json
            ) VALUES
              ('ta24','t_a','AAA','Alpha','2023-24','NBA','regular',82,58,24,9400,8900,99.2,121,115,6,5.4,'sumitro_bref_history',2,'{}'),
              ('tb24','t_b','BBB','Beta','2023-24','NBA','regular',82,42,40,9000,8990,98.0,116,116,0,0.1,'sumitro_bref_history',2,'{}');

            CREATE TABLE canon_dim_game(
              game_key TEXT PRIMARY KEY,nba_game_id TEXT,game_date TEXT,season_id TEXT,league_id TEXT,
              season_type TEXT,home_team_key TEXT,away_team_key TEXT,home_score REAL,away_score REAL,
              winner_team_key TEXT,status TEXT,source_count INTEGER,provenance_json TEXT
            );
            INSERT INTO canon_dim_game VALUES
              ('g1','G001','2024-01-01','2023-24','NBA','regular','t_a','t_b',112,104,'t_a','Final',1,'{}');

            CREATE TABLE canon_fact_player_game(
              fact_key TEXT PRIMARY KEY,game_key TEXT,source_game_id TEXT,player_key TEXT,player_name TEXT,
              team_key TEXT,team_abbreviation TEXT,opponent_team_key TEXT,opponent_abbreviation TEXT,
              season_id TEXT,league_id TEXT,season_type TEXT,game_date TEXT,minutes REAL,pts REAL,reb REAL,
              ast REAL,stl REAL,blk REAL,tov REAL,pf REAL,ts_pct REAL,efg_pct REAL,usg_pct REAL,ortg REAL,
              drtg REAL,bpm REAL,source_key TEXT,source_table TEXT,source_row INTEGER,provenance_json TEXT
            );
            INSERT INTO canon_fact_player_game VALUES
              ('pg1','g1','G001','p_star','Example Star','t_a','AAA','t_b','BBB','2023-24','NBA','regular','2024-01-01',36,32,8,10,2,1,3,2,.64,.58,.31,125,111,8,'gonzalo_all_time','NBA_2023-2024_advanced',1,'{}'),
              ('pg2','g1','G001','p_other','Other Player','t_b','BBB','t_a','AAA','2023-24','NBA','regular','2024-01-01',34,24,9,4,1,2,2,3,.57,.52,.24,116,118,2,'gonzalo_all_time','NBA_2023-2024_advanced',2,'{}');

            CREATE TABLE canon_fact_award(award_key TEXT PRIMARY KEY,player_key TEXT,player_name TEXT,season_id TEXT,league_id TEXT,award TEXT,rank_text TEXT,winner INTEGER,share REAL,source_key TEXT,payload_json TEXT);
            CREATE TABLE canon_fact_all_star(selection_key TEXT PRIMARY KEY,player_key TEXT,player_name TEXT,season_id TEXT,league_id TEXT,team_text TEXT,source_key TEXT,payload_json TEXT);
            CREATE TABLE canon_fact_draft(draft_key TEXT PRIMARY KEY,player_key TEXT,player_name TEXT,draft_year INTEGER,league_id TEXT,round_text TEXT,pick_number REAL,drafting_team_key TEXT,drafting_team_text TEXT,source_key TEXT,payload_json TEXT);

            CREATE TABLE canon_field_provenance(
              entity_type TEXT,entity_key TEXT,field_name TEXT,source_key TEXT,source_table TEXT,source_row TEXT,
              source_value TEXT,selected INTEGER,evidence_json TEXT
            );
            INSERT INTO canon_field_provenance VALUES
              ('player_season','star24','pts','sumitro_bref_history','Player Totals','1','2400',1,'{}');

            CREATE TABLE canon_conflicts(
              conflict_id INTEGER PRIMARY KEY AUTOINCREMENT,entity_type TEXT,entity_key TEXT,field_name TEXT,
              selected_source TEXT,selected_value TEXT,alternate_source TEXT,alternate_value TEXT,severity TEXT,detected_at TEXT
            );
            INSERT INTO canon_conflicts(entity_type,entity_key,field_name,selected_source,selected_value,alternate_source,alternate_value,severity,detected_at)
            VALUES ('player_season','star24','pts','sumitro_bref_history','2400','gonzalo_all_time','2300','material','now');

            CREATE TABLE canon_coverage(domain TEXT,league_id TEXT,season_id TEXT,row_count INTEGER,source_count INTEGER,sources_json TEXT);
            INSERT INTO canon_coverage VALUES
              ('player_season','NBA','2022-23',2,2,'["sumitro_bref_history","gonzalo_all_time"]'),
              ('player_season','NBA','2023-24',2,2,'["sumitro_bref_history","gonzalo_all_time"]'),
              ('game','NBA','2023-24',1,1,'["wyatt_nbadb"]'),
              ('player_game','NBA','2023-24',2,1,'["gonzalo_all_time"]');
            """
        )
        insert_player_season(db,fact_key='star23',player_key='p_star',season='2022-23',team_key='t_a',team_abbr='AAA',games=75,minutes=2600,pts=2100,reb=500,ast=650,ws=11,bpm=6.2)
        insert_player_season(db,fact_key='star24',player_key='p_star',season='2023-24',team_key='t_a',team_abbr='AAA',games=80,minutes=2800,pts=2400,reb=560,ast=720,ws=13,bpm=7.1)
        insert_player_season(db,fact_key='other23',player_key='p_other',season='2022-23',team_key='t_b',team_abbr='BBB',games=78,minutes=2500,pts=1700,reb=650,ast=300,ws=7,bpm=2.0)
        insert_player_season(db,fact_key='other24',player_key='p_other',season='2023-24',team_key='t_b',team_abbr='BBB',games=76,minutes=2450,pts=1750,reb=680,ast=320,ws=7.5,bpm=2.2)
        db.commit()
    finally:
        db.close()


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix='sports-terminal-history-research-') as temp:
        database = Path(temp) / 'history.sqlite'
        seed(database)
        os.environ['SPORTS_TERMINAL_NBA_HISTORY_DB'] = str(database)
        sys.path.insert(0, str(repo_root / 'backend'))

        from app import historical_nba_research_api as research  # noqa: PLC0415

        summary = research.historical_research_summary()
        assert summary['counts']['players'] == 2, summary
        assert summary['counts']['material_conflicts'] == 1, summary
        assert len(summary['sources']) == 3, summary

        all_time = research.historical_all_time(
            metric='pts',basis='totals',mode='career',best_n=5,league='NBA',season_type='regular',
            season_from='',season_to='',min_seasons=1,min_games=0,offset=0,limit=100,
        )
        assert all_time['rows'][0]['player_name'] == 'Example Star', all_time
        assert all_time['rows'][0]['metric_value'] == 4500.0, all_time

        peak = research.historical_all_time(
            metric='bpm',basis='per_game',mode='peak',best_n=5,league='NBA',season_type='regular',
            season_from='',season_to='',min_seasons=1,min_games=0,offset=0,limit=100,
        )
        assert peak['rows'][0]['peak_season'] == '2023-24', peak

        compare = research.historical_compare(
            player_keys='p_star,p_other',metric='pts',basis='per_game',league='NBA',
            season_type='regular',min_games=1,
        )
        assert len(compare['players']) == 2, compare
        assert compare['players'][0]['peak_era'] is not None, compare

        games = research.historical_player_games(
            player_key='p_star',season='',season_type='combined',offset=0,limit=100,
        )
        assert games['matched_rows'] == 1 and games['rows'][0]['pts'] == 32.0, games

        franchises = research.historical_franchises(query='',league='NBA',limit=100)
        assert len(franchises['rows']) == 2, franchises
        franchise = research.historical_franchise('fr_alpha')
        assert franchise['teams'][0]['abbreviation'] == 'AAA', franchise
        assert franchise['seasons'][0]['wins'] == 58.0, franchise

        from app.main_launch import app  # noqa: PLC0415

        paths = {getattr(route, 'path', '') for route in app.routes}
        required = {
            '/v2/nba/history/research/summary',
            '/v2/nba/history/all-time',
            '/v2/nba/history/compare',
            '/v2/nba/history/players/{player_key}/games',
            '/v2/nba/history/franchises',
            '/v2/nba/history/franchises/{franchise_key}',
        }
        missing = sorted(required - paths)
        assert not missing, {'missing_routes': missing, 'sample_paths': sorted(path for path in paths if '/v2/nba/history' in path)}

        print(json.dumps({'research_routes': len(required), 'all_time_leader': all_time['rows'][0]['player_name'], 'franchises': len(franchises['rows'])}, indent=2))

    print('Historical NBA research lab contract passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
