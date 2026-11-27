"""Phase 4B: conservative NBA with/without pair-split materializer.

Uses the actual Wyatt event-level play-by-play table. Time intervals are
accepted only after all ten on-court players are evidenced by observed events
and coherent substitutions. Earlier uncertain minutes are excluded; a later
contradiction rejects the affected period. No missing statistics are imputed.

Outputs source-verified *coverage*, not necessarily complete-season splits.
No NBA.com requests or synthetic production rows.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "data/warehouse/nba_history.sqlite"
DEFAULT_STATIC = ROOT / "web/data/nba_static"
DEFAULT_EVIDENCE = ROOT / "experimental/arcside-react/evidence/coverage/phase4b-lineups.json"
CONTRACT = "arcside-phase4b-verified-pbp-pair-splits-v1"


def ident(v):
    s = str(v or "").strip()
    m = re.fullmatch(r"(\d+)(?:\.0+)?", s)
    return (m.group(1).lstrip("0") or "0") if m else ""


def num(v):
    try:
        x = float(v)
        return x if x == x else None
    except (ValueError, TypeError):
        return None


def field(row, key):
    if key in row:
        return row[key]
    return row.get(key.upper())


def clock_seconds(raw):
    m = re.fullmatch(r"\s*(\d{1,2}):(\d{2}(?:\.\d+)?)\s*", str(raw or ""))
    if not m or float(m.group(2)) >= 60:
        return None
    return int(m.group(1))*60+float(m.group(2))


def score_tuple(raw):
    m = re.fullmatch(r"\s*(\d+)\s*-\s*(\d+)\s*", str(raw or ""))
    return (int(m.group(1)),int(m.group(2))) if m else None


def event_type(e):
    v = field(e, "eventmsgtype")
    try:
        return int(v)
    except (ValueError, TypeError):
        return -1


def participant(e, n, sides, player_keys):
    player_id = ident(field(e, f"player{n}_id"))
    team_id = ident(field(e, f"player{n}_team_id"))
    if not player_id or player_id == "0":
        return None
    if team_id not in sides:
        return None
    player_key = player_keys.get(player_id)
    return (sides[team_id],player_key) if player_key else None


def active_slots(e):
    # Bench technicals, timeouts, replay and administrative events are not
    # evidence of court presence. Free-throw shooters may be technical shooters.
    return {1:(1,2,3),2:(1,3),4:(1,),5:(1,2),10:(1,2,3)}.get(event_type(e),())


def inferred_openers(events, sides, player_keys):
    # A player's first appearance as an outgoing substitution or an active
    # participant proves opening presence if no earlier incoming swap exists.
    first = {"home":{}, "away":{}}
    for e in events:
        if event_type(e)==8:
            out=participant(e,1,sides,player_keys)
            inc=participant(e,2,sides,player_keys)
            if not out or not inc or out[0]!=inc[0]:
                return None
            first[out[0]].setdefault(out[1],True)
            first[inc[0]].setdefault(inc[1],False)
        else:
            for n in active_slots(e):
                p=participant(e,n,sides,player_keys)
                if p:
                    first[p[0]].setdefault(p[1],True)
    on={side:{p for p,started in items.items() if started} for side,items in first.items()}
    return on if all(len(v)==5 for v in on.values()) else None


def starter_fives(events, sides, player_keys):
    """Five directly observed players on each team before its first substitution.

    This is deliberately stricter than assuming the first five box-score rows
    started. An outgoing player on the first substitution was on court.
    """
    observed = {"home":set(),"away":set()}
    first_swap = next((i for i,e in enumerate(events) if event_type(e)==8),len(events))
    first_clock = clock_seconds(field(events[first_swap],"pctimestring")) if first_swap<len(events) else None
    initial = list(events[:first_swap])
    if first_swap<len(events):
        initial.append(events[first_swap])
        # Multiple swaps at that same time all supply on-court outgoing players.
        for e in events[first_swap+1:]:
            if event_type(e)==8 and clock_seconds(field(e,"pctimestring"))==first_clock:
                initial.append(e)
            elif clock_seconds(field(e,"pctimestring")) != first_clock:
                break
    for e in initial:
        for n in (1,) if event_type(e)==8 else (1,2,3):
            part=participant(e,n,sides,player_keys)
            if part:
                observed[part[0]].add(part[1])
    if any(len(s)!=5 for s in observed.values()):
        return None,"starting_five_not_evidenced"
    return observed,None


def scoreboard_is_valid(events, away_final, home_final):
    if away_final is None or home_final is None:
        return False
    previous=(0,0)
    saw=False
    for e in events:
        score=score_tuple(field(e,"score"))
        if score is None:
            continue
        da,dh=score[0]-previous[0],score[1]-previous[1]
        if da<0 or dh<0 or da>4 or dh>4 or (da and dh):
            return False
        previous=score
        saw=True
    return saw and previous==(away_final,home_final)


def process_game(events, game, player_keys):
    """Extract only stints for which both on-court fives are directly known.

    Recognition may occur after period start. Substitution OUT is evidence
    that the outgoing player was on court, but never authorizes retroactively
    counting an unknown interval. An unexpected eleventh player after both
    sides are known invalidates that period.
    """
    home_id=ident(game["home_nba_id"])
    away_id=ident(game["away_nba_id"])
    if not home_id or not away_id or home_id==away_id:
        return [],{},{"team_identity_unavailable":1}
    sides={home_id:"home",away_id:"away"}
    try:
        events=sorted(events,key=lambda e:int(field(e,"eventnum")))
    except (ValueError,TypeError):
        return [],{},{"invalid_event_number":1}
    unique={}
    for e in events:
        n=int(field(e,"eventnum"))
        if n in unique and unique[n]!=e:
            return [],{},{"conflicting_duplicate_event_number":1}
        unique[n]=e
    events=list(unique.values())
    periods=collections.defaultdict(list)
    rosters={"home":set(),"away":set()}
    for e in events:
        try:
            period=int(field(e,"period"))
        except (ValueError,TypeError):
            continue
        if period<1 or period>15:
            continue
        periods[period].append(e)
        for n in (1,2,3):
            part=participant(e,n,sides,player_keys)
            if part:
                rosters[part[0]].add(part[1])
    if not periods:
        return [],{},{"no_periods":1}
    if 1 not in periods:
        return [],{},{"period_one_missing":1}
    score_ok=scoreboard_is_valid(events,num(game.get("away_score")),num(game.get("home_score")))
    stints=[]
    reasons=collections.Counter()
    previous_score=(0,0)
    for period, pevents in sorted(periods.items()):
        duration=720 if period<=4 else 300
        clocks=[clock_seconds(field(e,"pctimestring")) for e in pevents]
        if any(t is None or t>duration for t in clocks) or any(a<b for a,b in zip(clocks,clocks[1:])):
            reasons["invalid_period_clock"]+=1
            for e in pevents:
                score=score_tuple(field(e,"score"))
                if score is not None:previous_score=score
            continue
        on=inferred_openers(pevents,sides,player_keys) or {"home":set(),"away":set()}
        local=[]
        t_prev=duration
        valid=True
        for e,t in zip(pevents,clocks):
            fully_known=all(len(on[side])==5 for side in on)
            if fully_known and t<t_prev:
                local.append({"seconds":t_prev-t,"home":frozenset(on["home"]),
                              "away":frozenset(on["away"]),"points":(0,0)})
            t_prev=t
            value=score_tuple(field(e,"score"))
            if value is not None:
                diff=(value[0]-previous_score[0],value[1]-previous_score[1])
                if score_ok and fully_known and (diff[0]>0 or diff[1]>0):
                    local.append({"seconds":0,"home":frozenset(on["home"]),
                                  "away":frozenset(on["away"]),"points":diff})
                previous_score=value
            if event_type(e)==8:
                outgoing=participant(e,1,sides,player_keys)
                incoming=participant(e,2,sides,player_keys)
                if (not outgoing or not incoming or outgoing[0]!=incoming[0]
                        or incoming[1] in on[outgoing[0]]
                        or (len(on[outgoing[0]])==5 and outgoing[1] not in on[outgoing[0]])):
                    valid=False
                    reasons["invalid_substitution"]+=1
                    break
                on[outgoing[0]].discard(outgoing[1])
                on[outgoing[0]].add(incoming[1])
            else:
                for n in active_slots(e):
                    part=participant(e,n,sides,player_keys)
                    if part and part[1] not in on[part[0]]:
                        if len(on[part[0]])==5:
                            valid=False
                            reasons["participant_not_on_court"]+=1
                            break
                        on[part[0]].add(part[1])
                if not valid:break
        if valid:
            if all(len(on[side])==5 for side in on) and t_prev>0 and event_type(pevents[-1])==13:
                local.append({"seconds":t_prev,"home":frozenset(on["home"]),
                              "away":frozenset(on["away"]),"points":(0,0)})
            verified_seconds=sum(x["seconds"] for x in local)
            if verified_seconds>duration:
                reasons["period_duration_not_conserved"]+=1
                continue
            if verified_seconds>0:
                stints.extend(local)
                reasons["periods_verified"]+=1
                if verified_seconds<duration:
                    reasons["partially_observed_periods"]+=1
            else:
                reasons["no_fully_evidenced_interval"]+=1
        else:
            reasons["periods_rejected"]+=1
            for e in pevents:
                score=score_tuple(field(e,"score"))
                if score is not None:previous_score=score
    return stints,rosters,dict(reasons)|{"score_verified":int(score_ok)}


def summarize_games(games):
    """Aggregate only observed, time-conserved stints for two rostered players."""
    totals=collections.defaultdict(lambda:{"with":[0.0,0.0,0.0],
                                           "without":[0.0,0.0,0.0],"score_certified":True})
    seen_games=collections.Counter()
    verified=collections.Counter()
    for game,stints,rosters,reasons in games:
        scope=(game["season"],game["segment"])
        seen_games[scope]+=1
        verified[scope]+=reasons.get("periods_verified",0)
        if not stints:continue
        for side in ("home","away"):
            roster=sorted(rosters.get(side,set()))
            team=game[side+"_abbr"]
            if not team:continue
            for stint in stints:
                active=stint[side]
                seconds=stint["seconds"]
                points=stint["points"]
                for a in active:
                    for b in roster:
                        if b==a:continue
                        slot="with" if b in active else "without"
                        pair=totals[(scope,team,a,b)]
                        if not reasons.get("score_verified"):
                            pair["score_certified"]=False
                        agg=pair[slot]
                        agg[0]+=seconds
                        if reasons.get("score_verified"):
                            mine=points[1] if side=="home" else points[0]
                            other=points[0] if side=="home" else points[1]
                            agg[1]+=mine
                            agg[2]+=mine-other
    result=collections.defaultdict(list)
    for (scope,team,a,b),slots in totals.items():
        w=slots["with"];n=slots["without"]
        if w[0]<=0 and n[0]<=0:continue
        def metrics(vals):
            seconds=vals[0]
            return {"pts":round(vals[1]*2160/seconds,3),
                    "plus_minus":round(vals[2]*2160/seconds,3)} if seconds>0 and slots["score_certified"] else {}
        # Scoring values are suppressed whenever *any* contributing game's
        # scoreboard could not be checked. Never silently average partial stats.
        result[scope].append({
            "team":team,"player_id":a,"teammate_id":b,
            "minutes_with":round(w[0]/60,3),"minutes_without":round(n[0]/60,3),
            "with":metrics(w),"without":metrics(n),
        })
    return result,seen_games,verified


def load_game_catalog(db, season=None):
    where=" WHERE g.league_id='NBA' AND g.season_type IN ('regular','playoffs')"
    params=[]
    if season:
        where+=" AND g.season_id=?"
        params.append(season)
    catalog={}
    query=("SELECT g.game_key,g.nba_game_id,g.season_id AS season,g.season_type AS segment,"
           "g.home_score,g.away_score,ht.nba_team_id AS home_nba_id,"
           "at.nba_team_id AS away_nba_id,ht.abbreviation AS home_abbr,"
           "at.abbreviation AS away_abbr "
           "FROM canon_dim_game g "
           "LEFT JOIN canon_dim_team ht ON ht.team_key=g.home_team_key "
           "LEFT JOIN canon_dim_team at ON at.team_key=g.away_team_key"+where)
    for row in db.execute(query,params):
        entry=dict(row)
        token=ident(entry["nba_game_id"])
        if token:
            if token in catalog:
                raise ValueError("Ambiguous canonical NBA game ID: "+token)
            catalog[token]=entry
    return catalog


def player_identity_catalog(db):
    mapping=collections.defaultdict(set)
    for key,nba in db.execute("SELECT player_key,nba_id FROM canon_dim_player"):
        if ident(nba):mapping[ident(nba)].add(str(key))
    if db.execute("SELECT 1 FROM sqlite_master WHERE name='canon_player_source_xref'").fetchone():
        for source_id,key in db.execute(
            "SELECT source_id,player_key FROM canon_player_source_xref "
            "WHERE source_key='wyatt_nbadb' AND source_id<>''"
        ):
            if ident(source_id):mapping[ident(source_id)].add(str(key))
    return {k:next(iter(v)) for k,v in mapping.items() if len(v)==1}


def source_pbp_table(db):
    row=db.execute(
        "SELECT warehouse_table FROM historical_table_inventory "
        "WHERE source_key='wyatt_nbadb' AND source_table='play_by_play' LIMIT 1"
    ).fetchone()
    if not row:
        raise ValueError("Wyatt event-level play_by_play table not registered")
    name=str(row[0])
    if not re.fullmatch(r"[a-zA-Z0-9_]+",name):
        raise ValueError("Unsafe play-by-play table name")
    columns={x[1].lower() for x in db.execute(f"PRAGMA table_info({name})")}
    needed={"game_id","eventnum","eventmsgtype","period","pctimestring","score",
            "player1_id","player2_id","player1_team_id","player2_team_id"}
    if not needed.issubset(columns):
        raise ValueError("Missing event-level PBP identity/substitution columns: "+repr(sorted(needed-columns)))
    return name


def iter_game_events(db,table,catalog):
    """Stream in game/event order. Never load the entire multi-million-event PBP."""
    current_id=None;current_rows=[]
    # One indexed or external-sort scan, not 160 table scans.
    ids=sorted({variant for token,g in catalog.items() for variant in (str(g["nba_game_id"]),token,token.zfill(10))})
    if not ids:
        return
    # A season-sized run scans only its target NBA game IDs; an all-season
    # run streams the source once. SQLite supports >=999 bind parameters;
    # if the target is larger, use the full scan rather than repeated scans.
    placeholders=",".join("?" for _ in ids)
    max_bound=db.getlimit(sqlite3.SQLITE_LIMIT_VARIABLE_NUMBER) if hasattr(db,"getlimit") else 999
    bounded=len(ids)<=min(max_bound,20000)
    query=(f"SELECT * FROM {table} WHERE game_id IN ({placeholders}) ORDER BY game_id,eventnum"
           if bounded else f"SELECT * FROM {table} ORDER BY game_id,eventnum")
    for row in db.execute(query,ids if bounded else ()):
        raw=dict(row)
        token=ident(field(raw,"game_id"))
        if token!=current_id:
            if current_id in catalog and current_rows:
                yield catalog[current_id],current_rows
            current_id=token;current_rows=[]
        if token in catalog:
            current_rows.append(raw)
    if current_id in catalog and current_rows:
        yield catalog[current_id],current_rows


def build(db,*,season=None):
    db.row_factory=sqlite3.Row
    catalog=load_game_catalog(db,season)
    players=player_identity_catalog(db)
    table=source_pbp_table(db)
    total=collections.Counter()
    def reconstructed_games():
        for game,events in iter_game_events(db,table,catalog):
            stints,rosters,reasons=process_game(events,game,players)
            scope=(game["season"],game["segment"])
            total[scope,"source_games"]+=1
            total[scope,"accepted_periods"]+=reasons.get("periods_verified",0)
            total[scope,"verified_seconds"]+=sum(s["seconds"] for s in stints)
            if stints:total[scope,"games_with_stints"]+=1
            if reasons.get("score_verified"):total[scope,"score_verified_games"]+=1
            for reason,value in reasons.items():
                if reason not in ("periods_verified","score_verified"):
                    total[scope,"rejection_"+reason]+=value
            yield game,stints,rosters,reasons
    rows,_,_=summarize_games(reconstructed_games())
    coverage={}
    scope_counts=collections.Counter((g["season"],g["segment"]) for g in catalog.values())
    for scope in sorted(scope_counts):
        counts={metric:n for (sc,metric),n in total.items() if sc==scope}
        counts["canonical_games"]=scope_counts[scope]
        counts["published_pair_rows"]=len(rows.get(scope,[]))
        coverage[scope]=counts
    return rows,coverage


def atomic_json(path,payload):
    path.parent.mkdir(parents=True,exist_ok=True)
    temp=path.with_suffix(".phase4b.tmp")
    temp.write_text(json.dumps(payload,ensure_ascii=False,separators=(",",":")),encoding="utf-8")
    temp.replace(path)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--database",type=Path,default=Path(os.environ.get("SPORTS_TERMINAL_NBA_HISTORY_DB",DEFAULT_DB)))
    p.add_argument("--static",type=Path,default=DEFAULT_STATIC)
    p.add_argument("--season",help="Restrict to one season (e.g. 2018-19). Omit for all")
    p.add_argument("--report",type=Path,default=DEFAULT_EVIDENCE)
    p.add_argument("--publish",action="store_true",help="Publish source-verified split files; default report only")
    args=p.parse_args()
    if args.season and not re.fullmatch(r"\d{4}-\d\d",args.season):
        p.error("Invalid season")
    if not args.database.is_file():
        p.error("Canonical database not found")
    with sqlite3.connect(args.database.resolve().as_uri()+"?mode=ro",uri=True) as db:
        db.execute("PRAGMA query_only=ON")
        rows,coverage=build(db,season=args.season)
    reports=[]
    for scope,stats in coverage.items():
        season,segment=scope
        payload={"contract":CONTRACT,"source":"wyatt_nbadb/play_by_play (verified stints)",
                 "season":season,"segment":segment,"available":bool(rows.get(scope)),
                 "units":"team_on_court_per36","coverage":stats,
                 "rows":sorted(rows.get(scope,[]),key=lambda r:(r["team"],r["player_id"],r["teammate_id"])),
                 "message":"Partial coverage: only fully reconstructed periods are represented."}
        destination=args.static/"lineups"/season/segment/"with_without.json"
        if args.publish and payload["rows"]:
            if destination.exists():
                previous=json.loads(destination.read_text(encoding="utf-8"))
                if previous.get("contract") != CONTRACT:
                    raise ValueError("Refusing to overwrite non-Phase4B lineup data: "+str(destination))
            atomic_json(destination,payload)
        reports.append({"season":season,"segment":segment,**stats,
                        "published":bool(args.publish and payload["rows"])})
    report={"contract":CONTRACT,"published":bool(args.publish),
            "scopes":reports,"source":"existing Wyatt event-level PBP",
            "caveat":"Only reconstructable periods. Empty/missing split values are not estimated. On-court team scoring is per 36 verified minutes."}
    args.report.parent.mkdir(parents=True,exist_ok=True)
    atomic_json(args.report,report)
    print(json.dumps({"scopes":len(reports),"scopes_with_pairs":sum(x["published_pair_rows"]>0 for x in reports),
                      "files_written":sum(x["published"] for x in reports),
                      "verified_periods":sum(x.get("accepted_periods",0) for x in reports),
                      "report":str(args.report)},indent=2))


if __name__=="__main__":
    main()
