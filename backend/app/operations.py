from __future__ import annotations

import json
import logging
import os
import threading
import time
from collections import defaultdict, deque
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from fastapi import Request
from fastapi.responses import JSONResponse

from .rate_limit import DatabaseRateLimiter
from .runtime_config import load_runtime_config

logger = logging.getLogger("sports_terminal.api")
if not logger.handlers:
    handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
logger.setLevel(os.getenv("SPORTS_TERMINAL_LOG_LEVEL", "INFO").upper())
logger.propagate = False

_BUCKETS: dict[str, deque[float]] = defaultdict(deque)
_BUCKET_LOCK = threading.Lock()


def _rate_limit_enabled() -> bool:
    return load_runtime_config().rate_limits_enabled


def _rate_limit_backend() -> str:
    explicit = os.getenv("SPORTS_TERMINAL_RATE_LIMIT_BACKEND", "").strip().lower()
    if explicit:
        if explicit not in {"memory", "database"}:
            raise RuntimeError("SPORTS_TERMINAL_RATE_LIMIT_BACKEND must be memory or database")
        return explicit
    return "database" if load_runtime_config().production else "memory"


def _limit_for(path: str) -> tuple[int, int]:
    if path.startswith("/v2/auth/login") or path.startswith("/v2/auth/signup"):
        return int(os.getenv("SPORTS_TERMINAL_AUTH_REQUESTS_PER_MINUTE", "12")), 60
    if path.startswith("/v2/billing/webhooks/"):
        return int(os.getenv("SPORTS_TERMINAL_WEBHOOK_REQUESTS_PER_MINUTE", "120")), 60
    if path.startswith("/v2/nba/"):
        return int(os.getenv("SPORTS_TERMINAL_DATA_REQUESTS_PER_MINUTE", "240")), 60
    return int(os.getenv("SPORTS_TERMINAL_API_REQUESTS_PER_MINUTE", "120")), 60


def _client_key(request: Request) -> str:
    config = load_runtime_config()
    forwarded = ""
    if config.trust_proxy_headers:
        forwarded = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
    host = forwarded or (request.client.host if request.client else "unknown")
    user_id = getattr(request.state, "user_id", "")
    return f"{host}:{user_id}:{request.url.path}"


def _consume_memory(request: Request, limit: int, window: int) -> tuple[bool, int, int]:
    now = time.monotonic()
    key = _client_key(request)
    with _BUCKET_LOCK:
        bucket = _BUCKETS[key]
        cutoff = now - window
        while bucket and bucket[0] <= cutoff:
            bucket.popleft()
        if len(bucket) >= limit:
            retry_after = max(1, int(window - (now - bucket[0])))
            return False, 0, retry_after
        bucket.append(now)
        return True, max(0, limit - len(bucket)), 0


def _consume_rate_limit(request: Request) -> tuple[bool, int, int, int]:
    limit, window = _limit_for(request.url.path)
    if _rate_limit_backend() == "database":
        try:
            decision = DatabaseRateLimiter().consume(
                _client_key(request), limit=limit, window_seconds=window
            )
            return decision.allowed, limit, decision.remaining, decision.retry_after
        except Exception:
            if load_runtime_config().production:
                raise
            logger.exception("database rate limiter unavailable; using development memory fallback")
    allowed, remaining, retry_after = _consume_memory(request, limit, window)
    return allowed, limit, remaining, retry_after


async def launch_operations_middleware(request: Request, call_next: Any):
    request_id = request.headers.get("x-request-id", "").strip() or uuid4().hex
    request.state.request_id = request_id
    started = time.perf_counter()
    rate_limit_headers: dict[str, str] = {}

    if _rate_limit_enabled():
        try:
            allowed, limit, remaining, retry_after = _consume_rate_limit(request)
        except Exception:
            logger.exception(
                json.dumps(
                    {
                        "event": "rate_limit_backend_error",
                        "request_id": request_id,
                        "path": request.url.path,
                        "method": request.method,
                        "recorded_at": datetime.now(timezone.utc).isoformat(),
                    },
                    separators=(",", ":"),
                )
            )
            return JSONResponse(
                status_code=503,
                content={"detail": "Request safety backend unavailable", "request_id": request_id},
                headers={"X-Request-ID": request_id},
            )
        rate_limit_headers = {
            "X-RateLimit-Limit": str(limit),
            "X-RateLimit-Remaining": str(remaining),
        }
        if not allowed:
            logger.warning(
                json.dumps(
                    {
                        "event": "rate_limit",
                        "request_id": request_id,
                        "path": request.url.path,
                        "method": request.method,
                        "limit": limit,
                        "retry_after": retry_after,
                        "recorded_at": datetime.now(timezone.utc).isoformat(),
                    },
                    separators=(",", ":"),
                )
            )
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests", "request_id": request_id},
                headers={
                    "Retry-After": str(retry_after),
                    "X-Request-ID": request_id,
                    **rate_limit_headers,
                },
            )

    try:
        response = await call_next(request)
    except Exception:
        duration_ms = round((time.perf_counter() - started) * 1000, 2)
        logger.exception(
            json.dumps(
                {
                    "event": "request_error",
                    "request_id": request_id,
                    "path": request.url.path,
                    "method": request.method,
                    "duration_ms": duration_ms,
                    "recorded_at": datetime.now(timezone.utc).isoformat(),
                },
                separators=(",", ":"),
            )
        )
        raise

    duration_ms = round((time.perf_counter() - started) * 1000, 2)
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
    response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"
    for key, value in rate_limit_headers.items():
        response.headers[key] = value
    if load_runtime_config().hsts_enabled:
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    logger.info(
        json.dumps(
            {
                "event": "request_complete",
                "request_id": request_id,
                "path": request.url.path,
                "method": request.method,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
                "user_id": getattr(request.state, "user_id", None),
                "recorded_at": datetime.now(timezone.utc).isoformat(),
            },
            separators=(",", ":"),
        )
    )
    return response
