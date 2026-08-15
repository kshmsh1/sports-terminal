from __future__ import annotations

from dataclasses import dataclass

from .database import connect
from .main import now_iso
from .migrations import current_schema_version
from .platform_audit import PlatformAuditLog


ENVIRONMENTS = ("development", "staging", "production")
ALLOWED_PROMOTIONS = {
    ("development", "staging"),
    ("staging", "production"),
}


@dataclass(frozen=True)
class PromotionResult:
    source: str
    target: str
    release_id: str
    schema_version: str
    promoted_at: str


class EnvironmentPromotionError(RuntimeError):
    pass


class EnvironmentPromotionService:
    def promote(
        self,
        *,
        source: str,
        target: str,
        actor: str,
        reason: str,
    ) -> PromotionResult:
        source = source.strip().lower()
        target = target.strip().lower()
        if (source, target) not in ALLOWED_PROMOTIONS:
            raise EnvironmentPromotionError("environment promotion must follow development → staging → production")
        if len(reason.strip()) < 5:
            raise EnvironmentPromotionError("promotion reason is required")

        schema_version = current_schema_version()
        with connect() as connection:
            source_row = connection.execute(
                "SELECT * FROM deployment_environments WHERE environment = ?",
                (source,),
            ).fetchone()
            if source_row is None or not source_row["release_id"]:
                raise EnvironmentPromotionError("source environment has no deployed release")
            if str(source_row["status"]) not in {"healthy", "verified", "active"}:
                raise EnvironmentPromotionError("source environment is not healthy enough to promote")
            if str(source_row["database_schema_version"] or "") != schema_version:
                raise EnvironmentPromotionError("source environment schema is not current")
            release = connection.execute(
                "SELECT id, status FROM certified_releases WHERE id = ?",
                (source_row["release_id"],),
            ).fetchone()
            if release is None or str(release["status"]) not in {"certified", "active"}:
                raise EnvironmentPromotionError("only certified releases can be promoted")
            timestamp = now_iso()
            connection.execute(
                "DELETE FROM deployment_environments WHERE environment = ?",
                (target,),
            )
            connection.execute(
                """
                INSERT INTO deployment_environments
                  (environment, release_id, database_schema_version, status, deployed_at, updated_at)
                VALUES (?, ?, ?, 'promoted', ?, ?)
                """,
                (target, release["id"], schema_version, timestamp, timestamp),
            )
            connection.commit()

        PlatformAuditLog().record(
            actor_type="user",
            actor_id=actor,
            action="environment.promoted",
            object_type="deployment_environment",
            object_id=target,
            metadata={
                "source": source,
                "target": target,
                "release_id": str(release["id"]),
                "schema_version": schema_version,
                "reason": reason.strip(),
            },
        )
        return PromotionResult(source, target, str(release["id"]), schema_version, timestamp)

    def mark_healthy(self, environment: str, *, actor: str) -> dict:
        environment = environment.strip().lower()
        if environment not in ENVIRONMENTS:
            raise EnvironmentPromotionError("unknown deployment environment")
        with connect() as connection:
            row = connection.execute(
                "SELECT * FROM deployment_environments WHERE environment = ?",
                (environment,),
            ).fetchone()
            if row is None:
                raise EnvironmentPromotionError("deployment environment is not initialized")
            connection.execute(
                "UPDATE deployment_environments SET status = 'healthy', updated_at = ? WHERE environment = ?",
                (now_iso(), environment),
            )
            connection.commit()
        PlatformAuditLog().record(
            actor_type="user",
            actor_id=actor,
            action="environment.healthy",
            object_type="deployment_environment",
            object_id=environment,
        )
        return {"environment": environment, "status": "healthy"}
