"""Synthetic source-schema tests for official NBA Live Q1 lineage."""
import unittest
from tools.phase4_materialize_live_nba_pbp import native_q1


def game_source():
    game={"nba_game_id":"0022500001","home_nba_id":"100","away_nba_id":"200",
          "home_score":2,"away_score":0,"season":"2025-26","segment":"regular",
          "home_abbr":"AAA","away_abbr":"BBB"}
    players={str(i):"p"+str(i) for i in range(1,12)}
    home=[{"personId":i,"starter":i<=5,
           "statistics":{"minutes":"PT02M00S" if i==1 else
                             "PT10M00S" if i==11 else "PT12M00S"}} for i in [1,2,3,4,5,11]]
    away=[{"personId":i,"starter":True,"statistics":{"minutes":"PT12M00S"}} for i in range(6,11)]
    box={"game":{"gameId":"0022500001",
                 "homeTeam":{"teamId":100,"score":2,"players":home},
                 "awayTeam":{"teamId":200,"score":0,"players":away}}}
    actions=[
        {"actionNumber":1,"orderNumber":1,"period":1,"clock":"PT12M00.00S",
         "actionType":"period","subType":"start","scoreHome":"0","scoreAway":"0"},
        {"actionNumber":2,"orderNumber":2,"period":1,"clock":"PT11M30.00S",
         "actionType":"2pt","personId":2,"teamId":100,
         "scoreHome":"2","scoreAway":"0"},
        {"actionNumber":3,"orderNumber":3,"period":1,"clock":"PT10M00.00S",
         "actionType":"substitution","subType":"out","personId":1,"teamId":100,
         "scoreHome":"2","scoreAway":"0"},
        {"actionNumber":4,"orderNumber":4,"period":1,"clock":"PT10M00.00S",
         "actionType":"substitution","subType":"in","personId":11,"teamId":100,
         "scoreHome":"2","scoreAway":"0"},
        {"actionNumber":5,"orderNumber":5,"period":1,"clock":"PT00M00.00S",
         "actionType":"period","subType":"end","scoreHome":"2","scoreAway":"0"},
    ]
    return game,players,box,{"game":{"gameId":"0022500001","actions":actions}}


class LiveQ1Tests(unittest.TestCase):
    def test_verified_q1_stints(self):
        game,players,box,pbp=game_source()
        stints,rosters,reasons=native_q1(pbp,box,game,players)
        self.assertEqual(reasons["periods_verified"],1)
        self.assertEqual(reasons["score_verified"],1)
        self.assertEqual(sum(s["seconds"] for s in stints),720)
        self.assertEqual(sum(s["points"][1] for s in stints),2)
        self.assertEqual(len(rosters["home"]),6)

    def test_unpaired_substitution_fails_closed(self):
        game,players,box,pbp=game_source()
        pbp["game"]["actions"]=[a for a in pbp["game"]["actions"] if a["actionNumber"]!=4]
        stints,_,reason=native_q1(pbp,box,game,players)
        self.assertEqual(stints,[])
        self.assertEqual(reason["rejected"],"contradictory_substitution")

    def test_official_score_conflict_fails_closed(self):
        game,players,box,pbp=game_source()
        box["game"]["homeTeam"]["score"]=3
        stints,_,reason=native_q1(pbp,box,game,players)
        self.assertEqual(stints,[])
        self.assertEqual(reason["rejected"],"boxscore_final_score_mismatch")


if __name__=="__main__":
    unittest.main()
