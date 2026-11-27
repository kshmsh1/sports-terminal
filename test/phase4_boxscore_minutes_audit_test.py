"""Fixture tests of independent NBA boxscore minute checks, without HTTP."""
import unittest
from tools.phase4_audit_pbp_vs_boxscore import check,duration

class BoxscoreAuditTest(unittest.TestCase):
    def test_iso_minutes(self):
        self.assertEqual(duration("PT25M01.00S"),1501)
        self.assertEqual(duration("25:01"),1501)
        self.assertIsNone(duration("unknown"))
    def test_official_starting_five_mismatch_rejected(self):
        g={"nba_game_id":"0022500001","home_nba_id":"100","away_nba_id":"200",
           "home_score":2,"away_score":0}
        home=[{"personId":i,"starter":True,
               "statistics":{"minutes":"PT12M00S"}} for i in range(1,6)]
        away=[{"personId":i,"starter":True,
               "statistics":{"minutes":"PT12M00S"}} for i in range(6,11)]
        box={"game":{"gameId":"0022500001",
             "homeTeam":{"teamId":100,"score":2,"players":home},
             "awayTeam":{"teamId":200,"score":0,"players":away}}}
        keys={str(i):"p"+str(i) for i in range(1,12)}
        stint=[{"period":1,"start":720,"end":700,"seconds":20,
                "home":frozenset("p"+str(i) for i in range(1,6)),
                "away":frozenset("p"+str(i) for i in range(6,11)),
                "points":(0,0)}]
        self.assertIsNone(check(g,stint,box,keys))
        stint[0]["home"]=frozenset(["p11","p2","p3","p4","p5"])
        self.assertEqual(check(g,stint,box,keys),
                         "official_starting_five_mismatch")

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
        stint[0]["seconds"]=603
        self.assertEqual(check(g,stint,official,keys),
                         "reconstructed_minutes_exceed_boxscore")
        official["game"]["homeTeam"]["score"]=3
        self.assertEqual(check(g,stint,official,keys),"official_score_mismatch")

if __name__=="__main__":
    unittest.main()
