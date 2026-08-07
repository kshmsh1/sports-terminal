from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

DEFAULT_REGISTRY = "assets/data/nba/metadata/historical_source_registry.json"
DEFAULT_SOURCE_ROOT = "raw/historical"
DEFAULT_OUTPUT = "data/warehouse/nba_history.sqlite"
DEFAULT_REPORT = "data/warehouse/nba_history_import_report.json"

SQLITE_SUFFIXES = {".sqlite", ".sqlite3", ".db"}
CSV_SUFFIXES = {".csv"}
SEASON_COLUMN_CANDIDATES = (
    "season",
    "season_id",
    "season_year",
    "season_end_year",
    "year",
    "year_id",
    "seasonyear",
    "seasonid",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Losslessly ingest downloaded historical NBA source packages into a namespaced SQLite "
            "warehouse. SQLite is preferred when a package includes both a database and flat-file "
            "exports so the same source is not duplicated millions of times."
        )
    )
    parser.add_argument("--registry", default=DEFAULT_REGISTRY)
    parser.add_argument("--source-root", default=DEFAULT_SOURCE_ROOT)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--report", default=DEFAULT_REPORT)
    parser.add_argument(
        "--sources",
        default="",
        help="Comma-separated source keys. Empty means every downloaded dataset source in the registry.",
    )
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Delete the existing historical warehouse before importing.",
    )
    parser.add_argument(
        "--include-csv-with-sqlite",
        action="store_true",
        help="Also import CSV exports when the same source package already contains SQLite.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=20000,
        help="CSV insertion batch size.",
    )
    return parser.parse_args()


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, default=str) + "\n", encoding="utf-8")


def quote_identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def safe_identifier(value: str, *, fallback: str = "table") -> str:
    normalized = re.sub(r"[^a-zA-Z0-9]+", "_", value.strip()).strip("_").lower()
    if not normalized:
        normalized = fallback
    if normalized[0].isdigit():
        normalized = f"n_{normalized}"
    return normalized[:180]


def unique_columns(headers: list[str]) -> list[str]:
    used: dict[str, int] = {}
    result: list[str] = []
    for index, header in enumerate(headers):
        base = safe_identifier(header or f"column_{index + 1}", fallback=f"column_{index + 1}")
        count = used.get(base, 0) + 1
        used[base] = count
        result.append(base if count == 1 else f"{base}_{count}")
    return result


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def infer_domain(name: str) -> str:
    value = safe_identifier(name)
    checks = (
        ("play_by_play", ("play_by_play", "playbyplay", "pbp")),
        ("shot_chart", ("shot_chart", "shotchart", "shot_location", "shooting")),
        ("box_score", ("box_score", "boxscore")),
        ("tracking", ("tracking", "hustle", "speed_distance", "touches", "passing", "rebounding")),
        ("lineup_rotation", ("lineup", "rotation")),
        ("matchup", ("matchup", "synergy")),
        ("award", ("award", "all_league", "all_nba", "all_defense", "all_rookie", "mvp", "voting")),
        ("draft", ("draft", "rookie")),
        ("all_star", ("all_star", "allstar")),
        ("standings", ("standing", "record")),
        ("player_season", ("player_season", "player_total", "player_per_game", "player_advanced", "player_stats")),
        ("player_identity", ("player_info", "player_career", "dim_player", "players")),
        ("team_season", ("team_season", "team_total", "team_per_game", "team_summary", "team_stats")),
        ("team_identity", ("team_info", "team_history", "dim_team", "teams")),
        ("game", ("game", "schedule", "scoreboard")),
    )
    for domain, needles in checks:
        if any(needle in value for needle in needles):
            return domain
    if value.startswith("analytics_"):
        return "analytics"
    if value.startswith("agg_"):
        return "aggregate"
    if value.startswith("dim_"):
        return "dimension"
    if value.startswith("fact_"):
        return "fact"
    if value.startswith("bridge_"):
        return "bridge"
    return "other"


def infer_grain(name: str) -> str:
    value = safe_identifier(name)
    if "play_by_play" in value or "playbyplay" in value or "pbp" in value:
        return "event"
    if "shot" in value:
        return "shot_or_shooting_split"
    if "player" in value and ("game" in value or "box" in value):
        return "player_game"
    if "team" in value and ("game" in value or "box" in value):
        return "team_game"
    if "player" in value and ("season" in value or "total" in value or "per_game" in value or "advanced" in value):
        return "player_season"
    if "team" in value and ("season" in value or "total" in value or "per_game" in value or "summary" in value):
        return "team_season"
    if "game" in value or "schedule" in value:
        return "game"
    return "source_native"


def initialize_database(db: sqlite3.Connection) -> None:
    db.executescript(
        """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA temp_store = MEMORY;

        CREATE TABLE IF NOT EXISTS historical_import_runs(
          run_id TEXT PRIMARY KEY,
          started_at TEXT NOT NULL,
          finished_at TEXT,
          status TEXT NOT NULL,
          source_root TEXT NOT NULL,
          output_database TEXT NOT NULL,
          sources_json TEXT NOT NULL,
          table_count INTEGER NOT NULL DEFAULT 0,
          row_count INTEGER NOT NULL DEFAULT 0,
          file_count INTEGER NOT NULL DEFAULT 0,
          warnings_json TEXT NOT NULL DEFAULT '[]'
        );

        CREATE TABLE IF NOT EXISTS historical_source_registry(
          source_key TEXT PRIMARY KEY,
          label TEXT NOT NULL,
          dataset_slug TEXT,
          dataset_url TEXT,
          code_url TEXT,
          origin TEXT,
          license TEXT,
          priority INTEGER,
          role TEXT,
          coverage TEXT,
          redistribution_note TEXT,
          package_path TEXT,
          imported_at TEXT,
          file_count INTEGER NOT NULL DEFAULT 0,
          table_count INTEGER NOT NULL DEFAULT 0,
          row_count INTEGER NOT NULL DEFAULT 0,
          metadata_json TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS historical_source_files(
          source_key TEXT NOT NULL,
          relative_path TEXT NOT NULL,
          format TEXT NOT NULL,
          size_bytes INTEGER NOT NULL,
          sha256 TEXT NOT NULL,
          imported_at TEXT NOT NULL,
          PRIMARY KEY(source_key, relative_path)
        );

        CREATE TABLE IF NOT EXISTS historical_table_inventory(
          source_key TEXT NOT NULL,
          source_file TEXT NOT NULL,
          source_table TEXT NOT NULL,
          warehouse_table TEXT NOT NULL UNIQUE,
          domain TEXT NOT NULL,
          grain TEXT NOT NULL,
          row_count INTEGER NOT NULL,
          column_count INTEGER NOT NULL,
          columns_json TEXT NOT NULL,
          season_column TEXT,
          min_season TEXT,
          max_season TEXT,
          imported_at TEXT NOT NULL,
          PRIMARY KEY(source_key, source_file, source_table)
        );

        CREATE INDEX IF NOT EXISTS idx_historical_inventory_source
          ON historical_table_inventory(source_key);
        CREATE INDEX IF NOT EXISTS idx_historical_inventory_domain
          ON historical_table_inventory(domain);
        CREATE INDEX IF NOT EXISTS idx_historical_inventory_grain
          ON historical_table_inventory(grain);
        """
    )
    db.execute("DROP VIEW IF EXISTS historical_source_coverage")
    db.execute(
        """
        CREATE VIEW historical_source_coverage AS
        SELECT source_key,
               domain,
               grain,
               COUNT(*) AS table_count,
               SUM(row_count) AS row_count,
               MIN(min_season) AS min_season,
               MAX(max_season) AS max_season
        FROM historical_table_inventory
        GROUP BY source_key, domain, grain
        ORDER BY source_key, domain, grain
        """
    )


def load_registry(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict) or not isinstance(payload.get("sources"), list):
        raise ValueError(f"Historical source registry is invalid: {path}")
    return payload


def drop_source(db: sqlite3.Connection, source_key: str) -> None:
    tables = [
        row[0]
        for row in db.execute(
            "SELECT warehouse_table FROM historical_table_inventory WHERE source_key = ?",
            (source_key,),
        ).fetchall()
    ]
    for table in tables:
        db.execute(f"DROP TABLE IF EXISTS {quote_identifier(table)}")
    db.execute("DELETE FROM historical_table_inventory WHERE source_key = ?", (source_key,))
    db.execute("DELETE FROM historical_source_files WHERE source_key = ?", (source_key,))
    db.execute("DELETE FROM historical_source_registry WHERE source_key = ?", (source_key,))
    db.commit()


def discover_files(package_dir: Path, include_csv_with_sqlite: bool) -> tuple[list[Path], list[str]]:
    files = [path for path in package_dir.rglob("*") if path.is_file()]
    sqlite_files = sorted(path for path in files if path.suffix.lower() in SQLITE_SUFFIXES)
    csv_files = sorted(path for path in files if path.suffix.lower() in CSV_SUFFIXES)
    warnings: list[str] = []
    if sqlite_files and csv_files and not include_csv_with_sqlite:
        warnings.append(
            f"{package_dir.name}: SQLite present; skipped {len(csv_files)} CSV exports to avoid source-format duplication."
        )
        selected = sqlite_files
    else:
        selected = sqlite_files + csv_files
    unsupported = sorted({path.suffix.lower() for path in files if path.suffix.lower() in {".parquet", ".duckdb"}})
    if unsupported and not sqlite_files:
        warnings.append(
            f"{package_dir.name}: found {', '.join(unsupported)} but no SQLite file; Parquet/DuckDB are not imported by the stdlib importer."
        )
    return selected, warnings


def register_file(db: sqlite3.Connection, source_key: str, package_dir: Path, path: Path, imported_at: str) -> None:
    relative = str(path.relative_to(package_dir))
    db.execute(
        """
        INSERT OR REPLACE INTO historical_source_files(
          source_key, relative_path, format, size_bytes, sha256, imported_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            source_key,
            relative,
            path.suffix.lower().lstrip("."),
            path.stat().st_size,
            sha256_file(path),
            imported_at,
        ),
    )


def find_season_column(columns: Iterable[str]) -> str | None:
    by_normalized = {safe_identifier(column): column for column in columns}
    for candidate in SEASON_COLUMN_CANDIDATES:
        if candidate in by_normalized:
            return by_normalized[candidate]
    for normalized, original in by_normalized.items():
        if "season" in normalized and not any(token in normalized for token in ("type", "segment", "stage")):
            return original
    return None


def season_bounds(db: sqlite3.Connection, table: str, season_column: str | None) -> tuple[str | None, str | None]:
    if not season_column:
        return None, None
    q_table = quote_identifier(table)
    q_column = quote_identifier(season_column)
    try:
        row = db.execute(
            f"SELECT MIN(CAST({q_column} AS TEXT)), MAX(CAST({q_column} AS TEXT)) "
            f"FROM {q_table} WHERE {q_column} IS NOT NULL AND TRIM(CAST({q_column} AS TEXT)) <> ''"
        ).fetchone()
    except sqlite3.Error:
        return None, None
    if not row:
        return None, None
    return (None if row[0] is None else str(row[0]), None if row[1] is None else str(row[1]))


def record_table(
    db: sqlite3.Connection,
    *,
    source_key: str,
    source_file: str,
    source_table: str,
    warehouse_table: str,
    row_count: int,
    columns: list[dict[str, Any]],
    imported_at: str,
) -> None:
    column_names = [str(column.get("name") or "") for column in columns]
    season_column = find_season_column(column_names)
    min_season, max_season = season_bounds(db, warehouse_table, season_column)
    db.execute(
        """
        INSERT OR REPLACE INTO historical_table_inventory(
          source_key, source_file, source_table, warehouse_table, domain, grain,
          row_count, column_count, columns_json, season_column, min_season, max_season, imported_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            source_key,
            source_file,
            source_table,
            warehouse_table,
            infer_domain(source_table),
            infer_grain(source_table),
            row_count,
            len(columns),
            json.dumps(columns, ensure_ascii=False),
            season_column,
            min_season,
            max_season,
            imported_at,
        ),
    )


def import_sqlite(
    db: sqlite3.Connection,
    *,
    source_key: str,
    package_dir: Path,
    path: Path,
    imported_at: str,
) -> tuple[int, int]:
    source = sqlite3.connect(path)
    source.row_factory = sqlite3.Row
    source_tables = [
        str(row[0])
        for row in source.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        ).fetchall()
    ]
    source.close()
    alias = "historical_src"
    db.execute(f"ATTACH DATABASE ? AS {alias}", (str(path),))
    table_count = 0
    total_rows = 0
    try:
        for source_table in source_tables:
            file_stem = safe_identifier(path.stem, fallback="database")
            warehouse_table = safe_identifier(f"src_{source_key}__{file_stem}__{source_table}")
            db.execute(f"DROP TABLE IF EXISTS {quote_identifier(warehouse_table)}")
            db.execute(
                f"CREATE TABLE {quote_identifier(warehouse_table)} AS "
                f"SELECT * FROM {alias}.{quote_identifier(source_table)}"
            )
            row_count = int(db.execute(f"SELECT COUNT(*) FROM {quote_identifier(warehouse_table)}").fetchone()[0])
            info_rows = db.execute(f"PRAGMA {alias}.table_info({quote_identifier(source_table)})").fetchall()
            columns = [
                {
                    "name": str(row[1]),
                    "declaredType": str(row[2] or ""),
                    "notNull": bool(row[3]),
                    "primaryKeyPosition": int(row[5] or 0),
                }
                for row in info_rows
            ]
            record_table(
                db,
                source_key=source_key,
                source_file=str(path.relative_to(package_dir)),
                source_table=source_table,
                warehouse_table=warehouse_table,
                row_count=row_count,
                columns=columns,
                imported_at=imported_at,
            )
            table_count += 1
            total_rows += row_count
            print(f"  SQLite {source_table} -> {warehouse_table}: {row_count:,} rows")
        db.commit()
    finally:
        db.execute(f"DETACH DATABASE {alias}")
    return table_count, total_rows


def import_csv(
    db: sqlite3.Connection,
    *,
    source_key: str,
    package_dir: Path,
    path: Path,
    imported_at: str,
    batch_size: int,
) -> tuple[int, int]:
    try:
        csv.field_size_limit(sys.maxsize)
    except OverflowError:
        csv.field_size_limit(2**31 - 1)

    source_table = path.stem
    file_stem = safe_identifier(path.stem, fallback="csv")
    warehouse_table = safe_identifier(f"src_{source_key}__{file_stem}")
    with path.open("r", encoding="utf-8-sig", errors="replace", newline="") as handle:
        reader = csv.reader(handle)
        try:
            headers = next(reader)
        except StopIteration:
            return 0, 0
        normalized = unique_columns([str(header) for header in headers])
        if not normalized:
            return 0, 0
        db.execute(f"DROP TABLE IF EXISTS {quote_identifier(warehouse_table)}")
        definitions = ", ".join(f"{quote_identifier(column)} TEXT" for column in normalized)
        db.execute(
            f"CREATE TABLE {quote_identifier(warehouse_table)} "
            f"(__source_row INTEGER NOT NULL, {definitions})"
        )
        placeholders = ",".join("?" for _ in range(len(normalized) + 1))
        insert_sql = f"INSERT INTO {quote_identifier(warehouse_table)} VALUES ({placeholders})"
        batch: list[tuple[Any, ...]] = []
        row_count = 0
        for row_index, row in enumerate(reader, start=1):
            values = list(row[: len(normalized)])
            if len(values) < len(normalized):
                values.extend([""] * (len(normalized) - len(values)))
            batch.append((row_index, *values))
            if len(batch) >= batch_size:
                db.executemany(insert_sql, batch)
                row_count += len(batch)
                batch.clear()
                if row_count % 250000 < batch_size:
                    print(f"    {path.name}: {row_count:,} rows")
        if batch:
            db.executemany(insert_sql, batch)
            row_count += len(batch)
        columns = [
            {"name": "__source_row", "declaredType": "INTEGER", "sourceHeader": None},
            *[
                {"name": normalized[index], "declaredType": "TEXT", "sourceHeader": headers[index]}
                for index in range(len(normalized))
            ],
        ]
        record_table(
            db,
            source_key=source_key,
            source_file=str(path.relative_to(package_dir)),
            source_table=source_table,
            warehouse_table=warehouse_table,
            row_count=row_count,
            columns=columns,
            imported_at=imported_at,
        )
        db.commit()
    print(f"  CSV {path.name} -> {warehouse_table}: {row_count:,} rows")
    return 1, row_count


def import_source(
    db: sqlite3.Connection,
    *,
    source: dict[str, Any],
    source_root: Path,
    include_csv_with_sqlite: bool,
    batch_size: int,
) -> dict[str, Any]:
    source_key = str(source["key"])
    package_dir = source_root / source_key
    result: dict[str, Any] = {
        "sourceKey": source_key,
        "packagePath": str(package_dir),
        "status": "missing",
        "files": 0,
        "tables": 0,
        "rows": 0,
        "warnings": [],
    }
    if not package_dir.exists():
        result["warnings"].append(f"Source package not downloaded: {package_dir}")
        return result

    drop_source(db, source_key)
    imported_at = now_iso()
    selected_files, warnings = discover_files(package_dir, include_csv_with_sqlite)
    result["warnings"].extend(warnings)
    if not selected_files:
        result["status"] = "empty"
        result["warnings"].append(f"No supported SQLite/CSV files found under {package_dir}")
        return result

    for path in selected_files:
        register_file(db, source_key, package_dir, path, imported_at)
        result["files"] += 1
        if path.suffix.lower() in SQLITE_SUFFIXES:
            tables, rows = import_sqlite(
                db,
                source_key=source_key,
                package_dir=package_dir,
                path=path,
                imported_at=imported_at,
            )
        else:
            tables, rows = import_csv(
                db,
                source_key=source_key,
                package_dir=package_dir,
                path=path,
                imported_at=imported_at,
                batch_size=batch_size,
            )
        result["tables"] += tables
        result["rows"] += rows

    db.execute(
        """
        INSERT OR REPLACE INTO historical_source_registry(
          source_key, label, dataset_slug, dataset_url, code_url, origin, license, priority,
          role, coverage, redistribution_note, package_path, imported_at, file_count,
          table_count, row_count, metadata_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            source_key,
            source.get("label") or source_key,
            source.get("dataset"),
            source.get("datasetUrl"),
            source.get("codeUrl"),
            source.get("origin"),
            source.get("license"),
            source.get("priority"),
            source.get("role"),
            source.get("coverage"),
            source.get("redistributionNote"),
            str(package_dir),
            imported_at,
            result["files"],
            result["tables"],
            result["rows"],
            json.dumps(source, ensure_ascii=False),
        ),
    )
    db.commit()
    result["status"] = "imported"
    return result


def main() -> int:
    args = parse_args()
    registry_path = Path(args.registry)
    source_root = Path(args.source_root)
    output = Path(args.output)
    report_path = Path(args.report)
    registry = load_registry(registry_path)

    selected_keys = {value.strip() for value in args.sources.split(",") if value.strip()}
    dataset_sources = [source for source in registry["sources"] if source.get("dataset")]
    if selected_keys:
        unknown = selected_keys - {str(source["key"]) for source in dataset_sources}
        if unknown:
            raise ValueError(f"Unknown historical source key(s): {', '.join(sorted(unknown))}")
        dataset_sources = [source for source in dataset_sources if str(source["key"]) in selected_keys]

    output.parent.mkdir(parents=True, exist_ok=True)
    if args.replace and output.exists():
        output.unlink()

    run_id = datetime.now(timezone.utc).strftime("history-%Y%m%dT%H%M%S%fZ")
    started_at = now_iso()
    report: dict[str, Any] = {
        "runId": run_id,
        "startedAt": started_at,
        "status": "running",
        "registry": str(registry_path),
        "sourceRoot": str(source_root),
        "outputDatabase": str(output),
        "sources": [],
        "summary": {},
    }

    db = sqlite3.connect(output)
    try:
        initialize_database(db)
        db.execute(
            "INSERT OR REPLACE INTO historical_import_runs(run_id, started_at, status, source_root, output_database, sources_json) VALUES (?, ?, 'running', ?, ?, ?)",
            (run_id, started_at, str(source_root), str(output), json.dumps([source["key"] for source in dataset_sources])),
        )
        db.commit()

        for source in dataset_sources:
            print(f"\n==> {source['key']}: {source.get('label', '')}")
            report["sources"].append(
                import_source(
                    db,
                    source=source,
                    source_root=source_root,
                    include_csv_with_sqlite=args.include_csv_with_sqlite,
                    batch_size=max(1000, args.batch_size),
                )
            )

        imported = [source for source in report["sources"] if source["status"] == "imported"]
        table_count = sum(int(source["tables"]) for source in imported)
        row_count = sum(int(source["rows"]) for source in imported)
        file_count = sum(int(source["files"]) for source in imported)
        warnings = [warning for source in report["sources"] for warning in source["warnings"]]
        status = "pass" if imported else "no_sources_imported"
        finished_at = now_iso()
        report["status"] = status
        report["finishedAt"] = finished_at
        report["summary"] = {
            "importedSources": len(imported),
            "configuredSources": len(dataset_sources),
            "files": file_count,
            "tables": table_count,
            "rows": row_count,
            "warnings": len(warnings),
        }
        db.execute(
            """
            UPDATE historical_import_runs
            SET finished_at = ?, status = ?, table_count = ?, row_count = ?, file_count = ?, warnings_json = ?
            WHERE run_id = ?
            """,
            (finished_at, status, table_count, row_count, file_count, json.dumps(warnings), run_id),
        )
        db.commit()
    except Exception as error:
        report["status"] = "fail"
        report["finishedAt"] = now_iso()
        report["error"] = f"{type(error).__name__}: {error}"
        try:
            db.execute(
                "UPDATE historical_import_runs SET finished_at = ?, status = 'fail', warnings_json = ? WHERE run_id = ?",
                (report["finishedAt"], json.dumps([report["error"]]), run_id),
            )
            db.commit()
        except sqlite3.Error:
            pass
        write_json(report_path, report)
        raise
    finally:
        db.close()

    write_json(report_path, report)
    print("\n" + json.dumps(report["summary"], indent=2))
    print(f"Historical warehouse: {output}")
    print(f"Import report: {report_path}")
    return 0 if report["status"] == "pass" else 2


if __name__ == "__main__":
    raise SystemExit(main())
