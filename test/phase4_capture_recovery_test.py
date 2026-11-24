"""Synthetic Phase 4A source-qualified ingestion contract (not NBA corpus evidence)."""
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

from tools.build_historical_nba_canonical import initialize_schema
from tools.phase4_recover_capture_games import recover_capture_games, minutes


def rows(game_id="000001", date="NOV 01, 2025", bad=False):
    out = []
    for team_id, abbr, matchup, result, points, first in (
        ("100","AAA","AAA vs. BBB","W",10,1),
        ("200","BBB","BBB @ AAA","L",8,6),
    ):
        for offset in range(5):
            out.append({
                "GAME_ID":game_id,"GAME_DATE":date if not bad or offset else "NOV 02, 2025",
                "TEAM_ID":team_id,"TEAM_ABBREVIATION":abbr,"MATCHUP":matchup,
                "PLAYER_ID":str(first+offset),"PLAYER_NAME":"Player "+str(first+offset),
                "MIN":"12:30","PTS":points,"WL":result,
                "FGM":4,"FGA":8,"FG3M":1,"FG3A":2,"FTM":1,"FTA":2,
                "OREB":1,"DREB":2,"REB":3,"AST":1,"STL":0,"BLK":0,"TOV":1,"PF":1,
            })
    return out


class RecoveryTest(unittest.TestCase):
    def setUp(self):
        self.folder=tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root=Path(self.folder.name)
        self.database=self.root/"warehouse.sqlite"
        self.conn=sqlite3.connect(self.database)
        self.addCleanup(self.conn.close)
        initialize_schema(self.conn)
        for key,abbr,nba in (("team-a","AAA","100"),("team-b","BBB","200")):
            self.conn.execute("INSERT INTO canon_dim_team "
                              "(team_key,canonical_name,abbreviation,league_id,nba_team_id) "
                              "VALUES (?,?,?,?,?)",(key,abbr,abbr,"NBA",nba))
        for i in range(1,11):
            self.conn.execute("INSERT INTO canon_dim_player "
                              "(player_key,canonical_name,normalized_name,nba_id,source_count,identity_confidence) "
                              "VALUES (?,?,?,?,1,1)",("nba_"+str(i),"Player "+str(i),"player"+str(i),str(i)))
        self.conn.commit()
        self.capture=self.root/"nba_com/surfaces/players_boxscores_traditional/default/2025-26"
        self.capture.mkdir(parents=True)

    def write(self,data):
        (self.capture/"regular.json").write_text(json.dumps({
            "surface":"players_boxscores_traditional",
            "tables":[{"rows":data}]
        }))

    def test_recovery_is_source_qualified_and_idempotent(self):
        self.write(rows())
        preview=recover_capture_games(self.conn,self.root)
        self.assertEqual(preview["counts"]["qualified_missing_games"],1)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM canon_dim_game").fetchone()[0],0)
        result=recover_capture_games(self.conn,self.root,apply=True)
        self.conn.commit()
        self.assertEqual(result["counts"]["inserted_games"],1)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM canon_dim_game").fetchone()[0],1)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM canon_fact_team_game").fetchone()[0],2)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM canon_fact_player_game").fetchone()[0],10)
        row=self.conn.execute("SELECT game_date,home_score,away_score FROM canon_dim_game").fetchone()
        self.assertEqual(row,("2025-11-01",50,40))
        self.assertEqual(self.conn.execute("SELECT minutes FROM canon_fact_player_game LIMIT 1").fetchone()[0],12.5)
        repeat=recover_capture_games(self.conn,self.root,apply=True)
        self.assertEqual(repeat["counts"].get("inserted_games",0),0)
        self.assertEqual(repeat["counts"]["already_canonical"],1)

    def test_invalid_dates_cannot_create_games(self):
        self.write(rows(bad=True))
        outcome=recover_capture_games(self.conn,self.root,apply=True)
        self.assertEqual(outcome["counts"]["missing_or_conflicting_dates"],1)
        self.assertEqual(self.conn.execute("SELECT COUNT(*) FROM canon_dim_game").fetchone()[0],0)

    def test_unreconciled_team_is_not_guessed(self):
        data=rows()
        data[0]["TEAM_ID"]="999"
        self.write(data)
        report=recover_capture_games(self.conn,self.root)
        self.assertEqual(report["counts"]["unresolved_team_identity"],1)

    def test_incremental_index_publication_preserves_other_static_data(self):
        from tools.phase4_publish_recovered_games import refresh
        self.write(rows())
        self.conn.execute(
            "INSERT INTO canon_dim_game "
            "(game_key,nba_game_id,game_date,season_id,league_id,season_type,"
            "home_team_key,away_team_key,source_count) VALUES (?,?,?,?,?,?,?,?,?)",
            ("existing","000999","2025-10-22","2025-26","NBA","regular","team-a","team-b",1))
        self.conn.commit()
        (self.root/"games").mkdir()
        (self.root/"history").mkdir()
        (self.root/"manifest.json").write_text(json.dumps({
            "contract":"sports-terminal-static-nba-website-v5",
            "static_schema_version":5,"game_count":1}))
        (self.root/"games/index.json").write_text(json.dumps([{
            "game_key":"existing","nba_game_id":"000999",
            "season_id":"2025-26","season_type":"regular",
            "file":"games/detail/existing.json","box_score_available":False
        }]))
        (self.root/"seasons.json").write_text('[{"season_id":"2025-26","games":1}]')
        (self.root/"history/coverage.json").write_text("[]")
        marker=self.root/"nba_com/retain-me.json"
        marker.parent.mkdir(parents=True,exist_ok=True)
        marker.write_text('{"must_preserve":true}')
        recover_capture_games(self.conn,self.root,apply=True)
        self.conn.commit()
        preview=refresh(self.database,self.root,self.root/"backups",apply=False)
        self.assertEqual(preview["additions"],1)
        self.assertEqual(json.loads((self.root/"games/index.json").read_text()).__len__(),1)
        published=refresh(self.database,self.root,self.root/"backups",apply=True,details=False)
        self.assertEqual(published["additions"],1)
        index=json.loads((self.root/"games/index.json").read_text())
        self.assertEqual(len(index),2)
        self.assertEqual(next(r for r in index if r["game_key"]=="existing")["file"],
                         "games/detail/existing.json")
        self.assertTrue(marker.is_file())
        self.assertEqual(json.loads((self.root/"seasons.json").read_text())[0]["games"],2)

    def test_clock_minutes_parsed_only_for_minute_column(self):
        self.assertAlmostEqual(minutes("22:45"),22.75)
        self.assertIsNone(minutes("24:99"))


if __name__=="__main__":
    unittest.main()
