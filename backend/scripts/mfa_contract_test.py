from __future__ import annotations

from app.mfa import SecretVault, TotpService, issue_recovery_codes
from app.security_tokens import SecurityTokenService


def main() -> None:
    vault = SecretVault("mfa-key-" + "x" * 40)
    encrypted = vault.encrypt("JBSWY3DPEHPK3PXP", aad="user:u1")
    assert encrypted.startswith("v1.")
    assert "JBSWY3DPEHPK3PXP" not in encrypted
    assert vault.decrypt(encrypted, aad="user:u1") == "JBSWY3DPEHPK3PXP"

    totp = TotpService()
    secret = "JBSWY3DPEHPK3PXP"
    code = totp.code(secret, timestamp=1_700_000_000)
    assert len(code) == 6
    assert totp.verify(secret, code, timestamp=1_700_000_000)
    assert not totp.verify(secret, "000000", timestamp=1_700_000_000)
    uri = totp.provisioning_uri(secret=secret, account="person@example.com")
    assert uri.startswith("otpauth://totp/")
    assert "secret=JBSWY3DPEHPK3PXP" in uri

    token_service = SecurityTokenService("pepper-" + "z" * 32)
    recovery = issue_recovery_codes(token_service)
    assert len(recovery.plaintext_codes) == 10
    assert len(recovery.hashes) == 10
    assert len(set(recovery.hashes)) == 10
    assert token_service.matches(
        recovery.plaintext_codes[0],
        "mfa-recovery",
        recovery.hashes[0],
    )

    print("mfa_contract: PASS")


if __name__ == "__main__":
    main()
