from __future__ import annotations

import json
import os
import urllib.parse
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

from .database import DatabaseConnection
from .main import make_id, now_iso
from .mfa import SecretVault
from .runtime_config import load_runtime_config
from .security_tokens import SecurityTokenService


@dataclass(frozen=True)
class SsoLoginStart:
    connection_id: str
    authorization_url: str
    state: str
    expires_at: str


class SsoConfigurationError(RuntimeError):
    pass


class SsoConnectionService:
    STATE_PURPOSE = "oidc-state"
    NONCE_PURPOSE = "oidc-nonce"

    def _token_service(self) -> SecurityTokenService:
        config = load_runtime_config()
        pepper = config.session_pepper or "development-only-sso-state-pepper-32chars"
        return SecurityTokenService(pepper)

    def _vault(self) -> SecretVault:
        key = os.getenv("SPORTS_TERMINAL_SSO_ENCRYPTION_KEY", "")
        if not key:
            key = load_runtime_config().mfa_encryption_key
        if len(key) < 32:
            raise SsoConfigurationError("SSO client-secret encryption key is not configured")
        return SecretVault(key)

    def upsert_oidc_connection(
        self,
        connection: DatabaseConnection,
        *,
        organization_id: str,
        issuer: str,
        client_id: str,
        client_secret: str | None,
        authorization_endpoint: str,
        token_endpoint: str,
        jwks_uri: str,
        allowed_domains: list[str],
        enabled: bool = False,
    ) -> dict[str, Any]:
        urls = [issuer, authorization_endpoint, token_endpoint, jwks_uri]
        if any(not value.startswith("https://") for value in urls):
            raise SsoConfigurationError("OIDC issuer and endpoints must use HTTPS")
        normalized_domains = sorted(
            {domain.strip().lower().lstrip("@") for domain in allowed_domains if domain.strip()}
        )
        if not normalized_domains:
            raise SsoConfigurationError("at least one allowed SSO email domain is required")
        existing = connection.execute(
            "SELECT id, client_secret_ciphertext FROM sso_connections WHERE organization_id = ? AND issuer = ? AND client_id = ?",
            (organization_id, issuer, client_id),
        ).fetchone()
        connection_id = str(existing["id"]) if existing is not None else make_id("sso")
        ciphertext = existing["client_secret_ciphertext"] if existing is not None else None
        if client_secret:
            ciphertext = self._vault().encrypt(
                client_secret,
                aad=f"organization:{organization_id}:sso:{connection_id}",
            )
        timestamp = now_iso()
        if existing is not None:
            connection.execute(
                """
                UPDATE sso_connections SET authorization_endpoint = ?, token_endpoint = ?,
                    jwks_uri = ?, allowed_domains = ?, status = ?, client_secret_ciphertext = ?, updated_at = ?
                WHERE id = ?
                """,
                (
                    authorization_endpoint,
                    token_endpoint,
                    jwks_uri,
                    json.dumps(normalized_domains, separators=(",", ":")),
                    "enabled" if enabled else "disabled",
                    ciphertext,
                    timestamp,
                    connection_id,
                ),
            )
        else:
            connection.execute(
                """
                INSERT INTO sso_connections (
                  id, organization_id, connection_type, issuer, client_id,
                  client_secret_ciphertext, authorization_endpoint, token_endpoint,
                  jwks_uri, allowed_domains, status, created_at, updated_at
                ) VALUES (?, ?, 'oidc', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    connection_id,
                    organization_id,
                    issuer,
                    client_id,
                    ciphertext,
                    authorization_endpoint,
                    token_endpoint,
                    jwks_uri,
                    json.dumps(normalized_domains, separators=(",", ":")),
                    "enabled" if enabled else "disabled",
                    timestamp,
                    timestamp,
                ),
            )
        row = connection.execute(
            "SELECT id, organization_id, connection_type, issuer, client_id, authorization_endpoint, token_endpoint, jwks_uri, allowed_domains, status, created_at, updated_at FROM sso_connections WHERE id = ?",
            (connection_id,),
        ).fetchone()
        return dict(row) if row is not None else {}

    def begin_login(
        self,
        connection: DatabaseConnection,
        *,
        connection_id: str,
        redirect_uri: str,
    ) -> SsoLoginStart:
        row = connection.execute(
            "SELECT * FROM sso_connections WHERE id = ? AND status = 'enabled'",
            (connection_id,),
        ).fetchone()
        if row is None:
            raise SsoConfigurationError("SSO connection is not enabled")
        if not redirect_uri.startswith("https://") and not redirect_uri.startswith("http://localhost"):
            raise SsoConfigurationError("SSO redirect URI must use HTTPS")
        tokens = self._token_service()
        state = tokens.issue(self.STATE_PURPOSE)
        nonce = tokens.issue(self.NONCE_PURPOSE)
        state_id = make_id("ssostate")
        created = datetime.now(timezone.utc)
        expires = created + timedelta(minutes=10)
        connection.execute(
            """
            INSERT INTO sso_login_states (
              id, connection_id, state_hash, nonce_hash, redirect_uri, expires_at, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (state_id, connection_id, state.token_hash, nonce.token_hash, redirect_uri, expires.isoformat(), created.isoformat()),
        )
        query = urllib.parse.urlencode(
            {
                "response_type": "code",
                "client_id": row["client_id"],
                "redirect_uri": redirect_uri,
                "scope": "openid email profile",
                "state": state.plaintext,
                "nonce": nonce.plaintext,
            }
        )
        return SsoLoginStart(
            connection_id,
            f"{row['authorization_endpoint']}?{query}",
            state.plaintext,
            expires.isoformat(),
        )

    def consume_state(self, connection: DatabaseConnection, *, plaintext_state: str) -> dict[str, Any] | None:
        state_hash = self._token_service().hash(plaintext_state, self.STATE_PURPOSE)
        row = connection.execute(
            """
            SELECT sso_login_states.*, sso_connections.organization_id, sso_connections.issuer,
                   sso_connections.token_endpoint, sso_connections.jwks_uri, sso_connections.allowed_domains
            FROM sso_login_states
            JOIN sso_connections ON sso_connections.id = sso_login_states.connection_id
            WHERE sso_login_states.state_hash = ?
            """,
            (state_hash,),
        ).fetchone()
        if row is None or row["consumed_at"] is not None:
            return None
        if datetime.fromisoformat(str(row["expires_at"])) <= datetime.now(timezone.utc):
            return None
        connection.execute(
            "UPDATE sso_login_states SET consumed_at = ? WHERE id = ? AND consumed_at IS NULL",
            (now_iso(), row["id"]),
        )
        return dict(row)
