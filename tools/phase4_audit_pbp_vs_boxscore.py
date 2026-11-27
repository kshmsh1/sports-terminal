"""Read-only independent NBA boxscore cross-check for reconstructed Wyatt stints.

An accepted lineup interval cannot give any player more on-court seconds than
the NBA.com game boxscore reports. An audit pass certifies this upper bound,
NOT a full-game lineup, possessions, or player-stat parity.
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
        DEFAULT_DB,DEFAULT_STATIC,ident,iter_game_events,load_game_catalog,
        player_identity_catalog,process_game,source_pbp_table
    )
except ModuleNotFoundError:
    from phase4_materialize_with_without import (
        DEFAULT_DB,DEFAULT_STATIC,ident,iter_game_events,load_game_catalog,
        player_identity_catalog,process_game,source_pbp_table
    )

def duration(raw):
    s=str(raw or "")
    m=re.fullmatch(r"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?",s)
    if m:
        return int(m.group(1) or 0)*3600+int(m.group(2) or 0)*60+float(m.group(3) or 0)
    m=re.fullmatch(r"(\d+):(\d{2}(?:\.\d+)?)",s)
    if m and float(m.group(2))<60:
        return 60*int(m.group(1))+float(m.group(2))
    return None


def check(game,stints,box,keys,tolerance=2.0):
    payload=box.get("game") if isinstance(box,dict) else None
    if not isinstance(payload,dict) or ident(payload.get("gameId"))!=ident(game["nba_game_id"]):
        return "game_id_mismatch"
    for side in ("home","away"):
        raw=payload.get(side+"Team")
        if not isinstance(raw,dict) or ident(raw.get("teamId"))!=ident(game[side+"_nba_id"]):
            return "team_identity_mismatch"
        final=raw.get("score")
        if final is None or abs(float(final)-float(game[side+"_score"]))>0.01:
            return "official_score_mismatch"
        listed={}
        roster=raw.get("players")
        if not isinstance(roster,list):
            return "missing_official_players"
        starters=set()
        for p in roster:
            token=ident(p.get("personId"))
            mapped=keys.get(token)
            if not mapped:continue
            if str(p.get("starter")).lower() in ("true","1"):starters.add(mapped)
            stats=p.get("statistics") or {}
            seconds=duration(stats.get("minutes"))
            if seconds is not None:listed[mapped]=seconds
        first=next((st for st in stints if st.get("period")==1
                    and st.get("start")==720 and st["seconds"]>0),None)
        if first is not None and len(starters)==5 and first[side]!=starters:
            return "official_starting_five_mismatch"
        recorded=collections.Counter()
        for st in stints:
            for player in st[side]:
                recorded[player]+=st["seconds"]
        for player,seconds in recorded.items():
            if player not in listed:return "missing_official_player_minutes"
            if seconds>listed[player]+tolerance:
                return "reconstructed_minutes_exceed_boxscore"
    return None


def audit(database,static,season):
    with sqlite3.connect(database.resolve().as_uri()+"?mode=ro",uri=True) as db:
        db.row_factory=sqlite3.Row
        catalog=load_game_catalog(db,season)
        players=player_identity_catalog(db)
        table=source_pbp_table(db)
        counts=collections.Counter()
        examples=collections.defaultdict(list)
        for game,events in iter_game_events(db,table,catalog):
            counts["source_games"]+=1
            gid=str(game["nba_game_id"]).zfill(10)
            path=static/"nba_com/pbp_live/boxscore"/game["season"]/game["segment"]/(gid+".json")
            if not path.is_file():
                counts["missing_official_boxscore"]+=1
                continue
            try:
                box=json.loads(path.read_text(encoding="utf-8"))
                stints,_,reasons=process_game(events,game,players)
                if not stints:
                    counts["no_reconstructed_stints"]+=1
                    continue
                problem=check(game,stints,box,players)
                if problem:counts[problem]+=1
                else:counts["verified_player_minute_upper_bound"]+=1
                if problem and len(examples[problem])<12:
                    examples[problem].append(gid)
            except (ValueError,TypeError,KeyError) as exc:
                counts["invalid_official_boxscore"]+=1
                if len(examples["invalid_official_boxscore"])<12:
                    examples["invalid_official_boxscore"].append({"game_id":gid,"error":str(exc)})
    return {"contract":"arcside-phase4b-external-minute-upper-bound-audit-v1",
            "season":season,"counts":dict(counts),"examples":dict(examples),
            "caveat":"Only upper-bound validation of observed player minutes. Full lineup and possession certification remains outstanding."}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--database",type=Path,default=DEFAULT_DB)
    p.add_argument("--static",type=Path,default=DEFAULT_STATIC)
    p.add_argument("--season",required=True)
    p.add_argument("--report",type=Path,default=Path("experimental/arcside-react/evidence/coverage/phase4b-boxscore-audit.json"))
    args=p.parse_args()
    result=audit(args.database,args.static,args.season)
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result,indent=2))


if __name__=="__main__":
    main()
