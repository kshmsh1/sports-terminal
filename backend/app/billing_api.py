from __future__ import annotations

import hashlib
import hmac
import json
from dataclasses import dataclass
from typing import Any

from fastapi import APIRouter, Header, HTTPException, Request

from .main import connect, make_id, now_iso
from .runtime_config import load_runtime_config

router = APIRouter(prefix="/v2/billing", tags=["billing"])


@dataclass(frozen=True)
class BillingEventResult:
    provider_event_id: str
    duplicate: bool
    processed: bool
    event_type: str


class BillingWebhookService:
    def _secret(self) -> str:
        config = load_runtime_config()
        if config.billing_mode == "disabled":
            raise RuntimeError("billing is disabled")
        if len(config.billing_webhook_secret) < 24:
            raise RuntimeError("billing webhook secret is not configured")
        return config.billing_webhook_secret

    def signature(self, body: bytes) -> str:
        return hmac.new(
            self._secret().encode("utf-8"), body, hashlib.sha256
        ).hexdigest()

    def verify(self, body: bytes, signature: str) -> bool:
        if not signature:
            return False
        return hmac.compare_digest(self.signature(body), signature.strip().lower())

    def ingest(
        self,
        *,
        provider: str,
        provider_event_id: str,
        event_type: str,
        body: bytes,
        signature: str,
    ) -> BillingEventResult:
        if not provider_event_id.strip() or not event_type.strip():
            raise ValueError("provider event id and event type are required")
        if not self.verify(body, signature):
            raise PermissionError("invalid billing webhook signature")
        try:
            payload = json.loads(body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ValueError("billing webhook payload must be valid JSON") from error
        if not isinstance(payload, dict):
            raise ValueError("billing webhook payload must be a JSON object")

        payload_sha = hashlib.sha256(body).hexdigest()
        timestamp = now_iso()
        with connect() as connection:
            existing = connection.execute(
                "SELECT payload_sha256, event_type, status FROM billing_webhook_events "
                "WHERE provider_event_id = ?",
                (provider_event_id,),
            ).fetchone()
            if existing is not None:
                if existing["payload_sha256"] != payload_sha or existing["event_type"] != event_type:
                    raise RuntimeError("provider event id was reused with different payload")
                return BillingEventResult(provider_event_id, True, existing["status"] == "processed", event_type)

            connection.execute(
                "INSERT INTO billing_webhook_events "
                "(provider_event_id, provider, event_type, payload_sha256, received_at, status) "
                "VALUES (?, ?, ?, ?, ?, 'received')",
                (provider_event_id, provider, event_type, payload_sha, timestamp),
            )
            try:
                self._process(connection, event_type, payload)
                connection.execute(
                    "UPDATE billing_webhook_events SET status = 'processed', processed_at = ? "
                    "WHERE provider_event_id = ?",
                    (now_iso(), provider_event_id),
                )
            except Exception as error:
                connection.execute(
                    "UPDATE billing_webhook_events SET status = 'failed', error = ? "
                    "WHERE provider_event_id = ?",
                    (str(error)[:500], provider_event_id),
                )
                connection.commit()
                raise
            connection.commit()
        return BillingEventResult(provider_event_id, False, True, event_type)

    def _process(self, connection: Any, event_type: str, payload: dict[str, Any]) -> None:
        data = payload.get("data") if isinstance(payload.get("data"), dict) else payload
        if event_type == "subscription.activated":
            user_id = _required(data, "user_id")
            plan_id = _required(data, "plan_id")
            subscription_id = str(data.get("subscription_id") or make_id("sub"))
            connection.execute(
                "DELETE FROM subscriptions WHERE user_id = ?",
                (user_id,),
            )
            connection.execute(
                "INSERT INTO subscriptions (id, user_id, plan_id, status, updated_at) "
                "VALUES (?, ?, ?, 'active', ?)",
                (subscription_id, user_id, plan_id, now_iso()),
            )
            return
        if event_type in {"subscription.canceled", "subscription.expired"}:
            user_id = _required(data, "user_id")
            connection.execute(
                "UPDATE subscriptions SET status = ?, updated_at = ? WHERE user_id = ?",
                ("canceled" if event_type.endswith("canceled") else "expired", now_iso(), user_id),
            )
            return
        if event_type == "entitlement.granted":
            subject_type = str(data.get("subject_type") or "user")
            subject_id = _required(data, "subject_id")
            key = _required(data, "entitlement_key")
            source = str(data.get("source") or "billing")
            connection.execute(
                "INSERT OR IGNORE INTO entitlement_grants "
                "(id, subject_type, subject_id, entitlement_key, source, starts_at, ends_at, metadata, created_at, updated_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    make_id("ent"),
                    subject_type,
                    subject_id,
                    key,
                    source,
                    data.get("starts_at"),
                    data.get("ends_at"),
                    json.dumps(data.get("metadata") or {}, separators=(",", ":")),
                    now_iso(),
                    now_iso(),
                ),
            )
            return
        if event_type == "entitlement.revoked":
            subject_type = str(data.get("subject_type") or "user")
            subject_id = _required(data, "subject_id")
            key = _required(data, "entitlement_key")
            connection.execute(
                "UPDATE entitlement_grants SET revoked_at = ?, updated_at = ? "
                "WHERE subject_type = ? AND subject_id = ? AND entitlement_key = ? AND revoked_at IS NULL",
                (now_iso(), now_iso(), subject_type, subject_id, key),
            )
            return
        # Unknown provider events are retained as processed evidence but do not mutate entitlements.


def _required(data: dict[str, Any], key: str) -> str:
    value = str(data.get(key) or "").strip()
    if not value:
        raise ValueError(f"billing event is missing {key}")
    return value


@router.post("/webhooks/{provider}")
async def billing_webhook(
    provider: str,
    request: Request,
    x_sports_terminal_event_id: str | None = Header(default=None),
    x_sports_terminal_event_type: str | None = Header(default=None),
    x_sports_terminal_signature: str | None = Header(default=None),
) -> dict[str, Any]:
    config = load_runtime_config()
    if config.billing_mode == "disabled":
        raise HTTPException(status_code=503, detail="Billing is disabled")
    body = await request.body()
    try:
        result = BillingWebhookService().ingest(
            provider=provider,
            provider_event_id=x_sports_terminal_event_id or "",
            event_type=x_sports_terminal_event_type or "",
            body=body,
            signature=x_sports_terminal_signature or "",
        )
    except PermissionError as error:
        raise HTTPException(status_code=401, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return {
        "event_id": result.provider_event_id,
        "event_type": result.event_type,
        "duplicate": result.duplicate,
        "processed": result.processed,
    }
