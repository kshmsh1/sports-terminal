from __future__ import annotations

import os
import tempfile
from pathlib import Path

from app.object_store import FilesystemObjectStore, HttpObjectStore, ObjectStoreError, object_store_from_env


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        store = FilesystemObjectStore(Path(directory))
        payload = b"sports-terminal-backup-bytes"
        result = store.put("backups/2026/test.dump", payload)
        assert result.byte_size == len(payload)
        assert len(result.sha256) == 64
        assert result.backend == "filesystem"
        assert store.exists(result.key) is True
        assert store.get(result.key) == payload
        try:
            store.put("../escape", b"bad")
        except ObjectStoreError:
            pass
        else:
            raise AssertionError("path traversal must be rejected")

    try:
        HttpObjectStore("http://insecure.example", "token")
    except ObjectStoreError as error:
        assert "HTTPS" in str(error)
    else:
        raise AssertionError("object gateway must require HTTPS")

    original = {key: os.environ.get(key) for key in (
        "SPORTS_TERMINAL_ENV",
        "SPORTS_TERMINAL_OBJECT_STORE",
        "SPORTS_TERMINAL_ALLOW_PRODUCTION_FILESYSTEM_OBJECT_STORE",
    )}
    try:
        os.environ["SPORTS_TERMINAL_ENV"] = "production"
        os.environ["SPORTS_TERMINAL_OBJECT_STORE"] = "filesystem"
        os.environ["SPORTS_TERMINAL_ALLOW_PRODUCTION_FILESYSTEM_OBJECT_STORE"] = "false"
        try:
            object_store_from_env()
        except ObjectStoreError as error:
            assert "production filesystem" in str(error)
        else:
            raise AssertionError("production filesystem object store must fail closed")
    finally:
        for key, value in original.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value

    print("object_store_contract: PASS")


if __name__ == "__main__":
    main()
