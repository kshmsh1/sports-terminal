"""Hard prerequisites for granting a browser local-code execution authority."""
from __future__ import annotations

import hmac
import re
import secrets
from pathlib import Path

from fastapi import HTTPException, Request, WebSocket


class Security:
    def __init__(self, root: Path, origin: list[str], token: str | None = None) -> None:
        self.root = root.expanduser().resolve(strict=True)
        if not self.root.is_dir():
            raise ValueError("Workspace must be an existing directory")
        self.token = token or secrets.token_urlsafe(32)
        self.origins = frozenset(origin)
        if not self.origins or "*" in self.origins or "null" in self.origins:
            raise ValueError("Configure explicit trusted web Origins (never wildcard)")
        for entry in self.origins:
            if not re.fullmatch(r"https?://[a-zA-Z0-9.:-]+", entry):
                raise ValueError(f"Invalid Origin: {entry!r}")

    def file(self, name: str, *, allow_root: bool = False) -> Path:
        if not isinstance(name, str) or not name or len(name) > 240:
            raise HTTPException(400, "Invalid workspace path")
        if name.startswith(("/", "\\")) or "\\" in name or "\x00" in name:
            raise HTTPException(400, "Absolute, backslash or NUL paths are prohibited")
        parts = name.split("/")
        if any(part in ("", ".", "..") for part in parts):
            raise HTTPException(400, "Invalid relative path")
        resolved = (self.root / name).resolve()
        try:
            resolved.relative_to(self.root)
        except ValueError:
            raise HTTPException(403, "Path escapes configured workspace") from None
        if resolved == self.root and not allow_root:
            raise HTTPException(400, "File path must not be workspace root")
        return resolved

    def authorized(self, token: str | None) -> bool:
        return isinstance(token, str) and hmac.compare_digest(self.token, token)

    def check_origin(self, origin: str | None) -> bool:
        # Browser callers always supply Origin. Non-browser automation still
        # requires the 256-bit token; omission doesn't bypass authentication.
        return origin is None or origin in self.origins

    def check_http(self, request: Request) -> None:
        if not self.check_origin(request.headers.get("origin")):
            raise HTTPException(403, "Untrusted Origin")
        host = request.headers.get("host", "")
        if not re.fullmatch(r"(?:127\.0\.0\.1|localhost):\d{1,5}", host):
            raise HTTPException(403, "Only loopback Host accepted")
        header = request.headers.get("authorization", "")
        if not header.startswith("Bearer ") or not self.authorized(header[7:]):
            raise HTTPException(401, "Invalid runtime token")

    async def check_ws(self, ws: WebSocket) -> bool:
        origin = ws.headers.get("origin")
        if not self.check_origin(origin):
            await ws.close(code=1008, reason="Untrusted Origin")
            return False
        host = ws.headers.get("host", "")
        if not re.fullmatch(r"(?:127\.0\.0\.1|localhost):\d{1,5}", host):
            await ws.close(code=1008, reason="Loopback-only Host")
            return False
        await ws.accept()
        try:
            # First-message auth avoids tokens in WS URLs and access logs.
            envelope = await __import__("asyncio").wait_for(ws.receive_json(), 6)
            if envelope.get("type") != "authenticate" or not self.authorized(envelope.get("token")):
                await ws.close(code=1008, reason="Invalid runtime token")
                return False
        except Exception:
            await ws.close(code=1008, reason="Authentication required")
            return False
        await ws.send_json({"type": "authenticated"})
        return True
