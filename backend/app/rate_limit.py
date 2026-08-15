from __future__ import annotations

import time
from dataclasses import dataclass
from datetime import datetime, timezone

from .main import connect


@dataclass(frozen=True)
class RateLimitDecision:
    allowed: bool
    limit: int
    remaining: int
    retry_after: int
    window_started_at: int


class DatabaseRateLimiter:
    """Fixed-window limiter with one atomic upsert shared by all API workers."""

    def consume(
        self,
        bucket_key: str,
        *,
        limit: int,
        window_seconds: int,
        now_epoch: int | None = None,
    ) -> RateLimitDecision:
        if limit < 1 or window_seconds < 1:
            raise ValueError("rate limit and window must be positive")
        now = int(time.time() if now_epoch is None else now_epoch)
        window_start = now - (now % window_seconds)
        updated_at = datetime.now(timezone.utc).isoformat()
        with connect() as connection:
            row = connection.execute(
                """
                INSERT INTO rate_limit_buckets
                  (bucket_key, window_started_at, request_count, updated_at)
                VALUES (?, ?, 1, ?)
                ON CONFLICT(bucket_key) DO UPDATE SET
                  request_count = CASE
                    WHEN rate_limit_buckets.window_started_at = excluded.window_started_at
                    THEN rate_limit_buckets.request_count + 1
                    ELSE 1
                  END,
                  window_started_at = excluded.window_started_at,
                  updated_at = excluded.updated_at
                RETURNING window_started_at, request_count
                """,
                (bucket_key, window_start, updated_at),
            ).fetchone()
            connection.commit()
        count = int(row["request_count"] if row is not None else 1)
        allowed = count <= limit
        retry_after = 0 if allowed else max(1, window_start + window_seconds - now)
        return RateLimitDecision(
            allowed=allowed,
            limit=limit,
            remaining=max(0, limit - count),
            retry_after=retry_after,
            window_started_at=window_start,
        )

    def cleanup(self, *, older_than_epoch: int) -> int:
        with connect() as connection:
            cursor = connection.execute(
                "DELETE FROM rate_limit_buckets WHERE window_started_at < ?",
                (older_than_epoch,),
            )
            connection.commit()
            return max(0, cursor.rowcount)
