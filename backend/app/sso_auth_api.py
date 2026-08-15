from __future__ import annotations

import hashlib
import os
from typing import Any

from fastapi import APIRouter, HTTPException, Query, Request

from . import auth_api
from .database import connect
from .main import now_iso
from .platform_audit import PlatformAuditLog
from .runtime_config import load_runtime_config
from .sso import SsoConfigurationError, SsoConnectionService, SsoProtocolError

router = APIRouter(prefix="/v2/auth/sso", tags=["authentication", "sso"])


def _callback_uri(request: Request, organization_id: str) -> str:
    configured = os.getenv("SPORTS_TERMINAL_PUBLIC_API_ORIGIN", "").strip().rstrip("/")
    path = f"/v2/auth/sso/{organization_id}/callback"
    if configured:
        if load_runtime_config().production and not configured.startswith("https://"):
            raise HTTPException(status_code=503, detail="Production public API origin must use HTTPS")
        return f"{configured}{path}"
    candidate = str(request.base_url).rstrip("/") + path
    if load_runtime_config().production and not candidate.startswith("https://"):
        raise HTTPException(
            status_code=503,
            detail="Production SSO requires SPORTS_TERMINAL_PUBLIC_API_ORIGIN with HTTPS",
        )
    return candidate


def _record_session_assurance(connection: Any, token: str, auth_level: str) -> None:
    token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
    timestamp = now_iso()
    connection.execute("DELETE FROM auth_session_security WHERE token_hash = ?", (token_hash,))
    connection.execute(
        """
        INSERT INTO auth_session_security
          (token_hash, auth_level, mfa_verified_at, created_at)
        VALUES (?, ?, ?, ?)
        """,
        (
            token_hash,
            auth_level,
            timestamp if auth_level == "sso_mfa" else None,
            timestamp,
        ),
    )


def _organization_requires_mfa(connection: Any, organization_id: str) -> bool:
    row = connection.execute(
        "SELECT require_mfa FROM organization_security_policies WHERE organization_id = ?",
        (organization_id,),
    ).fetchone()
    return row is not None and bool(row["require_mfa"])


@router.get("/{organization_id}/start")
def start_oidc_login(
    organization_id: str,
    request: Request,
    connection_id: str | None = Query(default=None),
) -> dict[str, Any]:
    service = SsoConnectionService()
    try:
        with connect() as connection:
            selected = service.enabled_connection(
                connection,
                organization_id=organization_id,
                connection_id=connection_id,
            )
            start = service.begin_login(
                connection,
                connection_id=str(selected["id"]),
                redirect_uri=_callback_uri(request, organization_id),
            )
            connection.commit()
    except SsoConfigurationError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return {
        "organization_id": organization_id,
        "connection_id": start.connection_id,
        "authorization_url": start.authorization_url,
        "expires_at": start.expires_at,
        "pkce": "S256",
    }


@router.get("/{organization_id}/callback", name="oidc_callback")
def complete_oidc_login(
    organization_id: str,
    code: str,
    state: str,
) -> dict[str, Any]:
    service = SsoConnectionService()
    try:
        with connect() as connection:
            login_state = service.consume_state(connection, plaintext_state=state.strip())
            if login_state is None:
                connection.commit()
                raise HTTPException(status_code=401, detail="OIDC login state is invalid, expired, or already used")
            if str(login_state["organization_id"]) != organization_id:
                connection.commit()
                raise HTTPException(status_code=401, detail="OIDC login state does not match the organization")

            tokens = service.exchange_authorization_code(login_state, code=code)
            identity = service.verify_id_token(
                login_state,
                id_token=str(tokens["id_token"]),
            )
            user = service.link_existing_identity(
                connection,
                state=login_state,
                identity=identity,
            )
            if _organization_requires_mfa(connection, organization_id) and not identity.mfa_authenticated:
                connection.commit()
                raise HTTPException(
                    status_code=403,
                    detail="Organization policy requires the identity provider to assert MFA for SSO sign-in",
                )

            auth_level = "sso_mfa" if identity.mfa_authenticated else "sso"
            token, expires_at = auth_api._create_session(connection, str(user["id"]))
            _record_session_assurance(connection, token, auth_level)
            response = auth_api._session_response(connection, user, token, expires_at)
            response.update(
                {
                    "auth_level": auth_level,
                    "mfa_required": False,
                    "sso": {
                        "organization_id": organization_id,
                        "connection_id": str(login_state["connection_id"]),
                        "issuer": identity.issuer,
                    },
                }
            )
            connection.commit()
        try:
            PlatformAuditLog().record(
                actor_type="user",
                actor_id=str(user["id"]),
                action="sso.login",
                object_type="organization",
                object_id=organization_id,
                metadata={
                    "connection_id": str(login_state["connection_id"]),
                    "auth_level": auth_level,
                    "issuer": identity.issuer,
                },
            )
        except Exception:
            # Authentication success must not be rewritten as failure because the
            # separate operational audit sink is temporarily unavailable.
            pass
        return response
    except HTTPException:
        raise
    except SsoConfigurationError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    except SsoProtocolError as error:
        raise HTTPException(status_code=401, detail=str(error)) from error
