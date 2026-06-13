from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from sports_reference import BasketballReferenceNba, SportsReferenceClient
from sports_reference.table_extractor import LinkedTableExtractor

DATASETS = (
    "player_per_game",
    "player_totals",
    "player_advanced",
    "playoff_player_per_game",
    "playoff_player_totals",
    "playoff_player_advanced",
    "team_per_game",
    "team_opponent_per_game",
    "team_advanced",
    "standings",
    "schedule",
)

TABLE_PAGES = (
    "league",
    "per_game",
    "totals",
    "advanced",
    "schedule",
    "playoff_per_game",
    "playoff_totals",
    "playoff_advanced",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Write one cached Basketball Reference table to raw review files."
    )
    parser.add_argument("--season", type=int, required=True)
    parser.add_argument("--dataset", choices=DATASETS)
    parser.add_argument("--list-tables", choices=TABLE_PAGES)
    parser.add_argument("--output-root", default="raw/basketball_reference")
    parser.add_argument("--cache-dir", default=".cache/sports_reference")
    parser.add_argument(
        "--minimum-interval",
        type=float,
        default=7.0,
        help="Seconds between network requests; must remain between 6 and 8.",
    )
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    if bool(args.dataset) == bool(args.list_tables):
        parser.error("Choose exactly one of --dataset or --list-tables")
    return args


def extract_linked_tables(client, fetch, table_id: str) -> list[dict]:
    soup = client.expanded_soup(fetch.html)
    extractor = LinkedTableExtractor()
    tables = []
    for current_id in table_id.split(","):
        current_id = current_id.strip()
        table = soup.find("table", id=current_id)
        if table is not None:
            tables.append(extractor.extract_table(table, fetch.url))
    return tables


def main() -> int:
    args = parse_args()
    client = SportsReferenceClient(
        cache_dir=args.cache_dir,
        minimum_interval_seconds=args.minimum_interval,
    )
    adapter = BasketballReferenceNba(client)
    try:
        if args.list_tables:
            table_ids, fetch = adapter.list_table_ids(
                args.season,
                page=args.list_tables,
                force=args.force,
            )
            print(json.dumps({"url": fetch.url, "tableIds": table_ids}, indent=2))
            return 0
        frame, fetch, table_id = adapter.fetch_dataset(
            args.dataset,
            args.season,
            force=args.force,
        )
        linked_tables = extract_linked_tables(client, fetch, table_id)
    except Exception as exc:
        print(f"Ingestion stopped: {exc}", file=sys.stderr)
        return 1

    season_label = f"{args.season - 1}-{str(args.season)[-2:]}"
    output_dir = Path(args.output_root) / season_label
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = output_dir / f"{args.dataset}.csv"
    json_path = output_dir / f"{args.dataset}.json"
    linked_path = output_dir / f"{args.dataset}.linked.json"
    manifest_path = output_dir / f"{args.dataset}.manifest.json"

    frame.to_csv(csv_path, index=False)
    records = frame.where(frame.notna(), None).to_dict(orient="records")
    json_path.write_text(
        json.dumps(records, indent=2, default=str) + "\n",
        encoding="utf-8",
    )
    linked_document = linked_tables[0] if len(linked_tables) == 1 else {
        "tableCount": len(linked_tables),
        "tables": linked_tables,
    }
    linked_path.write_text(
        json.dumps(linked_document, indent=2, default=str) + "\n",
        encoding="utf-8",
    )
    manifest = {
        "source": "Basketball Reference",
        "sourceUrl": fetch.url,
        "seasonEndYear": args.season,
        "seasonLabel": season_label,
        "dataset": args.dataset,
        "tableId": table_id,
        "rowCount": len(frame.index),
        "columns": list(frame.columns),
        "fetchedAt": fetch.fetched_at,
        "fromCache": fetch.from_cache,
        "sourceSha256": fetch.sha256,
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "status": "raw-review-only",
        "canonicalAssetsModified": False,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print("Basketball Reference raw candidate written")
    print(f"Dataset: {args.dataset}")
    print(f"Season: {season_label}")
    print(f"Rows: {len(frame.index)}")
    print(f"Table: {table_id}")
    print(f"CSV: {csv_path}")
    print(f"JSON: {json_path}")
    print(f"Linked JSON: {linked_path}")
    print(f"Manifest: {manifest_path}")
    print("Canonical Flutter assets were not modified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
