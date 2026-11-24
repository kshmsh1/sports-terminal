"""Synthetic audit regression; not evidence of historical NBA coverage."""
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from tools.phase4_warehouse_audit import audit


class WarehouseAuditTest(unittest.TestCase):
    def test_detects_unpublished_game_and_missing_detail(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            database = base / "test.sqlite"
            with sqlite3.connect(database) as db:
                db.executescript("""
                CREATE TABLE canon_dim_game(game_key TEXT, nba_game_id TEXT, season_id TEXT, season_type TEXT, game_date TEXT, league_id TEXT);
                CREATE TABLE canon_fact_player_game(game_key TEXT, league_id TEXT);
                CREATE TABLE canon_fact_team_game(game_key TEXT, league_id TEXT);
                INSERT INTO canon_dim_game VALUES
                  ('game-a','0001','2025-26','regular','2025-10-01','NBA'),
                  ('game-b','0002','2025-26','regular','2025-10-02','NBA');
                INSERT INTO canon_fact_player_game VALUES ('game-a','NBA'),('game-b','NBA');
                """)
            (base / "games").mkdir()
            (base / "manifest.json").write_text(json.dumps({"contract":"sports-terminal-static-nba-website-v5","static_schema_version":5}))
            (base / "games/index.json").write_text(json.dumps([
                {"game_key":"game-a","nba_game_id":"0001","season_id":"2025-26","season_type":"regular","file":"games/missing.json","box_score_available":True}
            ]))
            captured = base / "nba_com/surfaces/players_boxscores_traditional/default/2025-26"
            captured.mkdir(parents=True)
            (captured / "regular.json").write_text(json.dumps({"tables":[{"rows":[{"GAME_ID":"0001"},{"GAME_ID":"0002"},{"GAME_ID":"0003"}]}]}))
            result = audit(database, base)
            group = result["gameCoverage"][0]
            self.assertEqual(group["canonical_missing_from_index"], 1)
            self.assertEqual(group["missing_or_unsafe_detail_file"], 1)
            self.assertEqual(result["capturedTraditionalGameLogs"][0]["missingFromPublishedIndex"], 2)
            self.assertEqual(result["capturedTraditionalGameLogs"][0]["missingFromCanonical"], 1)


if __name__ == "__main__":
    unittest.main()
