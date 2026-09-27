import importlib.util
import sqlite3
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "tools" / "import_historical_nba_sources.py"
spec = importlib.util.spec_from_file_location("import_historical_nba_sources", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


def test_normalize_inventory_season_full_range():
    assert module.normalize_inventory_season("2017-2018") == "2017-18"
    assert module.normalize_inventory_season("1999-2000") == "1999-00"
    assert module.normalize_inventory_season("2017-18") == "2017-18"


def test_season_bounds_uses_canonical_strings():
    db = sqlite3.connect(":memory:")
    db.execute("CREATE TABLE sample(season TEXT)")
    db.executemany("INSERT INTO sample VALUES (?)", [("2017-2018",), ("2018-2019",), ("1999-2000",)])
    assert module.season_bounds(db, "sample", "season") == ("1999-00", "2018-19")
