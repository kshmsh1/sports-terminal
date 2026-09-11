from __future__ import annotations

import json
import tempfile
from pathlib import Path

from nba_research_catalog import CATALOG_CONTRACT, build_research_catalog
from validate_nba_static_corpus_v2 import validate


def _write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="sports-terminal-research-catalog-") as temp:
        root = Path(temp)
        _write(
            root / "manifest.json",
            {
                "contract": "sports-terminal-static-nba-website-v5",
                "runtime": {"historical_http_api_required": False},
                "latest_season": "2025-26",
            },
        )
        _write(
            root / "seasons.json",
            [
                {
                    "season_id": "2025-26",
                    "players": 500,
                    "teams": 30,
                    "games": 1230,
                },
                {
                    "season_id": "2024-25",
                    "players": 500,
                    "teams": 30,
                    "games": 1230,
                },
            ],
        )
        _write(root / "players/index.json", [{"player_key": "player-1"}])
        _write(root / "teams/index.json", [{"team_key": "team-1"}])
        _write(root / "games/index.json", [{"game_key": "game-1"}])
        _write(root / "history/awards.json", [{"award": "MVP"}])
        _write(root / "history/draft.json", [])
        _write(
            root / "data_foundation.json",
            {
                "contract": "sports-terminal-nba-data-foundation-v1",
                "source_precedence": {"identity": ["canonical_warehouse"]},
                "providers": [
                    {
                        "key": "canonical_warehouse",
                        "available": True,
                    },
                    {
                        "key": "manual_awards",
                        "available": True,
                    },
                ],
            },
        )
        for season in ("2025-26", "2024-25"):
            for season_type in ("regular", "playoffs"):
                _write(
                    root / "seasons" / season / f"{season_type}.json",
                    {
                        "manifest": {"season": season},
                        "players": [],
                        "teams": [],
                    },
                )

        catalog = build_research_catalog(root, project_root=root)
        assert catalog["contract"] == CATALOG_CONTRACT
        assert catalog["runtime_network_required"] is False
        assert catalog["historical_delivery"] == "static"
        assert "investigate" in catalog["action_grammar"]
        assert "export" in catalog["action_grammar"]

        by_key = {
            row["key"]: row
            for row in catalog["datasets"]
            if isinstance(row, dict) and row.get("key")
        }
        for required in (
            "identity",
            "traditional_player_seasons",
            "advanced_player_seasons",
            "games_boxscores",
            "play_by_play",
            "possessions",
            "lineups",
            "shots",
            "awards",
        ):
            assert required in by_key, required
        assert by_key["identity"]["status"] == "available"
        assert by_key["awards"]["status"] == "available"

        result = validate(root)
        assert result["ok"], result["errors"]
        assert result["season_count"] == 2

    print("NBA research catalog contract test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
