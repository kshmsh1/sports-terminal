from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database
from app.auth_api import init_auth_db
from app.email_delivery import EmailDeliveryError, SecurityEmailDelivery
from app.migrations import run_migrations
from app.production_bootstrap import bind_database_boundary


def main() -> None:
    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_EMAIL_PROVIDER",
        "SPORTS_TERMINAL_ENV",
    )}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_ENV"] = "development"
        os.environ["SPORTS_TERMINAL_EMAIL_PROVIDER"] = "console"
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "email.db"
            bind_database_boundary()
            init_auth_db()
            run_migrations()
            receipt = SecurityEmailDelivery().send_security_email(
                destination="Analyst@Example.com",
                template_key="verify-email",
                subject="Verify",
                text="sensitive token is passed only to the delivery boundary",
                metadata={"user_id": "usr_demo", "token": "must-not-persist"},
            )
            assert receipt.status == "delivered"
            with database.connect() as connection:
                row = connection.execute(
                    "SELECT destination_hash, payload, provider, status FROM delivery_outbox WHERE id = ?",
                    (receipt.message_id,),
                ).fetchone()
                assert row is not None
                assert row["destination_hash"] != "analyst@example.com"
                assert "must-not-persist" not in row["payload"]
                assert "token" not in row["payload"]
                assert row["provider"] == "console"
                assert row["status"] == "delivered"

        os.environ["SPORTS_TERMINAL_ENV"] = "production"
        os.environ["SPORTS_TERMINAL_EMAIL_PROVIDER"] = "console"
        try:
            SecurityEmailDelivery().send_security_email(
                destination="a@example.com",
                template_key="security-alert",
                subject="Security",
                text="body",
            )
        except EmailDeliveryError as error:
            assert "forbidden in production" in str(error)
        else:
            raise AssertionError("production console mail must be rejected")

        print("email_delivery_contract: PASS")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
