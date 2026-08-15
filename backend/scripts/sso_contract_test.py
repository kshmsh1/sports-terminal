from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app import database
from app.sso import SsoConfigurationError, SsoConnectionService


def main() -> None:
    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_SESSION_PEPPER",
        "SPORTS_TERMINAL_SSO_ENCRYPTION_KEY",
    )}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_SESSION_PEPPER"] = "o" * 40
        os.environ["SPORTS_TERMINAL_SSO_ENCRYPTION_KEY"] = "e" * 40
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "sso.db"
            with database.connect() as connection:
                connection.executescript(
                    """
                    CREATE TABLE organizations (id TEXT PRIMARY KEY);
                    INSERT INTO organizations VALUES ('org_1');
                    CREATE TABLE sso_connections (
                      id TEXT PRIMARY KEY, organization_id TEXT NOT NULL REFERENCES organizations(id),
                      connection_type TEXT NOT NULL, issuer TEXT NOT NULL, client_id TEXT NOT NULL,
                      client_secret_ciphertext TEXT, authorization_endpoint TEXT, token_endpoint TEXT,
                      jwks_uri TEXT, allowed_domains TEXT NOT NULL DEFAULT '[]', status TEXT NOT NULL,
                      created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
                      UNIQUE(organization_id, issuer, client_id)
                    );
                    CREATE TABLE sso_login_states (
                      id TEXT PRIMARY KEY, connection_id TEXT NOT NULL REFERENCES sso_connections(id),
                      state_hash TEXT NOT NULL UNIQUE, nonce_hash TEXT NOT NULL,
                      redirect_uri TEXT NOT NULL, expires_at TEXT NOT NULL,
                      consumed_at TEXT, created_at TEXT NOT NULL
                    );
                    """
                )
                service = SsoConnectionService()
                created = service.upsert_oidc_connection(
                    connection,
                    organization_id="org_1",
                    issuer="https://id.example.com",
                    client_id="sports-terminal",
                    client_secret="never-store-plaintext",
                    authorization_endpoint="https://id.example.com/authorize",
                    token_endpoint="https://id.example.com/token",
                    jwks_uri="https://id.example.com/jwks",
                    allowed_domains=["Example.com", "example.com"],
                    enabled=True,
                )
                assert "client_secret_ciphertext" not in created
                stored = connection.execute(
                    "SELECT client_secret_ciphertext, allowed_domains FROM sso_connections WHERE id = ?",
                    (created["id"],),
                ).fetchone()
                assert stored is not None
                assert "never-store-plaintext" not in stored["client_secret_ciphertext"]
                assert stored["allowed_domains"] == '["example.com"]'
                started = service.begin_login(
                    connection,
                    connection_id=created["id"],
                    redirect_uri="https://terminal.example.com/auth/callback",
                )
                assert "response_type=code" in started.authorization_url
                assert "state=" in started.authorization_url
                assert "nonce=" in started.authorization_url
                consumed = service.consume_state(connection, plaintext_state=started.state)
                assert consumed is not None
                assert consumed["organization_id"] == "org_1"
                assert service.consume_state(connection, plaintext_state=started.state) is None

                try:
                    service.upsert_oidc_connection(
                        connection,
                        organization_id="org_1",
                        issuer="http://insecure.example",
                        client_id="bad",
                        client_secret=None,
                        authorization_endpoint="http://insecure.example/auth",
                        token_endpoint="http://insecure.example/token",
                        jwks_uri="http://insecure.example/jwks",
                        allowed_domains=["example.com"],
                    )
                except SsoConfigurationError as error:
                    assert "HTTPS" in str(error)
                else:
                    raise AssertionError("OIDC endpoints must require HTTPS")

        print("sso_contract: PASS")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
