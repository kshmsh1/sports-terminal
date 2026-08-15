from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable

from .database import connect, database_backend
from .migrations import current_schema_version, discover_migrations
from .platform_audit import PlatformAuditLog
from .runtime_config import load_runtime_config


@dataclass(frozen=True)
class HealthCheck:
    name: str
    healthy: bool
    detail: str
    critical: bool = True


@dataclass(frozen=True)
class HealthSnapshot:
    status: str
    checks: tuple[HealthCheck, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "status": self.status,
            "checks": [
                {
                    "name": check.name,
                    "healthy": check.healthy,
                    "detail": check.detail,
                    "critical": check.critical,
                }
                for check in self.checks
            ],
        }


class ServiceHealthEvaluator:
    def _database(self) -> HealthCheck:
        try:
            with connect() as connection:
                connection.execute("SELECT 1 AS ok").fetchone()
            return HealthCheck("database", True, database_backend())
        except Exception as error:
            return HealthCheck("database", False, type(error).__name__)

    def _schema(self) -> HealthCheck:
        try:
            migrations = discover_migrations()
            target = migrations[-1].version if migrations else "unversioned"
            current = current_schema_version()
            return HealthCheck(
                "schema",
                current == target,
                f"current={current} target={target}",
            )
        except Exception as error:
            return HealthCheck("schema", False, type(error).__name__)

    def _audit(self) -> HealthCheck:
        try:
            result = PlatformAuditLog().verify(limit=10_000)
            return HealthCheck(
                "audit_chain",
                result.valid,
                f"events={result.events} first_invalid={result.first_invalid_id}",
            )
        except Exception as error:
            return HealthCheck("audit_chain", False, type(error).__name__)

    def _configuration(self) -> HealthCheck:
        config = load_runtime_config()
        errors = config.production_errors()
        healthy = not config.production or not errors
        detail = "safe" if healthy else "; ".join(errors)
        return HealthCheck("runtime_configuration", healthy, detail)

    def snapshot(self) -> HealthSnapshot:
        checks = (
            self._database(),
            self._schema(),
            self._configuration(),
            self._audit(),
        )
        critical_failures = [check for check in checks if check.critical and not check.healthy]
        return HealthSnapshot("healthy" if not critical_failures else "unhealthy", checks)
