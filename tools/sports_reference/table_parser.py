from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
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
    schema_hash: str
    link_count: int


@dataclass(frozen=True)
class ParsedPage:
    title: str | None
    tables: list[ParsedTable]
    discovered_links: list[dict[str, Any]]
    canonical_url: str | None = None
    page_family: str | None = None
    source_key: str | None = None
    season_end_year: int | None = None
    team_abbreviation: str | None = None


class BasketballReferenceTableParser:
    """Parse visible and comment-wrapped tables while preserving provider links."""

    def __init__(self, scope: BasketballReferenceUrlScope) -> None:
        self.scope = scope

    def parse(self, html: str, *, source_url: str, expanded_soup: BeautifulSoup) -> ParsedPage:
        canonical_url = self._canonical_url(expanded_soup, source_url)
        scoped = self.scope.classify(canonical_url or source_url)
        heading = expanded_soup.find("h1")
        title = (
            heading.get_text(" ", strip=True)
            if heading is not None
            else expanded_soup.title.get_text(" ", strip=True)
            if expanded_soup.title
            else None
        )
        tables = [
            self._parse_table(table, ordinal=index, source_url=source_url)
            for index, table in enumerate(expanded_soup.find_all("table"), start=1)
        ]
        links = self._page_links(expanded_soup, source_url=source_url)
        return ParsedPage(
            title=title,
            tables=tables,
            discovered_links=links,
            canonical_url=scoped.url if scoped else canonical_url,
            page_family=scoped.page_family if scoped else None,
            source_key=scoped.source_key if scoped else None,
            season_end_year=scoped.season_end_year if scoped else None,
            team_abbreviation=scoped.team_abbreviation if scoped else None,
        )

    def _parse_table(self, table, *, ordinal: int, source_url: str) -> ParsedTable:
        table_id = table.get("id") or f"anonymous_{ordinal}"
        caption_node = table.find("caption")
        caption = caption_node.get_text(" ", strip=True) if caption_node else self._nearest_heading(table)
        columns = self._column_keys(table)
        rows: list[dict[str, Any]] = []
        body = table.find("tbody") or table
        section: str | None = None
        for source_index, tr in enumerate(body.find_all("tr", recursive=False)):
            classes = set(tr.get("class") or [])
            if "thead" in classes or "spacer" in classes:
                continue
            cells = tr.find_all(["th", "td"], recursive=False)
            if not cells:
                continue
            if len(cells) == 1 and cells[0].get("colspan"):
                section_text = cells[0].get_text(" ", strip=True)
                if section_text:
                    section = section_text
                continue

            row_values: dict[str, Any] = {}
            row_display: dict[str, str] = {}
            row_links: list[dict[str, Any]] = []
            seen_keys: dict[str, int] = {}
            for cell_index, cell in enumerate(cells):
                raw_key = cell.get("data-stat") or (
                    columns[cell_index] if cell_index < len(columns) else f"column_{cell_index + 1}"
                )
                key = self._snake_case(raw_key)
                seen_keys[key] = seen_keys.get(key, 0) + 1
                if seen_keys[key] > 1:
                    key = f"{key}_{seen_keys[key]}"
                text = cell.get_text(" ", strip=True)
                row_values[key] = self._typed_value(text)
                row_display[key] = text
                for anchor in cell.find_all("a", href=True):
                    canonical = self.scope.canonicalize(anchor["href"], source_url=source_url)
                    scoped = self.scope.classify(canonical) if canonical else None
                    row_links.append(
                        {
                            "column": key,
                            "text": anchor.get_text(" ", strip=True),
                            "href": canonical,
                            "rawHref": anchor["href"],
                            "pageFamily": scoped.page_family if scoped else None,
                            "sourceKey": scoped.source_key if scoped else None,
                        }
                    )
            if not any(value != "" for value in row_display.values()):
                continue
            rows.append(
                {
                    "rowIndex": len(rows),
                    "sourceRowIndex": source_index,
                    "rowClass": " ".join(sorted(classes)) or None,
                    "section": section,
                    "values": row_values,
                    "display": row_display,
                    "links": row_links,
                }
            )

        schema_payload = json.dumps(
            {
                "columns": columns,
                "rowKeys": sorted({key for row in rows for key in row["values"]}),
            },
            sort_keys=True,
            separators=(",", ":"),
        )
        return ParsedTable(
            table_id=table_id,
            ordinal=ordinal,
            caption=caption,
            columns=columns,
            rows=rows,
            schema_hash=hashlib.sha256(schema_payload.encode("utf-8")).hexdigest(),
            link_count=sum(len(row["links"]) for row in rows),
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

    def _page_links(self, soup: BeautifulSoup, *, source_url: str) -> list[dict[str, Any]]:
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
                    "sourceKey": scoped.source_key,
                    "seasonEndYear": scoped.season_end_year,
                    "teamAbbreviation": scoped.team_abbreviation,
                    "priority": scoped.priority,
                }
            )
        return output

    def _canonical_url(self, soup: BeautifulSoup, source_url: str) -> str | None:
        node = soup.find("link", rel=lambda value: value and "canonical" in value)
        if node is not None and node.get("href"):
            canonical = self.scope.canonicalize(node["href"], source_url=source_url)
            if canonical:
                return canonical
        return self.scope.canonicalize(source_url)

    def _nearest_heading(self, table) -> str | None:
        heading = table.find_previous(["h2", "h3"])
        return heading.get_text(" ", strip=True) if heading else None

    def _typed_value(self, text: str) -> Any:
        normalized = text.strip()
        if normalized in {"", "--", "—", "-"}:
            return None
        if normalized.endswith("%"):
            number = normalized[:-1].replace(",", "")
            if re.fullmatch(r"[-+]?(?:\d+\.?\d*|\.\d+)", number):
                try:
                    return float(Decimal(number) / Decimal(100))
                except InvalidOperation:
                    return normalized
            return normalized
        number = normalized.replace(",", "")
        if re.fullmatch(r"[-+]?\d+", number):
            return int(number)
        if re.fullmatch(r"[-+]?(?:\d+\.\d*|\.\d+)", number):
            return float(number)
        return normalized

    def _snake_case(self, value: str) -> str:
        value = value.replace("%", "_pct").replace("+/-", "plus_minus")
        value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_")
        return value.lower() or "column"
