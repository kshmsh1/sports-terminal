"""Minimal Language Server Protocol framing without external dependencies."""
from __future__ import annotations
import json
from typing import Any


def encode(message: dict[str, Any]) -> bytes:
    payload = json.dumps(message, separators=(",", ":")).encode("utf-8")
    return f"Content-Length: {len(payload)}\r\n\r\n".encode("ascii") + payload


def extract(buffer: bytearray) -> list[dict[str, Any]]:
    messages = []
    while True:
        boundary = buffer.find(b"\r\n\r\n")
        if boundary < 0:
            if len(buffer) > 8192:
                raise ValueError("LSP header too long")
            return messages
        header = bytes(buffer[:boundary]).decode("ascii", errors="strict")
        length = None
        for line in header.split("\r\n"):
            if line.lower().startswith("content-length:"):
                length = int(line.split(":", 1)[1].strip())
        if length is None or length < 0 or length > 16_000_000:
            raise ValueError("Invalid LSP content length")
        end = boundary + 4 + length
        if len(buffer) < end:
            return messages
        data = json.loads(buffer[boundary + 4:end])
        if not isinstance(data, dict):
            raise ValueError("Invalid LSP payload")
        messages.append(data)
        del buffer[:end]
