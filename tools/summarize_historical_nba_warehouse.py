from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path

DEFAULT_DATABASE = "data/warehouse/nba_history.sqlite"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Summarize the Sports Terminal historical NBA warehouse.")
    parser.add_argument("--database", default=DEFAULT_DATABASE)
    parser.add_argument("--top-tables", type=int, default=25)
    return parser.parse_args()


def exists(db: sqlite3.Connection, name: str) -> bool:
    return db.execute("SELECT 1 FROM sqlite_master WHERE name = ?", (name,)).fetchone() is not None


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
        print("=" * 104)
        print(f"Database: {database}")
        print(f"Sources:  {source_count:,}")
        print(f"Files:    {file_count:,}")
        print(f"Tables:   {table_count:,}")
        print(f"Rows:     {row_count:,}")

        print("\nSource totals")
        print("-" * 104)
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

        print("\nRaw coverage by source/domain/grain")
        print("-" * 104)
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
            print(f"{source:24} {domain:24} {grain:26} {tables:4} | {rows:14,}{span}")

        if exists(db, "canon_build_manifest"):
            manifest = db.execute("SELECT * FROM canon_build_manifest ORDER BY built_at DESC LIMIT 1").fetchone()
            print("\nCanonical historical platform")
            print("=" * 104)
            if manifest is not None:
                build_id, schema_version, built_at, source_rows, source_tables, canonical_sources, counts_json, warnings_json = manifest
                counts = json.loads(counts_json or "{}")
                warnings = json.loads(warnings_json or "[]")
                print(f"Build:          {build_id}")
                print(f"Schema:         {schema_version}")
                print(f"Built at:       {built_at}")
                print(f"Source rows:    {source_rows:,}")
                print(f"Source tables:  {source_tables:,}")
                print(f"Source systems: {canonical_sources:,}")
                print(f"Warnings:       {len(warnings):,}")
                for key, value in counts.items():
                    label = " ".join(part.capitalize() for part in key.replace("View", " view").split("_"))
                    rendered = f"{value:,}" if isinstance(value, int) and not isinstance(value, bool) else str(value)
                    print(f"  {label:24} {rendered}")

            print("\nCanonical league bounds")
            print("-" * 104)
            for league, name, first_season, last_season in db.execute(
                "SELECT league_id, league_name, first_season, last_season FROM canon_dim_league ORDER BY first_season, league_id"
            ):
                print(f"{league:4} {name:42} {first_season or '?':>8} -> {last_season or '?'}")

            print("\nCanonical domain coverage")
            print("-" * 104)
            for domain, league, minimum, maximum, seasons, rows, sources in db.execute(
                """
                SELECT domain, COALESCE(league_id,'—'), MIN(season_id), MAX(season_id),
                       COUNT(DISTINCT season_id), SUM(row_count), MAX(source_count)
                FROM canon_coverage
                GROUP BY domain, league_id
                ORDER BY domain, league_id
                """
            ):
                print(
                    f"{domain:20} {league:4} {seasons:4} seasons | {rows:12,} rows | "
                    f"{minimum or '?'} -> {maximum or '?'} | up to {sources} sources"
                )

            conflict_count = int(db.execute("SELECT COUNT(*) FROM canon_conflicts").fetchone()[0]) if exists(db, "canon_conflicts") else 0
            provenance_count = int(db.execute("SELECT COUNT(*) FROM canon_field_provenance").fetchone()[0]) if exists(db, "canon_field_provenance") else 0
            print(f"\nMaterial conflicts retained: {conflict_count:,}")
            print(f"Field provenance records:     {provenance_count:,}")
            if conflict_count:
                print("\nTop conflict fields")
                print("-" * 104)
                for entity_type, field_name, count in db.execute(
                    """
                    SELECT entity_type, field_name, COUNT(*)
                    FROM canon_conflicts
                    GROUP BY entity_type, field_name
                    ORDER BY COUNT(*) DESC, entity_type, field_name
                    LIMIT 20
                    """
                ):
                    print(f"{entity_type:20} {field_name:22} {count:10,}")
        else:
            print("\nCanonical historical platform")
            print("=" * 104)
            print("NOT BUILT — run: bash scripts/build_historical_nba_canonical.sh")

        print(f"\nLargest {max(1, args.top_tables)} imported source tables")
        print("-" * 104)
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
            print(f"{rows:14,} | {source:22} | {domain:22} | {grain:24} | {table}{span}")
    finally:
        db.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
