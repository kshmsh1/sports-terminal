"""Offline spreadsheet engine: parsed formulas, DAG invalidation and file I/O.

No eval/exec, HTTP, code generation, AI provider, or server-side execution.
A source cell change invalidates downstream dependents, including cross-sheet
references. Missing cells are zero in arithmetic and ignored by aggregates.
"""
from __future__ import annotations

import csv
import json
import math
import re
import statistics
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any

CELL_RE = re.compile(r"^\$?([A-Za-z]{1,3})\$?([1-9]\d{0,6})$")
TOKEN = re.compile(
    r'\s*(?:(?P<number>(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)'
    r'|(?P<string>"(?:[^"]|"")*")'
    r'|(?P<reference>(?:(?:\'[^\']+\'|[A-Za-z_][A-Za-z_0-9]*)!)?\$?[A-Za-z]{1,3}\$?[1-9]\d{0,6})'
    r'|(?P<word>[A-Za-z_][A-Za-z_0-9]*)'
    r'|(?P<operator><=|>=|<>|[()+\-*/^%,:=<>]))'
)
CellKey = tuple[str, str]
Ast = tuple[Any, ...]


class FormulaError(ValueError):
    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


def col_label(number: int) -> str:
    if number < 1 or number > 16384:
        raise FormulaError("#REF!")
    text = ""
    while number:
        number, rem = divmod(number - 1, 26)
        text = chr(65 + rem) + text
    return text


def col_index(name: str) -> int:
    result = 0
    for char in name.upper():
        if not "A" <= char <= "Z":
            raise FormulaError("#REF!")
        result = result * 26 + ord(char) - 64
    if not 1 <= result <= 16384:
        raise FormulaError("#REF!")
    return result


def address(row: int, col: int) -> str:
    if row < 1 or row > 1048576:
        raise FormulaError("#REF!")
    return f"{col_label(col)}{row}"


def coordinates(ref: str) -> tuple[int, int]:
    match = CELL_RE.fullmatch(ref)
    if not match:
        raise FormulaError("#REF!")
    row = int(match.group(2))
    if row > 1048576:
        raise FormulaError("#REF!")
    return row, col_index(match.group(1))


def normalize_ref(ref: str, current_sheet: str) -> CellKey:
    if "!" in ref:
        name, cell = ref.rsplit("!", 1)
        name = name.strip("'")
    else:
        name, cell = current_sheet, ref
    row, col = coordinates(cell)
    return (name, address(row, col))


def range_keys(first: CellKey, last: CellKey) -> list[CellKey]:
    if first[0] != last[0]:
        raise FormulaError("#REF!")
    r1, c1 = coordinates(first[1])
    r2, c2 = coordinates(last[1])
    count = (abs(r2 - r1) + 1) * (abs(c2 - c1) + 1)
    if count > 100000:
        raise FormulaError("#NUM!")
    return [(first[0], address(r, c))
            for r in range(min(r1, r2), max(r1, r2) + 1)
            for c in range(min(c1, c2), max(c1, c2) + 1)]


class Parser:
    PRECEDENCE = {"=": 1, "<>": 1, "<": 1, ">": 1, "<=": 1, ">=": 1,
                  "+": 2, "-": 2, "*": 3, "/": 3, "^": 4, ":": 6}

    def __init__(self, formula: str):
        self.tokens: list[tuple[str, str]] = []
        self.pos = 0
        cursor = 0
        while cursor < len(formula):
            if formula[cursor:].strip() == "":
                break
            match = TOKEN.match(formula, cursor)
            if match is None:
                raise FormulaError("#ERROR!")
            kind = match.lastgroup
            assert kind is not None
            self.tokens.append((kind, match.group(kind)))
            cursor = match.end()
        self.tokens.append(("end", ""))

    def peek(self) -> str:
        return self.tokens[self.pos][1]

    def take(self, expected: str | None = None) -> tuple[str, str]:
        value = self.tokens[self.pos]
        if expected is not None and value[1] != expected:
            raise FormulaError("#ERROR!")
        self.pos += 1
        return value

    def parse(self) -> Ast:
        expr = self.expression()
        if self.tokens[self.pos][0] != "end":
            raise FormulaError("#ERROR!")
        return expr

    def expression(self, minimum: int = 0) -> Ast:
        kind, value = self.take()
        if kind == "number":
            lhs: Ast = ("number", float(value))
        elif kind == "string":
            lhs = ("text", value[1:-1].replace('""', '"'))
        elif kind == "reference":
            lhs = ("ref", value)
        elif kind == "word":
            name = value.upper()
            if self.peek() == "(":
                self.take("(")
                args = []
                if self.peek() != ")":
                    while True:
                        args.append(self.expression())
                        if self.peek() != ",":
                            break
                        self.take(",")
                self.take(")")
                lhs = ("call", name, tuple(args))
            elif name in ("TRUE", "FALSE"):
                lhs = ("bool", name == "TRUE")
            else:
                raise FormulaError("#NAME?")
        elif value in ("+", "-"):
            lhs = ("unary", value, self.expression(5))
        elif value == "(":
            lhs = self.expression()
            self.take(")")
        else:
            raise FormulaError("#ERROR!")

        while True:
            op = self.peek()
            if op == "%":
                self.take()
                lhs = ("percent", lhs)
                continue
            strength = self.PRECEDENCE.get(op, -1)
            if strength < minimum:
                break
            self.take()
            right = self.expression(strength if op == "^" else strength + 1)
            lhs = ("binary", op, lhs, right)
        return lhs


def dependencies(node: Ast, sheet: str) -> set[CellKey]:
    kind = node[0]
    if kind == "ref":
        return {normalize_ref(node[1], sheet)}
    if kind == "binary" and node[1] == ":":
        if node[2][0] != "ref" or node[3][0] != "ref":
            raise FormulaError("#REF!")
        return set(range_keys(normalize_ref(node[2][1], sheet),
                              normalize_ref(node[3][1], sheet)))
    if kind in ("binary", "unary", "percent"):
        parts = node[2:] if kind == "binary" else node[2:] if kind == "unary" else node[1:]
        return set().union(*(dependencies(part, sheet) for part in parts))
    if kind == "call":
        return set().union(*(dependencies(arg, sheet) for arg in node[2]))
    return set()


def _num(value: Any) -> float:
    if value is None or value == "":
        return 0.0
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    try:
        return float(value)
    except (ValueError, TypeError):
        raise FormulaError("#VALUE!") from None


def _flatten(items: list[Any]) -> list[Any]:
    result = []
    for item in items:
        if isinstance(item, list):
            result.extend(_flatten(item))
        else:
            result.append(item)
    return result


class Workbook:
    def __init__(self):
        self.sheets: dict[str, dict[str, str]] = {"Sheet1": {}}
        self.depends_on: dict[CellKey, set[CellKey]] = {}
        self.dependents: dict[CellKey, set[CellKey]] = defaultdict(set)
        self.cache: dict[CellKey, Any] = {}
        self.parsed: dict[CellKey, Ast | FormulaError] = {}
        self.styles: dict[CellKey, dict[str, Any]] = {}

    def add_sheet(self, name: str) -> None:
        if not name or name in self.sheets or len(name) > 31 or any(
            ch in name for ch in "[]:*?/\\\\"):
            raise ValueError("Invalid or existing sheet name")
        self.sheets[name] = {}

    def delete_sheet(self, name: str) -> None:
        if name not in self.sheets or len(self.sheets) == 1:
            raise ValueError("Cannot delete the last sheet")
        self.sheets.pop(name)
        for key in list(self.depends_on):
            if key[0] == name:
                self._drop_dependencies(key)
                self.depends_on.pop(key, None)
                self.parsed.pop(key, None)
        self.cache.clear()

    def _drop_dependencies(self, key: CellKey) -> None:
        for upstream in self.depends_on.get(key, set()):
            self.dependents[upstream].discard(key)

    def set_cell(self, sheet: str, cell: str, raw: str) -> None:
        if sheet not in self.sheets:
            raise KeyError(sheet)
        row, col = coordinates(cell.upper().replace("$", ""))
        key = (sheet, address(row, col))
        self._drop_dependencies(key)
        self.depends_on.pop(key, None)
        self.parsed.pop(key, None)
        if raw == "":
            self.sheets[sheet].pop(key[1], None)
        else:
            self.sheets[sheet][key[1]] = str(raw)
        if raw.startswith("="):
            try:
                ast = Parser(raw[1:]).parse()
                deps = dependencies(ast, sheet)
                self.parsed[key] = ast
                self.depends_on[key] = deps
                for item in deps:
                    self.dependents[item].add(key)
            except FormulaError as error:
                self.parsed[key] = error
        affected = {key}
        pending = [key]
        while pending:
            parent = pending.pop()
            for child in self.dependents.get(parent, set()):
                if child not in affected:
                    affected.add(child)
                    pending.append(child)
        for item in affected:
            self.cache.pop(item, None)

    def raw(self, sheet: str, cell: str) -> str:
        return self.sheets[sheet].get(cell.upper().replace("$", ""), "")

    def value(self, sheet: str, cell: str) -> Any:
        key = normalize_ref(cell, sheet)
        try:
            return self._evaluate(key, set())
        except FormulaError as error:
            return error.code

    def _evaluate(self, key: CellKey, visiting: set[CellKey]) -> Any:
        if key in self.cache:
            return self.cache[key]
        if key in visiting:
            raise FormulaError("#CYCLE!")
        if key[0] not in self.sheets:
            raise FormulaError("#REF!")
        raw = self.sheets[key[0]].get(key[1], "")
        if raw == "":
            return ""
        if not raw.startswith("="):
            try:
                value: Any = float(raw)
            except ValueError:
                value = raw
            return value
        node = self.parsed.get(key)
        if isinstance(node, FormulaError):
            raise node
        if node is None:
            raise FormulaError("#ERROR!")
        visiting.add(key)
        try:
            value = self._run(node, key[0], visiting)
            self.cache[key] = value
            return value
        finally:
            visiting.remove(key)

    def _run(self, node: Ast, sheet: str, visiting: set[CellKey]) -> Any:
        kind = node[0]
        if kind in ("number", "text", "bool"):
            return node[1]
        if kind == "ref":
            return self._evaluate(normalize_ref(node[1], sheet), visiting)
        if kind == "percent":
            return _num(self._run(node[1], sheet, visiting)) / 100
        if kind == "unary":
            value = _num(self._run(node[2], sheet, visiting))
            return value if node[1] == "+" else -value
        if kind == "binary":
            op = node[1]
            if op == ":":
                if node[2][0] != "ref" or node[3][0] != "ref":
                    raise FormulaError("#REF!")
                return [self._evaluate(ref, visiting) for ref in range_keys(
                    normalize_ref(node[2][1], sheet),
                    normalize_ref(node[3][1], sheet))]
            left = self._run(node[2], sheet, visiting)
            right = self._run(node[3], sheet, visiting)
            if op == "=": return left == right
            if op == "<>": return left != right
            if op == "<": return left < right
            if op == ">": return left > right
            if op == "<=": return left <= right
            if op == ">=": return left >= right
            a, b = _num(left), _num(right)
            if op == "+": return a + b
            if op == "-": return a - b
            if op == "*": return a * b
            if op == "/":
                if b == 0: raise FormulaError("#DIV/0!")
                return a / b
            if op == "^":
                try: return a ** b
                except (ValueError, OverflowError): raise FormulaError("#NUM!") from None
        if kind == "call":
            name = node[1]
            args: tuple[Ast, ...] = node[2]
            # IF and IFERROR must be lazy to avoid evaluating unused branches.
            if name == "IF":
                if len(args) not in (2, 3): raise FormulaError("#VALUE!")
                choice = args[1] if self._run(args[0], sheet, visiting) else (
                    args[2] if len(args) == 3 else ("number", 0.0))
                return self._run(choice, sheet, visiting)
            if name == "IFERROR":
                if len(args) != 2: raise FormulaError("#VALUE!")
                try: return self._run(args[0], sheet, visiting)
                except FormulaError: return self._run(args[1], sheet, visiting)
            values = _flatten([self._run(arg, sheet, visiting) for arg in args])
            numbers = [_num(v) for v in values if v != "" and v is not None
                       and (isinstance(v, (int, float, bool)) or _is_number(v))]
            if name == "SUM": return sum(numbers)
            if name in ("AVG", "AVERAGE"):
                if not numbers: raise FormulaError("#DIV/0!")
                return sum(numbers) / len(numbers)
            if name == "COUNT": return len(numbers)
            if name == "COUNTA": return sum(v != "" and v is not None for v in values)
            if name == "MIN": return min(numbers) if numbers else 0
            if name == "MAX": return max(numbers) if numbers else 0
            if name == "MEDIAN": return statistics.median(numbers) if numbers else 0
            if name in ("STDEV", "STDEV.S"):
                return statistics.stdev(numbers) if len(numbers) >= 2 else 0
            if name == "PRODUCT": return math.prod(numbers)
            if name == "ABS" and len(values) == 1: return abs(_num(values[0]))
            if name == "SQRT" and len(values) == 1:
                if _num(values[0]) < 0: raise FormulaError("#NUM!")
                return math.sqrt(_num(values[0]))
            if name == "ROUND" and len(values) in (1, 2):
                return round(_num(values[0]), int(_num(values[1])) if len(values) == 2 else 0)
            if name == "POWER" and len(values) == 2: return _num(values[0]) ** _num(values[1])
            if name == "CONCAT": return "".join(str(x) for x in values)
            if name == "AND": return all(bool(v) for v in values)
            if name == "OR": return any(bool(v) for v in values)
            if name == "NOT" and len(values) == 1: return not bool(values[0])
            raise FormulaError("#NAME?")
        raise FormulaError("#ERROR!")

    def to_dict(self) -> dict[str, Any]:
        return {"format": "arcside-workbook", "version": 1,
                "sheets": self.sheets,
                "styles": [{"sheet": sheet, "cell": cell, "style": style}
                           for (sheet, cell), style in self.styles.items()]}

    def save(self, path: str | Path) -> None:
        Path(path).write_text(json.dumps(self.to_dict(), indent=2), encoding="utf-8")

    @classmethod
    def load(cls, path: str | Path) -> "Workbook":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        if data.get("format") != "arcside-workbook" or data.get("version") != 1:
            raise ValueError("Not an Arcside workbook")
        result = cls()
        result.sheets.clear()
        for name, records in data["sheets"].items():
            result.add_sheet(name)
            for cell, raw in records.items():
                result.set_cell(name, cell, str(raw))
        for item in data.get("styles", []):
            result.styles[(item["sheet"], item["cell"])] = dict(item["style"])
        return result

    def import_csv(self, path: str | Path, sheet: str = "Sheet1") -> None:
        if sheet not in self.sheets: self.add_sheet(sheet)
        with Path(path).open(newline="", encoding="utf-8-sig") as stream:
            for rownum, entries in enumerate(csv.reader(stream), 1):
                for colnum, item in enumerate(entries, 1):
                    if item:
                        self.set_cell(sheet, address(rownum, colnum), item)

    def export_csv(self, path: str | Path, sheet: str = "Sheet1",
                   max_row: int = 500, max_col: int = 30) -> None:
        with Path(path).open("w", newline="", encoding="utf-8") as stream:
            writer = csv.writer(stream)
            for row in range(1, max_row + 1):
                writer.writerow([self.value(sheet, address(row, col))
                                 for col in range(1, max_col + 1)])

    def import_xlsx(self, path: str | Path) -> None:
        from openpyxl import load_workbook  # optional local dependency
        book = load_workbook(path, data_only=False)
        self.__init__()
        self.sheets.clear()
        for source in book.worksheets:
            self.add_sheet(source.title)
            for row in source.iter_rows():
                for cell in row:
                    if cell.value is not None:
                        self.set_cell(source.title, cell.coordinate, str(cell.value))

    def export_xlsx(self, path: str | Path) -> None:
        from openpyxl import Workbook as OpenpyxlWorkbook  # optional
        out = OpenpyxlWorkbook()
        out.remove(out.active)
        for name, records in self.sheets.items():
            sheet = out.create_sheet(name)
            for key, raw in records.items():
                sheet[key] = raw
        out.save(path)


def _is_number(value: Any) -> bool:
    try:
        float(value)
        return True
    except (TypeError, ValueError):
        return False
