from __future__ import annotations

import os
import tempfile
import traceback
from pathlib import Path


def checkpoint(label: str) -> None:
    print(f"WORKSPACE_COMPLETION_CHECKPOINT: {label}", flush=True)


try:
    with tempfile.TemporaryDirectory(prefix="sports-terminal-workspace-") as temp_dir:
        os.environ["SPORTS_TERMINAL_DB_PATH"] = str(
            Path(temp_dir) / "workspace.sqlite"
        )

        from app import main_launch as _main_launch  # noqa: F401
        from app.workspace_api import (
            WorkspacePermissionUpsert,
            WorkspaceRestore,
            WorkspaceUpsert,
            get_primary_workspace,
            list_workspace_permissions,
            list_workspace_versions,
            restore_primary_workspace,
            upsert_primary_workspace,
            upsert_workspace_permission,
        )

        checkpoint("create multi-sheet workspace")
        first = upsert_primary_workspace(
            WorkspaceUpsert(
                actor_user_id="workspace-owner",
                owner_user_id="workspace-owner",
                title="Front Office Workbook",
                active_sheet="Contracts",
                sheets={
                    "Contracts": {"A1": "Player", "B1": "Salary"},
                    "Draft Assets": {"A1": "Pick", "B1": "Protection"},
                },
                expected_version=0,
            )
        )
        assert first["version"] == 1
        assert len(first["sheets"]) == 2

        checkpoint("optimistic conflict")
        second = upsert_primary_workspace(
            WorkspaceUpsert(
                actor_user_id="workspace-owner",
                owner_user_id="workspace-owner",
                title="Front Office Workbook",
                active_sheet="Contracts",
                sheets={
                    "Contracts": {
                        "A1": "Player",
                        "B1": "Salary",
                        "A2": "Launch Player",
                        "B2": "25000000",
                    },
                    "Draft Assets": {"A1": "Pick", "B1": "Protection"},
                },
                expected_version=1,
            )
        )
        assert second["version"] == 2
        try:
            upsert_primary_workspace(
                WorkspaceUpsert(
                    actor_user_id="stale-editor",
                    owner_user_id="workspace-owner",
                    title="Stale Workbook",
                    active_sheet="Contracts",
                    sheets={"Contracts": {"A1": "stale"}},
                    expected_version=1,
                )
            )
            raise AssertionError("Stale workspace save unexpectedly succeeded")
        except Exception as error:
            assert "conflict" in str(error).lower()

        checkpoint("permission controls")
        permission = upsert_workspace_permission(
            WorkspacePermissionUpsert(
                actor_user_id="workspace-owner",
                owner_user_id="workspace-owner",
                user_id="workspace-editor",
                permission="editor",
            )
        )
        assert permission["permission"] == "editor"
        permissions = list_workspace_permissions(
            owner_user_id="workspace-owner"
        )
        assert permissions[0]["user_id"] == "workspace-editor"

        checkpoint("restore creates new version")
        restored = restore_primary_workspace(
            WorkspaceRestore(
                actor_user_id="workspace-owner",
                owner_user_id="workspace-owner",
                version=1,
                expected_current_version=2,
            )
        )
        assert restored["version"] == 3
        assert restored["sheets"]["Contracts"] == {
            "A1": "Player",
            "B1": "Salary",
        }
        current = get_primary_workspace("workspace-owner")
        assert current["version"] == 3
        versions = list_workspace_versions("workspace-owner")
        assert [item["version"] for item in versions] == [3, 2, 1]
        assert versions[0]["snapshot"]["restore_from_version"] == 1

    print("Sports Terminal workspace completion contract test passed.")
except Exception as error:
    print(
        f"WORKSPACE_COMPLETION_FAILURE: {type(error).__name__}: {error}",
        flush=True,
    )
    traceback.print_exc()
    raise
