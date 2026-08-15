from __future__ import annotations

import os
import tempfile
from pathlib import Path

from starlette.requests import Request

from app import database, operations, rate_limit
from app.migrations import run_migrations


def _request(forwarded: str = "203.0.113.10") -> Request:
    return Request(
        {
            "type": "http",
            "method": "GET",
            "path": "/v2/nba/test",
            "headers": [(b"x-forwarded-for", forwarded.encode())],
            "client": ("127.0.0.1", 12345),
            "scheme": "https",
            "server": ("api.example", 443),
            "query_string": b"",
        }
    )


def main() -> None:
    keys = [
        "SPORTS_TERMINAL_DATABASE_URL",
        "SPORTS_TERMINAL_ENV",
        "SPORTS_TERMINAL_TRUST_PROXY_HEADERS",
    ]
    previous = {key: os.environ.get(key) for key in keys}
    try:
        os.environ.pop("SPORTS_TERMINAL_DATABASE_URL", None)
        os.environ["SPORTS_TERMINAL_ENV"] = "development"
        with tempfile.TemporaryDirectory() as directory:
            database.DEFAULT_SQLITE_PATH = Path(directory) / "rate-limit.db"
            rate_limit.connect = database.connect
            with database.connect() as connection:
                connection.execute(
                    "CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT UNIQUE NOT NULL)"
                )
            run_migrations()
            limiter = rate_limit.DatabaseRateLimiter()
            first = limiter.consume("client:/path", limit=2, window_seconds=60, now_epoch=120)
            second = limiter.consume("client:/path", limit=2, window_seconds=60, now_epoch=121)
            third = limiter.consume("client:/path", limit=2, window_seconds=60, now_epoch=122)
            next_window = limiter.consume("client:/path", limit=2, window_seconds=60, now_epoch=180)
            assert first.allowed and first.remaining == 1
            assert second.allowed and second.remaining == 0
            assert not third.allowed and third.retry_after == 58
            assert next_window.allowed and next_window.remaining == 1

        os.environ["SPORTS_TERMINAL_TRUST_PROXY_HEADERS"] = "false"
        assert operations._client_key(_request()).startswith("127.0.0.1:")
        os.environ["SPORTS_TERMINAL_TRUST_PROXY_HEADERS"] = "true"
        assert operations._client_key(_request()).startswith("203.0.113.10:")

        print("rate_limit_contract: PASS")
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


if __name__ == "__main__":
    main()
