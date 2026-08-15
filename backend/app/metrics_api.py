from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Response

from .database import connect
from .service_health import ServiceHealthEvaluator

router = APIRouter(prefix="/v2/operations/metrics", tags=["operations-metrics"])


def _scalar(connection: Any, sql: str, params: tuple[Any, ...] = ()) -> float:
    try:
        row = connection.execute(sql, params).fetchone()
        if row is None:
            return 0.0
        return float(row[0] or 0)
    except Exception:
        return 0.0


def operational_metrics() -> dict[str, float]:
    health = ServiceHealthEvaluator().snapshot()
    metrics: dict[str, float] = {
        "sports_terminal_health": 1.0 if health.status == "healthy" else 0.0,
        "sports_terminal_health_failed_checks": float(
            sum(1 for check in health.checks if not check.healthy)
        ),
    }
    with connect() as connection:
        metrics.update(
            {
                "sports_terminal_active_sessions": _scalar(
                    connection,
                    "SELECT COUNT(*) FROM auth_sessions WHERE revoked_at IS NULL AND expires_at > ?",
                    (datetime.now(timezone.utc).isoformat(),),
                ),
                "sports_terminal_failed_deliveries": _scalar(
                    connection,
                    "SELECT COUNT(*) FROM delivery_outbox WHERE status = 'failed'",
                ),
                "sports_terminal_failed_billing_webhooks": _scalar(
                    connection,
                    "SELECT COUNT(*) FROM billing_webhook_events WHERE status = 'failed'",
                ),
                "sports_terminal_active_releases": _scalar(
                    connection,
                    "SELECT COUNT(*) FROM certified_releases WHERE status = 'active'",
                ),
                "sports_terminal_verified_backups": _scalar(
                    connection,
                    "SELECT COUNT(*) FROM backup_manifests WHERE status IN ('verified', 'restored')",
                ),
            }
        )
        try:
            latest = connection.execute(
                "SELECT created_at FROM backup_manifests ORDER BY created_at DESC LIMIT 1"
            ).fetchone()
            if latest is None:
                metrics["sports_terminal_backup_age_seconds"] = -1.0
            else:
                when = datetime.fromisoformat(str(latest["created_at"]))
                metrics["sports_terminal_backup_age_seconds"] = max(
                    0.0, (datetime.now(timezone.utc) - when).total_seconds()
                )
        except Exception:
            metrics["sports_terminal_backup_age_seconds"] = -1.0
    return metrics


@router.get("")
def metrics_json() -> dict[str, Any]:
    return {"metrics": operational_metrics()}


@router.get("/prometheus")
def metrics_prometheus() -> Response:
    lines = [
        "# Sports Terminal operational metrics",
        *[
            f"{name} {value}"
            for name, value in sorted(operational_metrics().items())
        ],
        "",
    ]
    return Response("\n".join(lines), media_type="text/plain; version=0.0.4")
