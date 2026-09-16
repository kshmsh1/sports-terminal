from __future__ import annotations

import importlib.util
import sqlite3
from pathlib import Path


def _module():
    path = Path(__file__).resolve().parents[1] / "tools/materialize_static_nba_game_details.py"
    spec = importlib.util.spec_from_file_location("materialize_static_nba_game_details", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_optional_league_filter_supports_legacy_team_game_schema() -> None:
    module = _module()
    db = sqlite3.connect(":memory:")
    db.execute("CREATE TABLE canon_fact_team_game (game_key TEXT, team_key TEXT)")
    db.execute(
        "CREATE TABLE canon_fact_player_game (game_key TEXT, player_key TEXT, league_id TEXT)"
    )

    team_columns = module._columns(db, "canon_fact_team_game")
    player_columns = module._columns(db, "canon_fact_player_game")

    assert module._league_where("tg", team_columns) == ""
    assert module._league_where("pg", player_columns) == " AND pg.league_id='NBA'"

    db.execute("INSERT INTO canon_fact_team_game VALUES ('g1', 't1')")
    count = db.execute(
        "SELECT game_key,COUNT(*) FROM canon_fact_team_game tg "
        f"WHERE 1=1{module._league_where('tg', team_columns)} GROUP BY game_key"
    ).fetchone()
    assert count == ("g1", 1)
