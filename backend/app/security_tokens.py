from __future__ import annotations

import hashlib
import hmac
import secrets
from dataclasses import dataclass


@dataclass(frozen=True)
class IssuedToken:
    plaintext: str
    token_hash: str


class SecurityTokenService:
    def __init__(self, pepper: str) -> None:
        if len(pepper) < 16:
            raise ValueError("security token pepper must contain at least 16 characters")
        self._pepper = pepper.encode("utf-8")

    def issue(self, purpose: str, *, bytes_of_entropy: int = 32) -> IssuedToken:
        plaintext = secrets.token_urlsafe(bytes_of_entropy)
        return IssuedToken(
            plaintext=plaintext,
            token_hash=self.hash(plaintext, purpose),
        )

    def hash(self, plaintext: str, purpose: str) -> str:
        if not plaintext or not purpose:
            raise ValueError("token and purpose are required")
        return hmac.new(
            self._pepper,
            f"{purpose}\x00{plaintext}".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

    def matches(self, plaintext: str, purpose: str, expected_hash: str) -> bool:
        return hmac.compare_digest(self.hash(plaintext, purpose), expected_hash)


class PasswordPolicy:
    def __init__(self, *, minimum_length: int = 12, maximum_length: int = 256) -> None:
        self.minimum_length = minimum_length
        self.maximum_length = maximum_length

    def errors(self, password: str, *, email: str = "", display_name: str = "") -> list[str]:
        errors: list[str] = []
        if len(password) < self.minimum_length:
            errors.append(f"password must contain at least {self.minimum_length} characters")
        if len(password) > self.maximum_length:
            errors.append(f"password must contain at most {self.maximum_length} characters")
        if password and password.lower() == password:
            errors.append("password must contain an uppercase character")
        if password and password.upper() == password:
            errors.append("password must contain a lowercase character")
        if password and not any(character.isdigit() for character in password):
            errors.append("password must contain a number")
        lowered = password.casefold()
        local_part = email.split("@", 1)[0].casefold().strip()
        if len(local_part) >= 4 and local_part in lowered:
            errors.append("password must not contain the email local-part")
        for part in display_name.casefold().split():
            if len(part) >= 4 and part in lowered:
                errors.append("password must not contain the display name")
                break
        return errors

    def validate(self, password: str, *, email: str = "", display_name: str = "") -> None:
        errors = self.errors(password, email=email, display_name=display_name)
        if errors:
            raise ValueError("; ".join(errors))
