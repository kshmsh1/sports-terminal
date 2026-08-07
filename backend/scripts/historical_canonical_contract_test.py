from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path


def create_inventory(db: sqlite3.Connection) -> None:
    db.executescript(
        """
        CREATE TABLE historical_source_registry(
          source_key TEXT PRIMARY KEY, label TEXT, row_count INTEGER NOT NULL, table_count INTEGER NOT NULL,
          file_count INTEGER NOT NULL DEFAULT 1, metadata_json TEXT NOT NULL DEFAULT '{}'
        );
        CREATE TABLE historical_table_inventory(
          source_key TEXT NOT NULL, source_file TEXT NOT NULL, source_table TEXT NOT NULL,
          warehouse_table TEXT NOT NULL UNIQUE, domain TEXT NOT NULL DEFAULT 'other', grain TEXT NOT NULL DEFAULT 'source_native',
          row_count INTEGER NOT NULL, column_count INTEGER NOT NULL, columns_json TEXT NOT NULL,
          season_column TEXT, min_season TEXT, max_season TEXT, imported_at TEXT NOT NULL DEFAULT 'test',
          PRIMARY KEY(source_key, source_file, source_table)
        );
        INSERT INTO historical_source_registry(source_key,label,row_count,table_count) VALUES
          ('wyatt_nbadb','Wyatt',0,0),('sumitro_bref_history','Sumitro',0,0),('gonzalo_all_time','Gonzalo',0,0);
        """
    )


def register(db: sqlite3.Connection, source: str, source_table: str, warehouse_table: str) -> None:
    info = db.execute(f'PRAGMA table_info("{warehouse_table}")').fetchall()
    columns = [{"name": row[1], "declaredType": row[2]} for row in info]
    count = int(db.execute(f'SELECT COUNT(*) FROM "{warehouse_table}"').fetchone()[0])
    db.execute(
        "INSERT INTO historical_table_inventory(source_key,source_file,source_table,warehouse_table,row_count,column_count,columns_json) VALUES (?,?,?,?,?,?,?)",
        (source, f"{source_table}.test", source_table, warehouse_table, count, len(columns), json.dumps(columns)),
    )
    db.execute("UPDATE historical_source_registry SET row_count=row_count+?, table_count=table_count+1 WHERE source_key=?", (count, source))


def seed_sources(db: sqlite3.Connection) -> None:
    db.executescript(
        """
        CREATE TABLE w_player(id TEXT, full_name TEXT);
        INSERT INTO w_player VALUES ('100','Example Star'),('200','Other Player');
        CREATE TABLE w_common(person_id TEXT, display_first_last TEXT, birthdate TEXT, from_year INTEGER, to_year INTEGER, position TEXT);
        INSERT INTO w_common VALUES ('100','Example Star','1995-06-01',2016,2026,'G'),('200','Other Player','1994-01-02',2015,2026,'F');
        CREATE TABLE w_team(team_id TEXT, full_name TEXT, abbreviation TEXT);
        INSERT INTO w_team VALUES ('10','Example City Comets','EXC'),('20','Other City Owls','OTH');
        CREATE TABLE w_game(
          season_id TEXT, game_id TEXT, game_date TEXT,
          team_id_home TEXT, team_abbreviation_home TEXT, team_id_away TEXT, team_abbreviation_away TEXT,
          pts_home REAL, pts_away REAL, fgm_home REAL, fga_home REAL, fgm_away REAL, fga_away REAL
        );
        INSERT INTO w_game VALUES ('22023','G001','2024-01-03','10','EXC','20','OTH',110,101,42,84,39,86);
        CREATE TABLE w_pbp(
          game_id TEXT,eventnum INTEGER,period INTEGER,pctimestring TEXT,
          homedescription TEXT,neutraldescription TEXT,visitordescription TEXT,score TEXT,scoremargin TEXT,
          player1_id TEXT,player2_id TEXT,player3_id TEXT
        );
        INSERT INTO w_pbp VALUES ('G001',1,1,'12:00','Jump ball','','','0 - 0','0','100','200','');

        CREATE TABLE s_career(player_id TEXT, player TEXT, birth_year INTEGER);
        INSERT INTO s_career VALUES ('exampl01','Example Star',1995),('other01','Other Player',1994);
        CREATE TABLE s_season_info(player_id TEXT,player TEXT,season INTEGER,lg TEXT,tm TEXT,pos TEXT,age REAL);
        INSERT INTO s_season_info VALUES ('exampl01','Example Star',2024,'NBA','EXC','G',28),('other01','Other Player',2024,'NBA','OTH','F',29);
        CREATE TABLE s_totals(player_id TEXT,player TEXT,season INTEGER,lg TEXT,tm TEXT,pos TEXT,age REAL,g REAL,mp REAL,fg REAL,fga REAL,ft REAL,fta REAL,trb REAL,ast REAL,stl REAL,blk REAL,tov REAL,pf REAL,pts REAL);
        INSERT INTO s_totals VALUES
          ('exampl01','Example Star',2024,'NBA','EXC','G',28,80,2800,800,1600,400,500,500,600,120,40,200,150,2400),
          ('other01','Other Player',2024,'NBA','OTH','F',29,78,2500,600,1300,300,400,700,300,90,80,160,200,1800);
        CREATE TABLE s_advanced(player_id TEXT,player TEXT,season INTEGER,lg TEXT,tm TEXT,per REAL,ts_percent REAL,ws REAL,ws_per_48 REAL,obpm REAL,dbpm REAL,bpm REAL,vorp REAL);
        INSERT INTO s_advanced VALUES ('exampl01','Example Star',2024,'NBA','EXC',25.0,.625,12.0,.205,6.0,1.0,7.0,6.5),('other01','Other Player',2024,'NBA','OTH',18.0,.570,7.0,.140,2.0,0.0,2.0,3.0);
        CREATE TABLE s_team_abbrev(tm TEXT, team TEXT);
        INSERT INTO s_team_abbrev VALUES ('EXC','Example City Comets'),('OTH','Other City Owls');
        CREATE TABLE s_team_totals(season INTEGER,lg TEXT,tm TEXT,team TEXT,g REAL,w REAL,l REAL,pts REAL);
        INSERT INTO s_team_totals VALUES (2024,'NBA','EXC','Example City Comets',82,55,27,9200),(2024,'NBA','OTH','Other City Owls',82,41,41,8700);
        CREATE TABLE s_team_summaries(season INTEGER,lg TEXT,tm TEXT,team TEXT,g REAL,w REAL,l REAL,srs REAL);
        INSERT INTO s_team_summaries VALUES (2024,'NBA','EXC','Example City Comets',82,55,27,5.2),(2024,'NBA','OTH','Other City Owls',82,41,41,.1);
        CREATE TABLE s_awards(player_id TEXT,player TEXT,season INTEGER,award TEXT,rank INTEGER,share REAL);
        INSERT INTO s_awards VALUES ('exampl01','Example Star',2024,'MVP',1,.71);
        CREATE TABLE s_eos(player_id TEXT,player TEXT,season INTEGER,type TEXT,rank INTEGER);
        INSERT INTO s_eos VALUES ('exampl01','Example Star',2024,'All-NBA First Team',1);
        CREATE TABLE s_eos_vote(player_id TEXT,player TEXT,season INTEGER,type TEXT,rank INTEGER);
        INSERT INTO s_eos_vote VALUES ('exampl01','Example Star',2024,'All-NBA',1);
        CREATE TABLE s_allstar(player_id TEXT,player TEXT,season INTEGER,team TEXT);
        INSERT INTO s_allstar VALUES ('exampl01','Example Star',2024,'East');
        CREATE TABLE s_draft(player_id TEXT,player TEXT,season INTEGER,round INTEGER,pick INTEGER,tm TEXT);
        INSERT INTO s_draft VALUES ('exampl01','Example Star',2016,1,3,'EXC');

        CREATE TABLE g_totals(player TEXT,season INTEGER,tm TEXT,g REAL,mp REAL,pts REAL,trb REAL,ast REAL);
        INSERT INTO g_totals VALUES ('Example Star',2024,'EXC',80,2800,2390,500,600);
        CREATE TABLE g_adv_game(__source_row INTEGER,player TEXT,date TEXT,game_id TEXT,team TEXT,opponent TEXT,mp REAL,pts REAL,trb REAL,ast REAL,ts_percent REAL,bpm REAL);
        INSERT INTO g_adv_game VALUES (1,'Example Star','2024-01-03','G001','EXC','OTH',35,32,8,9,.650,8.0);
        """
    )
    mapping = [
        ("wyatt_nbadb", "player", "w_player"),
        ("wyatt_nbadb", "common_player_info", "w_common"),
        ("wyatt_nbadb", "team", "w_team"),
        ("wyatt_nbadb", "game", "w_game"),
        ("wyatt_nbadb", "play_by_play", "w_pbp"),
        ("sumitro_bref_history", "Player Career Info", "s_career"),
        ("sumitro_bref_history", "Player Season Info", "s_season_info"),
        ("sumitro_bref_history", "Player Totals", "s_totals"),
        ("sumitro_bref_history", "Advanced", "s_advanced"),
        ("sumitro_bref_history", "Team Abbrev", "s_team_abbrev"),
        ("sumitro_bref_history", "Team Totals", "s_team_totals"),
        ("sumitro_bref_history", "Team Summaries", "s_team_summaries"),
        ("sumitro_bref_history", "Player Award Shares", "s_awards"),
        ("sumitro_bref_history", "End of Season Teams", "s_eos"),
        ("sumitro_bref_history", "End of Season Teams (Voting)", "s_eos_vote"),
        ("sumitro_bref_history", "All-Star Selections", "s_allstar"),
        ("sumitro_bref_history", "Draft Pick History", "s_draft"),
        ("gonzalo_all_time", "totals_stats", "g_totals"),
        ("gonzalo_all_time", "NBA_2023-2024_advanced", "g_adv_game"),
    ]
    for item in mapping:
        register(db, *item)
    db.commit()


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    canonicalizer = repo_root / "tools" / "build_historical_nba_canonical.py"
    policy = repo_root / "assets" / "data" / "nba" / "metadata" / "historical_canonical_policy.json"
    with tempfile.TemporaryDirectory(prefix="sports-terminal-canonical-") as temp:
        root = Path(temp)
        database = root / "nba_history.sqlite"
        report = root / "report.json"
        db = sqlite3.connect(database)
        try:
            create_inventory(db)
            seed_sources(db)
        finally:
            db.close()
        result = subprocess.run(
            [sys.executable, str(canonicalizer), "--database", str(database), "--policy", str(policy), "--report", str(report)],
            cwd=repo_root,
            text=True,
            capture_output=True,
        )
        if result.returncode != 0:
            print(result.stdout)
            print(result.stderr, file=sys.stderr)
            raise AssertionError(f"canonicalizer exited {result.returncode}")
        payload = json.loads(report.read_text(encoding="utf-8"))
        assert payload["status"] == "pass", payload
        assert payload["counts"]["players"] == 2, payload
        assert payload["counts"]["playerSeasons"] >= 2, payload
        assert payload["counts"]["games"] == 1, payload
        assert payload["counts"]["teamGames"] == 2, payload
        assert payload["counts"]["playerGames"] == 1, payload
        assert payload["counts"]["playByPlayView"] is True, payload
        assert payload["counts"]["conflicts"] >= 1, payload

        db = sqlite3.connect(database)
        try:
            star = db.execute("SELECT player_key,nba_id,bref_id,canonical_name FROM canon_dim_player WHERE canonical_name='Example Star'").fetchone()
            assert star is not None and star[1] == "100" and star[2] == "exampl01", star
            player_key = star[0]
            season = db.execute("SELECT season_id,pts,primary_source,source_count FROM canon_fact_player_season WHERE player_key=? AND season_id='2023-24'", (player_key,)).fetchone()
            assert season is not None, season
            assert season[1] == 2400, season
            assert season[2] == "sumitro_bref_history", season
            assert season[3] >= 2, season
            game = db.execute("SELECT season_id,season_type,home_score,away_score FROM canon_dim_game WHERE nba_game_id='G001'").fetchone()
            assert game == ("2023-24", "regular", 110.0, 101.0), game
            event = db.execute("SELECT game_key,player1_key,description FROM canon_fact_play_by_play LIMIT 1").fetchone()
            assert event is not None and event[1] == player_key and "Jump ball" in event[2], event
            conflict = db.execute("SELECT selected_source,alternate_source,field_name FROM canon_conflicts WHERE entity_type='player_season' AND field_name='pts'").fetchone()
            assert conflict is not None and conflict[0] == "sumitro_bref_history" and conflict[1] == "gonzalo_all_time", conflict
        finally:
            db.close()

        os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(database)
        sys.path.insert(0, str(repo_root / "backend"))
        from app import historical_nba_api  # noqa: PLC0415

        status = historical_nba_api.history_status()
        assert status["canonical_ready"] is True, status
        seasons = historical_nba_api.history_seasons(league="NBA")
        assert any(row["season_id"] == "2023-24" for row in seasons["rows"]), seasons
        board = historical_nba_api.history_leaderboard(
            season="2023-24", metric="pts", basis="per_game", league="NBA", season_type="regular",
            team="", min_games=0, min_minutes=0, offset=0, limit=100,
        )
        assert board["rows"] and board["rows"][0]["player_name"] == "Example Star", board
        assert abs(board["rows"][0]["metric_value"] - 30.0) < 1e-9, board
        pbp = historical_nba_api.history_game_play_by_play("nba_game_g001", offset=0, limit=100)
        assert pbp["matched_rows"] == 1, pbp

    print("Historical NBA canonical platform contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
