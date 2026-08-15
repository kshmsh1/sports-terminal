from __future__ import annotations

import hashlib
import hmac
import json
from dataclasses import dataclass
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from .main import connect, make_id, now_iso, row_to_dict, rows_to_dicts
from .runtime_config import load_runtime_config

router = APIRouter(prefix="/v2/releases", tags=["certified-releases"])


class ReleaseCreateRequest(BaseModel):
    league: str = "NBA"
    season: str
    release_version: str
    manifest: dict[str, Any] = Field(default_factory=dict)
    source_snapshot: str | None = None


class ReleaseActivateRequest(BaseModel):
    environment: str
    actor: str
    reason: str | None = None


@dataclass(frozen=True)
class ReleaseEnvelope:
    manifest_json: str
    manifest_sha256: str
    signature: str


class ReleaseSigner:
    def _secret(self) -> str:
        config = load_runtime_config()
        secret = config.release_signing_secret
        if len(secret) < 32:
            if config.production:
                raise RuntimeError("release signing secret is not configured")
            secret = "development-release-signing-secret-32chars"
        return secret

    def envelope(self, manifest: dict[str, Any]) -> ReleaseEnvelope:
        canonical = json.dumps(manifest, separators=(",", ":"), sort_keys=True)
        digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
        signature = hmac.new(
            self._secret().encode("utf-8"),
            f"release-v1:{digest}".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        return ReleaseEnvelope(canonical, digest, signature)

    def verify(self, manifest_json: str, manifest_sha256: str, signature: str) -> bool:
        digest = hashlib.sha256(manifest_json.encode("utf-8")).hexdigest()
        if not hmac.compare_digest(digest, manifest_sha256):
            return False
        expected = hmac.new(
            self._secret().encode("utf-8"),
            f"release-v1:{digest}".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        return hmac.compare_digest(expected, signature)


class ReleaseService:
    def create_candidate(self, payload: ReleaseCreateRequest) -> dict[str, Any]:
        if not payload.season.strip() or not payload.release_version.strip():
            raise ValueError("season and release_version are required")
        envelope = ReleaseSigner().envelope(payload.manifest)
        release_id = make_id("rel")
        with connect() as connection:
            existing = connection.execute(
                "SELECT * FROM certified_releases WHERE league = ? AND season = ? AND release_version = ?",
                (payload.league.upper(), payload.season, payload.release_version),
            ).fetchone()
            if existing is not None:
                if existing["manifest_sha256"] != envelope.manifest_sha256:
                    raise RuntimeError("release version already exists with a different manifest")
                return dict(existing)
            connection.execute(
                "INSERT INTO certified_releases "
                "(id, league, season, release_version, manifest_sha256, manifest_json, signature, status, source_snapshot, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, 'candidate', ?, ?)",
                (
                    release_id,
                    payload.league.upper(),
                    payload.season,
                    payload.release_version,
                    envelope.manifest_sha256,
                    envelope.manifest_json,
                    envelope.signature,
                    payload.source_snapshot,
                    now_iso(),
                ),
            )
            connection.commit()
            row = connection.execute(
                "SELECT * FROM certified_releases WHERE id = ?", (release_id,)
            ).fetchone()
            return dict(row) if row is not None else {}

    def certify(self, release_id: str) -> dict[str, Any]:
        with connect() as connection:
            row = connection.execute(
                "SELECT * FROM certified_releases WHERE id = ?", (release_id,)
            ).fetchone()
            if row is None:
                raise KeyError("release not found")
            if not ReleaseSigner().verify(
                row["manifest_json"], row["manifest_sha256"], row["signature"]
            ):
                raise RuntimeError("release manifest integrity verification failed")
            if row["status"] == "retired":
                raise RuntimeError("retired releases cannot be recertified")
            connection.execute(
                "UPDATE certified_releases SET status = 'certified', certified_at = ? WHERE id = ?",
                (now_iso(), release_id),
            )
            connection.commit()
            return dict(
                connection.execute(
                    "SELECT * FROM certified_releases WHERE id = ?", (release_id,)
                ).fetchone()
            )

    def activate(
        self,
        release_id: str,
        *,
        environment: str,
        actor: str,
        reason: str | None = None,
    ) -> dict[str, Any]:
        normalized_env = environment.strip().lower()
        if normalized_env not in {"development", "staging", "production"}:
            raise ValueError("environment must be development, staging, or production")
        with connect() as connection:
            release = connection.execute(
                "SELECT * FROM certified_releases WHERE id = ?", (release_id,)
            ).fetchone()
            if release is None:
                raise KeyError("release not found")
            if release["status"] not in {"certified", "active"}:
                raise RuntimeError("only certified releases can be activated")
            if not ReleaseSigner().verify(
                release["manifest_json"], release["manifest_sha256"], release["signature"]
            ):
                raise RuntimeError("release manifest integrity verification failed")
            current = connection.execute(
                "SELECT release_id FROM deployment_environments WHERE environment = ?",
                (normalized_env,),
            ).fetchone()
            previous_id = current["release_id"] if current is not None else None
            timestamp = now_iso()
            connection.execute(
                "INSERT INTO release_activations "
                "(id, environment, release_id, previous_release_id, actor, reason, activated_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (make_id("act"), normalized_env, release_id, previous_id, actor, reason, timestamp),
            )
            connection.execute(
                "DELETE FROM deployment_environments WHERE environment = ?",
                (normalized_env,),
            )
            connection.execute(
                "INSERT INTO deployment_environments "
                "(environment, release_id, database_schema_version, status, deployed_at, updated_at) "
                "VALUES (?, ?, ?, 'active', ?, ?)",
                (normalized_env, release_id, _schema_version(connection), timestamp, timestamp),
            )
            connection.execute(
                "UPDATE certified_releases SET status = 'active', activated_at = ? WHERE id = ?",
                (timestamp, release_id),
            )
            connection.commit()
            return {
                "environment": normalized_env,
                "release_id": release_id,
                "previous_release_id": previous_id,
                "activated_at": timestamp,
            }

    def active(self, environment: str) -> dict[str, Any] | None:
        with connect() as connection:
            row = connection.execute(
                "SELECT deployment_environments.*, certified_releases.league, certified_releases.season, "
                "certified_releases.release_version, certified_releases.manifest_sha256 "
                "FROM deployment_environments LEFT JOIN certified_releases "
                "ON certified_releases.id = deployment_environments.release_id "
                "WHERE deployment_environments.environment = ?",
                (environment.strip().lower(),),
            ).fetchone()
            return None if row is None else dict(row)

    def history(self, environment: str, limit: int = 50) -> list[dict[str, Any]]:
        with connect() as connection:
            return rows_to_dicts(
                connection.execute(
                    "SELECT * FROM release_activations WHERE environment = ? "
                    "ORDER BY activated_at DESC LIMIT ?",
                    (environment.strip().lower(), max(1, min(limit, 200))),
                ).fetchall()
            )


def _schema_version(connection: Any) -> str:
    row = connection.execute(
        "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1"
    ).fetchone()
    return "unversioned" if row is None else str(row["version"])


@router.post("")
def create_release(payload: ReleaseCreateRequest) -> dict[str, Any]:
    try:
        return ReleaseService().create_candidate(payload)
    except (ValueError, RuntimeError) as error:
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.post("/{release_id}/certify")
def certify_release(release_id: str) -> dict[str, Any]:
    try:
        return ReleaseService().certify(release_id)
    except KeyError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except RuntimeError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.post("/{release_id}/activate")
def activate_release(release_id: str, payload: ReleaseActivateRequest) -> dict[str, Any]:
    try:
        return ReleaseService().activate(
            release_id,
            environment=payload.environment,
            actor=payload.actor,
            reason=payload.reason,
        )
    except KeyError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except (ValueError, RuntimeError) as error:
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.get("/active/{environment}")
def active_release(environment: str) -> dict[str, Any]:
    active = ReleaseService().active(environment)
    if active is None:
        raise HTTPException(status_code=404, detail="No active release for environment")
    return active


@router.get("/history/{environment}")
def release_history(environment: str, limit: int = 50) -> list[dict[str, Any]]:
    return ReleaseService().history(environment, limit=limit)
