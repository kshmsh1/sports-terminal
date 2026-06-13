from __future__ import annotations


def cell(row: dict, *keys: str) -> dict | None:
    cells = row.get("cells", {})
    for key in keys:
        if key in cells:
            return cells[key]
    return None


def value(row: dict, *keys: str):
    selected = cell(row, *keys)
    return None if selected is None else selected.get("value")


def text(row: dict, *keys: str) -> str | None:
    selected = cell(row, *keys)
    if selected is None:
        return None
    raw = selected.get("text")
    return None if raw is None else str(raw).strip()


def first_link(row: dict, *keys: str) -> dict | None:
    selected = cell(row, *keys)
    if selected is None:
        return None
    links = selected.get("links") or []
    return links[0] if links else None


def number(row: dict, *keys: str) -> float | None:
    raw = value(row, *keys)
    if raw is None:
        return None
    if isinstance(raw, (int, float)):
        return float(raw)
    try:
        return float(str(raw).replace(",", ""))
    except ValueError:
        return None


def integer(row: dict, *keys: str) -> int | None:
    raw = number(row, *keys)
    return None if raw is None else int(raw)
