from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from .database import DatabaseConnection
from .main import make_id, now_iso
from .security_tokens import SecurityTokenService


PURPOSES = {"verify-email", "password-reset"}


@dataclass(frozen=True)
class DeliveryToken:
    id: str
    plaintext: str
    purpose: str
    expires_at: str


class AuthDeliveryTokenService:
    def __init__(self, pepper: str) -> None:
        self.tokens = SecurityTokenService(pepper)

    def issue(
        self,
        connection: DatabaseConnection,
        *,
        user_id: str,
        purpose: str,
        ttl_minutes: int,
    ) -> DeliveryToken:
        if purpose not in PURPOSES:
            raise ValueError("unsupported auth delivery token purpose")
        ttl = max(5, min(int(ttl_minutes), 24 * 60))
        issued = self.tokens.issue(purpose)
        token_id = make_id("atok")
        created = datetime.now(timezone.utc)
        expires = created + timedelta(minutes=ttl)
        connection.execute(
            """
            UPDATE auth_delivery_tokens
            SET status = 'superseded'
            WHERE user_id = ? AND purpose = ? AND status = 'active'
            """,
            (user_id, purpose),
        )
        connection.execute(
            """
            INSERT INTO auth_delivery_tokens (
              id, user_id, purpose, token_hash, expires_at, status, attempts, created_at
            ) VALUES (?, ?, ?, ?, ?, 'active', 0, ?)
            """,
            (token_id, user_id, purpose, issued.token_hash, expires.isoformat(), created.isoformat()),
        )
        return DeliveryToken(token_id, issued.plaintext, purpose, expires.isoformat())

    def consume(
        self,
        connection: DatabaseConnection,
        *,
        plaintext: str,
        purpose: str,
        max_attempts: int = 8,
    ) -> str | None:
        if purpose not in PURPOSES or not plaintext:
            return None
        token_hash = self.tokens.hash(plaintext, purpose)
        row = connection.execute(
            """
            SELECT id, user_id, expires_at, status, attempts
            FROM auth_delivery_tokens
            WHERE token_hash = ? AND purpose = ?
            """,
            (token_hash, purpose),
        ).fetchone()
        if row is None or row["status"] != "active":
            return None
        now = datetime.now(timezone.utc)
        if datetime.fromisoformat(str(row["expires_at"])) <= now:
            connection.execute(
                "UPDATE auth_delivery_tokens SET status = 'expired' WHERE id = ?",
                (row["id"],),
            )
            return None
        attempts = int(row["attempts"]) + 1
        if attempts > max_attempts:
            connection.execute(
                "UPDATE auth_delivery_tokens SET status = 'locked', attempts = ? WHERE id = ?",
                (attempts, row["id"]),
            )
            return None
        connection.execute(
            """
            UPDATE auth_delivery_tokens
            SET status = 'consumed', attempts = ?, consumed_at = ?
            WHERE id = ? AND status = 'active'
            """,
            (attempts, now_iso(), row["id"]),
        )
        return str(row["user_id"])
