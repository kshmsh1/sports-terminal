"""Phase 4A: recover NBA.com captured games absent from the Wyatt canonical game source.

Only previously captured traditional league game logs are consumed. A candidate
needs two unambiguous NBA teams, a common date, a home/away marker, distinct
player IDs, and independently consistent team scoring. Nothing is inferred from
season aggregates. Re-running is idempotent; ambiguous candidates stay absent.

Use --apply to append to an EXISTING canonical warehouse (never reset it).
Before applying, an SQLite-consistent backup is made. Rebuilds can also invoke
recover_capture_games after creating the Wyatt canonical tables.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATIC = ROOT / "web/data/nba_static"
DB = ROOT / "data/warehouse/nba_history.sqlite"


def ident(value):
    raw = str(value or "").strip()
    return (raw.lstrip("0") or "0") if raw.isdigit() else ""


def date_iso(value):
    raw = str(value or "").strip()
    if re.match(r"^\d{4}-\d\d-\d\d", raw):
        try:
            return dt.date.fromisoformat(raw[:10]).isoformat()
        except ValueError:
            return None
    for fmt in ("%b %d, %Y", "%B %d, %Y", "%m/%d/%Y"):
        try:
            return dt.datetime.strptime(raw.title(), fmt).date().isoformat()
        except ValueError:
            pass
    return None


def numeric(value):
    if isinstance(value, bool) or value in ("", None):
        return None
    try:
        result = float(str(value).replace(",", ""))
        return result if result == result and abs(result) < 1e15 else None
    except (TypeError, ValueError):
        return None


def minutes(value):
    if isinstance(value, str) and ":" in value:
        pieces = value.strip().split(":")
        if len(pieces) == 2 and all(x.isdigit() for x in pieces) and int(pieces[1]) < 60:
            return int(pieces[0]) + int(pieces[1]) / 60.0
        return None
    return numeric(value)


def source_files(static):
    return sorted((static / "nba_com/surfaces/players_boxscores_traditional/default").glob("*/*.json"))


def captured_groups(static):
    """Read each immutable season/segment scope; do not silently skip corrupt files."""
    for path in source_files(static):
        season, segment = path.parent.name, path.stem
        if not re.fullmatch(r"\d{4}-\d\d", season) or segment not in ("regular", "playoffs"):
            continue
        payload = json.loads(path.read_text(encoding="utf-8"))
        if payload.get("surface") not in (None, "players_boxscores_traditional"):
            raise ValueError(f"Unexpected capture surface: {path}")
        tables = payload.get("tables")
        if not isinstance(tables, list):
            raise ValueError(f"Missing capture tables: {path}")
        groups = collections.defaultdict(list)
        for table in tables:
            if not isinstance(table, dict) or not isinstance(table.get("rows"), list):
                raise ValueError(f"Malformed capture table: {path}")
            for row in table["rows"]:
                if not isinstance(row, dict):
                    raise ValueError(f"Malformed player row: {path}")
                gid = ident(row.get("GAME_ID"))
                if gid:
                    groups[gid].append(row)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        for game_id, rows in sorted(groups.items()):
            yield season, segment, game_id, rows, path, digest


def lookup(db):
    teams = collections.defaultdict(set)
    for key, nba_id, abbr in db.execute(
        "SELECT team_key,nba_team_id,abbreviation FROM canon_dim_team WHERE league_id='NBA'"
    ):
        if ident(nba_id):
            teams[("id", ident(nba_id))].add(str(key))
        if abbr:
            teams[("abbr", str(abbr).upper())].add(str(key))
    players = collections.defaultdict(set)
    for key, nba_id in db.execute("SELECT player_key,nba_id FROM canon_dim_player"):
        if ident(nba_id):
            players[ident(nba_id)].add(str(key))
    return teams, players


def choose_team(teams, row):
    team_id = ident(row.get("TEAM_ID"))
    abbr = str(row.get("TEAM_ABBREVIATION") or "").strip().upper()
    if not team_id or not abbr:
        return None
    choices = teams.get(("id", team_id), set()) & teams.get(("abbr", abbr), set())
    return next(iter(choices)) if len(choices) == 1 else None


def candidate(season, segment, game_id, rows, teams, players, digest):
    dates = {date_iso(row.get("GAME_DATE")) for row in rows}
    if None in dates or len(dates) != 1:
        return None, "missing_or_conflicting_dates"
    date = next(iter(dates))
    first_year = int(season[:4])
    if not (f"{first_year}-07-01" <= date <= f"{first_year+1}-07-01"):
        return None, "date_outside_season"
    team_rows = collections.defaultdict(list)
    directions = collections.defaultdict(set)
    players_seen = set()
    for row in rows:
        tid = ident(row.get("TEAM_ID"))
        pid = ident(row.get("PLAYER_ID"))
        abbr = str(row.get("TEAM_ABBREVIATION") or "").strip().upper()
        matchup = str(row.get("MATCHUP") or "").upper()
        if not tid or not pid or not abbr:
            return None, "missing_player_or_team_identity"
        key = (tid, pid)
        if key in players_seen:
            return None, "duplicate_player_game"
        players_seen.add(key)
        if not choose_team(teams, row):
            return None, "unresolved_team_identity"
        if matchup.startswith(abbr + " VS. ") or matchup.startswith(abbr + " VS "):
            directions[tid].add("home")
        elif matchup.startswith(abbr + " @ "):
            directions[tid].add("away")
        else:
            return None, "unresolved_matchup"
        if numeric(row.get("PTS")) is None:
            return None, "missing_player_points"
        team_rows[tid].append(row)
    if len(team_rows) != 2 or any(len(v) < 5 for v in team_rows.values()):
        return None, "not_two_complete_teams"
    by_direction = {}
    for tid, part in team_rows.items():
        if len(directions[tid]) != 1:
            return None, "conflicting_matchup"
        direction = next(iter(directions[tid]))
        if direction in by_direction:
            return None, "home_away_collision"
        by_direction[direction] = (tid, part, choose_team(teams, part[0]))
        if len({choose_team(teams, x) for x in part}) != 1:
            return None, "team_identity_changed"
    if set(by_direction) != {"home", "away"}:
        return None, "missing_home_or_away"
    home, away = by_direction["home"], by_direction["away"]
    if home[2] == away[2]:
        return None, "same_canonical_team"
    score = {part: sum(numeric(r["PTS"]) for r in by_direction[part][1]) for part in ("home", "away")}
    if any(v < 0 or v != int(v) for v in score.values()):
        return None, "invalid_team_score"
    if score["home"] == score["away"]:
        return None, "tied_final_score"
    for direction, (_, part, _) in by_direction.items():
        outcome = "W" if score[direction] > score["away" if direction == "home" else "home"] else "L"
        if any(str(r.get("WL") or "").strip().upper() not in ("", outcome) for r in part):
            return None, "result_disagrees_with_score"
    return {
        "game_key": f"nba_game_{game_id}", "id": str(rows[0]["GAME_ID"]),
        "season": season, "segment": segment, "date": date,
        "home": home, "away": away, "score": score, "sha256": digest,
        "player_keys": players,
    }, None


def insert(db, item):
    h, a = item["home"], item["away"]
    key = item["game_key"]
    hs, aws = item["score"]["home"], item["score"]["away"]
    provenance = json.dumps({"source": "nba_com/leaguegamelog", "sha256": item["sha256"],
                             "scope": item["season"] + "|" + item["segment"]}, sort_keys=True)
    db.execute(
        "INSERT INTO canon_dim_game "
        "(game_key,nba_game_id,game_date,season_id,league_id,season_type,home_team_key,away_team_key,"
        "home_score,away_score,winner_team_key,status,source_count,provenance_json) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (key, item["id"], item["date"], item["season"], "NBA", item["segment"],
         h[2], a[2], hs, aws, h[2] if hs > aws else a[2], "Final", 1, provenance)
    )
    db.execute(
        "INSERT INTO canon_game_source_xref "
        "(source_key,source_table,source_id,game_key,match_method,confidence,evidence_json)"
        "VALUES (?,?,?,?,?,?,?)",
        ("nba_com", "players_boxscores_traditional", item["id"], key,
         "nba_game_id", 1.0, provenance)
    )
    for direction, current, rival in (("home", h, a), ("away", a, h)):
        mine, theirs = item["score"][direction], item["score"]["away" if direction == "home" else "home"]
        sums = {}
        for target, field in (("fgm","FGM"),("fga","FGA"),("three_pm","FG3M"),("three_pa","FG3A"),
                              ("ftm","FTM"),("fta","FTA"),("orb","OREB"),("drb","DREB"),
                              ("reb","REB"),("ast","AST"),("stl","STL"),("blk","BLK"),
                              ("tov","TOV"),("pf","PF")):
            values = [numeric(row.get(field)) for row in current[1]]
            sums[target] = sum(values) if all(v is not None for v in values) else None
        db.execute(
            "INSERT INTO canon_fact_team_game "
            "(game_key,team_key,opponent_team_key,is_home,result,points,opponent_points,"
            "fgm,fga,three_pm,three_pa,ftm,fta,orb,drb,reb,ast,stl,blk,tov,pf,source_key,provenance_json)"
            "VALUES (" + ",".join("?" for _ in range(23)) + ")",
            (key,current[2],rival[2],int(direction=="home"),"W" if mine>theirs else "L",mine,theirs,
             *(sums[t] for t in ("fgm","fga","three_pm","three_pa","ftm","fta","orb","drb",
                                  "reb","ast","stl","blk","tov","pf")),
             "nba_com",provenance)
        )
        for row in current[1]:
            pid = ident(row["PLAYER_ID"])
            matches = item["player_keys"].get(pid, set())
            player_key = next(iter(matches)) if len(matches)==1 else None
            measures = [minutes(row.get("MIN")), *(numeric(row.get(k)) for k in ("PTS","REB","AST","STL","BLK","TOV","PF"))]
            fgm, fga, fg3m, fta = (numeric(row.get(x)) for x in ("FGM","FGA","FG3M","FTA"))
            ts = measures[1] / (2 * (fga + 0.44 * fta)) if None not in (measures[1],fga,fta) and fga+0.44*fta>0 else None
            efg = (fgm + 0.5 * fg3m) / fga if None not in (fgm,fg3m,fga) and fga>0 else None
            row_prov = json.dumps({"nba_player_id": row["PLAYER_ID"],
                                   "nba_team_id": row["TEAM_ID"], "capture_sha256": item["sha256"]},
                                  sort_keys=True)
            db.execute(
                "INSERT INTO canon_fact_player_game "
                "(fact_key,game_key,source_game_id,player_key,player_name,team_key,team_abbreviation,"
                "opponent_team_key,opponent_abbreviation,season_id,league_id,season_type,game_date,"
                "minutes,pts,reb,ast,stl,blk,tov,pf,ts_pct,efg_pct,source_key,source_table,provenance_json)"
                "VALUES (" + ",".join("?" for _ in range(26)) + ")",
                ("nba_com|" + item["season"] + "|" + item["segment"] + "|" + ident(item["id"]) + "|" + pid,
                 key,item["id"],player_key,str(row.get("PLAYER_NAME") or "Unknown"),
                 current[2],str(row.get("TEAM_ABBREVIATION") or ""),
                 rival[2],str(rival[1][0].get("TEAM_ABBREVIATION") or ""),item["season"],
                 "NBA",item["segment"],item["date"],*measures,ts,efg,"nba_com",
                 "players_boxscores_traditional",row_prov)
            )


def recover_capture_games(db, static=STATIC, *, apply=False):
    """Return source-qualified report; writes only inside caller transaction with apply."""
    required = {"canon_dim_game","canon_fact_player_game","canon_fact_team_game",
                "canon_dim_team","canon_dim_player","canon_game_source_xref"}
    tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    if not required.issubset(tables):
        raise ValueError("Missing canonical tables: " + repr(sorted(required-tables)))
    team_map, player_map = lookup(db)
    existing = {ident(row[0]) for row in db.execute(
        "SELECT nba_game_id FROM canon_dim_game WHERE league_id='NBA'")}
    existing.discard("")
    key_set = {row[0] for row in db.execute("SELECT game_key FROM canon_dim_game")}
    counts = collections.Counter()
    examples = collections.defaultdict(list)
    seen = set()
    for season, segment, gid, rows, source, digest in captured_groups(static):
        counts["captured_game_groups"] += 1
        if gid in seen:
            reason = "duplicate_id_across_scopes"
        elif gid in existing:
            reason = "already_canonical"
        else:
            item, reason = candidate(season,segment,gid,rows,team_map,player_map,digest)
            if not reason and item["game_key"] in key_set:
                reason = "canonical_key_collision"
            if not reason:
                counts["qualified_missing_games"] += 1
                if apply:
                    insert(db,item)
                    counts["inserted_games"] += 1
                if len(examples["qualified"]) < 12:
                    examples["qualified"].append({"scope":season+"|"+segment,"game_id":gid})
        seen.add(gid)
        if reason:
            counts[reason] += 1
            if reason != "already_canonical" and len(examples[reason]) < 12:
                examples[reason].append({"scope":season+"|"+segment,"game_id":gid})
    return {"contract":"arcside-phase4a-capture-game-recovery-v1",
            "applied":bool(apply),"counts":dict(sorted(counts.items())),
            "examples":dict(examples),
            "caveat":"Qualification requires actual NBA.com team/date/matchup/player evidence. No historical game counts are assumed."}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--database",type=Path,default=Path(os.environ.get("SPORTS_TERMINAL_NBA_HISTORY_DB",DB)))
    p.add_argument("--static",type=Path,default=STATIC)
    p.add_argument("--report",type=Path,default=ROOT/"experimental/arcside-react/evidence/coverage/phase4a-recovery.json")
    p.add_argument("--apply",action="store_true",help="Append verified records; backs up original DB first.")
    args=p.parse_args()
    if not args.database.is_file():
        p.error("Canonical database not found")
    if args.apply and not source_files(args.static):
        p.error("No captured NBA.com files; refusing empty apply")
    backup=None
    with sqlite3.connect(args.database) as db:
        if args.apply:
            stamp=dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            backup=args.database.with_name(args.database.stem+".before-phase4a-"+stamp+".sqlite")
            if backup.exists():
                raise FileExistsError(backup)
            with sqlite3.connect(backup) as target:
                db.backup(target)
        try:
            if args.apply:
                db.execute("BEGIN")
            report=recover_capture_games(db,args.static,apply=args.apply)
            if args.apply:
                try:
                    from tools.build_historical_nba_canonical import build_coverage, update_league_bounds
                except ModuleNotFoundError:
                    from build_historical_nba_canonical import build_coverage, update_league_bounds
                build_coverage(db)
                update_league_bounds(db)
                db.commit()
        except Exception:
            db.rollback()
            raise
    report["database_backup"]=str(backup) if backup else None
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"counts":report["counts"],"applied":report["applied"],
                      "backup":report["database_backup"],"report":str(args.report)},indent=2))


if __name__=="__main__":
    main()
