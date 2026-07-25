from __future__ import annotations

import io
import json
import math
import statistics
import sys
from contextlib import redirect_stdout
from typing import Any


def _column(rows: list[dict[str, Any]], key: str) -> list[Any]:
    return [row.get(key) for row in rows if row.get(key) is not None]


def _numeric(rows: list[dict[str, Any]], key: str) -> list[float]:
    values: list[float] = []
    for value in _column(rows, key):
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            values.append(float(value))
    return values


def _mean(values: list[Any]) -> float | None:
    numeric = [float(value) for value in values if isinstance(value, (int, float)) and not isinstance(value, bool)]
    return statistics.fmean(numeric) if numeric else None


def _median(values: list[Any]) -> float | None:
    numeric = [float(value) for value in values if isinstance(value, (int, float)) and not isinstance(value, bool)]
    return statistics.median(numeric) if numeric else None


def _percentile(values: list[Any], percentile: float) -> float | None:
    numeric = sorted(float(value) for value in values if isinstance(value, (int, float)) and not isinstance(value, bool))
    if not numeric:
        return None
    p = min(100.0, max(0.0, float(percentile))) / 100.0
    position = p * (len(numeric) - 1)
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return numeric[lower]
    return numeric[lower] + (numeric[upper] - numeric[lower]) * (position - lower)


def _group_by(rows: list[dict[str, Any]], key: str) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for row in rows:
        grouped.setdefault(str(row.get(key, "")), []).append(row)
    return grouped


def _json_safe(value: Any, depth: int = 0) -> Any:
    if depth > 8:
        return "<maximum depth reached>"
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, dict):
        return {str(key): _json_safe(item, depth + 1) for key, item in list(value.items())[:1000]}
    if isinstance(value, (list, tuple, set)):
        return [_json_safe(item, depth + 1) for item in list(value)[:5000]]
    return str(value)


def main() -> None:
    request = json.load(sys.stdin)
    code = str(request.get("code", ""))
    rows = request.get("rows", [])
    columns = request.get("columns", [])
    if not isinstance(rows, list):
        rows = []
    if not isinstance(columns, list):
        columns = []

    safe_builtins = {
        "abs": abs,
        "all": all,
        "any": any,
        "bool": bool,
        "dict": dict,
        "enumerate": enumerate,
        "filter": filter,
        "float": float,
        "int": int,
        "len": len,
        "list": list,
        "map": map,
        "max": max,
        "min": min,
        "print": print,
        "range": range,
        "reversed": reversed,
        "round": round,
        "set": set,
        "sorted": sorted,
        "str": str,
        "sum": sum,
        "tuple": tuple,
        "zip": zip,
    }
    namespace: dict[str, Any] = {
        "__builtins__": safe_builtins,
        "rows": rows,
        "columns": columns,
        "column": lambda key: _column(rows, str(key)),
        "numeric": lambda key: _numeric(rows, str(key)),
        "mean": _mean,
        "median": _median,
        "percentile": _percentile,
        "group_by": lambda key: _group_by(rows, str(key)),
        "result": None,
    }
    stdout = io.StringIO()
    with redirect_stdout(stdout):
        compiled = compile(code, "<sports-terminal-notebook>", "exec")
        exec(compiled, namespace, namespace)
    response = {
        "stdout": stdout.getvalue(),
        "result": _json_safe(namespace.get("result")),
        "row_count": len(rows),
        "column_count": len(columns),
    }
    json.dump(response, sys.stdout, separators=(",", ":"))


if __name__ == "__main__":
    main()
