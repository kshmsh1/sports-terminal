"""No-network contract tests for immutable NBA CDN play-by-play capture."""
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from tools.phase4_collect_nba_pbp import collect,verify


class PbpCaptureTests(unittest.TestCase):
    def test_only_matching_game_and_real_actions_accepted(self):
        obj={"game":{"gameId":"0022500001","actions":[
             {"actionNumber":1,"period":1,"clock":"PT12M00.00S"}]}}
        self.assertEqual(verify(obj,"0022500001"),1)
        with self.assertRaises(ValueError):
            verify(obj,"0022500002")
        with self.assertRaises(ValueError):
            verify({"game":{"gameId":"0022500001","actions":[]}},"0022500001")

    def test_dry_run_does_not_request_or_write_capture(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            db=root/"sample.sqlite"
            with sqlite3.connect(db) as conn:
                conn.execute("CREATE TABLE canon_dim_game "
                             "(nba_game_id TEXT,league_id TEXT,season_id TEXT,season_type TEXT)")
                conn.execute("INSERT INTO canon_dim_game VALUES "
                             "('0022500001','NBA','2025-26','regular')")
            out=root/"pbp"
            report=root/"report.json"
            result=collect(db,"2025-26","regular",out,report,fetch=False)
            self.assertEqual(result["planned_games"],1)
            self.assertEqual(result["counts"]["unattempted"],1)
            self.assertFalse(out.exists())
            self.assertEqual(json.loads(report.read_text())["contract"],
                             "arcside-nba-cdn-playbyplay-capture-v1")


if __name__=="__main__":
    unittest.main()
