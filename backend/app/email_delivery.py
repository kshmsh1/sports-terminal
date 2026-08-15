from __future__ import annotations

import hashlib
import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any

from .database import connect
from .main import make_id, now_iso


@dataclass(frozen=True)
class DeliveryReceipt:
    message_id: str
    provider: str
    status: str


class EmailDeliveryError(RuntimeError):
    pass


class SecurityEmailDelivery:
    """Deliver account-security mail without persisting raw addresses or tokens.

    Supported modes are deliberately provider-neutral:
    - disabled: reject delivery; safest default.
    - console: development-only acknowledgement without external I/O.
    - http: POST one message to an operator-configured HTTPS mail gateway.

    The delivery ledger stores only a destination hash and scrubbed template metadata.
    Verification/reset secrets are never written to ``delivery_outbox``.
    """

    def __init__(self) -> None:
        self.provider = os.getenv("SPORTS_TERMINAL_EMAIL_PROVIDER", "disabled").strip().lower()
        self.endpoint = os.getenv("SPORTS_TERMINAL_EMAIL_HTTP_ENDPOINT", "").strip()
        self.api_token = os.getenv("SPORTS_TERMINAL_EMAIL_HTTP_TOKEN", "")
        self.environment = os.getenv("SPORTS_TERMINAL_ENV", "development").strip().lower()

    def _destination_hash(self, email: str) -> str:
        normalized = email.strip().lower().encode("utf-8")
        return hashlib.sha256(normalized).hexdigest()

    def _record(
        self,
        *,
        message_id: str,
        destination: str,
        template_key: str,
        status: str,
        metadata: dict[str, Any],
        error: str | None = None,
    ) -> None:
        safe_metadata = {
            key: value
            for key, value in metadata.items()
            if key not in {"token", "code", "secret", "password", "reset_token"}
        }
        timestamp = now_iso()
        with connect() as connection:
            connection.execute(
                """
                INSERT INTO delivery_outbox (
                  id, channel, destination_hash, template_key, payload, provider,
                  status, attempts, created_at, delivered_at, failed_at, error
                ) VALUES (?, 'email', ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)
                """,
                (
                    message_id,
                    self._destination_hash(destination),
                    template_key,
                    json.dumps(safe_metadata, sort_keys=True, separators=(",", ":")),
                    self.provider,
                    status,
                    timestamp,
                    timestamp if status == "delivered" else None,
                    timestamp if status == "failed" else None,
                    error,
                ),
            )
            connection.commit()

    def send_security_email(
        self,
        *,
        destination: str,
        template_key: str,
        subject: str,
        text: str,
        metadata: dict[str, Any] | None = None,
    ) -> DeliveryReceipt:
        destination = destination.strip().lower()
        if not destination or "@" not in destination:
            raise EmailDeliveryError("A valid email destination is required")
        if template_key not in {"verify-email", "password-reset", "security-alert"}:
            raise EmailDeliveryError("Unsupported security email template")

        message_id = make_id("mail")
        metadata = dict(metadata or {})

        if self.provider == "disabled":
            self._record(
                message_id=message_id,
                destination=destination,
                template_key=template_key,
                status="failed",
                metadata=metadata,
                error="email delivery disabled",
            )
            raise EmailDeliveryError("Security email delivery is disabled")

        if self.provider == "console":
            if self.environment == "production":
                raise EmailDeliveryError("Console email delivery is forbidden in production")
            # Do not print message contents or account tokens. Development callers can
            # use the token returned from their own test fixture if they need it.
            self._record(
                message_id=message_id,
                destination=destination,
                template_key=template_key,
                status="delivered",
                metadata=metadata,
            )
            return DeliveryReceipt(message_id, self.provider, "delivered")

        if self.provider != "http":
            raise EmailDeliveryError(f"Unsupported email provider: {self.provider}")
        if not self.endpoint.startswith("https://"):
            raise EmailDeliveryError("HTTP email delivery requires an HTTPS endpoint")

        body = json.dumps(
            {
                "to": destination,
                "template": template_key,
                "subject": subject,
                "text": text,
                "message_id": message_id,
            },
            separators=(",", ":"),
        ).encode("utf-8")
        request = urllib.request.Request(
            self.endpoint,
            data=body,
            method="POST",
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {self.api_token}",
                "Idempotency-Key": message_id,
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as response:  # noqa: S310
                if int(response.status) < 200 or int(response.status) >= 300:
                    raise EmailDeliveryError(f"Email gateway returned HTTP {response.status}")
        except (urllib.error.URLError, TimeoutError, EmailDeliveryError) as error:
            self._record(
                message_id=message_id,
                destination=destination,
                template_key=template_key,
                status="failed",
                metadata=metadata,
                error=str(error)[:500],
            )
            raise EmailDeliveryError("Security email delivery failed") from error

        self._record(
            message_id=message_id,
            destination=destination,
            template_key=template_key,
            status="delivered",
            metadata=metadata,
        )
        return DeliveryReceipt(message_id, self.provider, "delivered")
