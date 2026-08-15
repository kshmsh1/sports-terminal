from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from .database import DatabaseConnection
from .mfa import SecretVault, TotpService
from .runtime_config import load_runtime_config
from .security_tokens import SecurityTokenService
from .main import make_id, now_iso


@dataclass(frozen=True)
class MfaLoginChallenge:
    id: str
    plaintext: str
    expires_at: str


class MfaLoginService:
    PURPOSE = "mfa-login-challenge"

    def __init__(self) -> None:
        config = load_runtime_config()
        pepper = config.session_pepper or "development-only-security-pepper-32chars"
        key = config.mfa_encryption_key or "development-only-mfa-key-material-32chars"
        self.tokens = SecurityTokenService(pepper)
        self.vault = SecretVault(key)
        self.totp = TotpService()

    def has_verified_factor(self, connection: DatabaseConnection, user_id: str) -> bool:
        row = connection.execute(
            """
            SELECT 1 FROM auth_mfa_factors
            WHERE user_id = ? AND verified_at IS NOT NULL AND disabled_at IS NULL
            LIMIT 1
            """,
            (user_id,),
        ).fetchone()
        return row is not None

    def begin(self, connection: DatabaseConnection, user_id: str, *, ttl_minutes: int = 5) -> MfaLoginChallenge:
        issued = self.tokens.issue(self.PURPOSE)
        challenge_id = make_id("mfach")
        created = datetime.now(timezone.utc)
        expires = created + timedelta(minutes=max(2, min(ttl_minutes, 10)))
        connection.execute(
            "UPDATE auth_login_challenges SET status = 'superseded' "
            "WHERE user_id = ? AND status = 'pending'",
            (user_id,),
        )
        connection.execute(
            """
            INSERT INTO auth_login_challenges (
              id, user_id, challenge_hash, factor_type, status, attempts,
              expires_at, created_at
            ) VALUES (?, ?, ?, 'totp-or-recovery', 'pending', 0, ?, ?)
            """,
            (challenge_id, user_id, issued.token_hash, expires.isoformat(), created.isoformat()),
        )
        return MfaLoginChallenge(challenge_id, issued.plaintext, expires.isoformat())

    def complete(
        self,
        connection: DatabaseConnection,
        *,
        challenge_token: str,
        code: str,
        max_attempts: int = 8,
    ) -> str | None:
        challenge_hash = self.tokens.hash(challenge_token, self.PURPOSE)
        row = connection.execute(
            "SELECT * FROM auth_login_challenges WHERE challenge_hash = ?",
            (challenge_hash,),
        ).fetchone()
        if row is None or row["status"] != "pending":
            return None
        now = datetime.now(timezone.utc)
        if datetime.fromisoformat(str(row["expires_at"])) <= now:
            connection.execute(
                "UPDATE auth_login_challenges SET status = 'expired' WHERE id = ?",
                (row["id"],),
            )
            return None

        attempts = int(row["attempts"]) + 1
        verified = self._verify_factor(connection, str(row["user_id"]), code)
        if not verified:
            status = "locked" if attempts >= max_attempts else "pending"
            connection.execute(
                "UPDATE auth_login_challenges SET attempts = ?, status = ? WHERE id = ?",
                (attempts, status, row["id"]),
            )
            return None

        connection.execute(
            """
            UPDATE auth_login_challenges
            SET status = 'consumed', attempts = ?, completed_at = ?
            WHERE id = ? AND status = 'pending'
            """,
            (attempts, now_iso(), row["id"]),
        )
        return str(row["user_id"])

    def _verify_factor(self, connection: DatabaseConnection, user_id: str, code: str) -> bool:
        factors = connection.execute(
            """
            SELECT id, secret_ciphertext FROM auth_mfa_factors
            WHERE user_id = ? AND factor_type = 'totp'
              AND verified_at IS NOT NULL AND disabled_at IS NULL
            ORDER BY verified_at DESC
            """,
            (user_id,),
        ).fetchall()
        for factor in factors:
            secret = self.vault.decrypt(
                str(factor["secret_ciphertext"]),
                aad=f"user:{user_id}:factor:{factor['id']}",
            )
            if self.totp.verify(secret, code.strip()):
                return True

        recovery_hash = self.tokens.hash(code.strip().upper(), "mfa-recovery")
        recovery = connection.execute(
            "SELECT code_hash FROM auth_recovery_codes WHERE user_id = ? AND code_hash = ? AND consumed_at IS NULL",
            (user_id, recovery_hash),
        ).fetchone()
        if recovery is None:
            return False
        connection.execute(
            "UPDATE auth_recovery_codes SET consumed_at = ? WHERE code_hash = ? AND consumed_at IS NULL",
            (now_iso(), recovery_hash),
        )
        return True
