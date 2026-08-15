from __future__ import annotations

import os

from app.alerting import AlertEvaluator


def main() -> None:
    original = os.environ.get("SPORTS_TERMINAL_ENV")
    try:
        os.environ["SPORTS_TERMINAL_ENV"] = "production"
        alerts = AlertEvaluator().evaluate(
            {
                "sports_terminal_health": 0.0,
                "sports_terminal_backup_age_seconds": -1.0,
                "sports_terminal_failed_deliveries": 2.0,
                "sports_terminal_failed_billing_webhooks": 1.0,
                "sports_terminal_active_releases": 0.0,
            }
        )
        codes = {alert.code for alert in alerts}
        assert {
            "platform-unhealthy",
            "backup-missing",
            "security-email-failures",
            "billing-webhook-failures",
            "active-release-missing",
        }.issubset(codes)
        assert all(alert.severity in {"warning", "critical"} for alert in alerts)

        clear = AlertEvaluator().evaluate(
            {
                "sports_terminal_health": 1.0,
                "sports_terminal_backup_age_seconds": 60.0,
                "sports_terminal_failed_deliveries": 0.0,
                "sports_terminal_failed_billing_webhooks": 0.0,
                "sports_terminal_active_releases": 1.0,
            }
        )
        assert clear == []
        print("alerting_contract: PASS")
    finally:
        if original is None:
            os.environ.pop("SPORTS_TERMINAL_ENV", None)
        else:
            os.environ["SPORTS_TERMINAL_ENV"] = original


if __name__ == "__main__":
    main()
