from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "build_nba_source_coverage_manifest.py"


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload), encoding="utf-8")


def main() -> int:
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        static = root / "static"
        nba = root / "nba_com"
        sdv = root / "sportsdataverse"
        bref = root / "basketball_reference"
        pbp = root / "pbpstats"
        output = static / "source_coverage.json"

        _write_json(
            static / "manifest.json",
            {
                "nba_com_enrichment": {
                    "enriched_player_rows": 10,
                    "matched_source_rows": 20,
                    "unmatched_source_rows": 1,
                }
            },
        )
        _write_json(
            nba / "players_hustle" / "2025-26" / "normalized.json",
            {"rows": []},
        )
        _write_json(
            sdv / "manifest.json",
            {
                "datasets": [
                    {"dataset": "stats_possessions", "seasons": [2025, 2026]},
                    {"dataset": "stats_lineups", "seasons": [2025, 2026]},
                ]
            },
        )
        _write_json(
            bref / "manifest.json",
            {
                "datasets": [
                    {"dataset": "player_advanced", "season_end_year": 2026},
                    {"dataset": "shooting", "season_end_year": 2026},
                ]
            },
        )
        _write_json(pbp / "pbp" / "sample.json", {"game": "fixture"})

        subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--output",
                str(output),
                "--static-root",
                str(static),
                "--nba-com-root",
                str(nba),
                "--sportsdataverse-root",
                str(sdv),
                "--basketball-reference-root",
                str(bref),
                "--pbpstats-root",
                str(pbp),
            ],
            check=True,
        )

        payload = json.loads(output.read_text(encoding="utf-8"))
        assert payload["contract"] == "sports-terminal-nba-source-coverage-v1"
        assert payload["architecture"]["historical_runtime"] == "static-first"
        assert (
            payload["architecture"]["browser_runtime_external_scraping_required"]
            is False
        )
        assert payload["available_source_count"] == 4

        sources = {row["id"]: row for row in payload["sources"]}
        assert sources["nba_com"]["materialized_player_season_rows"] == 10
        assert sources["sportsdataverse"]["dataset_count"] == 2
        assert sources["sportsdataverse"]["season_end_year_min"] == 2025
        assert sources["sportsdataverse"]["season_end_year_max"] == 2026
        assert sources["basketball_reference"]["dataset_count"] == 2
        assert sources["basketball_reference"]["season_end_year_min"] == 2026
        assert sources["basketball_reference"]["season_end_year_max"] == 2026
        assert sources["pbpstats"]["available"] is True

    print("NBA source coverage manifest: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
