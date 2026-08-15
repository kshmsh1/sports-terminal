from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import struct
import time
from dataclasses import dataclass
from urllib.parse import quote

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from .security_tokens import SecurityTokenService


class SecretVault:
    """Authenticated encryption for MFA material stored in the application DB.

    The configured key is treated as high-entropy secret material and expanded to
    an AES-256 key with SHA-256. Ciphertexts are versioned so rotation/migration can
    be introduced without silently changing stored formats.
    """

    VERSION = "v1"

    def __init__(self, key_material: str) -> None:
        if len(key_material) < 32:
            raise ValueError("MFA encryption key must contain at least 32 characters")
        self._key = hashlib.sha256(key_material.encode("utf-8")).digest()
        self._cipher = AESGCM(self._key)

    def encrypt(self, plaintext: str, *, aad: str = "sports-terminal:mfa") -> str:
        nonce = secrets.token_bytes(12)
        ciphertext = self._cipher.encrypt(
            nonce,
            plaintext.encode("utf-8"),
            aad.encode("utf-8"),
        )
        payload = base64.urlsafe_b64encode(nonce + ciphertext).decode("ascii").rstrip("=")
        return f"{self.VERSION}.{payload}"

    def decrypt(self, encoded: str, *, aad: str = "sports-terminal:mfa") -> str:
        version, separator, payload = encoded.partition(".")
        if separator != "." or version != self.VERSION:
            raise ValueError("Unsupported MFA secret ciphertext version")
        padded = payload + "=" * (-len(payload) % 4)
        raw = base64.urlsafe_b64decode(padded.encode("ascii"))
        if len(raw) <= 12:
            raise ValueError("Invalid MFA secret ciphertext")
        plaintext = self._cipher.decrypt(
            raw[:12],
            raw[12:],
            aad.encode("utf-8"),
        )
        return plaintext.decode("utf-8")


class TotpService:
    def __init__(self, *, period_seconds: int = 30, digits: int = 6) -> None:
        if period_seconds < 15:
            raise ValueError("TOTP period is too small")
        if digits not in {6, 7, 8}:
            raise ValueError("TOTP digits must be 6, 7, or 8")
        self.period_seconds = period_seconds
        self.digits = digits

    def generate_secret(self, bytes_of_entropy: int = 20) -> str:
        return base64.b32encode(secrets.token_bytes(bytes_of_entropy)).decode("ascii").rstrip("=")

    def code(self, secret: str, *, timestamp: int | float | None = None) -> str:
        when = int(time.time() if timestamp is None else timestamp)
        counter = when // self.period_seconds
        key = _decode_base32(secret)
        digest = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
        offset = digest[-1] & 0x0F
        binary = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
        return str(binary % (10**self.digits)).zfill(self.digits)

    def verify(
        self,
        secret: str,
        candidate: str,
        *,
        timestamp: int | float | None = None,
        window: int = 1,
    ) -> bool:
        if not candidate.isdigit() or len(candidate) != self.digits:
            return False
        when = int(time.time() if timestamp is None else timestamp)
        for offset in range(-window, window + 1):
            expected = self.code(
                secret,
                timestamp=when + offset * self.period_seconds,
            )
            if hmac.compare_digest(expected, candidate):
                return True
        return False

    def provisioning_uri(self, *, secret: str, account: str, issuer: str = "Sports Terminal") -> str:
        label = quote(f"{issuer}:{account}", safe="")
        return (
            f"otpauth://totp/{label}?secret={quote(secret, safe='')}"
            f"&issuer={quote(issuer, safe='')}&period={self.period_seconds}&digits={self.digits}"
        )


@dataclass(frozen=True)
class RecoveryCodeSet:
    plaintext_codes: tuple[str, ...]
    hashes: tuple[str, ...]


def issue_recovery_codes(token_service: SecurityTokenService, count: int = 10) -> RecoveryCodeSet:
    if count < 5 or count > 20:
        raise ValueError("recovery code count must be between 5 and 20")
    plaintext: list[str] = []
    hashes: list[str] = []
    for _ in range(count):
        raw = secrets.token_hex(4).upper()
        code = f"{raw[:4]}-{raw[4:]}"
        plaintext.append(code)
        hashes.append(token_service.hash(code, "mfa-recovery"))
    return RecoveryCodeSet(tuple(plaintext), tuple(hashes))


def _decode_base32(secret: str) -> bytes:
    normalized = "".join(secret.split()).upper()
    normalized += "=" * (-len(normalized) % 8)
    return base64.b32decode(normalized, casefold=True)
