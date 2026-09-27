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
