"""Regression coverage for standalone Arcside workspaces and profile parity."""
from __future__ import annotations

import sys
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "arcside_spreadsheet"))
sys.path.insert(0, str(ROOT))

from engine import Workbook, Sheet, Parser, normalize_ref, expand_range
from tools.player_dossier_stat_parity import overlay_published_season
from tools.sync_player_dossier_stat_parity import sync


class SpreadsheetTests(unittest.TestCase):
    def test_references_and_operations(self):
        sheet = Sheet("Model")
        sheet.set("A1", "100")
        sheet.set("A2", "200")
        sheet.set("B1", "=SUM(A1:A2)*1.05")
        self.assertAlmostEqual(sheet.value("B1"), 315)
        sheet.set("A1", "120")
        self.assertAlmostEqual(sheet.value("B1"), 336)
        sheet.set("B2", "=IF(B1>330,ROUND(B1/3,2),0)")
        self.assertEqual(sheet.value("B2"), 112)
        sheet.set("C1", "=AVERAGE(A1:A2)")
        self.assertEqual(sheet.value("C1"), 160)
        self.assertEqual(sheet.value("D1"), "")

    def test_circular_and_error_propagation(self):
        sheet = Sheet("Cycles")
        sheet.set("A1", "=B1+1")
        sheet.set("B1", "=A1+1")
        self.assertEqual(sheet.value("A1"), "#CIRC!")
        self.assertEqual(sheet.value("B1"), "#CIRC!")
        sheet.set("B1", "4")
        self.assertEqual(sheet.value("A1"), 5)
        sheet.set("C1", "=1/0")
        self.assertEqual(sheet.value("C1"), "#DIV/0!")
        sheet.set("D1", "=C1+2")
        self.assertEqual(sheet.value("D1"), "#DIV/0!")
        sheet.set("E1", "=IFERROR(C1,7)")
        self.assertEqual(sheet.value("E1"), 7)

    def test_no_arbitrary_python_execution(self):
        sheet = Sheet("Guard")
        sheet.set("A1", "=__import__(\"os\").system(\"whoami\")")
        self.assertEqual(sheet.value("A1"), "#ERROR!")
        sheet.set("A2", "=DO_EVIL(2)")
        self.assertEqual(sheet.value("A2"), "#NAME?")

    def test_workbook_json_and_csv(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "book.arcside.json"
            book = Workbook([Sheet("First")])
            book.sheets[0].set("A1", "18")
            book.sheets[0].set("B1", "=A1*2")
            book.add_sheet("Forecast")
            book.save(path)
            reopened = Workbook.load(path)
            self.assertEqual(reopened.sheets[0].value("B1"), 36)
            self.assertEqual(reopened.sheets[1].name, "Forecast")
            csv_path = Path(directory) / "first.csv"
            reopened.sheets[0].save_csv(csv_path)
            self.assertEqual(Sheet.load_csv(csv_path).value("B1"), 36)

    def test_range_addresses(self):
        self.assertEqual(normalize_ref("$AA$002"), "AA2")
        self.assertEqual(expand_range("B2", "A1"), ["A1","B1","A2","B2"])
        with self.assertRaises(ValueError):
            normalize_ref("XFE1")


class PlayerParityTests(unittest.TestCase):
    def test_source_only_joins_into_matching_player_and_segment(self):
        regular = {"season_id":"2025-26", "season_type":"regular",
                   "team_abbreviation":"LAL", "pts":1800}
        postseason = {"season_id":"2025-26", "season_type":"playoffs",
                      "team_abbreviation":"LAL"}
        dossier = {"profile":{"player_key":"nba_123"}, "seasons":[regular,postseason]}
        count = overlay_published_season(dossier, {
            "player_season_totals":[
                {"player_id":"nba_123","ts_pct":0.63,"deflections_pg":2.8,
                 "pts":9999,"team_abbreviation":"LAL"},
                {"player_id":"nba_999","per":49}
            ]
        }, "2025-26", "regular")
        self.assertEqual(count,2)
        self.assertEqual(regular["pts"],1800)
        self.assertEqual(regular["ts_pct"],0.63)
        self.assertEqual(regular["deflections_pg"],2.8)
        self.assertNotIn("ts_pct",postseason)

    def test_post_enrichment_static_sync_updates_player_profiles(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "players").mkdir()
            (root / "seasons/2025-26").mkdir(parents=True)
            (root / "seasons.json").write_text(
                json.dumps([{"season_id":"2025-26"}]))
            (root / "players/index.json").write_text(
                json.dumps([{"player_key":"nba_12","file":"players/test.json"}]))
            (root / "players/test.json").write_text(json.dumps({
                "profile":{"player_key":"nba_12"},
                "seasons":[{"season_id":"2025-26",
                            "season_type":"regular","team_abbreviation":"LAL"}],
                "regular_seasons":[],
                "playoff_seasons":[]
            }))
            (root / "seasons/2025-26/regular.json").write_text(
                json.dumps({"player_season_totals":[
                    {"player_id":"nba_12","deflections_pg":3.5,"ts_pct":0.62},
                    {"player_id":"nba_13","deflections_pg":10}
                ]}))
            changed, additions = sync(root)
            self.assertEqual(changed, 1)
            self.assertEqual(additions, 2)
            updated = json.loads((root / "players/test.json").read_text())
            self.assertEqual(updated["regular_seasons"][0]["deflections_pg"], 3.5)
            self.assertEqual(updated["regular_seasons"][0]["ts_pct"], 0.62)
            self.assertEqual(sync(root), (0, 0))

    def test_team_stints_only_join_matching_teams(self):
        records = [
            {"season_id":"2024-25","season_type":"regular",
             "team_abbreviation":team}
            for team in ("LAL", "DAL")
        ]
        dossier = {"profile":{"player_key":"nba_10"},"seasons":records}
        count = overlay_published_season(dossier, {
            "player_season_totals":[{
                "player_id":"nba_10", "team_ids":"2TM","ts_pct":0.615,
                "team_stints":[
                    {"team_abbreviation":"LAL","ts_pct":0.6},
                    {"team_abbreviation":"DAL","ts_pct":0.65},
                ],
            }]
        }, "2024-25", "regular")
        self.assertEqual(count, 2)
        self.assertEqual(records[0]["ts_pct"], 0.6)
        self.assertEqual(records[1]["ts_pct"], 0.65)

    def test_team_mismatch_never_injects_source_measures(self):
        record = {"season_id":"2024-25","season_type":"regular",
                  "team_abbreviation":"DAL"}
        dossier = {"profile":{"player_key":"nba_10"},"seasons":[record]}
        count = overlay_published_season(dossier, {
            "player_season_totals":[{
                "player_id":"nba_10","team_abbreviation":"LAL",
                "ts_pct":0.9,
            }]
        }, "2024-25", "regular")
        self.assertEqual(count, 0)
        self.assertNotIn("ts_pct", record)

    def test_do_not_stamp_combined_totals_onto_separate_team_stints(self):
        rows = [
            {"season_id":"2024-25","season_type":"regular","team_abbreviation":team}
            for team in ("LAL","DAL")
        ]
        dossier = {"profile":{"player_key":"nba_10"},"seasons":rows}
        count = overlay_published_season(dossier, {
            "player_season_totals":[{"player_id":"nba_10","ts_pct":0.61}]
        }, "2024-25","regular")
        self.assertEqual(count,0)
        self.assertNotIn("ts_pct",rows[0])
        self.assertNotIn("ts_pct",rows[1])


if __name__ == "__main__":
    unittest.main()
