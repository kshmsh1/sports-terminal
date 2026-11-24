"""Synthetic Phase 4B event-level reconstruction tests, not historical coverage."""
import unittest
from tools.phase4_materialize_with_without import process_game, summarize_games


def event(n, clock, type_=1, p1=None, t1=None, p2=None, t2=None, score=None):
    return {
        "eventnum":n,"eventmsgtype":type_,"period":1,"pctimestring":clock,
        "player1_id":p1,"player1_team_id":t1,
        "player2_id":p2,"player2_team_id":t2,
        "player3_id":None,"player3_team_id":None,"score":score,
    }


def fixture():
    game={
        "game_key":"g1","season":"2020-21","segment":"regular",
        "home_nba_id":"100","away_nba_id":"200",
        "home_abbr":"AAA","away_abbr":"BBB",
        "home_score":4,"away_score":2,
    }
    players={str(i):"nba_"+str(i) for i in range(1,12)}
    events=[event(1,"12:00",12)]
    for i in range(1,6):
        events.append(event(i+1,"11:45",1,str(i),"100",str(i+5),"200",
                            score="0 - 0"))
    events.extend([
        event(7,"10:00",1,"6","200",score="2 - 0"),
        event(8,"09:00",8,"1","100","11","100"),
        event(9,"08:00",1,"11","100",score="2 - 2"),
        event(10,"00:00",1,"2","100",score="2 - 4"),
    ])
    return game,players,events


class LineupTest(unittest.TestCase):
    def test_verified_stints_and_per36_scores(self):
        game,players,events=fixture()
        stints,rosters,report=process_game(events,game,players)
        self.assertEqual(report["periods_verified"],1)
        self.assertEqual(sum(s["seconds"] for s in stints),720)
        self.assertEqual(report["score_verified"],1)
        rows,_,_=summarize_games([(game,stints,rosters,report)])
        splits=rows[("2020-21","regular")]
        pair=next(r for r in splits if r["player_id"]=="nba_2" and r["teammate_id"]=="nba_1")
        self.assertEqual(pair["minutes_with"],2.75)
        self.assertEqual(pair["minutes_without"],9)
        self.assertIn("pts",pair["with"])
        self.assertIn("plus_minus",pair["without"])

    def test_late_lineup_evidence_counts_only_later_minutes(self):
        game,players,events=fixture()
        for e in events:
            if e["eventnum"]==6:
                e["pctimestring"]="10:30"
        stints,rosters,report=process_game(events,game,players)
        self.assertEqual(report["periods_verified"],1)
        self.assertEqual(report["partially_observed_periods"],1)
        self.assertEqual(sum(s["seconds"] for s in stints),630)
        rows,_,_=summarize_games([(game,stints,rosters,report)])
        pair=next(r for r in rows[("2020-21","regular")]
                  if r["player_id"]=="nba_2" and r["teammate_id"]=="nba_1")
        self.assertEqual(pair["minutes_with"],1.5)
        self.assertEqual(pair["minutes_without"],9)

    def test_missing_starting_five_is_rejected(self):
        game,players,events=fixture()
        events=[e for e in events if e["eventnum"]!=6]
        stints,_,report=process_game(events,game,players)
        self.assertEqual(stints,[])
        self.assertGreater(report["no_fully_evidenced_interval"],0)

    def test_invalid_substitution_fails_closed(self):
        game,players,events=fixture()
        events[7]["player2_id"]="3"
        stints,_,report=process_game(events,game,players)
        self.assertEqual(stints,[])
        self.assertEqual(report["invalid_substitution"],1)

    def test_uncertified_score_never_becomes_zero_point_stat(self):
        game,players,events=fixture()
        game["home_score"]=99
        stints,rosters,report=process_game(events,game,players)
        self.assertEqual(report["score_verified"],0)
        self.assertTrue(stints)
        rows,_,_=summarize_games([(game,stints,rosters,report)])
        pair=next(r for r in rows[("2020-21","regular")] if r["player_id"]=="nba_2" and r["teammate_id"]=="nba_1")
        self.assertEqual(pair["with"],{})
        self.assertEqual(pair["without"],{})


if __name__=="__main__":
    unittest.main()
