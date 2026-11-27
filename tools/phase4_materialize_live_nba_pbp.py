"""Source-qualified NBA Live V3 opening-quarter lineup research materializer.

Uses NBA Live play-by-play actions and independently published NBA player
boxscores. Only Q1 is eligible: each starting five comes directly from the
official starter flags. Other periods require independently certified opening
lineups and are intentionally excluded. Full-season estimates, possession
stats, and individual player-stat splits are NOT fabricated.

Preview is the default. --publish writes only certified research-level partial
split records. Existing unrelated lineups are never overwritten.
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sqlite3
from pathlib import Path

try:
    from tools.phase4_materialize_with_without import (
        CONTRACT,DEFAULT_DB,DEFAULT_STATIC,atomic_json,ident,
        load_game_catalog,player_identity_catalog,summarize_games
    )
    from tools.phase4_audit_pbp_vs_boxscore import check
except ModuleNotFoundError:
    from phase4_materialize_with_without import (
        CONTRACT,DEFAULT_DB,DEFAULT_STATIC,atomic_json,ident,
        load_game_catalog,player_identity_catalog,summarize_games
    )
    from phase4_audit_pbp_vs_boxscore import check


def clock_seconds(raw):
    match=re.fullmatch(r"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?",str(raw or ""))
    if not match:
        return None
    return 3600*int(match.group(1) or 0)+60*int(match.group(2) or 0)+float(match.group(3) or 0)


def validated_starters(box,game,players):
    doc=box.get("game") if isinstance(box,dict) else None
    if not isinstance(doc,dict) or ident(doc.get("gameId"))!=ident(game["nba_game_id"]):
        return None,None,"invalid_boxscore_game_id"
    on={};rosters={}
    for side in ("home","away"):
        team=doc.get(side+"Team")
        if not isinstance(team,dict) or ident(team.get("teamId"))!=ident(game[side+"_nba_id"]):
            return None,None,"invalid_boxscore_team_id"
        if team.get("score") is None or int(team["score"])!=int(game[side+"_score"]):
            return None,None,"boxscore_final_score_mismatch"
        roster=team.get("players")
        if not isinstance(roster,list):
            return None,None,"missing_player_roster"
        mapped=set();starter=set()
        for row in roster:
            if not isinstance(row,dict):continue
            key=players.get(ident(row.get("personId")))
            if not key:continue
            mapped.add(key)
            if str(row.get("starter")).lower() in ("true","1"):
                starter.add(key)
        if len(starter)!=5 or len(mapped)<5:
            return None,None,"starting_five_not_certified"
        on[side]=starter
        rosters[side]=mapped
    if on["home"] & on["away"]:
        return None,None,"overlapping_team_identity"
    return on,rosters,None


def parse_score(action):
    values=[]
    for key in ("scoreAway","scoreHome"):
        value=action.get(key)
        if value in (None,""):
            return None
        try:
            parsed=int(value)
        except (TypeError,ValueError):
            return None
        if parsed<0:return None
        values.append(parsed)
    return tuple(values)


def native_q1(pbp,box,game,players):
    on,rosters,error=validated_starters(box,game,players)
    if error:return [],{},{"rejected":error}
    doc=pbp.get("game") if isinstance(pbp,dict) else None
    if not isinstance(doc,dict) or ident(doc.get("gameId"))!=ident(game["nba_game_id"]):
        return [],rosters,{"rejected":"invalid_pbp_game_id"}
    actions=doc.get("actions")
    if not isinstance(actions,list) or not actions:
        return [],rosters,{"rejected":"empty_pbp"}
    if any(not isinstance(a,dict) or not isinstance(a.get("actionNumber"),int) for a in actions):
        return [],rosters,{"rejected":"invalid_event_sequence"}
    try:
        actions=sorted(actions,key=lambda a:int(a.get("orderNumber",a["actionNumber"])))
    except (TypeError,ValueError):
        return [],rosters,{"rejected":"invalid_event_order"}
    if len({a["actionNumber"] for a in actions})!=len(actions):
        return [],rosters,{"rejected":"duplicate_action_number"}
    first=[a for a in actions if a.get("period")==1]
    if not first:return [],rosters,{"rejected":"missing_q1"}
    clocks=[clock_seconds(a.get("clock")) for a in first]
    if any(x is None or x<0 or x>720 for x in clocks):
        return [],rosters,{"rejected":"invalid_clock"}
    if any(a<b for a,b in zip(clocks,clocks[1:])):
        return [],rosters,{"rejected":"clock_reversal"}
    # Check complete source final score independently, not just the first period.
    full_scores=[parse_score(a) for a in actions]
    final=next((score for score in reversed(full_scores) if score is not None),None)
    if final!=(int(game["away_score"]),int(game["home_score"])):
        return [],rosters,{"rejected":"full_game_score_mismatch"}
    sides={ident(game[side+"_nba_id"]):side for side in ("home","away")}
    grouped=[]
    for a,t in zip(first,clocks):
        if not grouped or grouped[-1][0]!=t:
            grouped.append((t,[]))
        grouped[-1][1].append(a)
    stints=[]
    last=720.0
    previous=(0,0)
    ambiguous_score=False
    for t,group in grouped:
        if last>t:
            stints.append({"period":1,"start":last,"end":t,"seconds":last-t,
                           "home":frozenset(on["home"]),"away":frozenset(on["away"]),
                           "points":(0,0)})
        last=t
        scored=[parse_score(a) for a in group]
        values=[v for v in scored if v is not None]
        current=values[-1] if values else previous
        diff=(current[0]-previous[0],current[1]-previous[1])
        if any(x<0 or x>4 for x in diff) or (diff[0] and diff[1]):
            return [],rosters,{"rejected":"invalid_scoring_progression"}
        subs=[a for a in group if str(a.get("actionType") or "").lower()=="substitution"]
        if any(diff):
            if subs:
                ambiguous_score=True
            else:
                stints.append({"period":1,"start":t,"end":t,"seconds":0,
                               "home":frozenset(on["home"]),"away":frozenset(on["away"]),
                               "points":diff})
        previous=current
        for side in ("home","away"):
            out=set();incoming=set()
            for a in subs:
                if sides.get(ident(a.get("teamId")))!=side:continue
                key=players.get(ident(a.get("personId")))
                subtype=str(a.get("subType") or "").strip().lower()
                if not key or subtype not in ("in","out"):
                    return [],rosters,{"rejected":"ambiguous_substitution"}
                if subtype=="out":out.add(key)
                else:incoming.add(key)
            if out or incoming:
                if (len(out)!=len(incoming) or not out.issubset(on[side])
                        or incoming & on[side] or out & incoming):
                    return [],rosters,{"rejected":"contradictory_substitution"}
                revised=(on[side]-out)|incoming
                if len(revised)!=5:
                    return [],rosters,{"rejected":"lineup_size_violation"}
                on[side]=revised
        for a in subs:
            if ident(a.get("teamId")) not in sides:
                return [],rosters,{"rejected":"unknown_substitution_team"}
    if not stints or not any(s["seconds"]>0 for s in stints):
        return [],rosters,{"rejected":"no_verified_interval"}
    independent=check(game,stints,box,players)
    if independent:
        return [],rosters,{"rejected":"official_"+independent}
    return stints,rosters,{"periods_verified":1,
                           "score_verified":int(not ambiguous_score),
                           "partial_q1":1,
                           "verified_seconds":sum(s["seconds"] for s in stints)}


def materialize(db,static,season,segment):
    db.row_factory=sqlite3.Row
    games=[g for g in load_game_catalog(db,season).values() if g["segment"]==segment]
    players=player_identity_catalog(db)
    counts=collections.Counter()
    samples=collections.defaultdict(list)
    accepted=[]
    for game in games:
        gid=str(game["nba_game_id"]).zfill(10)
        base=static/"nba_com/pbp_live"
        pbp=base/"pbp"/season/segment/(gid+".json")
        box=base/"boxscore"/season/segment/(gid+".json")
        if not pbp.is_file() or not box.is_file():
            counts["missing_source_pair"]+=1
            continue
        counts["source_pairs_seen"]+=1
        try:
            stints,rosters,reasons=native_q1(json.loads(pbp.read_text()),
                              json.loads(box.read_text()),game,players)
            if not stints:
                reason=reasons.get("rejected","unknown_rejection")
                counts["rejected_"+reason]+=1
                if len(samples[reason])<10:samples[reason].append(gid)
                continue
            accepted.append((game,stints,rosters,reasons))
            counts["games_verified"]+=1
            counts["verified_seconds"]+=reasons["verified_seconds"]
            counts["games_with_score_metrics"]+=reasons["score_verified"]
        except (ValueError,KeyError,TypeError) as exc:
            counts["invalid_capture"]+=1
            if len(samples["invalid_capture"])<10:samples["invalid_capture"].append({"id":gid,"error":str(exc)})
    rows,_,_=summarize_games(accepted)
    scope=(season,segment)
    return rows.get(scope,[]),{"canonical_games":len(games),
                                  "source_games":counts["source_pairs_seen"],
                                  **dict(counts),"examples":dict(samples)}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--database",type=Path,default=DEFAULT_DB)
    p.add_argument("--static",type=Path,default=DEFAULT_STATIC)
    p.add_argument("--season",required=True)
    p.add_argument("--segment",choices=("regular","playoffs"),required=True)
    p.add_argument("--publish",action="store_true")
    p.add_argument("--report",type=Path,default=Path("experimental/arcside-react/evidence/coverage/phase4b-live-q1.json"))
    args=p.parse_args()
    if not re.fullmatch(r"\d{4}-\d\d",args.season):p.error("Invalid season")
    with sqlite3.connect(args.database.resolve().as_uri()+"?mode=ro",uri=True) as db:
        rows,stats=materialize(db,args.static,args.season,args.segment)
    report={"contract":"arcside-phase4b-nba-live-q1-research-v1",
            "season":args.season,"segment":args.segment,"coverage":stats,
            "pair_rows":len(rows),"published":False,
            "caveat":"Q1-only partial coverage, official starters and player-minute upper bounds; not complete games, full seasons or possessions."}
    if args.publish and rows:
        target=args.static/"lineups"/args.season/args.segment/"with_without.json"
        if target.exists():
            previous=json.loads(target.read_text())
            if previous.get("contract")!=CONTRACT or previous.get("source")!="nba_live/q1_starters_and_actions":
                raise ValueError("Refusing to overwrite unrelated published lineup material")
        coverage=dict(stats,accepted_periods=stats.get("games_verified",0),
                      games_with_stints=stats.get("games_verified",0))
        atomic_json(target,{"contract":CONTRACT,"source":"nba_live/q1_starters_and_actions",
                   "season":args.season,"segment":args.segment,
                   "available":True,"units":"team_on_court_per36",
                   "coverage":coverage,
                   "rows":sorted(rows,key=lambda x:(x["team"],x["player_id"],x["teammate_id"])),
                   "message":"Only verified first quarters; other periods not inferred."})
        report["published"]=True
    args.report.parent.mkdir(parents=True,exist_ok=True)
    atomic_json(args.report,report)
    print(json.dumps(report,indent=2))


if __name__=="__main__":
    main()
