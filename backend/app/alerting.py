from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any

from fastapi import APIRouter

from .metrics_api import operational_metrics

router = APIRouter(prefix="/v2/operations/alerts", tags=["operations-alerts"])


@dataclass(frozen=True)
class OperationalAlert:
    code: str
    severity: str
    message: str
    value: float

    def to_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "severity": self.severity,
            "message": self.message,
            "value": self.value,
        }


class AlertEvaluator:
    def evaluate(self, metrics: dict[str, float] | None = None) -> list[OperationalAlert]:
        values = metrics or operational_metrics()
        alerts: list[OperationalAlert] = []
        if values.get("sports_terminal_health", 0.0) < 1:
            alerts.append(
                OperationalAlert("platform-unhealthy", "critical", "A critical health check is failing", values.get("sports_terminal_health", 0.0))
            )
        backup_age = values.get("sports_terminal_backup_age_seconds", -1.0)
        environment = os.getenv("SPORTS_TERMINAL_ENV", "development").lower()
        max_backup_age = float(os.getenv("SPORTS_TERMINAL_MAX_BACKUP_AGE_SECONDS", "93600"))
        if environment == "production" and backup_age < 0:
            alerts.append(
                OperationalAlert("backup-missing", "critical", "No database backup is recorded", backup_age)
            )
        elif backup_age > max_backup_age:
            alerts.append(
                OperationalAlert("backup-stale", "critical", "Latest database backup exceeds the allowed age", backup_age)
            )
        failed_delivery = values.get("sports_terminal_failed_deliveries", 0.0)
        if failed_delivery > 0:
            alerts.append(
                OperationalAlert("security-email-failures", "warning", "One or more security email deliveries failed", failed_delivery)
            )
        failed_billing = values.get("sports_terminal_failed_billing_webhooks", 0.0)
        if failed_billing > 0:
            alerts.append(
                OperationalAlert("billing-webhook-failures", "warning", "One or more billing webhook events failed", failed_billing)
            )
        active_releases = values.get("sports_terminal_active_releases", 0.0)
        if environment == "production" and active_releases < 1:
            alerts.append(
                OperationalAlert("active-release-missing", "critical", "Production has no active certified release", active_releases)
            )
        return alerts


@router.get("")
def current_alerts() -> dict[str, Any]:
    alerts = AlertEvaluator().evaluate()
    return {
        "status": "attention" if alerts else "clear",
        "alerts": [alert.to_dict() for alert in alerts],
    }
