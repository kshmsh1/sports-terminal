from __future__ import annotations

import os
import shutil
import sqlite3
import subprocess
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

from .backup_manifests import BackupManifestService
from .database import connect, database_backend
from .main import make_id
from .object_store import ObjectPutResult, object_store_from_env
from .runtime_config import load_runtime_config


@dataclass(frozen=True)
class BackupExecutionResult:
    manifest: dict
    object: ObjectPutResult


class BackupExecutionError(RuntimeError):
    pass


def _sqlite_dump_bytes() -> bytes:
    with tempfile.TemporaryDirectory() as directory:
        target = Path(directory) / "sports_terminal.sqlite3"
        source = connect()
        try:
            if source.backend != "sqlite":
                raise BackupExecutionError("SQLite backup requested for non-SQLite database")
            destination = sqlite3.connect(target)
            try:
                source.raw.backup(destination)
            finally:
                destination.close()
        finally:
            source.close()
        return target.read_bytes()


def _postgres_dump_bytes() -> bytes:
    config = load_runtime_config()
    if not shutil.which("pg_dump"):
        raise BackupExecutionError("pg_dump is required for PostgreSQL backups")
    parsed = urlparse(config.database_url)
    if parsed.scheme not in {"postgres", "postgresql"}:
        raise BackupExecutionError("PostgreSQL backup requires a PostgreSQL DATABASE_URL")
    env = dict(os.environ)
    env.update(
        {
            "PGHOST": parsed.hostname or "",
            "PGPORT": str(parsed.port or 5432),
            "PGUSER": parsed.username or "",
            "PGPASSWORD": parsed.password or "",
            "PGDATABASE": (parsed.path or "").lstrip("/"),
        }
    )
    completed = subprocess.run(
        ["pg_dump", "--format=custom", "--no-owner", "--no-acl"],
        env=env,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        error = completed.stderr.decode("utf-8", errors="replace")[-1000:]
        raise BackupExecutionError(f"pg_dump failed: {error}")
    if not completed.stdout:
        raise BackupExecutionError("pg_dump returned an empty backup")
    return completed.stdout


def create_database_backup(*, release_id: str | None = None) -> BackupExecutionResult:
    backend = database_backend()
    if backend == "sqlite":
        data = _sqlite_dump_bytes()
        extension = "sqlite3"
    elif backend == "postgresql":
        data = _postgres_dump_bytes()
        extension = "pgdump"
    else:
        raise BackupExecutionError(f"unsupported database backend: {backend}")

    timestamp = datetime.now(timezone.utc).strftime("%Y/%m/%d/%H%M%S")
    object_key = f"database-backups/{timestamp}-{make_id('backup')}.{extension}"
    stored = object_store_from_env().put(object_key, data)
    manifest = BackupManifestService().record(
        object_key=stored.key,
        sha256=stored.sha256,
        byte_size=stored.byte_size,
        release_id=release_id,
    )
    if not BackupManifestService().verify_manifest(
        str(manifest["id"]), observed_sha256=stored.sha256
    ):
        raise BackupExecutionError("new backup manifest failed immediate verification")
    return BackupExecutionResult(manifest=manifest, object=stored)
