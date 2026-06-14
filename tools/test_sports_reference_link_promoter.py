from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from sports_reference.link_promoter import StoredLinkPromoter
from sports_reference.page_store import SportsReferencePageStore
from sports_reference.schema_review import SportsReferenceSchemaReview


class StoredLinkPromoterTest(unittest.TestCase):
    def test_promotes_completed_page_links_without_refetching(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = SportsReferencePageStore(Path(directory) / "catalog.sqlite")
            source_url = "https://www.basketball-reference.com/leagues/NBA_2025.html"
            store.enqueue(
                source_url,
                "league",
                depth=0,
                season_end_year=2025,
                priority=10,
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
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    [
                        (
                            source_url,
                            "https://www.basketball-reference.com/teams/BOS/2025.html",
                            "team_season",
                            "basketball-reference:team-season:BOS:2025",
                            2025,
                            "BOS",
                            30,
                            "Boston Celtics",
                        ),
                        (
                            source_url,
                            "https://www.basketball-reference.com/players/t/tatumja01.html",
                            "player",
                            "basketball-reference:player:tatumja01",
                            None,
                            None,
                            50,
                            "Jayson Tatum",
                        ),
                    ],
                )

            promoter = StoredLinkPromoter(store)
            dry_run = promoter.promote(
                families={"team_season", "player"},
                start_year=2025,
                end_year=2025,
                source_depth=0,
                dry_run=True,
            )
            self.assertEqual(dry_run.candidate_count, 2)
            self.assertEqual(dry_run.inserted_count, 0)
            self.assertEqual(store.status()["pages"]["complete"], 1)

            applied = promoter.promote(
                families={"team_season", "player"},
                start_year=2025,
                end_year=2025,
                source_depth=0,
            )
            self.assertEqual(applied.inserted_count, 2)
            status = store.status()
            self.assertEqual(status["pages"]["queued"], 2)

            second = promoter.promote(
                families={"team_season", "player"},
                start_year=2025,
                end_year=2025,
                source_depth=0,
            )
            self.assertEqual(second.inserted_count, 0)
            self.assertEqual(second.existing_count, 2)

    def test_filters_source_family_and_repairs_inherited_season(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = SportsReferencePageStore(Path(directory) / "catalog.sqlite")
            league_url = "https://www.basketball-reference.com/leagues/NBA_2025_games.html"
            playoff_url = "https://www.basketball-reference.com/playoffs/NBA_2025.html"
            regular_game = "https://www.basketball-reference.com/boxscores/202410220BOS.html"
            playoff_game = "https://www.basketball-reference.com/boxscores/202504190OKC.html"

            for url, family in ((league_url, "league"), (playoff_url, "playoff")):
                store.enqueue(
                    url,
                    family,
                    depth=0,
                    season_end_year=2025,
                    priority=10,
                )
                with store.connect() as db:
                    db.execute(
                        "UPDATE pages SET status = 'complete' WHERE url = ?",
                        (url,),
                    )

            store.enqueue(playoff_game, "boxscore", depth=1, priority=40)
            with store.connect() as db:
                db.execute(
                    """
                    INSERT INTO discovered_links(
                      source_url, target_url, page_family, source_key,
                      season_end_year, team_abbreviation, priority, anchor_text
                    ) VALUES (?, ?, 'boxscore', ?, NULL, NULL, 40, 'Box Score')
                    """,
                    (
                        league_url,
                        regular_game,
                        "basketball-reference:game:202410220BOS",
                    ),
                )
                db.execute(
                    """
                    INSERT INTO discovered_links(
                      source_url, target_url, page_family, source_key,
                      season_end_year, team_abbreviation, priority, anchor_text
                    ) VALUES (?, ?, 'boxscore', ?, NULL, NULL, 40, 'Box Score')
                    """,
                    (
                        playoff_url,
                        playoff_game,
                        "basketball-reference:game:202504190OKC",
                    ),
                )

            promoter = StoredLinkPromoter(store)
            preview = promoter.promote(
                families={"boxscore"},
                source_families={"playoff"},
                start_year=2025,
                end_year=2025,
                source_depth=0,
                dry_run=True,
            )
            self.assertEqual(preview.candidate_count, 1)
            self.assertEqual(preview.existing_count, 1)
            self.assertEqual(preview.metadata_update_count, 1)

            applied = promoter.promote(
                families={"boxscore"},
                source_families={"playoff"},
                start_year=2025,
                end_year=2025,
                source_depth=0,
            )
            self.assertEqual(applied.inserted_count, 0)
            with store.connect() as db:
                page = db.execute(
                    "SELECT season_end_year FROM pages WHERE url = ?",
                    (playoff_game,),
                ).fetchone()
            self.assertEqual(page["season_end_year"], 2025)

    def test_filters_detail_targets_by_path_prefix(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = SportsReferencePageStore(Path(directory) / "catalog.sqlite")
            source_url = "https://www.basketball-reference.com/boxscores/202504190OKC.html"
            store.enqueue(
                source_url,
                "boxscore",
                depth=1,
                season_end_year=2025,
                priority=40,
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
                    ) VALUES (?, ?, 'boxscore_detail', ?, NULL, NULL, 42, ?)
                    """,
                    [
                        (
                            source_url,
                            "https://www.basketball-reference.com/boxscores/pbp/202504190OKC.html",
                            "basketball-reference:game-detail:pbp:202504190OKC",
                            "Play-by-Play",
                        ),
                        (
                            source_url,
                            "https://www.basketball-reference.com/boxscores/shot-chart/202504190OKC.html",
                            "basketball-reference:game-detail:shot-chart:202504190OKC",
                            "Shot Chart",
                        ),
                        (
                            source_url,
                            "https://www.basketball-reference.com/boxscores/plus-minus/202504190OKC.html",
                            "basketball-reference:game-detail:plus-minus:202504190OKC",
                            "Plus/Minus",
                        ),
                    ],
                )

            preview = StoredLinkPromoter(store).promote(
                families={"boxscore_detail"},
                source_families={"boxscore"},
                target_path_prefix="/boxscores/pbp/",
                start_year=2025,
                end_year=2025,
                source_depth=1,
                dry_run=True,
            )
            self.assertEqual(preview.candidate_count, 1)
            self.assertEqual(preview.families, {"boxscore_detail": 1})

    def test_schema_review_ignores_anonymous_cross_page_collisions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = SportsReferencePageStore(Path(directory) / "catalog.sqlite")
            with store.connect() as db:
                db.executemany(
                    """
                    INSERT INTO pages(
                      url, page_family, status, depth, attempts,
                      table_count, link_count, html_bytes, updated_at
                    ) VALUES (?, ?, 'complete', 0, 0, 1, 0, 0, 'now')
                    """,
                    [
                        ("https://example.test/league", "league"),
                        ("https://example.test/playoff", "playoff"),
                    ],
                )
                db.executemany(
                    """
                    INSERT INTO tables(
                      page_url, table_id, ordinal, caption, columns_json,
                      schema_hash, link_count, row_count
                    ) VALUES (?, ?, 1, NULL, '[]', ?, 0, 1)
                    """,
                    [
                        ("https://example.test/league", "anonymous_1", "a"),
                        ("https://example.test/playoff", "anonymous_1", "b"),
                        ("https://example.test/league", "advanced-team", "c"),
                        ("https://example.test/playoff", "advanced-team", "d"),
                    ],
                )

            review = SportsReferenceSchemaReview(store).build()
            self.assertEqual(review["actionableWithinFamily"], [])
            self.assertEqual(
                review["expectedCrossFamilyVariation"][0]["tableId"],
                "advanced-team",
            )
            self.assertEqual(
                review["anonymousTableSummary"]["tableInstances"],
                2,
            )


if __name__ == "__main__":
    unittest.main()
