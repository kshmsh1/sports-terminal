from __future__ import annotations

import hashlib
import os
import shutil
import sqlite3
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

from . import backup_manifests
from .database import connect
from .object_store import object_store_from_env


@dataclass(frozen=True)
class RestoreVerification:
    backup_id: str
    object_key: str
    sha256: str
    byte_size: int


class RestoreExecutionError(RuntimeError):
    pass


def verify_backup_object(backup_id: str) -> tuple[dict, bytes, RestoreVerification]:
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM backup_manifests WHERE id = ?",
            (backup_id,),
        ).fetchone()
        if row is None:
            raise RestoreExecutionError("backup manifest not found")
        manifest = dict(row)
    data = object_store_from_env().get(str(manifest["object_key"]))
    observed = hashlib.sha256(data).hexdigest()
    if observed != str(manifest["sha256"]):
        raise RestoreExecutionError("backup object checksum does not match manifest")
    if not backup_manifests.BackupManifestService().verify_manifest(
        backup_id, observed_sha256=observed
    ):
        raise RestoreExecutionError("backup manifest signature is invalid")
    return manifest, data, RestoreVerification(
        backup_id=backup_id,
        object_key=str(manifest["object_key"]),
        sha256=observed,
        byte_size=len(data),
    )


def restore_sqlite_to_path(backup_id: str, target: Path) -> RestoreVerification:
    manifest, data, verification = verify_backup_object(backup_id)
    if str(manifest["database_backend"]) != "sqlite":
        raise RestoreExecutionError("backup is not a SQLite backup")
    target = target.resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as handle:
        handle.write(data)
        temporary = Path(handle.name)
    try:
        connection = sqlite3.connect(temporary)
        try:
            quick = connection.execute("PRAGMA quick_check").fetchone()
            if quick is None or str(quick[0]).lower() != "ok":
                raise RestoreExecutionError("restored SQLite backup failed quick_check")
        finally:
            connection.close()
        os.replace(temporary, target)
    finally:
        if temporary.exists():
            temporary.unlink()
    backup_manifests.BackupManifestService().mark_restored(backup_id)
    return verification


def restore_postgres_to_database(
    backup_id: str,
    *,
    target_database_url: str,
    allow_destructive: bool = False,
) -> RestoreVerification:
    manifest, data, verification = verify_backup_object(backup_id)
    if str(manifest["database_backend"]) != "postgresql":
        raise RestoreExecutionError("backup is not a PostgreSQL backup")
    if not allow_destructive or os.getenv("SPORTS_TERMINAL_ALLOW_DATABASE_RESTORE", "false").lower() != "true":
        raise RestoreExecutionError("destructive PostgreSQL restore is disabled")
    if not shutil.which("pg_restore"):
        raise RestoreExecutionError("pg_restore is required for PostgreSQL restore")
    parsed = urlparse(target_database_url)
    if parsed.scheme not in {"postgres", "postgresql"}:
        raise RestoreExecutionError("target_database_url must be PostgreSQL")
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
        ["pg_restore", "--clean", "--if-exists", "--no-owner", "--no-acl", "--dbname", env["PGDATABASE"]],
        input=data,
        env=env,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        error = completed.stderr.decode("utf-8", errors="replace")[-1000:]
        raise RestoreExecutionError(f"pg_restore failed: {error}")
    backup_manifests.BackupManifestService().mark_restored(backup_id)
    return verification
