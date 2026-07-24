from __future__ import annotations

import argparse
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a consistent SQLite backup of the Sports Terminal launch database."
    )
    parser.add_argument(
        "--database",
        default=os.getenv("SPORTS_TERMINAL_DB_PATH", "backend/.data/sports_terminal.db"),
    )
    parser.add_argument("--output-directory", default="backups")
    parser.add_argument("--retain", type=int, default=14)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source = Path(args.database).expanduser().resolve()
    if not source.exists():
        raise FileNotFoundError(f"Sports Terminal database does not exist: {source}")
    output_directory = Path(args.output_directory).expanduser().resolve()
    output_directory.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    destination = output_directory / f"sports_terminal_{timestamp}.sqlite"

    source_connection = sqlite3.connect(source)
    destination_connection = sqlite3.connect(destination)
    try:
        source_connection.execute("PRAGMA wal_checkpoint(PASSIVE)")
        source_connection.backup(destination_connection)
        integrity = destination_connection.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise RuntimeError(f"Backup integrity check failed: {integrity}")
    finally:
        destination_connection.close()
        source_connection.close()

    backups = sorted(
        output_directory.glob("sports_terminal_*.sqlite"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    retained = max(1, args.retain)
    for expired in backups[retained:]:
        expired.unlink()

    print(
        f"Created verified Sports Terminal database backup: {destination} "
        f"({destination.stat().st_size} bytes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
