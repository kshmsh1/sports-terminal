from __future__ import annotations

import hashlib
import hmac
import os
import re
import secrets
import sqlite3
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel

from .launch_api import init_launch_db
from .main import connect, ensure_user, make_id, now_iso, row_to_dict, rows_to_dicts

router = APIRouter(prefix="/v2/auth", tags=["authentication"])

PASSWORD_ITERATIONS = 310_000
SESSION_DAYS = 30
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class SignUpRequest(BaseModel):
    email: str
    password: str
    display_name: str
    account_type: str = "individual"
    organization_name: str | None = None


class SignInRequest(BaseModel):
    email: str
    password: str


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


def init_auth_db() -> None:
    init_launch_db()
    with connect() as connection:
        connection.executescript(
            """
            CREATE TABLE IF NOT EXISTS auth_credentials (
              user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
              password_hash TEXT NOT NULL,
              password_salt TEXT NOT NULL,
              password_iterations INTEGER NOT NULL,
              email_verified INTEGER NOT NULL DEFAULT 0,
              failed_attempts INTEGER NOT NULL DEFAULT 0,
              locked_until TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS auth_sessions (
              token_hash TEXT PRIMARY KEY,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              expires_at TEXT NOT NULL,
              created_at TEXT NOT NULL,
              last_seen_at TEXT NOT NULL,
              revoked_at TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_auth_sessions_user ON auth_sessions(user_id, expires_at);
            CREATE INDEX IF NOT EXISTS idx_auth_credentials_verified ON auth_credentials(email_verified);
            """
        )
        connection.commit()


def _normalize_email(value: str) -> str:
    email = value.strip().lower()
    if not EMAIL_RE.match(email):
        raise HTTPException(status_code=400, detail="A valid email address is required")
    return email


def _validate_password(password: str) -> None:
    if len(password) < 10:
        raise HTTPException(status_code=400, detail="Password must contain at least 10 characters")
    if password.lower() == password or password.upper() == password:
        raise HTTPException(status_code=400, detail="Password must contain mixed-case characters")
    if not any(character.isdigit() for character in password):
        raise HTTPException(status_code=400, detail="Password must contain a number")


def _password_hash(password: str, salt_hex: str, iterations: int) -> str:
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        bytes.fromhex(salt_hex),
        iterations,
    )
    return digest.hex()


def _create_session(connection: sqlite3.Connection, user_id: str) -> tuple[str, str]:
    token = secrets.token_urlsafe(48)
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    created_at = datetime.now(timezone.utc)
    expires_at = created_at + timedelta(days=SESSION_DAYS)
    connection.execute(
        "INSERT INTO auth_sessions (token_hash, user_id, expires_at, created_at, last_seen_at) VALUES (?, ?, ?, ?, ?)",
        (token_hash, user_id, expires_at.isoformat(), created_at.isoformat(), created_at.isoformat()),
    )
    return token, expires_at.isoformat()


def _token_from_header(authorization: str | None) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="A bearer session token is required")
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="A bearer session token is required")
    return token


def _session_user(connection: sqlite3.Connection, token: str) -> tuple[dict[str, Any], str]:
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    row = connection.execute(
        """
        SELECT auth_sessions.*, users.email, users.display_name, users.role, users.status
        FROM auth_sessions
        JOIN users ON users.id = auth_sessions.user_id
        WHERE auth_sessions.token_hash = ?
        """,
        (token_hash,),
    ).fetchone()
    if row is None or row["revoked_at"] is not None:
        raise HTTPException(status_code=401, detail="Session is invalid or revoked")
    if datetime.fromisoformat(row["expires_at"]) <= datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Session has expired")
    if row["status"] != "active":
        raise HTTPException(status_code=403, detail="Account is not active")
    connection.execute(
        "UPDATE auth_sessions SET last_seen_at = ? WHERE token_hash = ?",
        (now_iso(), token_hash),
    )
    user = {
        "id": row["user_id"],
        "email": row["email"],
        "display_name": row["display_name"],
        "role": row["role"],
        "status": row["status"],
    }
    return user, token_hash


def _organizations_for(connection: sqlite3.Connection, user_id: str) -> list[dict[str, Any]]:
    return rows_to_dicts(
        connection.execute(
            """
            SELECT organizations.id,
                   organizations.name,
                   organizations.slug,
                   organizations.status,
                   organization_memberships.role AS membership_role,
                   organization_memberships.status AS membership_status
            FROM organizations
            JOIN organization_memberships ON organizations.id = organization_memberships.organization_id
            WHERE organization_memberships.user_id = ?
            ORDER BY organizations.name
            """,
            (user_id,),
        ).fetchall()
    )


def _session_response(
    connection: sqlite3.Connection,
    user: dict[str, Any],
    token: str,
    expires_at: str,
) -> dict[str, Any]:
    credential = connection.execute(
        "SELECT email_verified FROM auth_credentials WHERE user_id = ?",
        (user["id"],),
    ).fetchone()
    return {
        "token": token,
        "expires_at": expires_at,
        "user": user,
        "email_verified": bool(credential["email_verified"]) if credential is not None else False,
        "organizations": _organizations_for(connection, user["id"]),
        "external_requirements": {
            "email_delivery": not bool(os.getenv("SPORTS_TERMINAL_EMAIL_PROVIDER")),
            "mfa_provider": not bool(os.getenv("SPORTS_TERMINAL_MFA_PROVIDER")),
        },
    }


def _slug(value: str, fallback: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", value.strip().lower()).strip("-")
    return normalized or fallback


@router.on_event("startup")
def startup_auth_api() -> None:
    init_auth_db()


@router.post("/signup")
def sign_up(payload: SignUpRequest) -> dict[str, Any]:
    init_auth_db()
    email = _normalize_email(payload.email)
    _validate_password(payload.password)
    display_name = payload.display_name.strip()
    if len(display_name) < 2:
        raise HTTPException(status_code=400, detail="Display name is required")
    if payload.account_type not in {"individual", "organization"}:
        raise HTTPException(status_code=400, detail="Account type must be individual or organization")
    if payload.account_type == "organization" and not (payload.organization_name or "").strip():
        raise HTTPException(status_code=400, detail="Organization name is required")

    timestamp = now_iso()
    user_id = make_id("usr")
    salt = secrets.token_bytes(16).hex()
    password_hash = _password_hash(payload.password, salt, PASSWORD_ITERATIONS)
    with connect() as connection:
        if connection.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone() is not None:
            raise HTTPException(status_code=409, detail="An account already exists for this email")
        user_role = "organization_admin" if payload.account_type == "organization" else "analyst"
        connection.execute(
            "INSERT INTO users (id, email, display_name, role, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'active', ?, ?)",
            (user_id, email, display_name, user_role, timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO user_profiles (user_id, handle, is_public, created_at, updated_at) VALUES (?, ?, 0, ?, ?)",
            (user_id, _slug(display_name, user_id), timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO user_settings (user_id, dark_mode, email_digest, fantasy_alerts, notification_preferences, created_at, updated_at) VALUES (?, 0, 0, 1, '{}', ?, ?)",
            (user_id, timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO auth_credentials (user_id, password_hash, password_salt, password_iterations, email_verified, created_at, updated_at) VALUES (?, ?, ?, ?, 0, ?, ?)",
            (user_id, password_hash, salt, PASSWORD_ITERATIONS, timestamp, timestamp),
        )

        if payload.account_type == "organization":
            organization_id = make_id("org")
            organization_name = str(payload.organization_name).strip()
            organization_slug = _slug(organization_name, organization_id)
            suffix = 1
            base_slug = organization_slug
            while connection.execute("SELECT 1 FROM organizations WHERE slug = ?", (organization_slug,)).fetchone() is not None:
                suffix += 1
                organization_slug = f"{base_slug}-{suffix}"
            connection.execute(
                "INSERT INTO organizations (id, name, slug, status, plan_id, created_by_user_id, created_at, updated_at) VALUES (?, ?, ?, 'active', 'org', ?, ?, ?)",
                (organization_id, organization_name, organization_slug, user_id, timestamp, timestamp),
            )
            connection.execute(
                "INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES (?, ?, 'owner', 'active', ?, ?)",
                (organization_id, user_id, timestamp, timestamp),
            )

        token, expires_at = _create_session(connection, user_id)
        connection.commit()
        user = row_to_dict(connection.execute("SELECT id, email, display_name, role, status FROM users WHERE id = ?", (user_id,)).fetchone())
        assert user is not None
        return _session_response(connection, user, token, expires_at)


@router.post("/login")
def sign_in(payload: SignInRequest) -> dict[str, Any]:
    init_auth_db()
    email = _normalize_email(payload.email)
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
            locked_until = datetime.fromisoformat(row["locked_until"])
            if locked_until > datetime.now(timezone.utc):
                raise HTTPException(status_code=429, detail="Account is temporarily locked")
        actual = _password_hash(payload.password, row["password_salt"], int(row["password_iterations"]))
        if not hmac.compare_digest(actual, row["password_hash"]):
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
        if os.getenv("SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION") == "true" and not bool(row["email_verified"]):
            raise HTTPException(status_code=403, detail="Email verification is required")
        connection.execute(
            "UPDATE auth_credentials SET failed_attempts = 0, locked_until = NULL, updated_at = ? WHERE user_id = ?",
            (now_iso(), row["id"]),
        )
        token, expires_at = _create_session(connection, row["id"])
        connection.commit()
        user = {
            "id": row["id"],
            "email": row["email"],
            "display_name": row["display_name"],
            "role": row["role"],
            "status": row["status"],
        }
        return _session_response(connection, user, token, expires_at)


@router.get("/session")
def read_session(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    init_auth_db()
    token = _token_from_header(authorization)
    with connect() as connection:
        user, _ = _session_user(connection, token)
        connection.commit()
        expires_at = connection.execute(
            "SELECT expires_at FROM auth_sessions WHERE token_hash = ?",
            (hashlib.sha256(token.encode("utf-8")).hexdigest(),),
        ).fetchone()["expires_at"]
        return _session_response(connection, user, token, expires_at)


@router.post("/logout")
def sign_out(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    init_auth_db()
    token = _token_from_header(authorization)
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    with connect() as connection:
        connection.execute(
            "UPDATE auth_sessions SET revoked_at = ? WHERE token_hash = ?",
            (now_iso(), token_hash),
        )
        connection.commit()
    return {"signed_out": True}


@router.post("/change-password")
def change_password(
    payload: ChangePasswordRequest,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    init_auth_db()
    _validate_password(payload.new_password)
    token = _token_from_header(authorization)
    with connect() as connection:
        user, active_token_hash = _session_user(connection, token)
        credential = connection.execute(
            "SELECT * FROM auth_credentials WHERE user_id = ?",
            (user["id"],),
        ).fetchone()
        if credential is None:
            raise HTTPException(status_code=409, detail="Account does not have first-party credentials")
        actual = _password_hash(
            payload.current_password,
            credential["password_salt"],
            int(credential["password_iterations"]),
        )
        if not hmac.compare_digest(actual, credential["password_hash"]):
            raise HTTPException(status_code=401, detail="Current password is incorrect")
        salt = secrets.token_bytes(16).hex()
        password_hash = _password_hash(payload.new_password, salt, PASSWORD_ITERATIONS)
        connection.execute(
            "UPDATE auth_credentials SET password_hash = ?, password_salt = ?, password_iterations = ?, updated_at = ? WHERE user_id = ?",
            (password_hash, salt, PASSWORD_ITERATIONS, now_iso(), user["id"]),
        )
        connection.execute(
            "UPDATE auth_sessions SET revoked_at = ? WHERE user_id = ? AND token_hash != ? AND revoked_at IS NULL",
            (now_iso(), user["id"], active_token_hash),
        )
        connection.commit()
    return {"changed": True, "other_sessions_revoked": True}
