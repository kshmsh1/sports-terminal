from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from sports_reference.link_promoter import StoredLinkPromoter
from sports_reference.page_store import SportsReferencePageStore
from sports_reference.queue_maintenance import QueueMaintenance


class QueueMaintenanceTest(unittest.TestCase):
    def test_target_season_filter_excludes_next_season_team_links(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = SportsReferencePageStore(Path(directory) / "catalog.sqlite")
            source_url = "https://www.basketball-reference.com/draft/NBA_2025.html"
            store.enqueue(
                source_url,
                "draft",
                depth=0,
                season_end_year=2025,
                priority=35,
            )
            with store.connect() as db:
                db.execute(
                    "UPDATE pages SET status = 'complete' WHERE url = ?",
                    (source_url,),
                )
                db.executemany(
                    """
                    INSERT INTO discovered_links(
                      source_url, target_url, page_family, source_key,
                      season_end_year, team_abbreviation, priority, anchor_text
                    ) VALUES (?, ?, 'team_season', ?, ?, ?, 30, ?)
                    """,
                    [
                        (
                            source_url,
                            "https://www.basketball-reference.com/teams/ATL/2025.html",
                            "basketball-reference:team-season:ATL:2025",
                            2025,
                            "ATL",
                            "Atlanta Hawks",
                        ),
                        (
                            source_url,
                            "https://www.basketball-reference.com/teams/ATL/2026.html",
                            "basketball-reference:team-season:ATL:2026",
                            2026,
                            "ATL",
                            "Atlanta Hawks",
                        ),
                    ],
                )

            summary = StoredLinkPromoter(store).promote(
                families={"team_season"},
                start_year=2025,
                end_year=2025,
                source_depth=0,
            )
            self.assertEqual(summary.candidate_count, 1)
            self.assertEqual(summary.inserted_count, 1)
            queued = store.queue_sample("queued", 10)
            self.assertEqual(len(queued), 1)
            self.assertEqual(queued[0]["seasonEndYear"], 2025)

    def test_prune_removes_only_unfetched_out_of_range_pages(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = SportsReferencePageStore(Path(directory) / "catalog.sqlite")
            pages = [
                ("https://example.test/ATL/2025", "queued", 2025),
                ("https://example.test/ATL/2026", "queued", 2026),
                ("https://example.test/BOS/2026", "skipped", 2026),
                ("https://example.test/CHI/2026", "failed", 2026),
                ("https://example.test/DEN/2026", "complete", 2026),
            ]
            for url, status, season in pages:
                store.enqueue(
                    url,
                    "team_season",
                    season_end_year=season,
                    priority=30,
                )
                with store.connect() as db:
                    db.execute(
                        "UPDATE pages SET status = ? WHERE url = ?",
                        (status, url),
                    )

            maintenance = QueueMaintenance(store)
            preview = maintenance.prune_outside_season_range(
                families={"team_season"},
                start_year=2025,
                end_year=2025,
                dry_run=True,
            )
            self.assertEqual(preview.matched_count, 3)
            self.assertEqual(preview.deleted_count, 0)

            applied = maintenance.prune_outside_season_range(
                families={"team_season"},
                start_year=2025,
                end_year=2025,
            )
            self.assertEqual(applied.deleted_count, 3)
            with store.connect() as db:
                remaining = {
                    row["url"]: row["status"]
                    for row in db.execute("SELECT url, status FROM pages")
                }
            self.assertEqual(
                remaining,
                {
                    "https://example.test/ATL/2025": "queued",
                    "https://example.test/DEN/2026": "complete",
                },
            )


if __name__ == "__main__":
    unittest.main()
