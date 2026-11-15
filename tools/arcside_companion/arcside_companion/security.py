"""Path and browser-origin defenses for the explicitly trusted local IDE.

IMPORTANT: protecting the HTTP boundary does not sandbox a user's local
Python script or shell. Only run code/projects that you personally trust.
"""
from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
import hmac
import secrets

MAX_FILE = 2_000_000
MAX_PROJECT = 12_000_000
MAX_FILES = 256
PROTECTED = {".git", ".venv", ".conda", ".arcside", "__pycache__", "node_modules"}


@dataclass(frozen=True)
class Settings:
    workspace: Path
    token: str
    origins: tuple[str, ...]
    host: str = "127.0.0.1"
    port: int = 8766

    @classmethod
    def make(cls, workspace: str | Path, origins: list[str] | None = None,
             token: str | None = None, port: int = 8766):
        root = Path(workspace).expanduser().resolve(strict=True)
        if not root.is_dir():
            raise ValueError("Workspace must be an existing directory")
        if port < 1 or port > 65535:
            raise ValueError("Port out of range")
        return cls(workspace=root, token=token or secrets.token_urlsafe(32),
                   origins=tuple(origins or ["http://127.0.0.1:8765",
                                             "http://localhost:8765"]), port=port)

    def authorized(self, supplied: str | None) -> bool:
        return bool(supplied) and hmac.compare_digest(self.token, supplied)

    def origin_allowed(self, supplied: str | None) -> bool:
        # CLI tools do not send Origin; they still must supply the bearer token.
        return not supplied or supplied in self.origins

    def path(self, name: str, *, protect: bool = True) -> Path:
        if not isinstance(name, str) or not name or len(name) > 240:
            raise ValueError("Invalid relative path")
        if "\\" in name or "\x00" in name:
            raise ValueError("Path must use POSIX separators")
        pure = PurePosixPath(name)
        if pure.is_absolute() or not pure.parts or any(p in ("..", ".") for p in pure.parts):
            raise ValueError("Path escapes the workspace")
        if protect and any(part in PROTECTED for part in pure.parts):
            raise ValueError("Cannot modify protected workspace directories")
        candidate = self.workspace.joinpath(*pure.parts)
        root = self.workspace.resolve()
        if not candidate.resolve(strict=False).is_relative_to(root):
            raise ValueError("Symlink escapes the workspace")
        if candidate.is_symlink():
            raise ValueError("Cannot write to a symlink")
        return candidate

    def relative(self, path: Path) -> str:
        return path.resolve().relative_to(self.workspace).as_posix()
