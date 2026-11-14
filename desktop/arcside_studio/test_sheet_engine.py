"""Regression tests for the safe, fully offline Arcside spreadsheet engine."""
from __future__ import annotations

import ast
import tempfile
import unittest
from pathlib import Path

try:
    from .sheet_engine import Workbook, FormulaError, address, col_index, col_label
except ImportError:
    from sheet_engine import Workbook, FormulaError, address, col_index, col_label


class AddressTests(unittest.TestCase):
    def test_column_roundtrip(self):
        for number in (1, 26, 27, 52, 53, 702, 703, 16384):
            self.assertEqual(col_index(col_label(number)), number)
        self.assertEqual(address(25, 27), "AA25")
        with self.assertRaises(FormulaError):
            address(0, 1)

    def test_column_out_of_bounds(self):
        with self.assertRaises(FormulaError):
            col_label(16385)


class FormulaTests(unittest.TestCase):
    def setUp(self):
        self.book = Workbook()
        self.book.set_cell("Sheet1", "A1", "2")
        self.book.set_cell("Sheet1", "A2", "4")
        self.book.set_cell("Sheet1", "A3", "6")

    def test_operator_precedence_parentheses_exponent_and_percent(self):
        book = self.book
        for cell, raw, expected in [
            ("B1", "=2+3*4", 14.0),
            ("B2", "=(2+3)*4", 20.0),
            ("B3", "=2^3^2", 512.0),
            ("B4", "=200*5%", 10.0),
            ("B5", "=-A1+10", 8.0),
        ]:
            book.set_cell("Sheet1", cell, raw)
            self.assertEqual(book.value("Sheet1", cell), expected)

    def test_aggregates_and_nested_functions(self):
        for cell, raw, expected in [
            ("B1", "=SUM(A1:A3)", 12),
            ("B2", "=AVERAGE(A1:A3)", 4),
            ("B3", "=MIN(A1:A3)", 2),
            ("B4", "=MAX(A1:A3)", 6),
            ("B5", "=COUNT(A1:A3)", 3),
            ("B6", "=IF(A1<3,SUM(A1:A3),0)", 12),
            ("B7", "=ROUND(12.765,2)", 12.77),
            ("B8", "=ABS(-9)", 9),
            ("B9", "=MEDIAN(A1:A3)", 4),
            ("B10", "=PRODUCT(A1:A3)", 48),
        ]:
            self.book.set_cell("Sheet1", cell, raw)
            self.assertAlmostEqual(self.book.value("Sheet1", cell), expected)

    def test_text_and_boolean(self):
        self.book.set_cell("Sheet1", "C1", '=IF(A1=2,"correct","wrong")')
        self.assertEqual(self.book.value("Sheet1", "C1"), "correct")
        self.book.set_cell("Sheet1", "C2", '=CONCAT("Arc","side")')
        self.assertEqual(self.book.value("Sheet1", "C2"), "Arcside")
        self.book.set_cell("Sheet1", "C3", "=AND(TRUE,A1=2)")
        self.assertEqual(self.book.value("Sheet1", "C3"), True)

    def test_recalculate_transitive_dependencies_after_edit(self):
        self.book.set_cell("Sheet1", "C1", "=SUM(A1:A3)")
        self.book.set_cell("Sheet1", "D1", "=C1*2")
        self.assertEqual(self.book.value("Sheet1", "D1"), 24)
        self.book.set_cell("Sheet1", "A2", "14")
        self.assertEqual(self.book.value("Sheet1", "C1"), 22)
        self.assertEqual(self.book.value("Sheet1", "D1"), 44)

    def test_cross_sheet_reference_and_recalculation(self):
        self.book.add_sheet("Inputs")
        self.book.set_cell("Inputs", "B2", "101")
        self.book.set_cell("Sheet1", "B1", "=Inputs!B2+1")
        self.assertEqual(self.book.value("Sheet1", "B1"), 102)
        self.book.set_cell("Inputs", "B2", "109")
        self.assertEqual(self.book.value("Sheet1", "B1"), 110)

    def test_cycles_and_division_errors(self):
        self.book.set_cell("Sheet1", "B1", "=C1+1")
        self.book.set_cell("Sheet1", "C1", "=B1+1")
        self.assertEqual(self.book.value("Sheet1", "B1"), "#CYCLE!")
        self.book.set_cell("Sheet1", "C1", "=1/0")
        self.assertEqual(self.book.value("Sheet1", "C1"), "#DIV/0!")
        self.book.set_cell("Sheet1", "D1", "=IFERROR(C1,99)")
        self.assertEqual(self.book.value("Sheet1", "D1"), 99)

    def test_lazy_if_skips_erroring_branch(self):
        self.book.set_cell("Sheet1", "C1", "=IF(TRUE,42,1/0)")
        self.assertEqual(self.book.value("Sheet1", "C1"), 42)
        self.book.set_cell("Sheet1", "C2", "=IF(FALSE,1/0,11)")
        self.assertEqual(self.book.value("Sheet1", "C2"), 11)

    def test_errors_and_guarded_large_ranges(self):
        self.book.set_cell("Sheet1", "C1", "=DOES_NOT_EXIST(5)")
        self.assertEqual(self.book.value("Sheet1", "C1"), "#NAME?")
        self.book.set_cell("Sheet1", "C2", "=SUM(A1:XFD100)")
        self.assertEqual(self.book.value("Sheet1", "C2"), "#NUM!")
        self.book.set_cell("Sheet1", "C3", "=999/0")
        self.assertEqual(self.book.value("Sheet1", "C3"), "#DIV/0!")

    def test_clear_invalidates_downstream(self):
        self.book.set_cell("Sheet1", "B1", "=A1*2")
        self.assertEqual(self.book.value("Sheet1", "B1"), 4)
        self.book.set_cell("Sheet1", "A1", "")
        self.assertEqual(self.book.value("Sheet1", "B1"), 0)

    def test_file_roundtrip(self):
        self.book.add_sheet("Inputs")
        self.book.set_cell("Inputs", "A1", "40")
        self.book.set_cell("Sheet1", "E1", "=Inputs!A1+2")
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "workbook.arcside.json"
            self.book.save(file)
            loaded = Workbook.load(file)
            self.assertEqual(loaded.value("Sheet1", "E1"), 42)
            self.assertEqual(loaded.raw("Sheet1", "E1"), "=Inputs!A1+2")

    def test_csv_roundtrip(self):
        with tempfile.TemporaryDirectory() as tmp:
            file = Path(tmp) / "sheet.csv"
            self.book.export_csv(file, max_row=3, max_col=2)
            result = Workbook()
            result.import_csv(file)
            self.assertEqual(result.value("Sheet1", "A3"), 6)

    def test_no_dynamic_formula_python_execution(self):
        self.book.set_cell("Sheet1", "B1", '=__import__("os")')
        self.assertEqual(self.book.value("Sheet1", "B1"), "#NAME?")


class DesktopSourceTests(unittest.TestCase):
    def test_desktop_ui_syntax_compiles_without_gui_packages(self):
        here = Path(__file__).parent
        for filename in ("python_lab.py", "spreadsheet.py"):
            ast.parse((here / filename).read_text(), filename=filename)

    def test_ui_uses_local_process_not_api(self):
        code = (Path(__file__).parent / "python_lab.py").read_text()
        self.assertIn("QProcess(", code)
        self.assertIn('"-m", "pdb"', code)
        self.assertIn('"-m", "pytest"', code)
        self.assertNotIn("api.openai.com", code)


if __name__ == "__main__":
    unittest.main()
