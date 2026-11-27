"""Phase 4A: safely refresh the existing v5 game's index without erasing captures.

Unlike the older full static compiler, this utility preserves nba_com/, lineups/,
season shards and previously published entities. Changes are backed up first,
validated against canonical keys and then atomically replaced. The original
box-score materializer is invoked for actual detail files.
"""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import json
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.build_static_nba_website_data import db_fingerprint, game_index

DEFAULT_DB = ROOT / "data/warehouse/nba_history.sqlite"
DEFAULT_STATIC = ROOT / "web/data/nba_static"
DEFAULT_BACKUPS = ROOT / "experimental/arcside-react/evidence/coverage"


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".phase4a.tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":"), default=str), encoding="utf-8")
    temp.replace(path)


def refresh(db_path, static, backups, *, apply=False, details=True):
    index_path = static / "games/index.json"
    manifest_path = static / "manifest.json"
    seasons_path = static / "seasons.json"
    coverage_path = static / "history/coverage.json"
    if not db_path.is_file() or not index_path.is_file() or not manifest_path.is_file():
        raise FileNotFoundError("Expected local canonical database and published v5 files")
    old_index = json.loads(index_path.read_text(encoding="utf-8"))
    old_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if old_manifest.get("contract") != "sports-terminal-static-nba-website-v5" or old_manifest.get("static_schema_version") != 5:
        raise ValueError("Can only patch an existing original v5 archive")
    if not isinstance(old_index, list) or any(not isinstance(row, dict) for row in old_index):
        raise ValueError("Invalid original index")
    old_by_key = {str(row.get("game_key")): row for row in old_index}
    if len(old_by_key) != len(old_index):
        raise ValueError("Duplicate keys in original index")
    with sqlite3.connect(db_path.resolve().as_uri()+"?mode=ro", uri=True) as db:
        db.row_factory = sqlite3.Row
        new_rows = game_index(db)
        new_coverage = [dict(x) for x in db.execute("SELECT * FROM canon_coverage WHERE league_id='NBA' ORDER BY season_id,domain")]
    new_by_key = {str(row.get("game_key")): row for row in new_rows}
    if len(new_by_key) != len(new_rows):
        raise ValueError("Duplicate keys in canonical games")
    absent = set(old_by_key) - set(new_by_key)
    if absent:
        raise ValueError(f"Previously published games missing from canonical: {len(absent)}")
    for key, old in old_by_key.items():
        new = new_by_key[key]
        if str(old.get("nba_game_id") or "") != str(new.get("nba_game_id") or ""):
            raise ValueError("Game identity changed: " + key)
        for name in ("season_id", "season_type"):
            if str(old.get(name) or "") != str(new.get(name) or ""):
                raise ValueError("Existing game season/segment changed: " + key)
        for retained in ("file", "box_score_available", "box_score_source"):
            if retained in old:
                new[retained] = old[retained]
    additions = sorted(set(new_by_key) - set(old_by_key))
    output_index = sorted(new_rows, key=lambda g: (str(g.get("game_date") or ""), str(g["game_key"])))
    previous_seasons = json.loads(seasons_path.read_text(encoding="utf-8"))
    if not isinstance(previous_seasons, list):
        raise ValueError("Original seasons index is not an array")
    season_counts = {}
    for game in output_index:
        season = str(game.get("season_id") or "")
        season_counts[season] = season_counts.get(season, 0) + 1
    updated_seasons = copy.deepcopy(previous_seasons)
    for item in updated_seasons:
        season = str(item.get("season_id") or "")
        if season in season_counts:
            item["games"] = season_counts[season]
    report = {"contract":"arcside-phase4a-index-publication-v1",
              "original":len(old_index),"candidate":len(new_rows),
              "additions":len(additions),"samples":additions[:25],
              "applied":bool(apply),"preserved_capture_tree":True}
    if not apply:
        return report
    stamp=dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    folder=backups/("phase4a-index-before-"+stamp)
    folder.mkdir(parents=True,exist_ok=False)
    for name,source in (("index.json",index_path),("manifest.json",manifest_path),
                        ("seasons.json",seasons_path),("coverage.json",coverage_path),
                        ("detail_manifest.json",static/"games/detail_manifest.json")):
        if source.is_file():
            (folder/name).write_bytes(source.read_bytes())
    updated_manifest=copy.deepcopy(old_manifest)
    updated_manifest["database_fingerprint"]=db_fingerprint(db_path)
    updated_manifest["game_count"]=len(output_index)
    updated_manifest["phase4a_recovery"]={"games_added":len(additions),"source":"NBA.com captured leaguegamelog; validated canonical identities"}
    try:
        atomic_json(index_path,output_index)
        atomic_json(seasons_path,updated_seasons)
        atomic_json(coverage_path,new_coverage)
        atomic_json(manifest_path,updated_manifest)
        if details:
            subprocess.run([sys.executable,str(ROOT/"tools/materialize_static_nba_game_details.py"),
                            "--database",str(db_path),"--output",str(static),"--force"],check=True)
    except Exception:
        for name,target in (("index.json",index_path),("manifest.json",manifest_path),
                            ("seasons.json",seasons_path),("coverage.json",coverage_path),
                            ("detail_manifest.json",static/"games/detail_manifest.json")):
            saved=folder/name
            if saved.is_file():
                target.write_bytes(saved.read_bytes())
        raise
    report["backup_directory"]=str(folder)
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--database",type=Path,default=Path(os.environ.get("SPORTS_TERMINAL_NBA_HISTORY_DB",DEFAULT_DB)))
    p.add_argument("--static",type=Path,default=DEFAULT_STATIC)
    p.add_argument("--backups",type=Path,default=DEFAULT_BACKUPS)
    p.add_argument("--apply",action="store_true")
    p.add_argument("--skip-details",action="store_true",help="For tests only; do not use for a complete publication")
    args=p.parse_args()
    report=refresh(args.database,args.static,args.backups,apply=args.apply,details=not args.skip_details)
    print(json.dumps(report,indent=2))


if __name__=="__main__":
    main()
