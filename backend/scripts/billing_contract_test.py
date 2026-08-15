from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path

from app import billing_api, database
from app.entitlements import EntitlementService
from app import entitlements
from app.migrations import run_migrations


def main() -> None:
    keys = [
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_BILLING_MODE",
        "SPORTS_TERMINAL_BILLING_WEBHOOK_SECRET",
    ]
    previous = {key: os.environ.get(key) for key in keys}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_BILLING_MODE"] = "test"
        os.environ["SPORTS_TERMINAL_BILLING_WEBHOOK_SECRET"] = "billing-secret-" + "x" * 32
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "billing.db"
            billing_api.connect = database.connect
            entitlements.connect = database.connect
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL);
                    CREATE TABLE subscriptions (
                      id TEXT PRIMARY KEY,
                      user_id TEXT NOT NULL,
                      plan_id TEXT NOT NULL,
                      status TEXT NOT NULL,
                      updated_at TEXT NOT NULL
                    );
                    """
                )
                connection.execute("INSERT INTO users VALUES (?, ?)", ("u1", "user@example.com"))
            run_migrations()

            body = json.dumps(
                {"data": {"user_id": "u1", "plan_id": "pro", "subscription_id": "sub_1"}},
                separators=(",", ":"),
            ).encode()
            service = billing_api.BillingWebhookService()
            signature = service.signature(body)
            first = service.ingest(
                provider="contract",
                provider_event_id="evt_1",
                event_type="subscription.activated",
                body=body,
                signature=signature,
            )
            assert first.processed is True and first.duplicate is False
            second = service.ingest(
                provider="contract",
                provider_event_id="evt_1",
                event_type="subscription.activated",
                body=body,
                signature=signature,
            )
            assert second.duplicate is True
            snapshot = EntitlementService().for_user("u1")
            assert snapshot.plan_id == "pro"
            assert snapshot.allows("exports.structured")

            tampered = b'{"data":{"user_id":"u1","plan_id":"enterprise"}}'
            assert service.verify(tampered, signature) is False

        os.environ["SPORTS_TERMINAL_BILLING_MODE"] = "disabled"
        try:
            billing_api.BillingWebhookService().signature(b"{}")
        except RuntimeError as error:
            assert "disabled" in str(error)
        else:
            raise AssertionError("disabled billing must fail closed")

        print("billing_contract: PASS")
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
