"""Arcside Spreadsheet: deterministic local workbook and safe formula engine.

No eval(), exec(), network, arbitrary Python functions, or external services.
A dependency graph invalidates only affected formulas; circular references
are exposed as #CIRC! rather than freezing the UI.
"""
from __future__ import annotations

import csv
import json
import math
import re
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

CELL = re.compile(r"^\$?([A-Z]{1,3})\$?([0-9]{1,7})$")
TOKEN = re.compile(
    r'\s*(?:(\d+(?:\.\d+)?(?:[Ee][+-]?\d+)?)|("(?:[^"]|"")*")|'
    r'(\$?[A-Za-z]{1,3}\$?[0-9]{1,7})|([A-Za-z_][A-Za-z_0-9]*)|'
    r'(<=|>=|<>|[+\-*/^(),:=<>]))',
    re.ASCII
)
ERRORS = frozenset({"#REF!", "#DIV/0!", "#VALUE!", "#NAME?", "#CIRC!", "#NUM!", "#ERROR!"})


def normalize_ref(ref: str) -> str:
    match = CELL.fullmatch(ref.upper())
    if not match:
        raise ValueError(f"Invalid cell: {ref}")
    col, row = match.groups()
    number = 0
    for char in col:
        number = number * 26 + ord(char) - 64
    if number > 16384 or int(row) < 1 or int(row) > 1048576:
        raise ValueError("Cell outside Excel grid")
    return f"{col}{int(row)}"


def cell_coords(ref: str) -> tuple[int, int]:
    ref = normalize_ref(ref)
    match = CELL.fullmatch(ref)
    assert match is not None
    col = 0
    for letter in match.group(1):
        col = col * 26 + ord(letter) - 64
    return int(match.group(2)), col


def column_name(value: int) -> str:
    if value < 1 or value > 16384:
        raise ValueError("Column out of range")
    letters = ""
    while value:
        value, digit = divmod(value - 1, 26)
        letters = chr(65 + digit) + letters
    return letters


def expand_range(left: str, right: str) -> list[str]:
    r1, c1 = cell_coords(left)
    r2, c2 = cell_coords(right)
    count = (abs(r2 - r1) + 1) * (abs(c2 - c1) + 1)
    if count > 100_000:
        raise ValueError("A single range cannot exceed 100,000 cells")
    return [
        f"{column_name(col)}{row}"
        for row in range(min(r1, r2), max(r1, r2) + 1)
        for col in range(min(c1, c2), max(c1, c2) + 1)
    ]


class FormulaError(Exception):
    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


class Parser:
    """Recursive-descent parser. Never executes source-language code."""

    def __init__(self, formula: str):
        self.tokens = []
        position = 0
        while position < len(formula):
            match = TOKEN.match(formula, position)
            if not match:
                if formula[position:].strip() == "":
                    break
                raise FormulaError("#ERROR!")
            position = match.end()
            self.tokens.append(next(value for value in match.groups() if value is not None))
        self.pos = 0

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else ""

    def consume(self, expected=None):
        value = self.peek()
        if not value or (expected is not None and value != expected):
            raise FormulaError("#ERROR!")
        self.pos += 1
        return value

    def parse(self):
        tree = self.comparison()
        if self.peek():
            raise FormulaError("#ERROR!")
        return tree

    def comparison(self):
        expr = self.addition()
        while self.peek() in ("=", "<>", "<", ">", "<=", ">="):
            op = self.consume()
            expr = ("op", op, expr, self.addition())
        return expr

    def addition(self):
        expr = self.multiplication()
        while self.peek() in ("+", "-"):
            op = self.consume()
            expr = ("op", op, expr, self.multiplication())
        return expr

    def multiplication(self):
        expr = self.power()
        while self.peek() in ("*", "/"):
            op = self.consume()
            expr = ("op", op, expr, self.power())
        return expr

    def power(self):
        expr = self.unary()
        if self.peek() == "^":
            self.consume("^")
            expr = ("op", "^", expr, self.power())
        return expr

    def unary(self):
        if self.peek() in ("+", "-"):
            op = self.consume()
            return ("unary", op, self.unary())
        return self.primary()

    def primary(self):
        token = self.peek()
        if not token:
            raise FormulaError("#ERROR!")
        if token == "(":
            self.consume("(")
            expr = self.comparison()
            self.consume(")")
            return expr
        if token.startswith('"'):
            self.consume()
            return ("str", token[1:-1].replace('""', '"'))
        if re.fullmatch(r"\d+(?:\.\d+)?(?:[Ee][+-]?\d+)?", token):
            self.consume()
            return ("num", float(token))
        if CELL.fullmatch(token.upper()):
            self.consume()
            ref = normalize_ref(token)
            if self.peek() == ":":
                self.consume(":")
                finish = self.consume()
                try:
                    end = normalize_ref(finish)
                except ValueError as exc:
                    raise FormulaError("#REF!") from exc
                return ("range", ref, end)
            return ("ref", ref)
        if re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", token):
            name = self.consume().upper()
            if name == "TRUE":
                return ("bool", True)
            if name == "FALSE":
                return ("bool", False)
            if self.peek() != "(":
                raise FormulaError("#NAME?")
            self.consume("(")
            args = []
            if self.peek() != ")":
                while True:
                    args.append(self.comparison())
                    if self.peek() != ",":
                        break
                    self.consume(",")
            self.consume(")")
            return ("func", name, args)
        raise FormulaError("#ERROR!")


def referenced_cells(node) -> set[str]:
    kind = node[0]
    if kind == "ref":
        return {node[1]}
    if kind == "range":
        return set(expand_range(node[1], node[2]))
    if kind == "op":
        return referenced_cells(node[2]) | referenced_cells(node[3])
    if kind == "unary":
        return referenced_cells(node[2])
    if kind == "func":
        return set().union(*(referenced_cells(item) for item in node[2]))
    return set()


def _number(value):
    if isinstance(value, bool):
        return float(value)
    if value is None or value == "":
        return 0.0
    try:
        return float(value)
    except (ValueError, TypeError) as exc:
        raise FormulaError("#VALUE!") from exc


@dataclass
class Sheet:
    name: str
    cells: dict[str, str] = field(default_factory=dict)
    styles: dict[str, dict[str, Any]] = field(default_factory=dict)
    widths: dict[str, int] = field(default_factory=dict)
    _ast: dict[str, tuple] = field(default_factory=dict, repr=False)
    _dependents: dict[str, set[str]] = field(default_factory=lambda: defaultdict(set), repr=False)
    _dependencies: dict[str, set[str]] = field(default_factory=dict, repr=False)
    _cache: dict[str, Any] = field(default_factory=dict, repr=False)

    def __post_init__(self):
        initial = self.cells
        self.cells = {}
        for ref, content in initial.items():
            self.set(ref, content)

    def set(self, ref: str, raw: str):
        ref = normalize_ref(ref)
        raw = str(raw)
        for source in self._dependencies.pop(ref, ()):
            self._dependents[source].discard(ref)
        self._ast.pop(ref, None)
        if raw:
            self.cells[ref] = raw
        else:
            self.cells.pop(ref, None)
        if raw.startswith("="):
            try:
                tree = Parser(raw[1:]).parse()
                sources = referenced_cells(tree)
                self._dependencies[ref] = sources
                for source in sources:
                    self._dependents[source].add(ref)
                self._ast[ref] = tree
            except (FormulaError, ValueError):
                pass
        pending = deque([ref])
        visited = set()
        while pending:
            node = pending.popleft()
            if node in visited:
                continue
            visited.add(node)
            self._cache.pop(node, None)
            pending.extend(self._dependents.get(node, ()))

    def raw(self, ref: str) -> str:
        return self.cells.get(normalize_ref(ref), "")

    def value(self, ref: str):
        try:
            return self._value(normalize_ref(ref), set())
        except FormulaError as exc:
            return exc.code

    def _value(self, ref: str, visiting: set[str]):
        if ref in visiting:
            raise FormulaError("#CIRC!")
        if ref in self._cache:
            cached = self._cache[ref]
            if isinstance(cached, str) and cached in ERRORS:
                raise FormulaError(cached)
            return cached
        raw = self.cells.get(ref, "")
        if not raw.startswith("="):
            try:
                return float(raw) if raw and raw.strip() else raw
            except ValueError:
                return raw
        visiting.add(ref)
        try:
            tree = self._ast.get(ref)
            if tree is None:
                tree = Parser(raw[1:]).parse()
            value = self._eval(tree, visiting)
            if isinstance(value, float) and not math.isfinite(value):
                raise FormulaError("#NUM!")
            self._cache[ref] = value
            return value
        except (FormulaError, ValueError, OverflowError, ZeroDivisionError) as exc:
            code = exc.code if isinstance(exc, FormulaError) else "#ERROR!"
            self._cache[ref] = code
            raise FormulaError(code) from exc
        finally:
            visiting.remove(ref)

    def _eval(self, node, visiting):
        kind = node[0]
        if kind in ("num", "str", "bool"):
            return node[1]
        if kind == "ref":
            return self._value(node[1], visiting)
        if kind == "range":
            return [self._value(key, visiting) for key in expand_range(node[1], node[2])]
        if kind == "unary":
            return _number(self._eval(node[2], visiting)) * (-1 if node[1] == "-" else 1)
        if kind == "op":
            left = self._eval(node[2], visiting)
            right = self._eval(node[3], visiting)
            op = node[1]
            if op in ("=", "<>", "<", ">", "<=", ">="):
                if op == "=":
                    return left == right
                if op == "<>":
                    return left != right
                if op == "<":
                    return left < right
                if op == ">":
                    return left > right
                if op == "<=":
                    return left <= right
                return left >= right
            a, b = _number(left), _number(right)
            if op == "+":
                return a + b
            if op == "-":
                return a - b
            if op == "*":
                return a * b
            if op == "/":
                if b == 0:
                    raise FormulaError("#DIV/0!")
                return a / b
            if op == "^":
                return a ** b
        if kind == "func":
            name, exprs = node[1], node[2]
            if name == "IF":
                if len(exprs) != 3:
                    raise FormulaError("#VALUE!")
                return self._eval(exprs[1] if self._eval(exprs[0], visiting) else exprs[2], visiting)
            if name == "IFERROR":
                if len(exprs) != 2:
                    raise FormulaError("#VALUE!")
                try:
                    return self._eval(exprs[0], visiting)
                except FormulaError:
                    return self._eval(exprs[1], visiting)
            args = [self._eval(item, visiting) for item in exprs]
            vals = [item for arg in args for item in (arg if isinstance(arg, list) else [arg])]
            if name in ("SUM", "AVERAGE", "AVG", "MIN", "MAX", "COUNT", "COUNTA"):
                numeric = []
                for value in vals:
                    try:
                        if value != "":
                            numeric.append(_number(value))
                    except FormulaError:
                        if value in ERRORS:
                            raise FormulaError(value)
                if name == "SUM":
                    return sum(numeric)
                if name in ("AVERAGE", "AVG"):
                    if not numeric:
                        raise FormulaError("#DIV/0!")
                    return sum(numeric) / len(numeric)
                if name == "COUNT":
                    return len(numeric)
                if name == "COUNTA":
                    return sum(value != "" for value in vals)
                if not numeric:
                    return 0
                return min(numeric) if name == "MIN" else max(numeric)
            if name == "ROUND" and len(vals) in (1, 2):
                return round(_number(vals[0]), int(_number(vals[1])) if len(vals) == 2 else 0)
            if name == "ABS" and len(vals) == 1:
                return abs(_number(vals[0]))
            if name == "SQRT" and len(vals) == 1:
                return math.sqrt(_number(vals[0]))
            if name == "POWER" and len(vals) == 2:
                return _number(vals[0]) ** _number(vals[1])
            if name == "AND":
                return all(bool(v) for v in vals)
            if name == "OR":
                return any(bool(v) for v in vals)
            if name == "NOT" and len(vals) == 1:
                return not bool(vals[0])
            if name == "CONCAT":
                return "".join(str(v) for v in vals)
            raise FormulaError("#NAME?")
        raise FormulaError("#ERROR!")

    def display(self, ref: str) -> str:
        value = self.value(ref)
        if isinstance(value, bool):
            return str(value).upper()
        if isinstance(value, float):
            return str(int(value)) if value.is_integer() else f"{value:.10g}"
        return str(value)

    def save_csv(self, path: str | Path):
        used = [cell_coords(key) for key in self.cells]
        max_row = max((r for r, _ in used), default=1)
        max_col = max((c for _, c in used), default=1)
        with open(path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            for row in range(1, max_row + 1):
                writer.writerow([self.display(f"{column_name(c)}{row}")
                                 for c in range(1, max_col + 1)])

    @classmethod
    def load_csv(cls, path: str | Path, name: str | None = None) -> Sheet:
        cells = {}
        with open(path, newline="", encoding="utf-8-sig") as f:
            for row_id, row in enumerate(csv.reader(f), 1):
                for col_id, value in enumerate(row, 1):
                    if value:
                        cells[f"{column_name(col_id)}{row_id}"] = (
                            "'" + value if value.startswith("=") else value
                        )
        return cls(name or Path(path).stem, cells)


@dataclass
class Workbook:
    sheets: list[Sheet] = field(default_factory=lambda: [Sheet("Sheet1")])

    def add_sheet(self, name: str) -> Sheet:
        if any(sheet.name.lower() == name.lower() for sheet in self.sheets):
            raise ValueError("Duplicate worksheet name")
        if not name or len(name) > 31 or any(c in name for c in r"[]:*?/\\" ):
            raise ValueError("Invalid worksheet name")
        sheet = Sheet(name)
        self.sheets.append(sheet)
        return sheet

    def save(self, path: str | Path):
        data = {"version": 1, "sheets": [
            {"name": s.name, "cells": s.cells, "styles": s.styles,
             "widths": s.widths} for s in self.sheets
        ]}
        Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2),
                              encoding="utf-8")

    @classmethod
    def load(cls, path: str | Path) -> Workbook:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        if data.get("version") != 1:
            raise ValueError("Unsupported Arcside workbook version")
        return cls([Sheet(item["name"], item.get("cells", {}),
                          item.get("styles", {}), item.get("widths", {}))
                    for item in data["sheets"]])

    def save_xlsx(self, path: str | Path):
        try:
            from openpyxl import Workbook as OpenpyxlWorkbook
            from openpyxl.styles import Font, PatternFill, Alignment
        except ImportError as exc:
            raise RuntimeError("XLSX support requires openpyxl") from exc
        book = OpenpyxlWorkbook()
        book.remove(book.active)
        for sheet in self.sheets:
            ws = book.create_sheet(sheet.name)
            for ref, raw in sheet.cells.items():
                ws[ref] = raw
            for ref, style in sheet.styles.items():
                cell = ws[ref]
                if "bold" in style:
                    cell.font = Font(bold=bool(style["bold"]))
                if "format" in style:
                    cell.number_format = style["format"]
            for col, width in sheet.widths.items():
                ws.column_dimensions[col].width = width
        book.save(path)

    @classmethod
    def load_xlsx(cls, path: str | Path) -> Workbook:
        try:
            from openpyxl import load_workbook
        except ImportError as exc:
            raise RuntimeError("XLSX support requires openpyxl") from exc
        book = load_workbook(path, read_only=False, data_only=False)
        result = []
        for ws in book:
            cells = {cell.coordinate: str(cell.value)
                     for row in ws for cell in row if cell.value is not None}
            result.append(Sheet(ws.title, cells))
        book.close()
        return cls(result)
