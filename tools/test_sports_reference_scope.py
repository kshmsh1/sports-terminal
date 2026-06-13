from __future__ import annotations

import unittest

from sports_reference.url_scope import BasketballReferenceUrlScope


class BasketballReferenceScopeTest(unittest.TestCase):
    def test_index_seed_catalog_is_unique(self) -> None:
        scope = BasketballReferenceUrlScope()
        seeds = scope.site_index_seeds()
        self.assertGreater(len(seeds), 30)
        self.assertEqual(len(seeds), len({seed.url for seed in seeds}))

    def test_detail_routes_are_classified(self) -> None:
        scope = BasketballReferenceUrlScope()
        examples = {
            "https://www.basketball-reference.com/players/t/tatumja01/shooting/2025/": "player_detail",
            "https://www.basketball-reference.com/teams/BOS/2025/gamelog/": "team_season_detail",
            "https://www.basketball-reference.com/contracts/players.html": "contract",
            "https://www.basketball-reference.com/teams/BOS/2025_matchups.html": "data_page",
        }
        for url, family in examples.items():
            scoped = scope.classify(url)
            self.assertIsNotNone(scoped)
            self.assertEqual(scoped.page_family, family)

    def test_non_data_routes_are_rejected(self) -> None:
        scope = BasketballReferenceUrlScope()
        self.assertIsNone(
            scope.classify("https://www.basketball-reference.com/blog/example.html")
        )
        self.assertIsNone(scope.classify("https://example.com/teams/BOS/2025.html"))


if __name__ == "__main__":
    unittest.main()
