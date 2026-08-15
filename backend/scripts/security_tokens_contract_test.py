from __future__ import annotations

from app.security_tokens import PasswordPolicy, SecurityTokenService


def main() -> None:
    service = SecurityTokenService("pepper-" + "x" * 32)
    issued = service.issue("password-reset")
    assert issued.plaintext
    assert len(issued.token_hash) == 64
    assert service.matches(issued.plaintext, "password-reset", issued.token_hash)
    assert not service.matches(issued.plaintext, "email-verification", issued.token_hash)

    policy = PasswordPolicy()
    assert policy.errors("CorrectHorse42Battery", email="person@example.com") == []
    weak = policy.errors("person123", email="person@example.com")
    assert any("at least" in error for error in weak)
    assert any("uppercase" in error for error in weak)
    assert any("email local-part" in error for error in weak)

    try:
        SecurityTokenService("too-short")
    except ValueError:
        pass
    else:
        raise AssertionError("short token peppers must fail closed")

    print("security_tokens_contract: PASS")


if __name__ == "__main__":
    main()
