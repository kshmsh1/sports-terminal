#!/usr/bin/env python3
"""Embed the *same* enriched player-season records used by Arcside Stats.

The canonical dossier tables lack many NBA.com advanced fields. The finished
static season shards are authoritative for the Stats/Advanced Stats UI; this
post-processing step copies their player rows into each player dossier after
all enrichment passes. No runtime HTTP or database access is required.
"""
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path


def _read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def _write(path: Path, payload: dict):
    path.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
                    encoding="utf-8")


def sync(output: Path) -> dict[str, int]:
    players_path = output / "players" / "index.json"
    if not players_path.is_file():
        raise FileNotFoundError(f"Missing player index: {players_path}")
    index = _read(players_path)
    player_files = {
        str(row["player_key"]): str(row["file"])
        for row in index
        if row.get("player_key") and row.get("file")
    }
    by_player = defaultdict(list)
    seen = set()
    source_files = 0
    for path in sorted((output / "seasons").glob("*/regular.json")) + \
                sorted((output / "seasons").glob("*/playoffs.json")):
        payload = _read(path)
        segment = path.stem
        season = path.parent.name
        source_files += 1
        for item in payload.get("player_season_totals", []):
            if not isinstance(item, dict):
                continue
            pid = str(item.get("player_id") or item.get("id") or "")
            if pid not in player_files:
                continue
            key = (pid, season, segment)
            if key in seen:
                # Static season shards should have one aggregate per player.
                raise ValueError(f"Duplicate player-season in {path}: {pid}")
            seen.add(key)
            row = dict(item)
            row["season_id"] = season
            row["season_type"] = segment
            row["player_id"] = pid
            # Avoid recreating duplicate cross-season game rows: the source
            # Stats tables only need the season snapshot record.
            by_player[pid].append(row)

    updated = 0
    attached = 0
    for pid, rel in player_files.items():
        dest = output / rel
        if not dest.is_file():
            continue
        dossier = _read(dest)
        fresh = sorted(by_player.get(pid, []),
                       key=lambda r: (str(r["season_id"]), str(r["season_type"])))
        if dossier.get("stat_seasons") == fresh:
            continue
        dossier["stat_seasons"] = fresh
        dossier["stat_source"] = "published-season-shards"
        _write(dest, dossier)
        updated += 1
        attached += len(fresh)
    return {"season_shards": source_files, "player_files_updated": updated,
            "player_season_rows_attached": attached, "players_indexed": len(player_files)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("web/data/nba_static"))
    args = parser.parse_args()
    result = sync(args.output)
    print("Player profiles synchronized with Stats/Advanced Stats:", result)


if __name__ == "__main__":
    main()
