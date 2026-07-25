from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def checksum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def integrity(connection: sqlite3.Connection) -> str:
    row = connection.execute("PRAGMA integrity_check").fetchone()
    return str(row[0] if row else "unknown")


def table_counts(connection: sqlite3.Connection) -> dict[str, int]:
    counts: dict[str, int] = {}
    tables = [
        str(row[0])
        for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
        ).fetchall()
    ]
    for table in tables:
        counts[table] = int(connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])
    return counts


def record_evidence(
    database: Path,
    *,
    backup_path: Path,
    digest: str,
    size_bytes: int,
    restore_tested: bool,
    status: str,
    actor_user_id: str,
    metadata: dict[str, Any],
) -> str:
    with sqlite3.connect(database) as connection:
        exists = connection.execute(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'backup_runs'"
        ).fetchone()
        if exists is None:
            return ""
        timestamp = now_iso()
        backup_id = f"backup_{hashlib.sha256((str(backup_path) + timestamp).encode()).hexdigest()[:12]}"
        connection.execute(
            "INSERT INTO backup_runs (id, backup_type, status, location, checksum, size_bytes, restore_tested, metadata_json, started_at, completed_at, created_by_user_id) VALUES (?, 'database', ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                backup_id,
                status,
                str(backup_path),
                f"sha256:{digest}",
                size_bytes,
                int(restore_tested),
                json.dumps(metadata, separators=(",", ":"), sort_keys=True),
                timestamp,
                timestamp,
                actor_user_id,
            ),
        )
        connection.commit()
        return backup_id


def backup_and_verify(
    database: Path,
    output_dir: Path,
    *,
    actor_user_id: str,
    record: bool,
) -> dict[str, Any]:
    if not database.exists():
        raise FileNotFoundError(database)
    output_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup_path = output_dir / f"sports_terminal_{timestamp}.sqlite"
    source = sqlite3.connect(database)
    try:
        source.execute("PRAGMA wal_checkpoint(FULL)")
        source_integrity = integrity(source)
        source_counts = table_counts(source)
        destination = sqlite3.connect(backup_path)
        try:
            source.backup(destination, pages=256)
            destination.commit()
        finally:
            destination.close()
    finally:
        source.close()

    digest = checksum(backup_path)
    with sqlite3.connect(backup_path) as backup_connection:
        backup_integrity = integrity(backup_connection)
        backup_counts = table_counts(backup_connection)

    with tempfile.TemporaryDirectory(prefix="sports-terminal-restore-") as temporary:
        restore_path = Path(temporary) / "restored.sqlite"
        backup_connection = sqlite3.connect(backup_path)
        try:
            restore_connection = sqlite3.connect(restore_path)
            try:
                backup_connection.backup(restore_connection, pages=256)
                restore_connection.commit()
            finally:
                restore_connection.close()
        finally:
            backup_connection.close()
        with sqlite3.connect(restore_path) as restored:
            restore_integrity = integrity(restored)
            restore_counts = table_counts(restored)

    counts_match = source_counts == backup_counts == restore_counts
    restore_tested = (
        source_integrity == "ok"
        and backup_integrity == "ok"
        and restore_integrity == "ok"
        and counts_match
    )
    status = "verified" if restore_tested else "failed"
    report: dict[str, Any] = {
        "status": status,
        "database": str(database),
        "backup": str(backup_path),
        "sha256": digest,
        "bytes": backup_path.stat().st_size,
        "source_integrity": source_integrity,
        "backup_integrity": backup_integrity,
        "restore_integrity": restore_integrity,
        "restore_tested": restore_tested,
        "table_counts_match": counts_match,
        "table_counts": source_counts,
        "generated_at": now_iso(),
    }
    if record:
        report["backup_run_id"] = record_evidence(
            database,
            backup_path=backup_path,
            digest=digest,
            size_bytes=backup_path.stat().st_size,
            restore_tested=restore_tested,
            status=status,
            actor_user_id=actor_user_id,
            metadata={
                "source_integrity": source_integrity,
                "backup_integrity": backup_integrity,
                "restore_integrity": restore_integrity,
                "table_counts_match": counts_match,
            },
        )
    report_path = backup_path.with_suffix(".report.json")
    report_path.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    report["report"] = str(report_path)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create a consistent Sports Terminal SQLite backup and verify a full restore."
    )
    parser.add_argument(
        "--database",
        default=os.getenv("SPORTS_TERMINAL_DB_PATH", "backend/.data/sports_terminal.db"),
    )
    parser.add_argument("--output-dir", default="data/backups")
    parser.add_argument("--actor-user-id", default="system")
    parser.add_argument("--record-evidence", action="store_true")
    args = parser.parse_args()
    try:
        report = backup_and_verify(
            Path(args.database),
            Path(args.output_dir),
            actor_user_id=args.actor_user_id,
            record=args.record_evidence,
        )
        print(json.dumps(report, indent=2, sort_keys=True))
        return 0 if report["status"] == "verified" else 1
    except Exception as error:
        print(
            json.dumps(
                {"status": "fail", "error": str(error), "generated_at": now_iso()},
                indent=2,
            ),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
