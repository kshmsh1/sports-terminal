from __future__ import annotations

import unittest

from sports_reference.client import SportsReferenceClient


class SportsReferenceParserTest(unittest.TestCase):
    def setUp(self) -> None:
        self.client = SportsReferenceClient(
            cache_dir=".cache/test_sports_reference",
            minimum_interval_seconds=3.0,
        )

    def test_finds_visible_table(self) -> None:
        html = """
        <html><body>
          <table id="per_game_stats"><tr><th>Player</th></tr><tr><td>A Player</td></tr></table>
        </body></html>
        """
        table, table_id = self.client.find_table(html, ("per_game_stats",))
        self.assertEqual(table_id, "per_game_stats")
        self.assertEqual(table.find("td").get_text(strip=True), "A Player")

    def test_finds_table_inside_html_comment(self) -> None:
        html = """
        <html><body>
          <!-- <table id="advanced"><tr><th>Player</th></tr><tr><td>B Player</td></tr></table> -->
        </body></html>
        """
        table, table_id = self.client.find_table(html, ("advanced",))
        self.assertEqual(table_id, "advanced")
        self.assertEqual(table.find("td").get_text(strip=True), "B Player")

    def test_rejects_unknown_table(self) -> None:
        with self.assertRaises(LookupError):
            self.client.find_table("<html><body></body></html>", ("missing",))


if __name__ == "__main__":
    unittest.main()
