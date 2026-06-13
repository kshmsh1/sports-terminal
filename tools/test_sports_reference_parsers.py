from __future__ import annotations

import unittest

from sports_reference.client import SportsReferenceClient
from sports_reference.table_extractor import LinkedTableExtractor


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

    def test_preserves_linked_player_team_season_and_game_cells(self) -> None:
        html = """
        <table id="sample">
          <thead><tr>
            <th data-stat="season">Season</th>
            <th data-stat="player">Player</th>
            <th data-stat="team">Team</th>
            <th data-stat="game">Game</th>
            <th data-stat="pts">PTS</th>
          </tr></thead>
          <tbody><tr>
            <th data-stat="season"><a href="/leagues/NBA_2026.html">2025-26</a></th>
            <td data-stat="player"><a href="/players/t/tatumja01.html">Jayson Tatum</a></td>
            <td data-stat="team"><a href="/teams/BOS/2026.html">BOS</a></td>
            <td data-stat="game"><a href="/boxscores/202601010BOS.html">Box Score</a></td>
            <td data-stat="pts">31.5</td>
          </tr></tbody>
        </table>
        """
        soup = self.client.expanded_soup(html)
        extracted = LinkedTableExtractor().extract_table(
            soup.find("table"),
            "https://www.basketball-reference.com/leagues/NBA_2026.html",
        )
        cells = extracted["rows"][0]["cells"]

        self.assertEqual(cells["pts"]["value"], 31.5)
        self.assertEqual(cells["player"]["links"][0]["entityType"], "player")
        self.assertEqual(
            cells["player"]["links"][0]["sourceKey"],
            "basketball-reference:player:tatumja01",
        )
        self.assertEqual(cells["team"]["links"][0]["entityType"], "team-season")
        self.assertEqual(cells["season"]["links"][0]["entityType"], "season")
        self.assertEqual(cells["game"]["links"][0]["entityType"], "game")
        self.assertEqual(extracted["linkCount"], 4)

    def test_preserves_section_rows_and_repeated_headers(self) -> None:
        html = """
        <table id="playoffs_series">
          <thead><tr><th data-stat="season">Season</th><th data-stat="pts">PTS</th></tr></thead>
          <tbody>
            <tr><th colspan="2">Per Game</th></tr>
            <tr><th data-stat="season">2025-26</th><td data-stat="pts">25.7</td></tr>
            <tr class="thead"><th data-stat="season">Season</th><th data-stat="pts">PTS</th></tr>
            <tr><th data-stat="season">2024-25</th><td data-stat="pts">21.3</td></tr>
          </tbody>
        </table>
        """
        soup = self.client.expanded_soup(html)
        extracted = LinkedTableExtractor().extract_table(
            soup.find("table"),
            "https://www.basketball-reference.com/players/t/tatumja01.html",
        )

        self.assertEqual(extracted["rowCount"], 2)
        self.assertEqual(extracted["rows"][0]["section"], "Per Game")
        self.assertEqual(extracted["rows"][1]["section"], "Per Game")


if __name__ == "__main__":
    unittest.main()
