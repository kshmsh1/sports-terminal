import importlib.util
import sqlite3
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "build_historical_nba_canonical.py"
spec = importlib.util.spec_from_file_location("build_historical_nba_canonical", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


def test_normalize_full_year_range():
    assert module.normalize_season("2017-2018", source_key="gonzalo_all_time")[:3] == ("2017-18", 2017, 2018)
    assert module.normalize_season("1999-2000", source_key="gonzalo_all_time")[:3] == ("1999-00", 1999, 2000)


def test_build_player_games_accepts_game_reference_and_merges_basic_advanced():
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    module.initialize_schema(db)
    db.executescript(
        """
        CREATE TABLE historical_table_inventory(
          source_key TEXT,
          source_table TEXT,
          warehouse_table TEXT,
          row_count INTEGER,
          columns_json TEXT
        );
        CREATE TABLE src_gonzalo_all_time_nba_2017_2018_basic(
          __source_row INTEGER,
          game_reference TEXT,
          team TEXT,
          period TEXT,
          starter TEXT,
          player_name TEXT,
          player_reference TEXT,
          mp TEXT,
          trb TEXT,
          ast TEXT,
          stl TEXT,
          blk TEXT,
          tov TEXT,
          pf TEXT,
          pts TEXT
        );
        CREATE TABLE src_gonzalo_all_time_nba_2017_2018_advanced(
          __source_row INTEGER,
          game_reference TEXT,
          team TEXT,
          period TEXT,
          starter TEXT,
          player_name TEXT,
          player_reference TEXT,
          mp TEXT,
          ts TEXT,
          efg TEXT,
          usg TEXT,
          ortg TEXT,
          drtg TEXT,
          bpm TEXT
        );
        """
    )
    db.executemany(
        "INSERT INTO historical_table_inventory VALUES (?,?,?,?,?)",
        [
            ("gonzalo_all_time", "NBA_2017-2018_basic", "src_gonzalo_all_time_nba_2017_2018_basic", 1, "[]"),
            ("gonzalo_all_time", "NBA_2017-2018_advanced", "src_gonzalo_all_time_nba_2017_2018_advanced", 1, "[]"),
        ],
    )
    db.execute(
        "INSERT INTO canon_dim_team VALUES (?,?,?,?,?,?,?,?,?,?)",
        ("team_gsw", None, "Golden State Warriors", "GSW", "NBA", None, None, None, 1, "{}"),
    )
    db.execute(
        "INSERT INTO canon_dim_game VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        ("nba_game_0021700001", "0021700001", "2017-10-17", "2017-18", "NBA", "regular", "team_gsw", None, None, None, None, None, 1, "{}"),
    )
    db.execute(
        "INSERT INTO src_gonzalo_all_time_nba_2017_2018_basic VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (1, "201710170GSW", "HOU", "game", "True", "James Harden", "hardeja01", "36:24", "6", "11", "1", "0", "3", "2", "27"),
    )
    db.execute(
        "INSERT INTO src_gonzalo_all_time_nba_2017_2018_advanced VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (1, "201710170GSW", "HOU", "game", "True", "James Harden", "hardeja01", "36:24", ".545", ".522", "31.2", "117", "122", "6.1"),
    )
    count = module.build_player_games(db, {}, {"jamesharden": "player_harden"}, {}, {})
    assert count == 1
    row = db.execute(
        "SELECT source_game_id, game_key, season_id, season_type, pts, reb, ast, ts_pct, bpm FROM canon_fact_player_game"
    ).fetchone()
    assert tuple(row) == ("201710170GSW", "nba_game_0021700001", "2017-18", "regular", 27.0, 6.0, 11.0, 0.545, 6.1)


def test_build_player_games_inherits_playoff_season_type_from_date_home_match():
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    module.initialize_schema(db)
    db.executescript(
        """
        CREATE TABLE historical_table_inventory(
          source_key TEXT,
          source_table TEXT,
          warehouse_table TEXT,
          row_count INTEGER,
          columns_json TEXT
        );
        CREATE TABLE src_gonzalo_all_time_nba_2023_2024_basic(
          __source_row INTEGER, game_reference TEXT, team TEXT, period TEXT,
          player_name TEXT, player_reference TEXT, mp TEXT, trb TEXT, ast TEXT,
          stl TEXT, blk TEXT, tov TEXT, pf TEXT, pts TEXT
        );
        CREATE TABLE src_gonzalo_all_time_nba_2023_2024_advanced(
          __source_row INTEGER, game_reference TEXT, team TEXT, period TEXT,
          player_name TEXT, player_reference TEXT, mp TEXT, ts TEXT, efg TEXT,
          usg TEXT, ortg TEXT, drtg TEXT, bpm TEXT
        );
        """
    )
    db.executemany(
        "INSERT INTO historical_table_inventory VALUES (?,?,?,?,?)",
        [
            ("gonzalo_all_time", "NBA_2023-2024_basic", "src_gonzalo_all_time_nba_2023_2024_basic", 1, "[]"),
            ("gonzalo_all_time", "NBA_2023-2024_advanced", "src_gonzalo_all_time_nba_2023_2024_advanced", 1, "[]"),
        ],
    )
    db.execute(
        "INSERT INTO canon_dim_team VALUES (?,?,?,?,?,?,?,?,?,?)",
        ("team_bos", None, "Boston Celtics", "BOS", "NBA", None, None, None, 1, "{}"),
    )
    db.execute(
        "INSERT INTO canon_dim_game VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        ("nba_game_finals", "0042300405", "2024-06-17", "2023-24", "NBA", "playoffs", "team_bos", None, None, None, None, None, 1, "{}"),
    )
    db.execute(
        "INSERT INTO src_gonzalo_all_time_nba_2023_2024_basic VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (1, "202406170BOS", "DAL", "game", "Luka Doncic", "doncilu01", "43:23", "12", "5", "3", "0", "7", "3", "28"),
    )
    db.execute(
        "INSERT INTO src_gonzalo_all_time_nba_2023_2024_advanced VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (1, "202406170BOS", "DAL", "game", "Luka Doncic", "doncilu01", "43:23", ".515", ".520", "39.1", "86", "109", "2.3"),
    )
    count = module.build_player_games(db, {}, {"lukadoncic": "player_luka"}, {}, {})
    assert count == 1
    row = db.execute("SELECT game_key, season_type, game_date FROM canon_fact_player_game").fetchone()
    assert tuple(row) == ("nba_game_finals", "playoffs", "2024-06-17")


def test_build_teams_unifies_historical_abbreviations_under_stable_wyatt_id():
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    module.initialize_schema(db)
    db.executescript(
        """
        CREATE TABLE historical_table_inventory(
          source_key TEXT, source_table TEXT, warehouse_table TEXT,
          row_count INTEGER, columns_json TEXT
        );
        CREATE TABLE src_wyatt_team(id TEXT, full_name TEXT, abbreviation TEXT);
        CREATE TABLE src_wyatt_team_history(team_id TEXT, city TEXT, nickname TEXT);
        CREATE TABLE src_wyatt_game(
          team_id_home TEXT, team_abbreviation_home TEXT, team_name_home TEXT,
          team_id_away TEXT, team_abbreviation_away TEXT, team_name_away TEXT
        );
        """
    )
    db.executemany(
        "INSERT INTO historical_table_inventory VALUES (?,?,?,?,?)",
        [
            ("wyatt_nbadb", "team", "src_wyatt_team", 2, "[]"),
            ("wyatt_nbadb", "team_history", "src_wyatt_team_history", 1, "[]"),
            ("wyatt_nbadb", "game", "src_wyatt_game", 1, "[]"),
        ],
    )
    db.executemany(
        "INSERT INTO src_wyatt_team VALUES (?,?,?)",
        [
            ("1610612755", "Philadelphia 76ers", "PHI"),
            ("1610612738", "Boston Celtics", "BOS"),
        ],
    )
    db.execute(
        "INSERT INTO src_wyatt_team_history VALUES (?,?,?)",
        ("1610612755", "Syracuse", "Nationals"),
    )
    db.execute(
        "INSERT INTO src_wyatt_game VALUES (?,?,?,?,?,?)",
        ("1610612755", "SYR", "Syracuse Nationals", "1610612738", "BOS", "Boston Celtics"),
    )
    policy = {
        "sourcePriority": {"identity": ["wyatt_nbadb"]},
        "modernFranchiseAliases": {"PHI": "76ers", "SYR": "76ers", "BOS": "celtics"},
    }
    _, abbrs, _ = module.build_teams(db, policy)
    row = db.execute(
        "SELECT canonical_name,abbreviation FROM canon_dim_team WHERE nba_team_id='1610612755'"
    ).fetchone()
    assert tuple(row) == ("Philadelphia 76ers", "PHI")
    assert abbrs["PHI"] == "nba_team_1610612755"
    assert abbrs["SYR"] == "nba_team_1610612755"


def test_build_player_games_matches_cross_source_home_abbreviation_on_multi_game_date():
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    module.initialize_schema(db)
    db.executescript(
        """
        CREATE TABLE historical_table_inventory(
          source_key TEXT, source_table TEXT, warehouse_table TEXT,
          row_count INTEGER, columns_json TEXT
        );
        CREATE TABLE src_wyatt_game(
          game_id TEXT, team_abbreviation_home TEXT, team_abbreviation_away TEXT
        );
        CREATE TABLE src_gonzalo_all_time_nba_2019_2020_basic(
          __source_row INTEGER, game_reference TEXT, team TEXT, period TEXT,
          player_name TEXT, player_reference TEXT, mp TEXT, trb TEXT, ast TEXT,
          stl TEXT, blk TEXT, tov TEXT, pf TEXT, pts TEXT
        );
        CREATE TABLE src_gonzalo_all_time_nba_2019_2020_advanced(
          __source_row INTEGER, game_reference TEXT, team TEXT, period TEXT,
          player_name TEXT, player_reference TEXT, mp TEXT, ts TEXT, efg TEXT,
          usg TEXT, ortg TEXT, drtg TEXT, bpm TEXT
        );
        """
    )
    db.executemany(
        "INSERT INTO historical_table_inventory VALUES (?,?,?,?,?)",
        [
            ("wyatt_nbadb", "game", "src_wyatt_game", 2, "[]"),
            ("gonzalo_all_time", "NBA_2019-2020_basic", "src_gonzalo_all_time_nba_2019_2020_basic", 1, "[]"),
            ("gonzalo_all_time", "NBA_2019-2020_advanced", "src_gonzalo_all_time_nba_2019_2020_advanced", 1, "[]"),
        ],
    )
    db.executemany(
        "INSERT INTO canon_dim_team VALUES (?,?,?,?,?,?,?,?,?,?)",
        [
            ("team_phx", None, "Phoenix Suns", "PHX", "NBA", None, None, "1610612756", 1, "{}"),
            ("team_bos", None, "Boston Celtics", "BOS", "NBA", None, None, "1610612738", 1, "{}"),
        ],
    )
    db.executemany(
        "INSERT INTO canon_dim_game VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [
            ("nba_game_phx", "0021900001", "2020-01-01 00:00:00", "2019-20", "NBA", "regular", "team_phx", None, None, None, None, None, 1, "{}"),
            ("nba_game_bos", "0021900002", "2020-01-01 00:00:00", "2019-20", "NBA", "regular", "team_bos", None, None, None, None, None, 1, "{}"),
        ],
    )
    db.executemany(
        "INSERT INTO src_wyatt_game VALUES (?,?,?)",
        [
            ("0021900001", "PHX", "LAL"),
            ("0021900002", "BOS", "ORL"),
        ],
    )
    db.execute(
        "INSERT INTO src_gonzalo_all_time_nba_2019_2020_basic VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (1, "202001010PHO", "LAL", "game", "Example Player", "example01", "30:00", "5", "4", "1", "0", "2", "2", "20"),
    )
    db.execute(
        "INSERT INTO src_gonzalo_all_time_nba_2019_2020_advanced VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (1, "202001010PHO", "LAL", "game", "Example Player", "example01", "30:00", ".600", ".550", "25", "115", "110", "2.0"),
    )
    count = module.build_player_games(
        db,
        {},
        {"exampleplayer": "player_example"},
        {},
        {"PHO": "team_phx", "PHX": "team_phx", "BOS": "team_bos"},
        {"modernFranchiseAliases": {"PHO": "suns", "PHX": "suns"}},
    )
    assert count == 1
    row = db.execute(
        "SELECT game_key,season_type FROM canon_fact_player_game"
    ).fetchone()
    assert tuple(row) == ("nba_game_phx", "regular")


def test_unmatched_player_game_is_not_silently_regular():
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    module.initialize_schema(db)
    db.executescript(
        """
        CREATE TABLE historical_table_inventory(
          source_key TEXT, source_table TEXT, warehouse_table TEXT,
          row_count INTEGER, columns_json TEXT
        );
        CREATE TABLE src_basic(
          __source_row INTEGER, game_reference TEXT, team TEXT, period TEXT,
          player_name TEXT, player_reference TEXT, mp TEXT, trb TEXT, ast TEXT,
          stl TEXT, blk TEXT, tov TEXT, pf TEXT, pts TEXT
        );
        CREATE TABLE src_advanced(
          __source_row INTEGER, game_reference TEXT, team TEXT, period TEXT,
          player_name TEXT, player_reference TEXT, mp TEXT, ts TEXT, efg TEXT,
          usg TEXT, ortg TEXT, drtg TEXT, bpm TEXT
        );
        """
    )
    db.executemany(
        "INSERT INTO historical_table_inventory VALUES (?,?,?,?,?)",
        [
            ("gonzalo_all_time", "NBA_2017-2018_basic", "src_basic", 1, "[]"),
            ("gonzalo_all_time", "NBA_2017-2018_advanced", "src_advanced", 1, "[]"),
        ],
    )
    db.execute(
        "INSERT INTO src_basic VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (1, "201710010BOS", "BOS", "game", "Example Player", "example01", "10:00", "1", "1", "0", "0", "0", "1", "2"),
    )
    db.execute(
        "INSERT INTO src_advanced VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (1, "201710010BOS", "BOS", "game", "Example Player", "example01", "10:00", ".500", ".500", "10", "100", "100", "0"),
    )
    module.build_player_games(db, {}, {"exampleplayer": "player_example"}, {}, {})
    assert db.execute("SELECT season_type FROM canon_fact_player_game").fetchone()[0] == "unclassified"


def test_playoff_player_season_is_derived_from_matched_games():
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    module.initialize_schema(db)
    db.execute(
        """
        INSERT INTO canon_fact_player_game(
          fact_key,game_key,source_game_id,player_key,player_name,team_key,team_abbreviation,
          season_id,league_id,season_type,game_date,minutes,pts,reb,ast,stl,blk,tov,pf,
          source_key,source_table
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            "g1", "nba_game_1", "202405010BOS", "player_1", "Player One", "team_bos", "BOS",
            "2023-24", "NBA", "playoffs", "2024-05-01", 40, 25, 10, 5, 2, 1, 3, 2,
            "gonzalo_all_time", "NBA_2023-2024_advanced",
        ),
    )
    assert module.build_playoff_player_seasons_from_games(db) == 1
    row = db.execute(
        "SELECT season_type,games,minutes,pts,reb,ast FROM canon_fact_player_season"
    ).fetchone()
    assert tuple(row) == ("playoffs", 1.0, 40.0, 25.0, 10.0, 5.0)
