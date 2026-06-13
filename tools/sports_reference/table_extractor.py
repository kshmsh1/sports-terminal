from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup, Tag


@dataclass(frozen=True)
class ClassifiedLink:
    text: str
    href: str
    entity_type: str
    source_key: str | None

    def to_dict(self) -> dict[str, str | None]:
        return {
            "text": self.text,
            "href": self.href,
            "entityType": self.entity_type,
            "sourceKey": self.source_key,
        }


class BasketballReferenceLinkClassifier:
    """Classify Basketball Reference links without guessing terminal IDs."""

    _patterns = (
        (re.compile(r"^/players/[a-z]/([^/]+)\.html$"), "player", "player"),
        (re.compile(r"^/teams/([A-Z0-9]{2,3})/(\d{4})\.html$"), "team-season", "team-season"),
        (re.compile(r"^/teams/([A-Z0-9]{2,3})/$"), "team", "team"),
        (re.compile(r"^/leagues/NBA_(\d{4})\.html$"), "season", "season"),
        (re.compile(r"^/boxscores/([^/]+)\.html$"), "game", "game"),
        (re.compile(r"^/coaches/([^/]+)\.html$"), "coach", "coach"),
        (re.compile(r"^/awards/([^/]+)\.html$"), "award", "award"),
        (re.compile(r"^/playoffs/([^/]+)\.html$"), "playoff", "playoff"),
        (re.compile(r"^/friv/([^/]+)\.html$"), "reference", "reference"),
    )

    def classify(self, text: str, href: str, source_url: str) -> ClassifiedLink:
        absolute = urljoin(source_url, href)
        path = urlparse(absolute).path
        for pattern, entity_type, prefix in self._patterns:
            match = pattern.match(path)
            if match is None:
                continue
            parts = ":".join(match.groups())
            return ClassifiedLink(
                text=text,
                href=absolute,
                entity_type=entity_type,
                source_key=f"basketball-reference:{prefix}:{parts}",
            )
        return ClassifiedLink(
            text=text,
            href=absolute,
            entity_type="external-reference",
            source_key=None,
        )


class LinkedTableExtractor:
    """Extract data-stat keyed cells and preserve every anchor in each cell."""

    def __init__(self, classifier: BasketballReferenceLinkClassifier | None = None) -> None:
        self.classifier = classifier or BasketballReferenceLinkClassifier()

    def extract_all(self, html: str, source_url: str) -> list[dict]:
        soup = BeautifulSoup(html, "lxml")
        return [
            self.extract_table(table, source_url)
            for table in soup.find_all("table")
            if isinstance(table, Tag)
        ]

    def extract_table(self, table: Tag, source_url: str) -> dict:
        table_id = table.get("id") or "unnamed-table"
        columns = self._columns(table)
        rows = []
        section = None
        for tr in table.find_all("tr"):
            if not isinstance(tr, Tag):
                continue
            classes = set(tr.get("class") or [])
            if tr.find_parent("thead") is not None or "thead" in classes:
                continue
            cells = [
                cell
                for cell in tr.find_all(["th", "td"], recursive=False)
                if isinstance(cell, Tag)
            ]
            if not cells:
                continue
            if len(cells) == 1 and cells[0].get("colspan"):
                section = cells[0].get_text(" ", strip=True)
                continue
            row_cells: dict[str, dict] = {}
            fallback_index = 0
            for cell in cells:
                key = cell.get("data-stat") or self._fallback_key(cell, fallback_index)
                fallback_index += 1
                if key in row_cells:
                    suffix = 2
                    while f"{key}_{suffix}" in row_cells:
                        suffix += 1
                    key = f"{key}_{suffix}"
                text = cell.get_text(" ", strip=True)
                links = []
                for anchor in cell.find_all("a", href=True):
                    if not isinstance(anchor, Tag):
                        continue
                    link_text = anchor.get_text(" ", strip=True) or text
                    links.append(
                        self.classifier.classify(
                            link_text,
                            anchor["href"],
                            source_url,
                        ).to_dict()
                    )
                row_cells[key] = {
                    "text": text,
                    "value": self._coerce_value(text),
                    "links": links,
                    "classes": list(cell.get("class") or []),
                }
            if not any(cell["text"] for cell in row_cells.values()):
                continue
            rows.append(
                {
                    "index": len(rows),
                    "section": section,
                    "classes": list(tr.get("class") or []),
                    "cells": row_cells,
                }
            )
        caption = table.find("caption")
        return {
            "tableId": table_id,
            "caption": caption.get_text(" ", strip=True) if caption else None,
            "columns": columns,
            "rowCount": len(rows),
            "rows": rows,
            "linkCount": sum(
                len(cell["links"])
                for row in rows
                for cell in row["cells"].values()
            ),
        }

    def _columns(self, table: Tag) -> list[dict[str, str]]:
        header_rows = table.find_all("tr")
        best: list[dict[str, str]] = []
        for tr in header_rows:
            if not isinstance(tr, Tag):
                continue
            candidate = []
            for index, cell in enumerate(tr.find_all(["th", "td"], recursive=False)):
                if not isinstance(cell, Tag):
                    continue
                key = cell.get("data-stat") or self._fallback_key(cell, index)
                label = cell.get_text(" ", strip=True)
                if key or label:
                    candidate.append({"key": key, "label": label or key})
            if len(candidate) > len(best):
                best = candidate
            if tr.parent and getattr(tr.parent, "name", None) == "thead" and candidate:
                best = candidate
        seen = set()
        deduped = []
        for column in best:
            key = column["key"]
            if key in seen:
                continue
            seen.add(key)
            deduped.append(column)
        return deduped

    def _fallback_key(self, cell: Tag, index: int) -> str:
        label = cell.get_text(" ", strip=True).lower()
        label = re.sub(r"[^a-z0-9]+", "_", label).strip("_")
        return label or f"column_{index + 1}"

    def _coerce_value(self, text: str):
        normalized = text.strip().replace(",", "")
        if normalized in {"", "--", "—", "-"}:
            return None
        if normalized.endswith("%"):
            try:
                return float(normalized[:-1]) / 100
            except ValueError:
                return text
        if re.fullmatch(r"[-+]?\d+", normalized):
            try:
                return int(normalized)
            except ValueError:
                return text
        if re.fullmatch(r"[-+]?(?:\d+\.\d*|\.\d+)", normalized):
            try:
                return float(normalized)
            except ValueError:
                return text
        return text
