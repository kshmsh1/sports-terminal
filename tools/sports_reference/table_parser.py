from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from bs4 import BeautifulSoup

from .url_scope import BasketballReferenceUrlScope


@dataclass(frozen=True)
class ParsedTable:
    table_id: str
    ordinal: int
    caption: str | None
    columns: list[str]
    rows: list[dict[str, Any]]


@dataclass(frozen=True)
class ParsedPage:
    title: str | None
    tables: list[ParsedTable]
    discovered_links: list[dict[str, str | None]]


class BasketballReferenceTableParser:
    """Parses visible and comment-wrapped tables while preserving links."""

    def __init__(self, scope: BasketballReferenceUrlScope) -> None:
        self.scope = scope

    def parse(self, html: str, *, source_url: str, expanded_soup: BeautifulSoup) -> ParsedPage:
        title = expanded_soup.title.get_text(" ", strip=True) if expanded_soup.title else None
        tables = [
            self._parse_table(table, ordinal=index, source_url=source_url)
            for index, table in enumerate(expanded_soup.find_all("table"), start=1)
        ]
        links = self._page_links(expanded_soup, source_url=source_url)
        return ParsedPage(title=title, tables=tables, discovered_links=links)

    def _parse_table(self, table, *, ordinal: int, source_url: str) -> ParsedTable:
        table_id = table.get("id") or f"anonymous_{ordinal}"
        caption_node = table.find("caption")
        caption = caption_node.get_text(" ", strip=True) if caption_node else self._nearest_heading(table)
        columns = self._column_keys(table)
        rows: list[dict[str, Any]] = []
        body = table.find("tbody") or table
        for source_index, tr in enumerate(body.find_all("tr", recursive=False)):
            classes = set(tr.get("class") or [])
            if "thead" in classes or "spacer" in classes:
                continue
            cells = tr.find_all(["th", "td"], recursive=False)
            if not cells:
                continue
            row_values: dict[str, Any] = {}
            row_links: list[dict[str, str | None]] = []
            for cell_index, cell in enumerate(cells):
                key = cell.get("data-stat") or (
                    columns[cell_index] if cell_index < len(columns) else f"column_{cell_index + 1}"
                )
                text = cell.get_text(" ", strip=True)
                value = self._typed_value(text)
                row_values[key] = value
                for anchor in cell.find_all("a", href=True):
                    canonical = self.scope.canonicalize(anchor["href"], source_url=source_url)
                    row_links.append(
                        {
                            "column": key,
                            "text": anchor.get_text(" ", strip=True),
                            "href": canonical,
                            "rawHref": anchor["href"],
                        }
                    )
            rows.append(
                {
                    "rowIndex": len(rows),
                    "sourceRowIndex": source_index,
                    "rowClass": " ".join(sorted(classes)) or None,
                    "values": row_values,
                    "links": row_links,
                }
            )
        return ParsedTable(
            table_id=table_id,
            ordinal=ordinal,
            caption=caption,
            columns=columns,
            rows=rows,
        )

    def _column_keys(self, table) -> list[str]:
        header_rows = table.select("thead tr")
        header = header_rows[-1] if header_rows else table.find("tr")
        if header is None:
            return []
        keys = []
        seen: dict[str, int] = {}
        for index, cell in enumerate(header.find_all(["th", "td"], recursive=False)):
            raw = cell.get("data-stat") or cell.get_text(" ", strip=True) or f"column_{index + 1}"
            key = self._snake_case(raw)
            seen[key] = seen.get(key, 0) + 1
            keys.append(key if seen[key] == 1 else f"{key}_{seen[key]}")
        return keys

    def _page_links(self, soup: BeautifulSoup, *, source_url: str) -> list[dict[str, str | None]]:
        output = []
        seen = set()
        for anchor in soup.find_all("a", href=True):
            canonical = self.scope.canonicalize(anchor["href"], source_url=source_url)
            if canonical is None or canonical in seen:
                continue
            scoped = self.scope.classify(canonical)
            if scoped is None:
                continue
            seen.add(canonical)
            output.append(
                {
                    "url": scoped.url,
                    "pageFamily": scoped.page_family,
                    "anchorText": anchor.get_text(" ", strip=True) or None,
                }
            )
        return output

    def _nearest_heading(self, table) -> str | None:
        heading = table.find_previous(["h2", "h3"])
        return heading.get_text(" ", strip=True) if heading else None

    def _typed_value(self, text: str) -> Any:
        normalized = text.strip()
        if normalized in {"", "--", "—"}:
            return None
        number = normalized.replace(",", "").replace("%", "")
        if re.fullmatch(r"[-+]?\d+", number):
            return int(number)
        if re.fullmatch(r"[-+]?(?:\d+\.\d*|\.\d+)", number):
            return float(number)
        return normalized

    def _snake_case(self, value: str) -> str:
        value = value.replace("%", "_pct").replace("+/-", "plus_minus")
        value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_")
        return value.lower() or "column"
