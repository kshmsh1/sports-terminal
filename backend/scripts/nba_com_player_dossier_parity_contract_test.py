"""Ensure the browser player dossier and league season shard expose identical
NBA.com-derived metrics, without guessing traded-player team splits."""
from __future__ import annotations

import json
import tempfile
from pathlib import Path

from tools.nba_com_static_enrichment import sync_enriched_player_dossiers


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="arcside-player-parity-") as tmp:
        root = Path(tmp)
        (root / "players").mkdir()
        (root / "players/one.json").write_text(json.dumps({
            "profile": {"canonical_name": "Example One"},
            "regular_seasons": [
                {"season_id": "2025-26", "season_type": "regular",
                 "team_abbreviation": "BOS", "games": 80},
            ],
            "playoff_seasons": [
                {"season_id": "2025-26", "season_type": "playoffs",
                 "team_abbreviation": "BOS", "games": 15},
            ],
            "seasons": [
                {"season_id": "2025-26", "season_type": "regular",
                 "team_abbreviation": "BOS", "games": 80},
                {"season_id": "2025-26", "season_type": "playoffs",
                 "team_abbreviation": "BOS", "games": 15},
            ],
        }), encoding="utf-8")
        (root / "players/two.json").write_text(json.dumps({
            "regular_seasons": [
                {"season_id": "2025-26", "season_type": "regular",
                 "team_abbreviation": "TOT", "games": 79},
                {"season_id": "2025-26", "season_type": "regular",
                 "team_abbreviation": "MIA", "games": 34},
                {"season_id": "2025-26", "season_type": "regular",
                 "team_abbreviation": "LAL", "games": 45},
            ],
        }), encoding="utf-8")
        (root / "players/index.json").write_text(json.dumps([
            {"player_key": "nba_one", "file": "players/one.json"},
            {"player_key": "nba_two", "file": "players/two.json"},
        ]), encoding="utf-8")
        updates = {
            ("nba_one", "2025-26", "regular"): {
                "team_ids": "BOS",
                "nba_com_enriched_keys": ["deflections_pg", "bio_country"],
                "deflections_pg": 3.2,
                "bio_country": "Canada",
                "nba_com_sources": ["players_hustle", "players_bio"],
            },
            ("nba_one", "2025-26", "playoffs"): {
                "team_ids": "BOS",
                "nba_com_enriched_keys": ["deflections_pg"],
                "deflections_pg": 2.1,
            },
            ("nba_two", "2025-26", "regular"): {
                "team_ids": "2TM",
                "nba_com_enriched_keys": ["usg_pct"],
                "usg_pct": .341,
            },
        }
        changed = sync_enriched_player_dossiers(root, updates)
        assert changed == 2, changed
        first = json.loads((root / "players/one.json").read_text(encoding="utf-8"))
        assert first["regular_seasons"][0]["deflections_pg"] == 3.2, first
        assert first["regular_seasons"][0]["bio_country"] == "Canada", first
        assert first["playoff_seasons"][0]["deflections_pg"] == 2.1, first
        assert first["seasons"][1]["deflections_pg"] == 2.1, first
        assert first["seasons"][0]["deflections_pg"] == 3.2, first
        second = json.loads((root / "players/two.json").read_text(encoding="utf-8"))
        assert second["regular_seasons"][0]["usg_pct"] == .341, second
        assert "usg_pct" not in second["regular_seasons"][1], second
        assert "usg_pct" not in second["regular_seasons"][2], second
        assert sync_enriched_player_dossiers(root, {}) == 0

    print("Arcside NBA.com player dossier/league parity contract passed.")


if __name__ == "__main__":
    main()
