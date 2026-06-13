from __future__ import annotations

import gzip
import hashlib
import json
from pathlib import Path

from .table_parser import ParsedPage


class SportsReferenceSnapshotArchive:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)

    def write(
        self,
        *,
        url: str,
        parsed: ParsedPage,
        fetched_at: str,
        source_sha256: str,
        cache_path: str,
        status_code: int,
        content_type: str,
        html_bytes: int,
    ) -> Path:
        family = parsed.page_family or "unclassified"
        season = str(parsed.season_end_year or "unknown-season")
        url_hash = hashlib.sha256(url.encode("utf-8")).hexdigest()[:20]
        path = self.root / season / family / f"{url_hash}.json.gz"
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".tmp")
        document = {
            "url": url,
            "canonicalUrl": parsed.canonical_url or url,
            "pageFamily": parsed.page_family,
            "sourceKey": parsed.source_key,
            "seasonEndYear": parsed.season_end_year,
            "teamAbbreviation": parsed.team_abbreviation,
            "title": parsed.title,
            "fetchedAt": fetched_at,
            "sourceSha256": source_sha256,
            "cachePath": cache_path,
            "statusCode": status_code,
            "contentType": content_type,
            "htmlBytes": html_bytes,
            "tables": [
                {
                    "tableId": table.table_id,
                    "ordinal": table.ordinal,
                    "caption": table.caption,
                    "columns": table.columns,
                    "schemaHash": table.schema_hash,
                    "linkCount": table.link_count,
                    "rowCount": len(table.rows),
                    "rows": table.rows,
                }
                for table in parsed.tables
            ],
            "discoveredLinks": parsed.discovered_links,
        }
        with gzip.open(temporary, "wt", encoding="utf-8") as handle:
            json.dump(document, handle, ensure_ascii=False, separators=(",", ":"))
        temporary.replace(path)
        return path
