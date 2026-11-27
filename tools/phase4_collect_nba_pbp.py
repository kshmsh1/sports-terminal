"""Conservative opt-in NBA CDN PBP capture, with per-game evidence and resume.

Only the public game ID list in the existing warehouse is used; NEVER invent
game IDs or alter the canonical database. Requests are spaced, retryable, and
bounded; 403/429 stop the run. Do not run if NBA access terms disallow it.
Fetches are immutable by default and published lineup files are untouched.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BASE="https://cdn.nba.com/static/json/liveData/"
KINDS={"pbp":"playbyplay/playbyplay_","boxscore":"boxscore/boxscore_"}
DEFAULT_DB=ROOT/"data/warehouse/nba_history.sqlite"
DEFAULT_OUT=ROOT/"web/data/nba_static/nba_com/pbp_live"
DEFAULT_REPORT=ROOT/"experimental/arcside-react/evidence/coverage/phase4b-pbp-capture.json"


def game_ids(database,season,segment):
    with sqlite3.connect(database.resolve().as_uri()+"?mode=ro",uri=True) as db:
        values=[str(row[0]) for row in db.execute(
            "SELECT nba_game_id FROM canon_dim_game WHERE league_id='NBA' "
            "AND season_id=? AND season_type=? AND nba_game_id IS NOT NULL",
            (season,segment))]
    return sorted({v.zfill(10) for v in values if v.isdigit() and len(v)<=10})


def verify(payload,game_id,kind="pbp"):
    if not isinstance(payload,dict):
        raise ValueError("Not an NBA JSON object")
    game=payload.get("game")
    if not isinstance(game,dict) or str(game.get("gameId") or "")!=game_id:
        raise ValueError("PBP JSON game ID does not match")
    if kind=="boxscore":
        teams=[game.get("homeTeam"),game.get("awayTeam")]
        if any(not isinstance(team,dict) or not isinstance(team.get("players"),list) for team in teams):
            raise ValueError("Missing NBA boxscore player rosters")
        return sum(len(team["players"]) for team in teams)
    actions=game.get("actions")
    if not isinstance(actions,list) or not actions:
        raise ValueError("Missing PBP actions")
    if any(not isinstance(a,dict) or not isinstance(a.get("period"),int)
           or not isinstance(a.get("actionNumber"),int) for a in actions):
        raise ValueError("Malformed PBP action identifiers")
    return len(actions)


def collect(database,season,segment,destination,report,*,fetch=False,limit=0,delay=1.5,kind="pbp",selected_ids=None):
    if kind not in KINDS:raise ValueError("Unsupported NBA capture type")
    games=game_ids(database,season,segment)
    if selected_ids:
        selected={str(v).zfill(10) for v in selected_ids}
        if not selected.issubset(set(games)):
            raise ValueError("Requested game ID not in canonical season/segment")
        games=sorted(selected)
    result={"contract":"arcside-nba-cdn-playbyplay-capture-v1","source":BASE+KINDS[kind],"kind":kind,
            "season":season,"segment":segment,"planned_games":len(games),
            "fetch":fetch,"generated_at":dt.datetime.now(dt.timezone.utc).isoformat(),
            "counts":{},"failures":[],"captured":[]}
    counts={"verified_cached":0,"downloaded":0,"not_found":0,"failed":0,
            "unattempted":0,"rate_limited":0}
    attempts=0
    for game_id in games:
        target=destination/kind/season/segment/(game_id+".json")
        if target.exists():
            try:
                raw=target.read_bytes()
                n=verify(json.loads(raw),game_id,kind)
                counts["verified_cached"]+=1
                result["captured"].append({"game_id":game_id,"sha256":hashlib.sha256(raw).hexdigest(),"actions":n,"cached":True})
                continue
            except (ValueError,TypeError,json.JSONDecodeError) as exc:
                counts["failed"]+=1
                result["failures"].append({"game_id":game_id,"error":"invalid_existing_capture:"+str(exc)})
                continue
        if not fetch or (limit and attempts>=limit):
            counts["unattempted"]+=1
            continue
        attempts+=1
        try:
            req=urllib.request.Request(BASE+KINDS[kind]+game_id+".json",headers={
                "User-Agent":"ArcsideDataResearch/1.0 (source-qualified archive)",
                "Accept":"application/json"})
            with urllib.request.urlopen(req,timeout=25) as response:
                if response.status!=200:raise ValueError("Unexpected status "+str(response.status))
                raw=response.read(8_000_001)
            if len(raw)>8_000_000:raise ValueError("Source response too large")
            n=verify(json.loads(raw),game_id)
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(raw)
            counts["downloaded"]+=1
            result["captured"].append({"game_id":game_id,"sha256":hashlib.sha256(raw).hexdigest(),"actions":n,"cached":False})
        except urllib.error.HTTPError as exc:
            if exc.code in (403,429):
                counts["rate_limited"]+=1
                result["failures"].append({"game_id":game_id,"status":exc.code})
                break
            key="not_found" if exc.code==404 else "failed"
            counts[key]+=1
            result["failures"].append({"game_id":game_id,"status":exc.code})
        except (urllib.error.URLError,ValueError,TimeoutError,json.JSONDecodeError) as exc:
            counts["failed"]+=1
            result["failures"].append({"game_id":game_id,"error":str(exc)})
        if delay:time.sleep(delay)
    counts["unattempted"]+=max(0,len(games)-sum(counts.values()))
    result["counts"]=counts
    report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--database",type=Path,default=DEFAULT_DB)
    p.add_argument("--season",required=True)
    p.add_argument("--segment",choices=("regular","playoffs"),required=True)
    p.add_argument("--output",type=Path,default=DEFAULT_OUT)
    p.add_argument("--report",type=Path,default=DEFAULT_REPORT)
    p.add_argument("--kind",choices=tuple(KINDS),default="pbp",help="Play-by-play actions or player boxscore")
    p.add_argument("--game-id",action="append",default=[],help="Limit capture to a known NBA game ID (repeatable)")
    p.add_argument("--fetch",action="store_true",help="Opt in to spaced NBA CDN HTTP requests")
    p.add_argument("--limit",type=int,default=10,help="Maximum new HTTP attempts; 0 = uncapped")
    p.add_argument("--delay",type=float,default=1.5,help="Seconds between requests")
    args=p.parse_args()
    if not args.database.is_file():p.error("Missing canonical warehouse")
    if args.limit<0 or args.delay<0:p.error("Limit and delay must be nonnegative")
    actual_report=args.report.with_name(args.report.stem+"-"+args.kind+args.report.suffix)
    result=collect(args.database,args.season,args.segment,args.output,actual_report,
                   fetch=args.fetch,limit=args.limit,delay=args.delay,kind=args.kind,
                   selected_ids=args.game_id)
    print(json.dumps({"planned_games":result["planned_games"],"counts":result["counts"],
                      "report":str(actual_report)},indent=2))


if __name__=="__main__":
    main()
