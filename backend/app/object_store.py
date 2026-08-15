from __future__ import annotations

import hashlib
import os
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ObjectPutResult:
    key: str
    byte_size: int
    sha256: str
    backend: str


class ObjectStoreError(RuntimeError):
    pass


class FilesystemObjectStore:
    def __init__(self, root: Path) -> None:
        self.root = root.resolve()
        self.root.mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        clean = key.strip().lstrip("/")
        if not clean or ".." in Path(clean).parts:
            raise ObjectStoreError("invalid object key")
        candidate = (self.root / clean).resolve()
        try:
            candidate.relative_to(self.root)
        except ValueError as error:
            raise ObjectStoreError("object key escapes storage root") from error
        return candidate

    def put(self, key: str, data: bytes) -> ObjectPutResult:
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        digest = hashlib.sha256(data).hexdigest()
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as handle:
            handle.write(data)
            temporary = Path(handle.name)
        os.replace(temporary, path)
        return ObjectPutResult(key, len(data), digest, "filesystem")

    def get(self, key: str) -> bytes:
        path = self._path(key)
        if not path.exists() or not path.is_file():
            raise ObjectStoreError("object not found")
        return path.read_bytes()

    def exists(self, key: str) -> bool:
        try:
            return self._path(key).is_file()
        except ObjectStoreError:
            return False


class HttpObjectStore:
    """Minimal gateway contract for operator-owned object storage.

    Sports Terminal does not assume AWS, GCP, Azure, or another vendor. The configured
    HTTPS gateway owns provider authentication/storage semantics; this client supplies
    content SHA-256, byte length, bearer auth, and an idempotent object key.
    """

    def __init__(self, endpoint: str, token: str) -> None:
        endpoint = endpoint.rstrip("/")
        if not endpoint.startswith("https://"):
            raise ObjectStoreError("production object gateway must use HTTPS")
        self.endpoint = endpoint
        self.token = token

    def _url(self, key: str) -> str:
        clean = key.strip().lstrip("/")
        if not clean or ".." in Path(clean).parts:
            raise ObjectStoreError("invalid object key")
        return f"{self.endpoint}/{urllib.parse.quote(clean, safe='/')}"

    def put(self, key: str, data: bytes) -> ObjectPutResult:
        digest = hashlib.sha256(data).hexdigest()
        request = urllib.request.Request(
            self._url(key),
            data=data,
            method="PUT",
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/octet-stream",
                "Content-Length": str(len(data)),
                "X-Content-SHA256": digest,
                "Idempotency-Key": digest,
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:  # noqa: S310
                if int(response.status) < 200 or int(response.status) >= 300:
                    raise ObjectStoreError(f"object gateway returned HTTP {response.status}")
        except (urllib.error.URLError, TimeoutError) as error:
            raise ObjectStoreError("object gateway PUT failed") from error
        return ObjectPutResult(key, len(data), digest, "http")

    def get(self, key: str) -> bytes:
        request = urllib.request.Request(
            self._url(key),
            method="GET",
            headers={"Authorization": f"Bearer {self.token}"},
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:  # noqa: S310
                return response.read()
        except (urllib.error.URLError, TimeoutError) as error:
            raise ObjectStoreError("object gateway GET failed") from error

    def exists(self, key: str) -> bool:
        try:
            self.get(key)
            return True
        except ObjectStoreError:
            return False


def object_store_from_env():
    environment = os.getenv("SPORTS_TERMINAL_ENV", "development").strip().lower()
    backend = os.getenv(
        "SPORTS_TERMINAL_OBJECT_STORE",
        "filesystem" if environment != "production" else "disabled",
    ).strip().lower()
    if backend == "filesystem":
        if environment == "production" and os.getenv(
            "SPORTS_TERMINAL_ALLOW_PRODUCTION_FILESYSTEM_OBJECT_STORE", "false"
        ).lower() != "true":
            raise ObjectStoreError("production filesystem object storage is disabled")
        root = Path(os.getenv("SPORTS_TERMINAL_OBJECT_STORE_PATH", ".data/objects"))
        return FilesystemObjectStore(root)
    if backend == "http":
        return HttpObjectStore(
            os.getenv("SPORTS_TERMINAL_OBJECT_STORE_ENDPOINT", ""),
            os.getenv("SPORTS_TERMINAL_OBJECT_STORE_TOKEN", ""),
        )
    raise ObjectStoreError("object storage is disabled or unsupported")
