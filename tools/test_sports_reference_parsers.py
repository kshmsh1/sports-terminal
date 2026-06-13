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
            minimum_interval_seconds=7.0,
        )

    def test_request_policy_is_minimal_and_bounded(self) -> None:
        self.assertEqual(self.client.minimum_interval_seconds, 7.0)
        self.assertEqual(
            set(self.client.session.headers),
            {"User-Agent", "Accept"},
        )
        with self.assertRaises(ValueError):
            SportsReferenceClient(minimum_interval_seconds=5.9)
        with self.assertRaises(ValueError):
            SportsReferenceClient(minimum_interval_seconds=8.1)

    def test_visible_and_commented_tables_are_found(self) -> None:
        visible = '<table id="per_game"><tr><td>A</td></tr></table>'
        commented = '<!-- <table id="advanced"><tr><td>B</td></tr></table> -->'
        self.assertEqual(
            self.client.find_table(visible, ("per_game",))[1],
            "per_game",
        )
        self.assertEqual(
            self.client.find_table(commented, ("advanced",))[1],
            "advanced",
        )

    def test_linked_cells_and_header_exclusion(self) -> None:
        html = """
        <table id="sample"><thead><tr><th data-stat="player">Player</th>
        <th data-stat="team">Team</th><th data-stat="pts">PTS</th></tr></thead>
        <tbody><tr><td data-stat="player"><a href="/players/t/tatumja01.html">Jayson Tatum</a></td>
        <td data-stat="team"><a href="/teams/BOS/2026.html">BOS</a></td>
        <td data-stat="pts">31.5</td></tr></tbody></table>
        """
        table = self.client.expanded_soup(html).find("table")
        result = LinkedTableExtractor().extract_table(
            table,
            "https://www.basketball-reference.com/leagues/NBA_2026.html",
        )
        self.assertEqual(result["rowCount"], 1)
        cells = result["rows"][0]["cells"]
        self.assertEqual(cells["pts"]["value"], 31.5)
        self.assertEqual(cells["player"]["links"][0]["entityType"], "player")
        self.assertEqual(cells["team"]["links"][0]["entityType"], "team-season")

    def test_sections_and_repeated_headers_are_preserved(self) -> None:
        html = """
        <table><thead><tr><th data-stat="season">Season</th><th data-stat="pts">PTS</th></tr></thead>
        <tbody><tr><th colspan="2">Per Game</th></tr>
        <tr><th data-stat="season">2025-26</th><td data-stat="pts">25.7</td></tr>
        <tr class="thead"><th>Season</th><th>PTS</th></tr>
        <tr><th data-stat="season">2024-25</th><td data-stat="pts">21.3</td></tr></tbody></table>
        """
        table = self.client.expanded_soup(html).find("table")
        result = LinkedTableExtractor().extract_table(
            table,
            "https://www.basketball-reference.com/players/t/tatumja01.html",
        )
        self.assertEqual(result["rowCount"], 2)
        self.assertEqual([row["section"] for row in result["rows"]], ["Per Game", "Per Game"])

    def test_team_and_player_normalizers(self) -> None:
        team_row = {
            "cells": {
                "team": {
                    "text": "Boston Celtics*",
                    "value": "Boston Celtics*",
                    "links": [{"sourceKey": "basketball-reference:team-season:BOS:2026"}],
                },
                "pts": {"value": 114.9},
                "trb": {"value": 46.4},
                "fg_pct": {"value": 0.467},
            }
        }
        self.assertEqual(team_abbreviation(team_row), "BOS")
        stats = build_stats(team_row, "boston-celtics", "2025-26", "source", "2026-06-13")
        self.assertEqual(stats["pointsPerGame"], 114.9)

        partial = {
            "cells": {
                "team": {"text": "BOS", "value": "BOS"},
                "g": {"value": 20},
            }
        }
        total = {
            "cells": {
                "team": {"text": "TOT", "value": "TOT"},
                "g": {"value": 50},
                "pts_per_g": {"value": 15.5},
            }
        }
        chosen, method = choose_aggregate([partial, total])
        self.assertIs(chosen, total)
        self.assertEqual(method, "provider-total-row")
        stat = build_stat(total, None, "example-player", None, "2025-26", "source", "2026-06-13")
        self.assertEqual(stat["gamesPlayed"], 50)


if __name__ == "__main__":
    unittest.main()
