"""Fixture tests of independent NBA boxscore minute checks, without HTTP."""
import unittest
from tools.phase4_audit_pbp_vs_boxscore import check,duration

class BoxscoreAuditTest(unittest.TestCase):
    def test_iso_minutes(self):
        self.assertEqual(duration("PT25M01.00S"),1501)
        self.assertEqual(duration("25:01"),1501)
        self.assertIsNone(duration("unknown"))
    def test_player_time_cannot_exceed_official_boxscore(self):
        g={"nba_game_id":"0022500001","home_nba_id":"100","away_nba_id":"200",
           "home_score":2,"away_score":0}
        official={"game":{"gameId":"0022500001",
                "homeTeam":{"teamId":100,"score":2,"players":[{"personId":1,
                              "statistics":{"minutes":"PT10M00S"}}]},
                "awayTeam":{"teamId":200,"score":0,"players":[{"personId":2,
                              "statistics":{"minutes":"PT10M00S"}}]}}}
        # The validator requires ten on-court identities if actual reconstructed
        # stints are provided. The fixture tests a missing-ID fail-closed case.
        stint=[{"seconds":30,"home":frozenset(["p1"]),
                "away":frozenset(["p2"]),"points":(0,0)}]
        keys={"1":"p1","2":"p2"}
        self.assertIsNone(check(g,stint,official,keys))
        stint[0]["seconds"]=601
        self.assertEqual(check(g,stint,official,keys),
                         "reconstructed_minutes_exceed_boxscore")
        official["game"]["homeTeam"]["score"]=3
        self.assertEqual(check(g,stint,official,keys),"official_score_mismatch")

if __name__=="__main__":
    unittest.main()
