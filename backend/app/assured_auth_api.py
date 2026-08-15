from __future__ import annotations

import hashlib
import hmac
import os
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from . import auth_api
from .database import connect
from .mfa_login import MfaLoginService
from .migrations import run_migrations
from .main import now_iso

router = APIRouter(prefix="/v2/auth", tags=["authentication"])


class MfaLoginCompleteRequest(BaseModel):
    challenge_token: str
    code: str


def _prepare() -> None:
    auth_api.init_auth_db()
    run_migrations()


def _record_assurance(connection: Any, token: str, auth_level: str) -> None:
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    timestamp = now_iso()
    connection.execute(
        "DELETE FROM auth_session_security WHERE token_hash = ?",
        (token_hash,),
    )
    connection.execute(
        """
        INSERT INTO auth_session_security
          (token_hash, auth_level, mfa_verified_at, created_at)
        VALUES (?, ?, ?, ?)
        """,
        (token_hash, auth_level, timestamp if auth_level == "mfa" else None, timestamp),
    )


def _session(connection: Any, user_id: str, *, auth_level: str) -> dict[str, Any]:
    token, expires_at = auth_api._create_session(connection, user_id)
    _record_assurance(connection, token, auth_level)
    row = connection.execute(
        "SELECT id, email, display_name, role, status FROM users WHERE id = ?",
        (user_id,),
    ).fetchone()
    if row is None:
        raise HTTPException(status_code=401, detail="Account is unavailable")
    response = auth_api._session_response(connection, dict(row), token, expires_at)
    response["auth_level"] = auth_level
    response["mfa_required"] = False
    return response


@router.post("/login")
def sign_in(payload: auth_api.SignInRequest) -> dict[str, Any]:
    _prepare()
    email = auth_api._normalize_email(payload.email)
    with connect() as connection:
        row = connection.execute(
            """
            SELECT users.id, users.email, users.display_name, users.role, users.status,
                   auth_credentials.password_hash, auth_credentials.password_salt,
                   auth_credentials.password_iterations, auth_credentials.email_verified,
                   auth_credentials.failed_attempts, auth_credentials.locked_until
            FROM users
            JOIN auth_credentials ON auth_credentials.user_id = users.id
            WHERE users.email = ?
            """,
            (email,),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=401, detail="Email or password is incorrect")
        if row["locked_until"]:
            locked_until = datetime.fromisoformat(str(row["locked_until"]))
            if locked_until > datetime.now(timezone.utc):
                raise HTTPException(status_code=429, detail="Account is temporarily locked")
        actual = auth_api._password_hash(
            payload.password,
            str(row["password_salt"]),
            int(row["password_iterations"]),
        )
        if not hmac.compare_digest(actual, str(row["password_hash"])):
            attempts = int(row["failed_attempts"]) + 1
            locked_until = None
            if attempts >= 8:
                locked_until = (datetime.now(timezone.utc) + timedelta(minutes=15)).isoformat()
                attempts = 0
            connection.execute(
                "UPDATE auth_credentials SET failed_attempts = ?, locked_until = ?, updated_at = ? WHERE user_id = ?",
                (attempts, locked_until, now_iso(), row["id"]),
            )
            connection.commit()
            raise HTTPException(status_code=401, detail="Email or password is incorrect")
        if row["status"] != "active":
            raise HTTPException(status_code=403, detail="Account is not active")
        if os.getenv("SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION", "false").lower() == "true" and not bool(row["email_verified"]):
            raise HTTPException(status_code=403, detail="Email verification is required")

        connection.execute(
            "UPDATE auth_credentials SET failed_attempts = 0, locked_until = NULL, updated_at = ? WHERE user_id = ?",
            (now_iso(), row["id"]),
        )
        mfa = MfaLoginService()
        if mfa.has_verified_factor(connection, str(row["id"])):
            challenge = mfa.begin(connection, str(row["id"]))
            connection.commit()
            return {
                "mfa_required": True,
                "challenge_token": challenge.plaintext,
                "expires_at": challenge.expires_at,
                "allowed_factors": ["totp", "recovery_code"],
            }

        response = _session(connection, str(row["id"]), auth_level="password")
        connection.commit()
        return response


@router.post("/login/mfa")
def complete_mfa_login(payload: MfaLoginCompleteRequest) -> dict[str, Any]:
    _prepare()
    with connect() as connection:
        user_id = MfaLoginService().complete(
            connection,
            challenge_token=payload.challenge_token.strip(),
            code=payload.code.strip(),
        )
        if user_id is None:
            connection.commit()
            raise HTTPException(status_code=401, detail="MFA challenge or code is invalid")
        response = _session(connection, user_id, auth_level="mfa")
        connection.commit()
        return response
