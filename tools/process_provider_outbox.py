from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def connect(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    return connection


def adapter_config(provider_type: str) -> tuple[str, str]:
    prefix = f"SPORTS_TERMINAL_{provider_type.upper()}_ADAPTER"
    return os.getenv(f"{prefix}_URL", ""), os.getenv(f"{prefix}_TOKEN", "")


def deliver(row: sqlite3.Row, *, dry_run: bool) -> tuple[bool, str]:
    provider_type = str(row["provider_type"])
    destination = str(row["destination"] or "")
    payload = json.loads(row["payload_json"] or "{}")
    adapter_url, token = adapter_config(provider_type)
    if dry_run:
        print(
            json.dumps(
                {
                    "mode": "dry-run",
                    "id": row["id"],
                    "provider_type": provider_type,
                    "event_type": row["event_type"],
                    "destination": destination,
                    "payload": payload,
                },
                sort_keys=True,
            )
        )
        return True, "dry-run"
    if not adapter_url:
        return False, f"No {provider_type} adapter URL is configured"
    body = json.dumps(
        {
            "event_id": row["id"],
            "event_type": row["event_type"],
            "destination": destination,
            "payload": payload,
        }
    ).encode("utf-8")
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Idempotency-Key": str(row["idempotency_key"]),
        "User-Agent": "Sports-Terminal-Provider-Worker/1.0",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(adapter_url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            if 200 <= response.status < 300:
                return True, f"adapter returned {response.status}"
            return False, f"adapter returned {response.status}"
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")[-2000:]
        return False, f"adapter returned {error.code}: {detail}"
    except Exception as error:
        return False, str(error)


def process(
    database: Path,
    *,
    limit: int,
    provider_type: str,
    dry_run: bool,
) -> dict[str, Any]:
    if not database.exists():
        raise FileNotFoundError(database)
    completed = 0
    failed = 0
    skipped = 0
    with connect(database) as connection:
        table = connection.execute(
            "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'provider_outbox'"
        ).fetchone()
        if table is None:
            raise RuntimeError("provider_outbox table does not exist")
        clauses = ["status IN ('pending', 'failed')", "(next_attempt_at IS NULL OR next_attempt_at <= ?)"]
        values: list[Any] = [now_iso()]
        if provider_type:
            clauses.append("provider_type = ?")
            values.append(provider_type)
        values.append(max(1, min(limit, 1000)))
        rows = connection.execute(
            f"SELECT * FROM provider_outbox WHERE {' AND '.join(clauses)} ORDER BY created_at LIMIT ?",
            tuple(values),
        ).fetchall()
        for row in rows:
            if not dry_run:
                claimed = connection.execute(
                    "UPDATE provider_outbox SET status = 'processing', updated_at = ? WHERE id = ? AND status IN ('pending', 'failed')",
                    (now_iso(), row["id"]),
                ).rowcount
                connection.commit()
                if claimed != 1:
                    skipped += 1
                    continue
            success, detail = deliver(row, dry_run=dry_run)
            attempts = int(row["attempt_count"] or 0) + (0 if dry_run else 1)
            if dry_run:
                completed += 1
                continue
            if success:
                connection.execute(
                    "UPDATE provider_outbox SET status = 'delivered', attempt_count = ?, last_error = '', delivered_at = ?, updated_at = ? WHERE id = ?",
                    (attempts, now_iso(), now_iso(), row["id"]),
                )
                completed += 1
            else:
                delay_minutes = min(24 * 60, 2 ** min(attempts, 10))
                next_attempt = (
                    datetime.now(timezone.utc) + timedelta(minutes=delay_minutes)
                ).isoformat()
                connection.execute(
                    "UPDATE provider_outbox SET status = 'failed', attempt_count = ?, last_error = ?, next_attempt_at = ?, updated_at = ? WHERE id = ?",
                    (attempts, detail[-4000:], next_attempt, now_iso(), row["id"]),
                )
                failed += 1
            connection.commit()
    return {
        "status": "pass" if failed == 0 else "partial_failure",
        "database": str(database),
        "dry_run": dry_run,
        "provider_type": provider_type or "all",
        "completed": completed,
        "failed": failed,
        "skipped": skipped,
        "processed": completed + failed,
        "generated_at": now_iso(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Process Sports Terminal billing, email, SMS and webhook outbox events."
    )
    parser.add_argument(
        "--database",
        default=os.getenv("SPORTS_TERMINAL_DB_PATH", "backend/.data/sports_terminal.db"),
    )
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--provider", choices=["", "billing", "email", "sms", "webhook"], default="")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--report", default="")
    args = parser.parse_args()
    try:
        report = process(
            Path(args.database),
            limit=args.limit,
            provider_type=args.provider,
            dry_run=args.dry_run,
        )
    except Exception as error:
        report = {
            "status": "fail",
            "error": str(error),
            "generated_at": now_iso(),
        }
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    print(rendered, end="")
    if args.report:
        path = Path(args.report)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(rendered, encoding="utf-8")
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())
