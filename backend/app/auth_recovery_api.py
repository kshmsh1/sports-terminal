from __future__ import annotations

import hashlib
import os
import secrets
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from .auth_delivery import AuthDeliveryTokenService
from .database import connect
from .email_delivery import EmailDeliveryError, SecurityEmailDelivery
from .main import now_iso
from .runtime_config import load_runtime_config
from .security_tokens import PasswordPolicy

router = APIRouter(prefix="/v2/auth", tags=["authentication"])
PASSWORD_ITERATIONS = 310_000


class EmailRequest(BaseModel):
    email: str


class TokenConfirm(BaseModel):
    token: str


class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str


def _pepper() -> str:
    config = load_runtime_config()
    if config.session_pepper:
        return config.session_pepper
    if config.production:
        raise RuntimeError("Production recovery tokens require the session pepper")
    return "development-only-auth-token-pepper-00000000"


def _normalize_email(value: str) -> str:
    return value.strip().lower()


def _hash_password(password: str, salt_hex: str) -> str:
    return hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        bytes.fromhex(salt_hex),
        PASSWORD_ITERATIONS,
    ).hex()


def _dispatch(
    *,
    user_id: str,
    email: str,
    purpose: str,
    ttl_minutes: int,
) -> None:
    with connect() as connection:
        token = AuthDeliveryTokenService(_pepper()).issue(
            connection,
            user_id=user_id,
            purpose=purpose,
            ttl_minutes=ttl_minutes,
        )
        connection.commit()
    delivery = SecurityEmailDelivery()
    subject = "Verify your Sports Terminal email" if purpose == "verify-email" else "Reset your Sports Terminal password"
    delivery.send_security_email(
        destination=email,
        template_key=purpose,
        subject=subject,
        text=(
            "Use this one-time Sports Terminal token before it expires: "
            f"{token.plaintext}"
        ),
        metadata={"user_id": user_id, "purpose": purpose, "expires_at": token.expires_at},
    )


def _generic_request(email: str, *, purpose: str, ttl_minutes: int) -> dict[str, Any]:
    normalized = _normalize_email(email)
    with connect() as connection:
        row = connection.execute(
            "SELECT id, email FROM users WHERE lower(email) = ? AND status = 'active'",
            (normalized,),
        ).fetchone()
    if row is not None:
        try:
            _dispatch(
                user_id=str(row["id"]),
                email=str(row["email"]),
                purpose=purpose,
                ttl_minutes=ttl_minutes,
            )
        except (EmailDeliveryError, RuntimeError):
            # Deliberately suppress provider state so the public response cannot
            # distinguish registered from unregistered email addresses.
            pass
    return {"accepted": True}


@router.post("/email-verification/request")
def request_email_verification(payload: EmailRequest) -> dict[str, Any]:
    return _generic_request(payload.email, purpose="verify-email", ttl_minutes=60)


@router.post("/email-verification/confirm")
def confirm_email_verification(payload: TokenConfirm) -> dict[str, Any]:
    with connect() as connection:
        user_id = AuthDeliveryTokenService(_pepper()).consume(
            connection,
            plaintext=payload.token.strip(),
            purpose="verify-email",
        )
        if user_id is None:
            connection.commit()
            raise HTTPException(status_code=400, detail="Verification token is invalid or expired")
        connection.execute(
            "UPDATE auth_credentials SET email_verified = 1, updated_at = ? WHERE user_id = ?",
            (now_iso(), user_id),
        )
        connection.commit()
    return {"verified": True}


@router.post("/password-reset/request")
def request_password_reset(payload: EmailRequest) -> dict[str, Any]:
    return _generic_request(payload.email, purpose="password-reset", ttl_minutes=30)


@router.post("/password-reset/confirm")
def confirm_password_reset(payload: PasswordResetConfirm) -> dict[str, Any]:
    new_password = payload.new_password
    with connect() as connection:
        user_id = AuthDeliveryTokenService(_pepper()).consume(
            connection,
            plaintext=payload.token.strip(),
            purpose="password-reset",
        )
        if user_id is None:
            connection.commit()
            raise HTTPException(status_code=400, detail="Reset token is invalid or expired")
        user = connection.execute(
            "SELECT email, display_name FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()
        if user is None:
            raise HTTPException(status_code=400, detail="Reset token is invalid or expired")
        try:
            PasswordPolicy().validate(
                new_password,
                email=str(user["email"]),
                display_name=str(user["display_name"]),
            )
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from error
        salt = secrets.token_bytes(16).hex()
        password_hash = _hash_password(new_password, salt)
        timestamp = datetime.now(timezone.utc).isoformat()
        connection.execute(
            """
            UPDATE auth_credentials
            SET password_hash = ?, password_salt = ?, password_iterations = ?,
                failed_attempts = 0, locked_until = NULL, updated_at = ?
            WHERE user_id = ?
            """,
            (password_hash, salt, PASSWORD_ITERATIONS, timestamp, user_id),
        )
        connection.execute(
            "UPDATE auth_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL",
            (timestamp, user_id),
        )
        connection.commit()
    return {"password_reset": True, "sessions_revoked": True}
