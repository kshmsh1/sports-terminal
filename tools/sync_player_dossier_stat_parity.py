"""Sync enriched published Stats and Advanced Stats to per-player static dossiers.

Invoke after NBA.com and other local source-enrichment passes, not just after
the canonical base compiler. This prevents per-player historical profiles from
lagging behind the season tables after late overlay materialization.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.player_dossier_stat_parity import overlay_published_season


def sync(root: Path) -> tuple[int, int]:
    index_path = root / "players/index.json"
    seasons_path = root / "seasons.json"
    if not index_path.is_file() or not seasons_path.is_file():
        raise FileNotFoundError("Static NBA player index or season catalog missing")
    player_index = json.loads(index_path.read_text(encoding="utf-8"))
    season_catalog = json.loads(seasons_path.read_text(encoding="utf-8"))

    # Retain only the known player-season envelopes, not every other dashboard,
    # box-score, game or site document in the season payload.
    published: dict[str, list[tuple[str, str, dict[str, Any]]]] = {}
    for season in season_catalog:
        season_id = str(season.get("season_id") or season.get("id") or "")
        if not season_id:
            continue
        for segment in ("regular", "playoffs"):
            path = root / "seasons" / season_id / f"{segment}.json"
            if not path.is_file():
                continue
            snapshot = json.loads(path.read_text(encoding="utf-8"))
            for row in snapshot.get("player_season_totals", []):
                if not isinstance(row, dict):
                    continue
                player_id = str(row.get("player_id") or "")
                if player_id:
                    published.setdefault(player_id, []).append(
                        (season_id, segment, row)
                    )

    updated = updated_measures = 0
    for player in player_index:
        player_key = str(player.get("player_key") or "")
        file = str(player.get("file") or "")
        if not player_key or not file:
            continue
        path = (root / file).resolve()
        if not path.is_relative_to(root.resolve()) or not path.is_file():
            continue
        dossier = json.loads(path.read_text(encoding="utf-8"))
        merged = 0
        for season_id, segment, source in published.get(player_key, []):
            merged += overlay_published_season(
                dossier, {"player_season_totals": [source]},
                season_id, segment,
            )
        if merged:
            temp = path.with_suffix(path.suffix + ".tmp")
            temp.write_text(
                json.dumps(dossier, ensure_ascii=False, separators=(",", ":")),
                encoding="utf-8",
            )
            temp.replace(path)
            updated += 1
            updated_measures += merged
    return updated, updated_measures


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default=str(ROOT / "web/data/nba_static"))
    args = parser.parse_args()
    changed, values = sync(Path(args.output).expanduser().resolve())
    print(
        f"Player dossier stat parity: updated {changed} player profiles; "
        f"added {values} published measures without inventing source data."
    )


if __name__ == "__main__":
    main()
