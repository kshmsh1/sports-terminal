from __future__ import annotations

import os
import tempfile
import time
from pathlib import Path

from app import database
from app.auth_api import init_auth_db
from app.main import make_id, now_iso
from app.mfa import SecretVault, TotpService, issue_recovery_codes
from app.mfa_login import MfaLoginService
from app.migrations import run_migrations
from app.security_tokens import SecurityTokenService


def main() -> None:
    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_SESSION_PEPPER",
        "SPORTS_TERMINAL_MFA_ENCRYPTION_KEY",
    )}
    pepper = "m" * 40
    vault_key = "k" * 40
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_SESSION_PEPPER"] = pepper
        os.environ["SPORTS_TERMINAL_MFA_ENCRYPTION_KEY"] = vault_key
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "mfa-login.db"
            init_auth_db()
            run_migrations()
            user_id = make_id("usr")
            factor_id = make_id("mfa")
            timestamp = now_iso()
            totp = TotpService()
            secret = totp.generate_secret()
            encrypted = SecretVault(vault_key).encrypt(
                secret, aad=f"user:{user_id}:factor:{factor_id}"
            )
            with database.connect() as connection:
                connection.execute(
                    "INSERT INTO users (id, email, display_name, role, status, created_at, updated_at) VALUES (?, 'mfa@example.com', 'MFA User', 'analyst', 'active', ?, ?)",
                    (user_id, timestamp, timestamp),
                )
                connection.execute(
                    "INSERT INTO auth_mfa_factors (id, user_id, factor_type, secret_ciphertext, label, verified_at, created_at, updated_at) VALUES (?, ?, 'totp', ?, 'Authenticator', ?, ?, ?)",
                    (factor_id, user_id, encrypted, timestamp, timestamp, timestamp),
                )
                recovery = issue_recovery_codes(SecurityTokenService(pepper), count=5)
                for code_hash in recovery.hashes:
                    connection.execute(
                        "INSERT INTO auth_recovery_codes (code_hash, user_id, created_at) VALUES (?, ?, ?)",
                        (code_hash, user_id, timestamp),
                    )
                service = MfaLoginService()
                assert service.has_verified_factor(connection, user_id) is True
                first = service.begin(connection, user_id)
                assert service.complete(
                    connection,
                    challenge_token=first.plaintext,
                    code=totp.code(secret, timestamp=time.time()),
                ) == user_id
                assert service.complete(
                    connection, challenge_token=first.plaintext, code=totp.code(secret)
                ) is None

                second = service.begin(connection, user_id)
                recovery_code = recovery.plaintext_codes[0]
                assert service.complete(
                    connection, challenge_token=second.plaintext, code=recovery_code
                ) == user_id
                consumed = connection.execute(
                    "SELECT consumed_at FROM auth_recovery_codes WHERE code_hash = ?",
                    (SecurityTokenService(pepper).hash(recovery_code, "mfa-recovery"),),
                ).fetchone()
                assert consumed is not None and consumed["consumed_at"] is not None

            print("mfa_login_contract: PASS")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
