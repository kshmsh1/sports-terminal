from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

DEFAULT_DATABASE = "data/warehouse/nba_history.sqlite"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Summarize the Sports Terminal historical NBA warehouse.")
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--top-tables", type=int, default=25)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    database = Path(args.database)
    if not database.exists():
        raise FileNotFoundError(
            f"Historical NBA warehouse does not exist: {database}. "
            "Run bash scripts/import_historical_nba_sources.sh first."
        )

    db = sqlite3.connect(database)
    try:
        source_count = int(db.execute("SELECT COUNT(*) FROM historical_source_registry").fetchone()[0])
        file_count = int(db.execute("SELECT COUNT(*) FROM historical_source_files").fetchone()[0])
        table_count = int(db.execute("SELECT COUNT(*) FROM historical_table_inventory").fetchone()[0])
        row_count = int(db.execute("SELECT COALESCE(SUM(row_count), 0) FROM historical_table_inventory").fetchone()[0])

        print("Sports Terminal Historical NBA Warehouse")
        print("=" * 92)
        print(f"Database: {database}")
        print(f"Sources:  {source_count:,}")
        print(f"Files:    {file_count:,}")
        print(f"Tables:   {table_count:,}")
        print(f"Rows:     {row_count:,}")

        print("\nSource totals")
        print("-" * 92)
        for row in db.execute(
            """
            SELECT source_key, label, file_count, table_count, row_count, coverage, license
            FROM historical_source_registry
            ORDER BY priority, source_key
            """
        ):
            source_key, label, files, tables, rows, coverage, license_name = row
            print(f"{source_key:24} {rows:14,} rows | {tables:4} tables | {files:4} files")
            print(f"  {label}")
            print(f"  coverage: {coverage or 'source-native'}")
            print(f"  license:  {license_name or 'unspecified'}")

        print("\nCoverage by source/domain/grain")
        print("-" * 92)
        for row in db.execute(
            """
            SELECT source_key, domain, grain, table_count, row_count, min_season, max_season
            FROM historical_source_coverage
            ORDER BY source_key, row_count DESC, domain, grain
            """
        ):
            source, domain, grain, tables, rows, minimum, maximum = row
            span = ""
            if minimum is not None or maximum is not None:
                span = f" | {minimum or '?'} -> {maximum or '?'}"
            print(f"{source:24} {domain:18} {grain:22} {tables:4} | {rows:14,}{span}")

        print(f"\nLargest {max(1, args.top_tables)} imported tables")
        print("-" * 92)
        for row in db.execute(
            """
            SELECT source_key, source_table, domain, grain, row_count, min_season, max_season
            FROM historical_table_inventory
            ORDER BY row_count DESC, source_key, source_table
            LIMIT ?
            """,
            (max(1, args.top_tables),),
        ):
            source, table, domain, grain, rows, minimum, maximum = row
            span = ""
            if minimum is not None or maximum is not None:
                span = f" | {minimum or '?'} -> {maximum or '?'}"
            print(f"{rows:14,} | {source:22} | {domain:16} | {grain:20} | {table}{span}")
    finally:
        db.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
