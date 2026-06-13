from __future__ import annotations

import unittest

from normalize_team_table import build_stats, team_abbreviation
from prepare_player_stats import build_stat, choose_aggregate
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

    def test_team_normalizer_reads_provider_team_link_and_metrics(self) -> None:
        row = {
            "cells": {
                "team": {
                    "text": "Boston Celtics*",
                    "value": "Boston Celtics*",
                    "links": [
                        {
                            "sourceKey": "basketball-reference:team-season:BOS:2026",
                            "href": "https://www.basketball-reference.com/teams/BOS/2026.html",
                        }
                    ],
                },
                "pts": {"text": "114.9", "value": 114.9, "links": []},
                "trb": {"text": "46.4", "value": 46.4, "links": []},
                "fg_pct": {"text": ".467", "value": 0.467, "links": []},
            }
        }
        self.assertEqual(team_abbreviation(row), "BOS")
        stat = build_stats(
            row,
            "boston-celtics",
            "2025-26",
            "source",
            "2026-06-13",
        )
        self.assertEqual(stat["pointsPerGame"], 114.9)
        self.assertEqual(stat["reboundsPerGame"], 46.4)
        self.assertEqual(stat["fieldGoalPercentage"], 0.467)

    def test_player_normalizer_prefers_total_row_and_builds_contract(self) -> None:
        team_row = {
            "cells": {
                "player": {"text": "Example Player", "value": "Example Player", "links": []},
                "team": {"text": "BOS", "value": "BOS", "links": []},
                "g": {"text": "20", "value": 20, "links": []},
                "pts_per_g": {"text": "12.0", "value": 12.0, "links": []},
            }
        }
        total_row = {
            "cells": {
                "player": {"text": "Example Player", "value": "Example Player", "links": []},
                "team": {"text": "TOT", "value": "TOT", "links": []},
                "g": {"text": "50", "value": 50, "links": []},
                "pts_per_g": {"text": "15.5", "value": 15.5, "links": []},
            }
        }
        chosen, method = choose_aggregate([team_row, total_row])
        self.assertIs(chosen, total_row)
        self.assertEqual(method, "provider-total-row")
        stat = build_stat(
            total_row,
            None,
            "example-player",
            None,
            "2025-26",
            "source",
            "2026-06-13",
        )
        self.assertEqual(stat["gamesPlayed"], 50)
        self.assertEqual(stat["pointsPerGame"], 15.5)
        self.assertEqual(stat["seasonType"], "Regular Season")


if __name__ == "__main__":
    unittest.main()
