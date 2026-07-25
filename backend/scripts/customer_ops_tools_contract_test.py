from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from app import main as main_module
from app import main_launch as _main_launch  # noqa: F401
from app.customer_ops_api import (
    NotificationCreate,
    PrivacyRequestCreate,
    create_customer_notification,
    create_privacy_request,
    init_customer_ops_db,
)
from app.launch_api import _ensure_shadow_user
from app.main import connect


def parse_json_stream(value: str) -> dict[str, object]:
    decoder = json.JSONDecoder()
    index = 0
    documents: list[object] = []
    while index < len(value):
        while index < len(value) and value[index].isspace():
            index += 1
        if index >= len(value):
            break
        document, index = decoder.raw_decode(value, index)
        documents.append(document)
    if not documents or not isinstance(documents[-1], dict):
        raise AssertionError(f"Command did not return a final JSON report:\n{value}")
    return documents[-1]


def run(command: list[str], cwd: Path) -> dict[str, object]:
    completed = subprocess.run(
        command,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise AssertionError(
            f"Command failed ({completed.returncode}): {' '.join(command)}\n"
            f"STDOUT:\n{completed.stdout}\nSTDERR:\n{completed.stderr}"
        )
    return parse_json_stream(completed.stdout)


repo_root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="sports-terminal-customer-tools-") as temp_dir:
    temporary = Path(temp_dir)
    database = temporary / "customer_tools.sqlite"
    main_module.DB_PATH = database
    init_customer_ops_db()
    with connect() as connection:
        _ensure_shadow_user(connection, "tools-user", "Tools User", "analyst")
        connection.commit()

    notification = create_customer_notification(
        NotificationCreate(
            actor_user_id="tools-user",
            user_id="tools-user",
            kind="contract",
            title="Provider outbox contract",
            body="This event validates dry-run provider processing.",
            channel="email",
        )
    )
    assert notification["provider_outbox_id"]
    privacy = create_privacy_request(
        PrivacyRequestCreate(
            actor_user_id="tools-user",
            user_id="tools-user",
            request_type="export",
            details="Validate the controlled account export builder.",
        )
    )

    provider_report = run(
        [
            sys.executable,
            "tools/process_provider_outbox.py",
            "--database",
            str(database),
            "--dry-run",
            "--limit",
            "25",
        ],
        repo_root,
    )
    assert provider_report["status"] == "pass"
    assert int(provider_report["completed"]) >= 1

    backup_report = run(
        [
            sys.executable,
            "tools/backup_and_verify.py",
            "--database",
            str(database),
            "--output-dir",
            str(temporary / "backups"),
            "--record-evidence",
        ],
        repo_root,
    )
    assert backup_report["status"] == "verified"
    assert backup_report["restore_tested"] is True
    assert Path(str(backup_report["backup"])).exists()

    privacy_report = run(
        [
            sys.executable,
            "tools/build_privacy_export.py",
            "--database",
            str(database),
            "--user-id",
            "tools-user",
            "--request-id",
            str(privacy["id"]),
            "--output-dir",
            str(temporary / "privacy"),
        ],
        repo_root,
    )
    assert privacy_report["status"] == "complete"
    export_path = Path(str(privacy_report["export"]))
    assert export_path.exists()
    export = json.loads(export_path.read_text(encoding="utf-8"))
    assert export["user_id"] == "tools-user"
    assert export["security"]["authentication_sessions_included"] is False
    assert export["collection_counts"]["users"] == 1

    with connect() as connection:
        request = connection.execute(
            "SELECT status, export_location FROM privacy_requests WHERE id = ?",
            (privacy["id"],),
        ).fetchone()
        assert request is not None
        assert request["status"] == "completed"
        assert request["export_location"] == str(export_path)
        backup_count = connection.execute(
            "SELECT COUNT(*) FROM backup_runs WHERE restore_tested = 1"
        ).fetchone()[0]
        assert backup_count >= 1

print("Sports Terminal customer operations tools contract test passed.")
