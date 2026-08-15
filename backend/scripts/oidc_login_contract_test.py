from __future__ import annotations

import json
import os
import tempfile
import time
import urllib.parse
from pathlib import Path

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa

from app import database, sso as sso_module
from app.main import make_id, now_iso
from app.migrations import run_migrations
from app.sso import SsoConnectionService, SsoProtocolError
from scripts.migrate import bootstrap_core_schema


class FakeResponse:
    def __init__(self, payload: dict[str, object]) -> None:
        self.status = 200
        self._payload = json.dumps(payload).encode("utf-8")

    def read(self) -> bytes:
        return self._payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        return None


def main() -> None:
    previous = {
        key: os.environ.get(key)
        for key in (
            "SPORTS_TERMINAL_DATABASE_URL",
            "SPORTS_TERMINAL_SESSION_PEPPER",
            "SPORTS_TERMINAL_SSO_ENCRYPTION_KEY",
        )
    }
    original_urlopen = sso_module.urllib.request.urlopen
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_SESSION_PEPPER"] = "state-" + "p" * 40
        os.environ["SPORTS_TERMINAL_SSO_ENCRYPTION_KEY"] = "sso-key-" + "k" * 40
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "oidc.db"
            bootstrap_core_schema()
            run_migrations()
            timestamp = now_iso()
            user_id = make_id("usr")
            organization_id = make_id("org")
            with database.connect() as connection:
                connection.execute(
                    "INSERT INTO users (id, email, display_name, role, status, created_at, updated_at) "
                    "VALUES (?, 'analyst@example.com', 'OIDC Analyst', 'organization_admin', 'active', ?, ?)",
                    (user_id, timestamp, timestamp),
                )
                connection.execute(
                    "INSERT INTO organizations (id, name, slug, status, plan_id, created_by_user_id, created_at, updated_at) "
                    "VALUES (?, 'OIDC Org', 'oidc-org', 'active', 'org', ?, ?, ?)",
                    (organization_id, user_id, timestamp, timestamp),
                )
                connection.execute(
                    "INSERT INTO organization_memberships "
                    "(organization_id, user_id, role, status, joined_at, updated_at) "
                    "VALUES (?, ?, 'owner', 'active', ?, ?)",
                    (organization_id, user_id, timestamp, timestamp),
                )
                service = SsoConnectionService()
                configured = service.upsert_oidc_connection(
                    connection,
                    organization_id=organization_id,
                    issuer="https://id.example.com",
                    client_id="sports-terminal-client",
                    client_secret="never-store-plaintext",
                    authorization_endpoint="https://id.example.com/authorize",
                    token_endpoint="https://id.example.com/token",
                    jwks_uri="https://id.example.com/jwks",
                    allowed_domains=["example.com"],
                    enabled=True,
                )
                start = service.begin_login(
                    connection,
                    connection_id=str(configured["id"]),
                    redirect_uri=f"http://localhost:8000/v2/auth/sso/{organization_id}/callback",
                )
                connection.commit()

            query = urllib.parse.parse_qs(urllib.parse.urlparse(start.authorization_url).query)
            assert query["response_type"] == ["code"]
            assert query["code_challenge_method"] == ["S256"]
            assert query["code_challenge"][0]
            assert query["nonce"][0]
            assert query["state"] == [start.state]

            with database.connect() as connection:
                state_row = connection.execute(
                    "SELECT pkce_verifier_ciphertext FROM sso_login_states WHERE connection_id = ?",
                    (configured["id"],),
                ).fetchone()
                assert state_row is not None
                assert str(state_row["pkce_verifier_ciphertext"]).startswith("v1.")
                assert "never-store-plaintext" not in str(state_row["pkce_verifier_ciphertext"])
                state = service.consume_state(connection, plaintext_state=start.state)
                assert state is not None
                assert len(str(state["pkce_verifier"])) >= 43
                assert service.consume_state(connection, plaintext_state=start.state) is None
                connection.commit()

            private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
            public_jwk = jwt.algorithms.RSAAlgorithm.to_jwk(private_key.public_key())
            if isinstance(public_jwk, str):
                public_jwk = json.loads(public_jwk)
            public_jwk.update({"kid": "contract-key", "alg": "RS256", "use": "sig"})
            now = int(time.time())
            claims = {
                "iss": "https://id.example.com",
                "aud": "sports-terminal-client",
                "sub": "provider-subject-123",
                "email": "analyst@example.com",
                "email_verified": True,
                "nonce": query["nonce"][0],
                "iat": now,
                "exp": now + 300,
                "amr": ["pwd", "mfa"],
            }
            id_token = jwt.encode(
                claims,
                private_key,
                algorithm="RS256",
                headers={"kid": "contract-key"},
            )

            def fake_urlopen(request, timeout=0):
                assert request.full_url == "https://id.example.com/token"
                body = urllib.parse.parse_qs(request.data.decode("utf-8"))
                assert body["grant_type"] == ["authorization_code"]
                assert body["code"] == ["contract-code"]
                assert body["code_verifier"] == [state["pkce_verifier"]]
                assert request.headers.get("Authorization", "").startswith("Basic ")
                return FakeResponse({"id_token": id_token, "token_type": "Bearer"})

            sso_module.urllib.request.urlopen = fake_urlopen
            token_response = service.exchange_authorization_code(state, code="contract-code")
            assert token_response["id_token"] == id_token
            service._jwks = lambda uri: {"keys": [public_jwk]}  # type: ignore[method-assign]
            identity = service.verify_id_token(state, id_token=id_token)
            assert identity.email == "analyst@example.com"
            assert identity.subject == "provider-subject-123"
            assert identity.mfa_authenticated is True

            with database.connect() as connection:
                linked = service.link_existing_identity(connection, state=state, identity=identity)
                connection.commit()
                assert linked["id"] == user_id
                stored = connection.execute(
                    "SELECT user_id, email_normalized FROM sso_identities WHERE connection_id = ? AND provider_subject = ?",
                    (configured["id"], identity.subject),
                ).fetchone()
                assert stored is not None
                assert stored["user_id"] == user_id
                assert stored["email_normalized"] == "analyst@example.com"

            bad_claims = dict(claims)
            bad_claims["nonce"] = "wrong-nonce"
            bad_token = jwt.encode(
                bad_claims,
                private_key,
                algorithm="RS256",
                headers={"kid": "contract-key"},
            )
            try:
                service.verify_id_token(state, id_token=bad_token)
            except SsoProtocolError as error:
                assert "nonce" in str(error)
            else:
                raise AssertionError("OIDC nonce mismatch must be rejected")

        print("oidc_login_contract: PASS")
    finally:
        sso_module.urllib.request.urlopen = original_urlopen
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
