from __future__ import annotations

import hashlib
from typing import Any

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel

from . import auth_api
from .main import connect, make_id, now_iso, rows_to_dicts
from .mfa import SecretVault, TotpService, issue_recovery_codes
from .runtime_config import load_runtime_config
from .security_tokens import SecurityTokenService

router = APIRouter(prefix="/v2/security", tags=["account-security"])


class TotpVerifyRequest(BaseModel):
    code: str


def _authenticated(
    authorization: str | None,
) -> tuple[dict[str, Any], str]:
    token = auth_api._token_from_header(authorization)
    with connect() as connection:
        user, token_hash = auth_api._session_user(connection, token)
        connection.commit()
    return user, token_hash


def _token_service() -> SecurityTokenService:
    config = load_runtime_config()
    pepper = config.session_pepper
    if len(pepper) < 16:
        if config.production:
            raise HTTPException(status_code=503, detail="Account security secret is not configured")
        pepper = "development-only-security-pepper-32chars"
    return SecurityTokenService(pepper)


def _session_ref(token_hash: str) -> str:
    return _token_service().hash(token_hash, "session-reference")[:24]


def _vault() -> SecretVault:
    config = load_runtime_config()
    key = config.mfa_encryption_key
    if len(key) < 32:
        if config.production:
            raise HTTPException(status_code=503, detail="MFA encryption is not configured")
        key = "development-only-mfa-key-material-32chars"
    return SecretVault(key)


def _record_security_event(
    connection: Any,
    *,
    user_id: str,
    event_type: str,
    request: Request,
    metadata: str = "{}",
) -> None:
    pepper = load_runtime_config().session_pepper or "development-security-event-pepper"
    forwarded = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
    address = forwarded or (request.client.host if request.client else "unknown")
    user_agent = request.headers.get("user-agent", "")
    connection.execute(
        "INSERT INTO auth_security_events "
        "(id, user_id, event_type, ip_hash, user_agent_hash, metadata, recorded_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        (
            make_id("sec"),
            user_id,
            event_type,
            hashlib.sha256(f"{pepper}:{address}".encode()).hexdigest(),
            hashlib.sha256(f"{pepper}:{user_agent}".encode()).hexdigest(),
            metadata,
            now_iso(),
        ),
    )


@router.get("/sessions")
def sessions(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    user, current_hash = _authenticated(authorization)
    with connect() as connection:
        rows = rows_to_dicts(
            connection.execute(
                "SELECT token_hash, expires_at, created_at, last_seen_at, revoked_at "
                "FROM auth_sessions WHERE user_id = ? ORDER BY created_at DESC",
                (user["id"],),
            ).fetchall()
        )
    return {
        "user_id": user["id"],
        "sessions": [
            {
                "session_ref": _session_ref(row["token_hash"]),
                "expires_at": row["expires_at"],
                "created_at": row["created_at"],
                "last_seen_at": row["last_seen_at"],
                "revoked_at": row["revoked_at"],
                "current": row["token_hash"] == current_hash,
            }
            for row in rows
        ],
    }


@router.delete("/sessions/{session_ref}")
def revoke_session(
    session_ref: str,
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    user, current_hash = _authenticated(authorization)
    with connect() as connection:
        rows = connection.execute(
            "SELECT token_hash FROM auth_sessions WHERE user_id = ? AND revoked_at IS NULL",
            (user["id"],),
        ).fetchall()
        target = next(
            (row["token_hash"] for row in rows if _session_ref(row["token_hash"]) == session_ref),
            None,
        )
        if target is None:
            raise HTTPException(status_code=404, detail="Session not found")
        connection.execute(
            "UPDATE auth_sessions SET revoked_at = ? WHERE token_hash = ?",
            (now_iso(), target),
        )
        _record_security_event(
            connection,
            user_id=user["id"],
            event_type="session_revoked",
            request=request,
        )
        connection.commit()
    return {"revoked": True, "current_session": target == current_hash}


@router.post("/sessions/revoke-others")
def revoke_other_sessions(
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    user, current_hash = _authenticated(authorization)
    with connect() as connection:
        cursor = connection.execute(
            "UPDATE auth_sessions SET revoked_at = ? "
            "WHERE user_id = ? AND token_hash <> ? AND revoked_at IS NULL",
            (now_iso(), user["id"], current_hash),
        )
        _record_security_event(
            connection,
            user_id=user["id"],
            event_type="other_sessions_revoked",
            request=request,
        )
        connection.commit()
    return {"revoked_sessions": max(0, cursor.rowcount)}


@router.get("/mfa")
def mfa_factors(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    user, _ = _authenticated(authorization)
    with connect() as connection:
        factors = rows_to_dicts(
            connection.execute(
                "SELECT id, factor_type, label, verified_at, disabled_at, created_at, updated_at "
                "FROM auth_mfa_factors WHERE user_id = ? ORDER BY created_at",
                (user["id"],),
            ).fetchall()
        )
    return {"user_id": user["id"], "factors": factors}


@router.post("/mfa/totp/enroll")
def enroll_totp(
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    user, _ = _authenticated(authorization)
    totp = TotpService()
    secret = totp.generate_secret()
    factor_id = make_id("mfa")
    encrypted = _vault().encrypt(secret, aad=f"user:{user['id']}:factor:{factor_id}")
    timestamp = now_iso()
    with connect() as connection:
        connection.execute(
            "INSERT INTO auth_mfa_factors "
            "(id, user_id, factor_type, secret_ciphertext, label, created_at, updated_at) "
            "VALUES (?, ?, 'totp', ?, ?, ?, ?)",
            (factor_id, user["id"], encrypted, "Authenticator app", timestamp, timestamp),
        )
        _record_security_event(
            connection,
            user_id=user["id"],
            event_type="mfa_enrollment_started",
            request=request,
        )
        connection.commit()
    return {
        "factor_id": factor_id,
        "secret": secret,
        "provisioning_uri": totp.provisioning_uri(secret=secret, account=user["email"]),
        "verified": False,
    }


@router.post("/mfa/totp/{factor_id}/verify")
def verify_totp(
    factor_id: str,
    payload: TotpVerifyRequest,
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    user, _ = _authenticated(authorization)
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM auth_mfa_factors WHERE id = ? AND user_id = ? AND disabled_at IS NULL",
            (factor_id, user["id"]),
        ).fetchone()
        if row is None:
            raise HTTPException(status_code=404, detail="MFA factor not found")
        secret = _vault().decrypt(
            row["secret_ciphertext"],
            aad=f"user:{user['id']}:factor:{factor_id}",
        )
        if not TotpService().verify(secret, payload.code):
            raise HTTPException(status_code=400, detail="Invalid authenticator code")
        timestamp = now_iso()
        connection.execute(
            "UPDATE auth_mfa_factors SET verified_at = ?, updated_at = ? WHERE id = ?",
            (timestamp, timestamp, factor_id),
        )
        connection.execute(
            "DELETE FROM auth_recovery_codes WHERE user_id = ?",
            (user["id"],),
        )
        recovery = issue_recovery_codes(_token_service())
        for code_hash in recovery.hashes:
            connection.execute(
                "INSERT INTO auth_recovery_codes (code_hash, user_id, created_at) VALUES (?, ?, ?)",
                (code_hash, user["id"], timestamp),
            )
        _record_security_event(
            connection,
            user_id=user["id"],
            event_type="mfa_enabled",
            request=request,
        )
        connection.commit()
    return {
        "factor_id": factor_id,
        "verified": True,
        "recovery_codes": list(recovery.plaintext_codes),
        "recovery_codes_returned_once": True,
    }


@router.delete("/mfa/{factor_id}")
def disable_mfa(
    factor_id: str,
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    user, _ = _authenticated(authorization)
    timestamp = now_iso()
    with connect() as connection:
        cursor = connection.execute(
            "UPDATE auth_mfa_factors SET disabled_at = ?, updated_at = ? "
            "WHERE id = ? AND user_id = ? AND disabled_at IS NULL",
            (timestamp, timestamp, factor_id, user["id"]),
        )
        if cursor.rowcount <= 0:
            raise HTTPException(status_code=404, detail="MFA factor not found")
        _record_security_event(
            connection,
            user_id=user["id"],
            event_type="mfa_disabled",
            request=request,
        )
        connection.commit()
    return {"disabled": True, "factor_id": factor_id}
