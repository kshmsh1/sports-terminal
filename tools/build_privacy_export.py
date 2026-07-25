from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def connect(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    return connection


def redact(value: Any, key: str = "") -> Any:
    sensitive = ("password", "secret", "token", "authorization", "credential")
    if any(part in key.lower() for part in sensitive):
        return "[REDACTED]"
    if isinstance(value, dict):
        return {str(k): redact(v, str(k)) for k, v in value.items()}
    if isinstance(value, list):
        return [redact(item) for item in value]
    return value


def decode_json_columns(item: dict[str, Any]) -> dict[str, Any]:
    output = dict(item)
    for key, value in list(output.items()):
        if not key.endswith("_json") or not isinstance(value, str):
            continue
        try:
            output[key.removesuffix("_json")] = json.loads(value)
            del output[key]
        except json.JSONDecodeError:
            continue
    return redact(output)


def table_columns(connection: sqlite3.Connection, table: str) -> set[str]:
    return {
        str(row["name"])
        for row in connection.execute(f"PRAGMA table_info({table})").fetchall()
    }


def table_exists(connection: sqlite3.Connection, table: str) -> bool:
    return connection.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        (table,),
    ).fetchone() is not None


def rows_for_user(
    connection: sqlite3.Connection,
    table: str,
    user_id: str,
) -> list[dict[str, Any]]:
    if not table_exists(connection, table):
        return []
    columns = table_columns(connection, table)
    direct_columns = [
        column
        for column in (
            "id" if table == "users" else "",
            "user_id",
            "owner_user_id",
            "requester_user_id",
            "author_user_id",
            "sender_user_id",
            "actor_user_id",
            "created_by_user_id",
            "invited_by_user_id",
            "accepting_user_id",
        )
        if column and column in columns
    ]
    if not direct_columns:
        return []
    where = " OR ".join(f"{column} = ?" for column in direct_columns)
    values = tuple(user_id for _ in direct_columns)
    return [
        decode_json_columns(dict(row))
        for row in connection.execute(
            f"SELECT * FROM {table} WHERE {where}",
            values,
        ).fetchall()
    ]


def child_rows(
    connection: sqlite3.Connection,
    table: str,
    foreign_key: str,
    ids: list[str],
) -> list[dict[str, Any]]:
    if not ids or not table_exists(connection, table):
        return []
    placeholders = ",".join("?" for _ in ids)
    return [
        decode_json_columns(dict(row))
        for row in connection.execute(
            f"SELECT * FROM {table} WHERE {foreign_key} IN ({placeholders})",
            tuple(ids),
        ).fetchall()
    ]


def scoped_rows(
    connection: sqlite3.Connection,
    table: str,
    scope_key: str,
) -> list[dict[str, Any]]:
    if not table_exists(connection, table):
        return []
    columns = table_columns(connection, table)
    if "scope_key" not in columns:
        return []
    return [
        decode_json_columns(dict(row))
        for row in connection.execute(
            f"SELECT * FROM {table} WHERE scope_key = ?",
            (scope_key,),
        ).fetchall()
    ]


def build_export(database: Path, user_id: str) -> dict[str, Any]:
    if not database.exists():
        raise FileNotFoundError(database)
    with connect(database) as connection:
        if not table_exists(connection, "users"):
            raise RuntimeError("users table does not exist")
        user = connection.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        if user is None:
            raise RuntimeError(f"User not found: {user_id}")

        direct_tables = (
            "users",
            "user_profiles",
            "user_settings",
            "favorite_teams",
            "favorite_players",
            "player_watchlists",
            "organization_memberships",
            "organization_member_records",
            "customer_subscriptions",
            "onboarding_states",
            "support_tickets",
            "privacy_requests",
            "customer_notifications",
            "saved_sports_objects",
            "transaction_case_snapshots",
            "transaction_workflow_activities",
            "transaction_workflow_notifications",
            "posts",
            "comments",
            "reactions",
            "reports",
            "conversation_members",
            "messages",
            "articles",
            "subscriptions",
            "customer_ops_audit_events",
        )
        collections: dict[str, list[dict[str, Any]]] = {
            table: rows_for_user(connection, table, user_id)
            for table in direct_tables
        }

        personal_scope = f"personal:{user_id}"
        for table in ("workspace_snapshots", "workspace_versions", "support_tickets"):
            existing = collections.setdefault(table, [])
            seen = {str(item.get("id") or item.get("scope_key") or "") for item in existing}
            for item in scoped_rows(connection, table, personal_scope):
                identifier = str(item.get("id") or item.get("scope_key") or "")
                if identifier not in seen:
                    existing.append(item)
                    seen.add(identifier)

        ticket_ids = [
            str(item["id"])
            for item in collections.get("support_tickets", [])
            if item.get("id")
        ]
        privacy_ids = [
            str(item["id"])
            for item in collections.get("privacy_requests", [])
            if item.get("id")
        ]
        post_ids = [
            str(item["id"])
            for item in collections.get("posts", [])
            if item.get("id")
        ]
        conversation_ids = [
            str(item["conversation_id"])
            for item in collections.get("conversation_members", [])
            if item.get("conversation_id")
        ]
        collections["support_ticket_events"] = child_rows(
            connection,
            "support_ticket_events",
            "ticket_id",
            ticket_ids,
        )
        collections["privacy_request_events"] = child_rows(
            connection,
            "privacy_request_events",
            "request_id",
            privacy_ids,
        )
        authored_comments = child_rows(connection, "comments", "post_id", post_ids)
        existing_comment_ids = {
            str(item.get("id") or "") for item in collections.get("comments", [])
        }
        collections["comments"].extend(
            item
            for item in authored_comments
            if str(item.get("id") or "") not in existing_comment_ids
        )
        conversation_messages = child_rows(
            connection,
            "messages",
            "conversation_id",
            conversation_ids,
        )
        existing_message_ids = {
            str(item.get("id") or "") for item in collections.get("messages", [])
        }
        collections["messages"].extend(
            item
            for item in conversation_messages
            if str(item.get("id") or "") not in existing_message_ids
        )
        if conversation_ids and table_exists(connection, "conversations"):
            placeholders = ",".join("?" for _ in conversation_ids)
            collections["conversations"] = [
                decode_json_columns(dict(row))
                for row in connection.execute(
                    f"SELECT * FROM conversations WHERE id IN ({placeholders})",
                    tuple(conversation_ids),
                ).fetchall()
            ]

        collections = {
            key: value
            for key, value in collections.items()
            if value
        }
        return {
            "schema_version": 1,
            "product": "Sports Terminal",
            "user_id": user_id,
            "generated_at": now_iso(),
            "scope": "all first-party account records linked to the requesting user",
            "security": {
                "authentication_sessions_included": False,
                "passwords_included": False,
                "provider_credentials_included": False,
                "sensitive_fields_redacted": True,
            },
            "collection_counts": {
                key: len(value) for key, value in collections.items()
            },
            "collections": collections,
        }


def complete_request(
    database: Path,
    request_id: str,
    export_location: str,
    checksum: str,
) -> None:
    if not request_id:
        return
    with connect(database) as connection:
        if not table_exists(connection, "privacy_requests"):
            raise RuntimeError("privacy_requests table does not exist")
        request = connection.execute(
            "SELECT * FROM privacy_requests WHERE id = ?",
            (request_id,),
        ).fetchone()
        if request is None:
            raise RuntimeError(f"Privacy request not found: {request_id}")
        timestamp = now_iso()
        connection.execute(
            "UPDATE privacy_requests SET status = 'completed', verification_status = 'verified', export_location = ?, updated_at = ?, completed_at = ? WHERE id = ?",
            (export_location, timestamp, timestamp, request_id),
        )
        if table_exists(connection, "privacy_request_events"):
            event_id = f"privacy_export_{hashlib.sha256((request_id + timestamp).encode()).hexdigest()[:12]}"
            connection.execute(
                "INSERT INTO privacy_request_events (id, request_id, actor_user_id, action, note, metadata_json, created_at) VALUES (?, ?, 'system', 'complete', 'Privacy export generated by the controlled export builder.', ?, ?)",
                (
                    event_id,
                    request_id,
                    json.dumps({"export_location": export_location, "sha256": checksum}),
                    timestamp,
                ),
            )
        connection.commit()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build a redacted Sports Terminal first-party account data export."
    )
    parser.add_argument("--user-id", required=True)
    parser.add_argument(
        "--database",
        default=os.getenv("SPORTS_TERMINAL_DB_PATH", "backend/.data/sports_terminal.db"),
    )
    parser.add_argument("--output-dir", default="data/privacy_exports")
    parser.add_argument("--request-id", default="")
    args = parser.parse_args()

    database = Path(args.database)
    output_dir = Path(args.output_dir) / args.user_id
    output_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    output_path = output_dir / f"sports_terminal_export_{timestamp}.json"
    manifest_path = output_dir / f"sports_terminal_export_{timestamp}.manifest.json"
    try:
        export = build_export(database, args.user_id)
        rendered = json.dumps(export, indent=2, sort_keys=True) + "\n"
        output_path.write_text(rendered, encoding="utf-8")
        checksum = hashlib.sha256(rendered.encode("utf-8")).hexdigest()
        manifest = {
            "status": "complete",
            "user_id": args.user_id,
            "export": str(output_path),
            "sha256": checksum,
            "bytes": output_path.stat().st_size,
            "collection_counts": export["collection_counts"],
            "generated_at": export["generated_at"],
        }
        manifest_path.write_text(
            json.dumps(manifest, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        complete_request(database, args.request_id, str(output_path), checksum)
        print(json.dumps(manifest, indent=2, sort_keys=True))
        return 0
    except Exception as error:
        print(
            json.dumps(
                {"status": "fail", "error": str(error), "generated_at": now_iso()},
                indent=2,
            ),
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    sys.exit(main())
