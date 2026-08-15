from __future__ import annotations

import os
import secrets
import tempfile
from pathlib import Path

from app import database
from app import auth_api
from app.assured_auth_api import MfaLoginCompleteRequest, complete_mfa_login, sign_in
from app.main import make_id, now_iso
from app.mfa import SecretVault, TotpService
from app.migrations import run_migrations
from app.production_bootstrap import bind_database_boundary


def _user(connection, *, email: str, password: str) -> str:
    user_id = make_id("usr")
    timestamp = now_iso()
    salt = secrets.token_bytes(16).hex()
    connection.execute(
        "INSERT INTO users (id, email, display_name, role, status, created_at, updated_at) VALUES (?, ?, 'Assured User', 'analyst', 'active', ?, ?)",
        (user_id, email, timestamp, timestamp),
    )
    connection.execute(
        "INSERT INTO auth_credentials (user_id, password_hash, password_salt, password_iterations, email_verified, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?)",
        (
            user_id,
            auth_api._password_hash(password, salt, auth_api.PASSWORD_ITERATIONS),
            salt,
            auth_api.PASSWORD_ITERATIONS,
            timestamp,
            timestamp,
        ),
    )
    return user_id


def main() -> None:
    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_SESSION_PEPPER",
        "SPORTS_TERMINAL_MFA_ENCRYPTION_KEY",
        "SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION",
    )}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_SESSION_PEPPER"] = "s" * 40
        os.environ["SPORTS_TERMINAL_MFA_ENCRYPTION_KEY"] = "v" * 40
        os.environ["SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION"] = "true"
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "assured.db"
            bind_database_boundary()
            auth_api.init_auth_db()
            run_migrations()
            password = "StrongAuthPass123!"
            with database.connect() as connection:
                mfa_user = _user(connection, email="mfa@example.com", password=password)
                plain_user = _user(connection, email="plain@example.com", password=password)
                factor_id = make_id("mfa")
                secret = TotpService().generate_secret()
                ciphertext = SecretVault("v" * 40).encrypt(
                    secret, aad=f"user:{mfa_user}:factor:{factor_id}"
                )
                timestamp = now_iso()
                connection.execute(
                    "INSERT INTO auth_mfa_factors (id, user_id, factor_type, secret_ciphertext, label, verified_at, created_at, updated_at) VALUES (?, ?, 'totp', ?, 'Authenticator', ?, ?, ?)",
                    (factor_id, mfa_user, ciphertext, timestamp, timestamp, timestamp),
                )
                connection.commit()

            first = sign_in(auth_api.SignInRequest(email="mfa@example.com", password=password))
            assert first["mfa_required"] is True
            assert "token" not in first
            completed = complete_mfa_login(
                MfaLoginCompleteRequest(
                    challenge_token=first["challenge_token"],
                    code=TotpService().code(secret),
                )
            )
            assert completed["mfa_required"] is False
            assert completed["auth_level"] == "mfa"
            assert completed["token"]
            with database.connect() as connection:
                token_hash = __import__("hashlib").sha256(completed["token"].encode()).hexdigest()
                assurance = connection.execute(
                    "SELECT auth_level, mfa_verified_at FROM auth_session_security WHERE token_hash = ?",
                    (token_hash,),
                ).fetchone()
                assert assurance is not None
                assert assurance["auth_level"] == "mfa"
                assert assurance["mfa_verified_at"] is not None

            plain = sign_in(auth_api.SignInRequest(email="plain@example.com", password=password))
            assert plain["mfa_required"] is False
            assert plain["auth_level"] == "password"
            assert plain["token"]
            assert plain["user"]["id"] == plain_user

        print("assured_auth_contract: PASS")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
