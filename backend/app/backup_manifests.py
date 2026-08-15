from __future__ import annotations

import hashlib
import hmac
import json
from dataclasses import dataclass
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from .database import database_backend
from .main import connect, make_id, now_iso, rows_to_dicts
from .migrations import current_schema_version
from .release_management_api import ReleaseService
from .runtime_config import load_runtime_config

router = APIRouter(prefix="/v2/operations/backups", tags=["backups"])


class BackupRecordRequest(BaseModel):
    object_key: str
    sha256: str
    byte_size: int | None = None
    release_id: str | None = None


@dataclass(frozen=True)
class BackupEnvelope:
    payload: str
    signature: str


class BackupManifestService:
    def _secret(self) -> str:
        config = load_runtime_config()
        secret = config.backup_signing_secret
        if len(secret) < 32:
            if config.production:
                raise RuntimeError("backup signing secret is not configured")
            secret = "development-backup-signing-secret-32chars"
        return secret

    def _envelope(self, payload: dict[str, Any]) -> BackupEnvelope:
        canonical = json.dumps(payload, separators=(",", ":"), sort_keys=True)
        signature = hmac.new(
            self._secret().encode("utf-8"),
            f"backup-v1:{canonical}".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        return BackupEnvelope(canonical, signature)

    def record(
        self,
        *,
        object_key: str,
        sha256: str,
        byte_size: int | None = None,
        release_id: str | None = None,
    ) -> dict[str, Any]:
        normalized_hash = sha256.strip().lower()
        if len(normalized_hash) != 64 or any(ch not in "0123456789abcdef" for ch in normalized_hash):
            raise ValueError("backup sha256 must be a 64-character hexadecimal digest")
        if not object_key.strip():
            raise ValueError("backup object_key is required")
        backup_id = make_id("bak")
        payload = {
            "id": backup_id,
            "database_backend": database_backend(),
            "schema_version": current_schema_version(),
            "release_id": release_id,
            "object_key": object_key,
            "byte_size": byte_size,
            "sha256": normalized_hash,
        }
        signature = self._envelope(payload).signature
        with connect() as connection:
            connection.execute(
                "INSERT INTO backup_manifests "
                "(id, database_backend, schema_version, release_id, object_key, byte_size, sha256, signature, status, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'created', ?)",
                (
                    backup_id,
                    payload["database_backend"],
                    payload["schema_version"],
                    release_id,
                    object_key,
                    byte_size,
                    normalized_hash,
                    signature,
                    now_iso(),
                ),
            )
            connection.commit()
            return dict(
                connection.execute(
                    "SELECT * FROM backup_manifests WHERE id = ?", (backup_id,)
                ).fetchone()
            )

    def verify_manifest(self, backup_id: str, *, observed_sha256: str | None = None) -> bool:
        with connect() as connection:
            row = connection.execute(
                "SELECT * FROM backup_manifests WHERE id = ?", (backup_id,)
            ).fetchone()
            if row is None:
                raise KeyError("backup manifest not found")
            payload = {
                "id": row["id"],
                "database_backend": row["database_backend"],
                "schema_version": row["schema_version"],
                "release_id": row["release_id"],
                "object_key": row["object_key"],
                "byte_size": row["byte_size"],
                "sha256": row["sha256"],
            }
            expected = self._envelope(payload).signature
            valid = hmac.compare_digest(expected, str(row["signature"]))
            if observed_sha256 is not None:
                valid = valid and hmac.compare_digest(
                    str(row["sha256"]), observed_sha256.strip().lower()
                )
            if valid:
                connection.execute(
                    "UPDATE backup_manifests SET status = 'verified', verified_at = ? WHERE id = ?",
                    (now_iso(), backup_id),
                )
                connection.commit()
            return valid

    def mark_restored(self, backup_id: str) -> dict[str, Any]:
        if not self.verify_manifest(backup_id):
            raise RuntimeError("backup manifest integrity verification failed")
        with connect() as connection:
            connection.execute(
                "UPDATE backup_manifests SET status = 'restored', restored_at = ? WHERE id = ?",
                (now_iso(), backup_id),
            )
            connection.commit()
            return dict(
                connection.execute(
                    "SELECT * FROM backup_manifests WHERE id = ?", (backup_id,)
                ).fetchone()
            )

    def recent(self, limit: int = 50) -> list[dict[str, Any]]:
        with connect() as connection:
            return rows_to_dicts(
                connection.execute(
                    "SELECT * FROM backup_manifests ORDER BY created_at DESC LIMIT ?",
                    (max(1, min(limit, 500)),),
                ).fetchall()
            )


@router.post("")
def record_backup(payload: BackupRecordRequest) -> dict[str, Any]:
    try:
        return BackupManifestService().record(
            object_key=payload.object_key,
            sha256=payload.sha256,
            byte_size=payload.byte_size,
            release_id=payload.release_id,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.post("/{backup_id}/verify")
def verify_backup(backup_id: str, observed_sha256: str | None = None) -> dict[str, Any]:
    try:
        valid = BackupManifestService().verify_manifest(
            backup_id, observed_sha256=observed_sha256
        )
    except KeyError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    return {"backup_id": backup_id, "valid": valid}


@router.get("")
def recent_backups(limit: int = 50) -> list[dict[str, Any]]:
    return BackupManifestService().recent(limit)
