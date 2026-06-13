from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from sports_reference.client import SportsReferenceClient
from sports_reference.table_extractor import LinkedTableExtractor


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Discover or extract link-aware tables from one Basketball Reference page."
    )
    parser.add_argument("--url", required=True)
    parser.add_argument("--table-id", action="append", default=[])
    parser.add_argument("--all-tables", action="store_true")
    parser.add_argument("--discover", action="store_true")
    parser.add_argument("--output-root", default="raw/basketball_reference/pages")
    parser.add_argument("--cache-dir", default=".cache/sports_reference")
    parser.add_argument(
        "--minimum-interval",
        type=float,
        default=7.0,
        help="Seconds between network requests; must remain between 6 and 8.",
    )
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    if not args.discover and not args.all_tables and not args.table_id:
        parser.error("Choose --discover, --all-tables, or at least one --table-id")
    return args


def slug_for_url(url: str) -> str:
    parsed = urlparse(url)
    path = parsed.path.strip("/") or "home"
    slug = re.sub(r"[^a-zA-Z0-9]+", "-", path).strip("-").lower()
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:10]
    return f"{slug}-{digest}"


def flatten_table(table: dict) -> tuple[list[str], list[dict[str, object]]]:
    keys = []
    for column in table.get("columns", []):
        key = column["key"]
        if key not in keys:
            keys.append(key)
    for row in table.get("rows", []):
        for key in row["cells"]:
            if key not in keys:
                keys.append(key)

    fieldnames = ["row_index", "section", "row_classes"]
    for key in keys:
        fieldnames.extend(
            [
                key,
                f"{key}__text",
                f"{key}__href",
                f"{key}__entity_type",
                f"{key}__source_key",
            ]
        )

    rows = []
    for row in table.get("rows", []):
        flat: dict[str, object] = {
            "row_index": row["index"],
            "section": row.get("section"),
            "row_classes": " ".join(row.get("classes", [])),
        }
        for key in keys:
            cell = row["cells"].get(key)
            if cell is None:
                continue
            links = cell.get("links") or []
            first = links[0] if links else {}
            flat[key] = cell.get("value")
            flat[f"{key}__text"] = cell.get("text")
            flat[f"{key}__href"] = first.get("href")
            flat[f"{key}__entity_type"] = first.get("entityType")
            flat[f"{key}__source_key"] = first.get("sourceKey")
        rows.append(flat)
    return fieldnames, rows


def write_table(output_dir: Path, table: dict) -> dict:
    table_id = table["tableId"]
    safe_id = re.sub(r"[^a-zA-Z0-9_-]+", "-", table_id).strip("-") or "table"
    linked_path = output_dir / f"{safe_id}.linked.json"
    csv_path = output_dir / f"{safe_id}.flat.csv"
    linked_path.write_text(json.dumps(table, indent=2) + "\n", encoding="utf-8")
    fieldnames, rows = flatten_table(table)
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    return {
        "tableId": table_id,
        "caption": table.get("caption"),
        "rowCount": table.get("rowCount", 0),
        "linkCount": table.get("linkCount", 0),
        "columns": table.get("columns", []),
        "linkedJson": str(linked_path),
        "flatCsv": str(csv_path),
    }


def main() -> int:
    args = parse_args()
    client = SportsReferenceClient(
        cache_dir=args.cache_dir,
        minimum_interval_seconds=args.minimum_interval,
    )
    try:
        fetch = client.fetch(args.url, force=args.force)
        soup = client.expanded_soup(fetch.html)
    except Exception as exc:
        print(f"Page import stopped: {exc}", file=sys.stderr)
        return 1

    table_ids = sorted(
        table.get("id")
        for table in soup.find_all("table")
        if table.get("id")
    )
    if args.discover:
        print(json.dumps({"url": fetch.url, "tableIds": table_ids}, indent=2))
        return 0

    selected_tables = []
    extractor = LinkedTableExtractor()
    requested_ids = set(args.table_id)
    for table in soup.find_all("table"):
        table_id = table.get("id")
        if args.all_tables or table_id in requested_ids:
            selected_tables.append(extractor.extract_table(table, fetch.url))

    output_dir = Path(args.output_root) / slug_for_url(fetch.url)
    output_dir.mkdir(parents=True, exist_ok=True)
    tables = [write_table(output_dir, table) for table in selected_tables]
    manifest = {
        "source": "Basketball Reference",
        "sourceUrl": fetch.url,
        "fetchedAt": fetch.fetched_at,
        "sourceSha256": fetch.sha256,
        "fromCache": fetch.from_cache,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "tableCount": len(tables),
        "tables": tables,
        "status": "raw-review-only",
        "canonicalAssetsModified": False,
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output_dir), "manifest": str(manifest_path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
