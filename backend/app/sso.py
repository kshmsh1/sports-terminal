from __future__ import annotations

import base64
import hashlib
import json
import os
import secrets
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt

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


@dataclass(frozen=True)
class VerifiedOidcIdentity:
    subject: str
    email: str
    issuer: str
    mfa_authenticated: bool
    claims: dict[str, Any]


class SsoConfigurationError(RuntimeError):
    pass


class SsoProtocolError(RuntimeError):
    pass


_JWKS_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
_JWKS_TTL_SECONDS = 300
_SUPPORTED_ID_TOKEN_ALGORITHMS = {
    "RS256",
    "RS384",
    "RS512",
    "ES256",
    "ES384",
    "ES512",
}


def _base64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _pkce_pair() -> tuple[str, str]:
    verifier = _base64url(secrets.token_bytes(48))
    challenge = _base64url(hashlib.sha256(verifier.encode("ascii")).digest())
    return verifier, challenge


def _https_url(value: str, label: str) -> str:
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        raise SsoConfigurationError(f"{label} must be an HTTPS URL without embedded credentials")
    return value.rstrip("/") if label == "OIDC issuer" else value


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
        issuer = _https_url(issuer.strip(), "OIDC issuer")
        authorization_endpoint = _https_url(
            authorization_endpoint.strip(), "OIDC authorization endpoint"
        )
        token_endpoint = _https_url(token_endpoint.strip(), "OIDC token endpoint")
        jwks_uri = _https_url(jwks_uri.strip(), "OIDC JWKS endpoint")
        client_id = client_id.strip()
        if not client_id:
            raise SsoConfigurationError("OIDC client ID is required")
        normalized_domains = sorted(
            {domain.strip().lower().lstrip("@") for domain in allowed_domains if domain.strip()}
        )
        if not normalized_domains:
            raise SsoConfigurationError("at least one allowed SSO email domain is required")
        for domain in normalized_domains:
            if "." not in domain or " " in domain or "/" in domain:
                raise SsoConfigurationError(f"invalid allowed SSO email domain: {domain}")

        existing = connection.execute(
            "SELECT id, client_secret_ciphertext FROM sso_connections "
            "WHERE organization_id = ? AND issuer = ? AND client_id = ?",
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
            "SELECT id, organization_id, connection_type, issuer, client_id, "
            "authorization_endpoint, token_endpoint, jwks_uri, allowed_domains, status, created_at, updated_at "
            "FROM sso_connections WHERE id = ?",
            (connection_id,),
        ).fetchone()
        return dict(row) if row is not None else {}

    def enabled_connection(
        self,
        connection: DatabaseConnection,
        *,
        organization_id: str,
        connection_id: str | None = None,
    ) -> dict[str, Any]:
        if connection_id:
            row = connection.execute(
                "SELECT * FROM sso_connections WHERE id = ? AND organization_id = ? "
                "AND connection_type = 'oidc' AND status = 'enabled'",
                (connection_id, organization_id),
            ).fetchone()
            if row is None:
                raise SsoConfigurationError("OIDC connection is not enabled for this organization")
            return dict(row)
        rows = connection.execute(
            "SELECT * FROM sso_connections WHERE organization_id = ? "
            "AND connection_type = 'oidc' AND status = 'enabled' ORDER BY created_at",
            (organization_id,),
        ).fetchall()
        if not rows:
            raise SsoConfigurationError("No enabled OIDC connection exists for this organization")
        if len(rows) > 1:
            raise SsoConfigurationError("Multiple OIDC connections exist; select a connection explicitly")
        return dict(rows[0])

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
        redirect = urllib.parse.urlparse(redirect_uri)
        local_redirect = redirect.hostname in {"127.0.0.1", "localhost", "::1"}
        if not redirect.netloc or (redirect.scheme != "https" and not (local_redirect and redirect.scheme == "http")):
            raise SsoConfigurationError("SSO redirect URI must use HTTPS outside loopback development")

        tokens = self._token_service()
        state = tokens.issue(self.STATE_PURPOSE)
        nonce = tokens.issue(self.NONCE_PURPOSE)
        verifier, challenge = _pkce_pair()
        state_id = make_id("ssostate")
        created = datetime.now(timezone.utc)
        expires = created + timedelta(minutes=10)
        encrypted_verifier = self._vault().encrypt(
            verifier,
            aad=f"sso-state:{state_id}:pkce",
        )
        connection.execute(
            """
            INSERT INTO sso_login_states (
              id, connection_id, state_hash, nonce_hash, redirect_uri,
              pkce_verifier_ciphertext, expires_at, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                state_id,
                connection_id,
                state.token_hash,
                nonce.token_hash,
                redirect_uri,
                encrypted_verifier,
                expires.isoformat(),
                created.isoformat(),
            ),
        )
        query = urllib.parse.urlencode(
            {
                "response_type": "code",
                "client_id": row["client_id"],
                "redirect_uri": redirect_uri,
                "scope": "openid email profile",
                "state": state.plaintext,
                "nonce": nonce.plaintext,
                "code_challenge": challenge,
                "code_challenge_method": "S256",
            }
        )
        separator = "&" if "?" in str(row["authorization_endpoint"]) else "?"
        return SsoLoginStart(
            connection_id,
            f"{row['authorization_endpoint']}{separator}{query}",
            state.plaintext,
            expires.isoformat(),
        )

    def consume_state(
        self,
        connection: DatabaseConnection,
        *,
        plaintext_state: str,
    ) -> dict[str, Any] | None:
        state_hash = self._token_service().hash(plaintext_state, self.STATE_PURPOSE)
        row = connection.execute(
            """
            SELECT st.id AS state_id, st.connection_id, st.state_hash, st.nonce_hash,
                   st.redirect_uri, st.pkce_verifier_ciphertext, st.expires_at, st.consumed_at,
                   c.organization_id, c.issuer, c.client_id, c.client_secret_ciphertext,
                   c.token_endpoint, c.jwks_uri, c.allowed_domains, c.status
            FROM sso_login_states AS st
            JOIN sso_connections AS c ON c.id = st.connection_id
            WHERE st.state_hash = ?
            """,
            (state_hash,),
        ).fetchone()
        if row is None or row["consumed_at"] is not None or row["status"] != "enabled":
            return None
        if datetime.fromisoformat(str(row["expires_at"])) <= datetime.now(timezone.utc):
            return None
        cursor = connection.execute(
            "UPDATE sso_login_states SET consumed_at = ? WHERE id = ? AND consumed_at IS NULL",
            (now_iso(), row["state_id"]),
        )
        if cursor.rowcount != 1:
            return None
        result = dict(row)
        ciphertext = str(result.get("pkce_verifier_ciphertext") or "")
        if not ciphertext:
            raise SsoProtocolError("OIDC login state does not contain a PKCE verifier")
        result["pkce_verifier"] = self._vault().decrypt(
            ciphertext,
            aad=f"sso-state:{result['state_id']}:pkce",
        )
        return result

    def exchange_authorization_code(
        self,
        state: dict[str, Any],
        *,
        code: str,
        timeout_seconds: float = 8.0,
    ) -> dict[str, Any]:
        if not code.strip():
            raise SsoProtocolError("OIDC authorization code is required")
        body = urllib.parse.urlencode(
            {
                "grant_type": "authorization_code",
                "code": code.strip(),
                "client_id": str(state["client_id"]),
                "redirect_uri": str(state["redirect_uri"]),
                "code_verifier": str(state["pkce_verifier"]),
            }
        ).encode("utf-8")
        headers = {
            "Accept": "application/json",
            "Content-Type": "application/x-www-form-urlencoded",
        }
        encrypted_secret = str(state.get("client_secret_ciphertext") or "")
        if encrypted_secret:
            secret = self._vault().decrypt(
                encrypted_secret,
                aad=f"organization:{state['organization_id']}:sso:{state['connection_id']}",
            )
            credential = base64.b64encode(
                f"{state['client_id']}:{secret}".encode("utf-8")
            ).decode("ascii")
            headers["Authorization"] = f"Basic {credential}"
        request = urllib.request.Request(
            str(state["token_endpoint"]),
            data=body,
            headers=headers,
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
                if response.status < 200 or response.status >= 300:
                    raise SsoProtocolError("OIDC token endpoint rejected the authorization code")
                payload = json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            raise SsoProtocolError("OIDC token exchange failed") from error
        if not isinstance(payload, dict) or not isinstance(payload.get("id_token"), str):
            raise SsoProtocolError("OIDC token response did not contain an ID token")
        return payload

    def verify_id_token(
        self,
        state: dict[str, Any],
        *,
        id_token: str,
    ) -> VerifiedOidcIdentity:
        try:
            header = jwt.get_unverified_header(id_token)
        except jwt.PyJWTError as error:
            raise SsoProtocolError("OIDC ID token header is invalid") from error
        algorithm = str(header.get("alg") or "")
        key_id = str(header.get("kid") or "")
        if algorithm not in _SUPPORTED_ID_TOKEN_ALGORITHMS or not key_id:
            raise SsoProtocolError("OIDC ID token uses an unsupported signing key or algorithm")
        jwk = self._signing_jwk(str(state["jwks_uri"]), key_id)
        try:
            signing_key = jwt.PyJWK.from_dict(jwk, algorithm=algorithm).key
            claims = jwt.decode(
                id_token,
                signing_key,
                algorithms=[algorithm],
                audience=str(state["client_id"]),
                issuer=str(state["issuer"]),
                leeway=60,
                options={
                    "require": ["exp", "iat", "iss", "aud", "sub", "nonce", "email"],
                },
            )
        except (jwt.PyJWTError, ValueError) as error:
            # Refresh once in case the identity provider rotated keys between cache fills.
            self._refresh_jwks(str(state["jwks_uri"]))
            try:
                jwk = self._signing_jwk(str(state["jwks_uri"]), key_id)
                signing_key = jwt.PyJWK.from_dict(jwk, algorithm=algorithm).key
                claims = jwt.decode(
                    id_token,
                    signing_key,
                    algorithms=[algorithm],
                    audience=str(state["client_id"]),
                    issuer=str(state["issuer"]),
                    leeway=60,
                    options={
                        "require": ["exp", "iat", "iss", "aud", "sub", "nonce", "email"],
                    },
                )
            except (jwt.PyJWTError, ValueError) as retry_error:
                raise SsoProtocolError("OIDC ID token verification failed") from retry_error

        nonce = str(claims.get("nonce") or "")
        if not self._token_service().matches(
            nonce,
            self.NONCE_PURPOSE,
            str(state["nonce_hash"]),
        ):
            raise SsoProtocolError("OIDC ID token nonce does not match the login state")
        subject = str(claims.get("sub") or "").strip()
        email = str(claims.get("email") or "").strip().lower()
        if not subject or "@" not in email:
            raise SsoProtocolError("OIDC ID token is missing a usable subject or email")
        if claims.get("email_verified") is not True:
            raise SsoProtocolError("OIDC identity provider has not verified the email address")
        domain = email.rsplit("@", 1)[1]
        allowed_domains = _decode_domains(state.get("allowed_domains"))
        if domain not in allowed_domains:
            raise SsoProtocolError("OIDC email domain is not allowed for this connection")
        amr = claims.get("amr")
        methods = {
            str(item).strip().lower()
            for item in amr
            if isinstance(amr, list) and isinstance(item, (str, int))
        } if isinstance(amr, list) else set()
        mfa_authenticated = bool(methods & {"mfa", "otp", "totp", "hwk", "swk"})
        return VerifiedOidcIdentity(
            subject=subject,
            email=email,
            issuer=str(claims["iss"]),
            mfa_authenticated=mfa_authenticated,
            claims=dict(claims),
        )

    def link_existing_identity(
        self,
        connection: DatabaseConnection,
        *,
        state: dict[str, Any],
        identity: VerifiedOidcIdentity,
    ) -> dict[str, Any]:
        organization_id = str(state["organization_id"])
        connection_id = str(state["connection_id"])
        existing = connection.execute(
            "SELECT * FROM sso_identities WHERE connection_id = ? AND provider_subject = ?",
            (connection_id, identity.subject),
        ).fetchone()
        if existing is not None:
            user_id = str(existing["user_id"])
        else:
            user = connection.execute(
                "SELECT id FROM users WHERE lower(email) = ? AND status = 'active'",
                (identity.email,),
            ).fetchone()
            if user is None:
                raise SsoProtocolError(
                    "SSO sign-in requires an existing active Sports Terminal account with the same verified email"
                )
            user_id = str(user["id"])

        membership = connection.execute(
            "SELECT role, status FROM organization_memberships "
            "WHERE organization_id = ? AND user_id = ?",
            (organization_id, user_id),
        ).fetchone()
        if membership is None or membership["status"] != "active":
            raise SsoProtocolError("SSO account is not an active member of this organization")
        self._enforce_policy_domain(connection, organization_id, identity.email)

        timestamp = now_iso()
        if existing is None:
            collision = connection.execute(
                "SELECT provider_subject FROM sso_identities WHERE connection_id = ? AND user_id = ?",
                (connection_id, user_id),
            ).fetchone()
            if collision is not None and str(collision["provider_subject"]) != identity.subject:
                raise SsoProtocolError("Sports Terminal account is already linked to another provider identity")
            connection.execute(
                """
                INSERT INTO sso_identities (
                  connection_id, provider_subject, user_id, organization_id,
                  email_normalized, issuer, linked_at, last_login_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    connection_id,
                    identity.subject,
                    user_id,
                    organization_id,
                    identity.email,
                    identity.issuer,
                    timestamp,
                    timestamp,
                ),
            )
        else:
            if str(existing["organization_id"]) != organization_id or str(existing["issuer"]) != identity.issuer:
                raise SsoProtocolError("Stored SSO identity does not match the current organization or issuer")
            connection.execute(
                "UPDATE sso_identities SET email_normalized = ?, last_login_at = ? "
                "WHERE connection_id = ? AND provider_subject = ?",
                (identity.email, timestamp, connection_id, identity.subject),
            )

        row = connection.execute(
            "SELECT id, email, display_name, role, status FROM users WHERE id = ? AND status = 'active'",
            (user_id,),
        ).fetchone()
        if row is None:
            raise SsoProtocolError("Linked Sports Terminal account is not active")
        return dict(row)

    def _enforce_policy_domain(
        self,
        connection: DatabaseConnection,
        organization_id: str,
        email: str,
    ) -> None:
        row = connection.execute(
            "SELECT allowed_email_domains FROM organization_security_policies WHERE organization_id = ?",
            (organization_id,),
        ).fetchone()
        if row is None:
            return
        policy_domains = _decode_domains(row["allowed_email_domains"])
        if not policy_domains:
            return
        domain = email.rsplit("@", 1)[1]
        if domain not in policy_domains:
            raise SsoProtocolError("OIDC email domain is not allowed by organization policy")

    def _signing_jwk(self, uri: str, key_id: str) -> dict[str, Any]:
        payload = self._jwks(uri)
        for item in payload.get("keys", []):
            if isinstance(item, dict) and str(item.get("kid") or "") == key_id:
                return item
        self._refresh_jwks(uri)
        payload = self._jwks(uri)
        for item in payload.get("keys", []):
            if isinstance(item, dict) and str(item.get("kid") or "") == key_id:
                return item
        raise SsoProtocolError("OIDC signing key was not found in JWKS")

    def _jwks(self, uri: str) -> dict[str, Any]:
        cached = _JWKS_CACHE.get(uri)
        if cached and cached[0] > time.monotonic():
            return cached[1]
        return self._refresh_jwks(uri)

    def _refresh_jwks(self, uri: str) -> dict[str, Any]:
        _https_url(uri, "OIDC JWKS endpoint")
        request = urllib.request.Request(uri, headers={"Accept": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=8) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            raise SsoProtocolError("OIDC JWKS retrieval failed") from error
        if not isinstance(payload, dict) or not isinstance(payload.get("keys"), list):
            raise SsoProtocolError("OIDC JWKS response is invalid")
        _JWKS_CACHE[uri] = (time.monotonic() + _JWKS_TTL_SECONDS, payload)
        return payload


def _decode_domains(value: Any) -> set[str]:
    if isinstance(value, str):
        try:
            value = json.loads(value or "[]")
        except json.JSONDecodeError:
            value = []
    if not isinstance(value, list):
        return set()
    return {str(item).strip().lower().lstrip("@") for item in value if str(item).strip()}
