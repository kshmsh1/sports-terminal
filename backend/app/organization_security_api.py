from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from .database import connect
from .main import now_iso
from .sso import SsoConfigurationError, SsoConnectionService

router = APIRouter(prefix="/v2/organizations", tags=["organization-security"])


class OrganizationSecurityPolicyUpdate(BaseModel):
    require_mfa: bool = False
    sso_required: bool = False
    max_session_days: int = Field(default=30, ge=1, le=90)
    allowed_email_domains: list[str] = Field(default_factory=list)


class OidcConnectionUpdate(BaseModel):
    issuer: str
    client_id: str
    client_secret: str | None = None
    authorization_endpoint: str
    token_endpoint: str
    jwks_uri: str
    allowed_domains: list[str] = Field(default_factory=list)
    enabled: bool = False


def _authorize(request: Request, organization_id: str) -> str:
    user_id = str(getattr(request.state, "user_id", ""))
    role = str(getattr(request.state, "user_role", ""))
    session_org = str(getattr(request.state, "organization_id", ""))
    if role == "platform_admin":
        return user_id or "platform-admin"
    if role != "organization_admin" or session_org != organization_id:
        raise HTTPException(status_code=403, detail="Organization administrator access is required")
    return user_id


def _domains(values: list[str]) -> list[str]:
    normalized = sorted({value.strip().lower().lstrip("@") for value in values if value.strip()})
    for domain in normalized:
        if "." not in domain or " " in domain:
            raise HTTPException(status_code=400, detail=f"Invalid allowed email domain: {domain}")
    return normalized


@router.get("/{organization_id}/security-policy")
def security_policy(organization_id: str, request: Request) -> dict[str, Any]:
    _authorize(request, organization_id)
    with connect() as connection:
        row = connection.execute(
            "SELECT * FROM organization_security_policies WHERE organization_id = ?",
            (organization_id,),
        ).fetchone()
    if row is None:
        return {
            "organization_id": organization_id,
            "require_mfa": False,
            "sso_required": False,
            "max_session_days": 30,
            "allowed_email_domains": [],
        }
    return {
        "organization_id": organization_id,
        "require_mfa": bool(row["require_mfa"]),
        "sso_required": bool(row["sso_required"]),
        "max_session_days": int(row["max_session_days"]),
        "allowed_email_domains": json.loads(row["allowed_email_domains"] or "[]"),
        "updated_at": row["updated_at"],
    }


@router.put("/{organization_id}/security-policy")
def update_security_policy(
    organization_id: str,
    payload: OrganizationSecurityPolicyUpdate,
    request: Request,
) -> dict[str, Any]:
    actor = _authorize(request, organization_id)
    domains = _domains(payload.allowed_email_domains)
    if payload.sso_required and not domains:
        raise HTTPException(status_code=400, detail="SSO-required organizations must declare an allowed email domain")
    timestamp = now_iso()
    encoded = json.dumps(domains, separators=(",", ":"))
    with connect() as connection:
        connection.execute(
            "DELETE FROM organization_security_policies WHERE organization_id = ?",
            (organization_id,),
        )
        connection.execute(
            """
            INSERT INTO organization_security_policies (
              organization_id, require_mfa, sso_required, max_session_days,
              allowed_email_domains, updated_by_user_id, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                organization_id,
                int(payload.require_mfa),
                int(payload.sso_required),
                payload.max_session_days,
                encoded,
                actor or None,
                timestamp,
                timestamp,
            ),
        )
        connection.commit()
    return security_policy(organization_id, request)


@router.get("/{organization_id}/sso")
def sso_connections(organization_id: str, request: Request) -> dict[str, Any]:
    _authorize(request, organization_id)
    with connect() as connection:
        rows = connection.execute(
            """
            SELECT id, connection_type, issuer, client_id, authorization_endpoint,
                   token_endpoint, jwks_uri, allowed_domains, status, created_at, updated_at
            FROM sso_connections WHERE organization_id = ? ORDER BY created_at
            """,
            (organization_id,),
        ).fetchall()
    return {"organization_id": organization_id, "connections": [dict(row) for row in rows]}


@router.put("/{organization_id}/sso/oidc")
def configure_oidc(
    organization_id: str,
    payload: OidcConnectionUpdate,
    request: Request,
) -> dict[str, Any]:
    _authorize(request, organization_id)
    try:
        with connect() as connection:
            result = SsoConnectionService().upsert_oidc_connection(
                connection,
                organization_id=organization_id,
                issuer=payload.issuer,
                client_id=payload.client_id,
                client_secret=payload.client_secret,
                authorization_endpoint=payload.authorization_endpoint,
                token_endpoint=payload.token_endpoint,
                jwks_uri=payload.jwks_uri,
                allowed_domains=payload.allowed_domains,
                enabled=payload.enabled,
            )
            connection.commit()
            return result
    except SsoConfigurationError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
