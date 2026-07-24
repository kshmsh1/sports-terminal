from __future__ import annotations

import os
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="sports-terminal-launch-") as temp_dir:
    os.environ["SPORTS_TERMINAL_DB_PATH"] = str(Path(temp_dir) / "launch_test.sqlite")

    from app.launch_api import (
        CaseUpsert,
        DataReleaseUpsert,
        OrganizationCreate,
        PayloadUpsert,
        create_organization,
        current_data_release,
        init_launch_db,
        launch_readiness_v2,
        list_activities,
        list_member_records,
        list_notifications,
        list_transaction_cases,
        upsert_activity,
        upsert_data_release,
        upsert_member_record,
        upsert_notification,
        upsert_transaction_case,
    )
    from app.main import init_db

    init_db()
    init_launch_db()

    organization = create_organization(
        OrganizationCreate(
            id="org-test",
            name="Test Basketball Operations",
            created_by_user_id="admin-test",
            created_by_name="Test Admin",
        )
    )
    assert organization["id"] == "org-test"
    assert organization["member_count"] == 1

    case_payload = {
        "id": "case-test",
        "title": "Test trade review",
        "organizationId": "org-test",
        "organizationName": "Test Basketball Operations",
        "ownerUserId": "analyst-test",
        "ownerName": "Test Analyst",
        "operatingSeason": "2025-26",
        "teams": ["BOS", "PHI"],
        "status": "review",
        "priority": "high",
        "createdAtIso": "2026-07-24T00:00:00Z",
        "updatedAtIso": "2026-07-24T00:00:00Z",
        "summary": "Server-backed transaction workflow contract.",
        "assumptions": [],
        "ruleFindings": [],
        "approvals": [],
        "comments": [],
        "assignedUserIds": ["analyst-test"],
        "isOrganizationVisible": True,
    }
    upsert_transaction_case(
        "case-test",
        CaseUpsert(actor_user_id="analyst-test", scope="personal", case=case_payload),
    )
    upsert_transaction_case(
        "case-test",
        CaseUpsert(actor_user_id="analyst-test", scope="organization", case=case_payload),
    )
    personal = list_transaction_cases(owner_user_id="analyst-test", scope="personal")
    shared = list_transaction_cases(organization_id="org-test", scope="organization")
    assert len(personal) == 1
    assert len(shared) == 1
    assert shared[0]["title"] == "Test trade review"

    activity = {
        "id": "activity-test",
        "caseId": "case-test",
        "organizationId": "org-test",
        "actorUserId": "analyst-test",
        "actorName": "Test Analyst",
        "kind": "imported",
        "message": "Imported a case.",
        "createdAtIso": "2026-07-24T00:00:00Z",
        "recipientUserId": "admin-test",
    }
    upsert_activity("activity-test", PayloadUpsert(payload=activity))
    assert list_activities("org-test")[0]["id"] == "activity-test"

    notification = {
        "id": "notification-test",
        "caseId": "case-test",
        "organizationId": "org-test",
        "recipientUserId": "admin-test",
        "title": "Review requested",
        "body": "Review the test case.",
        "createdAtIso": "2026-07-24T00:00:00Z",
        "isRead": False,
    }
    upsert_notification("notification-test", PayloadUpsert(payload=notification))
    assert list_notifications("admin-test")[0]["isRead"] is False

    member = {
        "userId": "reviewer-test",
        "displayName": "Test Reviewer",
        "roleLabel": "Reviewer",
        "createdAtIso": "2026-07-24T00:00:00Z",
        "teamFocus": "Eastern Conference",
        "active": True,
        "reviewCapacity": 8,
    }
    upsert_member_record("org-test", "reviewer-test", PayloadUpsert(payload=member))
    assert any(item["userId"] == "reviewer-test" for item in list_member_records("org-test"))

    release = {
        "id": "nba-2025-26-test",
        "league": "NBA",
        "season": "2025-26",
        "status": "validated",
        "version": "test-1",
        "generatedAt": "2026-07-24T00:00:00Z",
        "manifest": {"counts": {"teams": 30, "games": 1300}},
        "validation": {"status": "pass", "blockingFailures": []},
        "sourceNotes": ["Contract-test release."],
    }
    upsert_data_release(
        "nba-2025-26-test",
        DataReleaseUpsert(actor_user_id="pipeline-test", release=release),
    )
    assert current_data_release("2025-26")["validation"]["status"] == "pass"
    readiness = launch_readiness_v2()
    assert readiness["data_release"]["season"] == "2025-26"
    assert "transaction_case_snapshots" in readiness["tables"]

print("Sports Terminal launch backend contract test passed.")
