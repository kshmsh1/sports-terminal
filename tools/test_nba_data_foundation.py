from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tools.nba_data_foundation import (
    DATA_FOUNDATION_CONTRACT,
    build_data_foundation,
)


class NbaDataFoundationTest(unittest.TestCase):
    def test_builds_offline_source_catalog_and_updates_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw) / "sports-terminal"
            parent = root.parent
            output = root / "web" / "data" / "nba_static"
            output.mkdir(parents=True)

            (output / "history").mkdir()
            (output / "history" / "awards.json").write_text(
                json.dumps([{"award": "Example"}]),
                encoding="utf-8",
            )
            (output / "manifest.json").write_text(
                json.dumps(
                    {
                        "contract": "sports-terminal-static-nba-website-v5",
                        "schema_version": 5,
                        "season_count": 77,
                        "latest_season": "2025-26",
                    }
                ),
                encoding="utf-8",
            )

            database = parent / "data" / "warehouse" / "nba_history.sqlite"
            database.parent.mkdir(parents=True)
            database.write_bytes(b"not-empty")

            nba_com = parent / "raw" / "nba_com_stats" / "normalized"
            nba_com.mkdir(parents=True)
            (nba_com / "capture.json").write_text("{}", encoding="utf-8")

            sportsdataverse = (
                parent / "raw" / "sportsdataverse" / "nba"
            )
            sportsdataverse.mkdir(parents=True)
            (sportsdataverse / "manifest.json").write_text(
                json.dumps(
                    {
                        "datasets": [
                            {
                                "dataset": "schedule",
                                "seasons": [2025, 2026],
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )

            pbpstats = parent / "raw" / "pbpstats" / "pbp"
            pbpstats.mkdir(parents=True)
            (pbpstats / "0022500001.json").write_text("{}", encoding="utf-8")

            basketball_reference = parent / "raw" / "basketball_reference"
            basketball_reference.mkdir(parents=True)
            (basketball_reference / "source_entity_index.json").write_text(
                json.dumps({"mappingCount": 12}),
                encoding="utf-8",
            )

            payload = build_data_foundation(
                output,
                database,
                project_root=root,
                parent_root=parent,
            )

            self.assertEqual(payload["contract"], DATA_FOUNDATION_CONTRACT)
            self.assertFalse(
                payload["architecture"]["dynamic_api_required_for_historical_stats"]
            )
            self.assertFalse(payload["architecture"]["browser_calls_nba_com"])
            self.assertIn("canonical_warehouse", payload["available_providers"])
            self.assertIn("nba_com_captures", payload["available_providers"])
            self.assertIn(
                "sportsdataverse_releases",
                payload["available_providers"],
            )
            self.assertIn("pbpstats_cache", payload["available_providers"])
            self.assertIn("basketball_reference", payload["available_providers"])
            self.assertIn("manual_awards", payload["available_providers"])

            data_path = output / "data_foundation.json"
            self.assertTrue(data_path.is_file())

            manifest = json.loads(
                (output / "manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(
                manifest["data_foundation"]["contract"],
                DATA_FOUNDATION_CONTRACT,
            )
            self.assertFalse(
                manifest["data_foundation"]["runtime_network_required"]
            )

    def test_empty_optional_sources_stay_registered_but_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw) / "sports-terminal"
            output = root / "web" / "data" / "nba_static"
            output.mkdir(parents=True)
            (output / "manifest.json").write_text(
                json.dumps(
                    {
                        "season_count": 1,
                        "latest_season": "2025-26",
                    }
                ),
                encoding="utf-8",
            )

            payload = build_data_foundation(
                output,
                None,
                project_root=root,
                parent_root=root.parent,
            )

            providers = {
                row["key"]: row
                for row in payload["providers"]
            }
            self.assertEqual(len(providers), 6)
            self.assertFalse(
                providers["sportsdataverse_releases"]["local"]["available"]
            )
            self.assertFalse(
                providers["pbpstats_cache"]["local"]["available"]
            )
            self.assertFalse(
                providers["nba_com_captures"]["local"]["available"]
            )


if __name__ == "__main__":
    unittest.main()
