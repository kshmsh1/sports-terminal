from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from sync_player_profile_stats import sync


def write(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data), encoding="utf8")


def run_contract() -> None:
    with tempfile.TemporaryDirectory(prefix="arcside-player-profile-") as dirname:
        root = Path(dirname)
        write(root / "players/index.json", [
            {"player_key": "nba_1", "file": "players/p1.json"},
            {"player_key": "nba_2", "file": "players/p2.json"},
        ])
        original = {"profile": {"canonical_name": "Example"}, "regular_seasons": [],
                    "playoff_seasons": [], "awards": []}
        write(root / "players/p1.json", original)
        write(root / "players/p2.json", original)
        write(root / "seasons/2024-25/regular.json", {
            "player_season_totals": [
                {"player_id": "nba_1", "player_label": "Example",
                 "points": 800, "per": 23.2, "deflections": 4.1,
                 "hustle_deflections_pg": 4.1, "bio_country": "USA",
                 "three_pct": None, "team_stints": [{"team_ids": "AAA"}]},
                {"player_id": "nba_2", "player_label": "Other",
                 "points": 400, "hustle_deflections_pg": None},
            ]
        })
        write(root / "seasons/2024-25/playoffs.json", {
            "player_season_totals": [
                {"player_id": "nba_1", "player_label": "Example",
                 "points": 170, "hustle_deflections_pg": 5.0},
            ]
        })
        first = sync(root)
        assert first["player_files_updated"] == 2, first
        assert first["player_season_rows_attached"] == 3, first
        dossier = json.loads((root / "players/p1.json").read_text())
        assert len(dossier["stat_seasons"]) == 2
        regular = next(x for x in dossier["stat_seasons"]
                       if x["season_type"] == "regular")
        playoffs = next(x for x in dossier["stat_seasons"]
                        if x["season_type"] == "playoffs")
        assert regular["hustle_deflections_pg"] == 4.1
        assert regular["bio_country"] == "USA"
        assert regular["three_pct"] is None
        assert regular["team_stints"][0]["team_ids"] == "AAA"
        assert playoffs["hustle_deflections_pg"] == 5.0
        assert dossier["awards"] == original["awards"]
        again = sync(root)
        assert again["player_files_updated"] == 0, again
        print("Player-season dossier parity contract passed.")


if __name__ == "__main__":
    run_contract()
