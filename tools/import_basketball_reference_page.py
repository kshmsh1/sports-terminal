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
    parser.add_argument("--minimum-interval", type=float, default=3.5)
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

    extractor = LinkedTableExtractor()
    discovered = []
    for table in soup.find_all("table"):
        extracted = extractor.extract_table(table, args.url)
        discovered.append(extracted)

    if args.discover:
        summary = [
            {
                "tableId": table["tableId"],
                "caption": table.get("caption"),
                "rowCount": table["rowCount"],
                "linkCount": table["linkCount"],
                "columns": table["columns"],
            }
            for table in discovered
        ]
        print(json.dumps({"url": args.url, "tables": summary}, indent=2))
        return 0

    selected_ids = set(args.table_id)
    selected = discovered if args.all_tables else [
        table for table in discovered if table["tableId"] in selected_ids
    ]
    missing = selected_ids.difference(table["tableId"] for table in selected)
    if missing:
        print(
            f"Requested table IDs were not found: {sorted(missing)}. "
            "Run with --discover to inspect the page.",
            file=sys.stderr,
        )
        return 1

    output_dir = Path(args.output_root) / slug_for_url(args.url)
    output_dir.mkdir(parents=True, exist_ok=True)
    table_manifests = [write_table(output_dir, table) for table in selected]
    manifest = {
        "source": "Basketball Reference",
        "sourceUrl": args.url,
        "fetchedAt": fetch.fetched_at,
        "fromCache": fetch.from_cache,
        "sourceSha256": fetch.sha256,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "status": "raw-review-only",
        "canonicalAssetsModified": False,
        "tableCount": len(table_manifests),
        "tables": table_manifests,
    }
    manifest_path = output_dir / "page.manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(f"Extracted {len(table_manifests)} link-aware table(s)")
    for table in table_manifests:
        print(
            f"- {table['tableId']}: {table['rowCount']} rows, "
            f"{table['linkCount']} links"
        )
    print(f"Output: {output_dir}")
    print(f"Manifest: {manifest_path}")
    print("Canonical Flutter assets were not modified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
