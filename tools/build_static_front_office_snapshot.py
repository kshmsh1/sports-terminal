from __future__ import annotations

import argparse
import json
import os
import sqlite3
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "backend/.data/sports_terminal.db"
DEFAULT_OUTPUT = ROOT / "web/data/nba_static/front_office"

RECORD_FILES = {
    "contract": "contracts.json",
    "team_position": "team_positions.json",
    "draft_asset": "draft_assets.json",
    "ledger": "ledger.json",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Publish the last persisted front-office registry as static website JSON."
    )
    parser.add_argument(
        "--database",
        default=os.getenv("SPORTS_TERMINAL_DB_PATH", str(DEFAULT_DB)),
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    return parser.parse_args()


def decode(value: str | None, fallback: Any) -> Any:
    if not value:
        return fallback
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return fallback


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str),
        encoding="utf-8",
    )
    temp.replace(path)


def empty_snapshot(output: Path, *, database_exists: bool) -> dict[str, Any]:
    for filename in RECORD_FILES.values():
        write_json(output / filename, [])
    manifest = {
        "contract": "sports-terminal-static-front-office-v1",
        "database_exists": database_exists,
        "registry_table_exists": False,
        "counts": {record_type: 0 for record_type in RECORD_FILES},
        "runtime_api_required_for_snapshot": False,
        "mutable_overlay_supported": True,
    }
    write_json(output / "manifest.json", manifest)
    return manifest


def serialize(row: sqlite3.Row) -> dict[str, Any]:
    payload = decode(row["payload_json"], {})
    if not isinstance(payload, dict):
        payload = {}
    payload["id"] = row["id"]
    validation = decode(row["validation_json"], {})
    if not isinstance(validation, dict):
        validation = {}
    return {
        "id": row["id"],
        "record_type": row["record_type"],
        "season": row["season"],
        "team_id": row["team_id"] or "",
        "player_id": row["player_id"] or "",
        "organization_id": row["organization_id"] or "",
        "source_status": row["source_status"],
        "record_status": row["record_status"],
        "record": payload,
        "validation": validation,
        "version": row["version"],
        "created_by_user_id": row["created_by_user_id"],
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
        "snapshot_transport": "static",
    }


def main() -> int:
    args = parse_args()
    database = Path(args.database).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)

    if not database.is_file():
        manifest = empty_snapshot(output, database_exists=False)
        print(json.dumps(manifest, indent=2))
        return 0

    with sqlite3.connect(str(database)) as db:
        db.row_factory = sqlite3.Row
        exists = db.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='front_office_records'"
        ).fetchone()
        if exists is None:
            manifest = empty_snapshot(output, database_exists=True)
            print(json.dumps(manifest, indent=2))
            return 0

        grouped: dict[str, list[dict[str, Any]]] = {
            record_type: [] for record_type in RECORD_FILES
        }
        for row in db.execute(
            """
            SELECT * FROM front_office_records
            WHERE record_status='active'
            ORDER BY record_type,season DESC,updated_at DESC,id
            """
        ):
            record_type = str(row["record_type"])
            if record_type in grouped:
                grouped[record_type].append(serialize(row))

    for record_type, filename in RECORD_FILES.items():
        write_json(output / filename, grouped[record_type])

    manifest = {
        "contract": "sports-terminal-static-front-office-v1",
        "database_exists": True,
        "registry_table_exists": True,
        "counts": {key: len(value) for key, value in grouped.items()},
        "runtime_api_required_for_snapshot": False,
        "mutable_overlay_supported": True,
    }
    write_json(output / "manifest.json", manifest)
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
