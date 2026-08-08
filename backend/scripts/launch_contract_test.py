from __future__ import annotations

import os
import tempfile
import traceback
from pathlib import Path

from fastapi import HTTPException


def checkpoint(label: str) -> None:
    print(f"BACKEND_CONTRACT_CHECKPOINT: {label}", flush=True)


try:
    with tempfile.TemporaryDirectory(prefix="sports-terminal-launch-") as temp_dir:
        os.environ["SPORTS_TERMINAL_DB_PATH"] = str(
            Path(temp_dir) / "launch_test.sqlite"
        )

        # Import the actual launch entrypoint first so the hardened organization
        # bootstrap and every launch router are applied exactly as they are when
        # Uvicorn runs the product.
        from app import main_launch as _main_launch  # noqa: F401
        from app.auth_api import (
            PRIVACY_VERSION,
            TERMS_VERSION,
            SignInRequest,
            SignUpRequest,
            sign_in,
            sign_up,
        )
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
            list_memberships,
            list_notifications,
            list_transaction_cases,
            upsert_activity,
            upsert_data_release,
            upsert_member_record,
            upsert_notification,
            upsert_transaction_case,
        )
        from app.main import init_db
        from app.workspace_api import (
            WorkspaceUpsert,
            get_primary_workspace,
            list_workspace_versions,
            upsert_primary_workspace,
        )

        checkpoint("initialize")
        init_db()
        init_launch_db()

        checkpoint("legal acceptance blocks account creation")
        try:
            sign_up(
                SignUpRequest(
                    email="blocked@example.com",
                    password="LaunchPass123",
                    display_name="Blocked User",
                    account_type="individual",
                    accepted_terms=False,
                    accepted_privacy=True,
                    terms_version=TERMS_VERSION,
                    privacy_version=PRIVACY_VERSION,
                )
            )
            raise AssertionError("signup unexpectedly bypassed Terms acceptance")
        except HTTPException as error:
            assert error.status_code == 400
        try:
            sign_up(
                SignUpRequest(
                    email="stale@example.com",
                    password="LaunchPass123",
                    display_name="Stale Legal User",
                    account_type="individual",
                    accepted_terms=True,
                    accepted_privacy=True,
                    terms_version="stale-version",
                    privacy_version=PRIVACY_VERSION,
                )
            )
            raise AssertionError("signup unexpectedly accepted a stale Terms version")
        except HTTPException as error:
            assert error.status_code == 409

        checkpoint("first-party individual authentication")
        individual_auth = sign_up(
            SignUpRequest(
                email="analyst@example.com",
                password="LaunchPass123",
                display_name="Launch Analyst",
                account_type="individual",
                accepted_terms=True,
                accepted_privacy=True,
                terms_version=TERMS_VERSION,
                privacy_version=PRIVACY_VERSION,
            )
        )
        assert individual_auth["user"]["role"] == "analyst"
        assert individual_auth["token"]
        assert individual_auth["legal"]["current"] is True
        assert individual_auth["legal"]["accepted"]["terms"]["version"] == TERMS_VERSION
        assert individual_auth["legal"]["accepted"]["privacy"]["version"] == PRIVACY_VERSION
        individual_login = sign_in(
            SignInRequest(
                email="analyst@example.com",
                password="LaunchPass123",
            )
        )
        assert individual_login["user"]["id"] == individual_auth["user"]["id"]
        assert individual_login["legal"]["current"] is True

        checkpoint("first-party organization authentication")
        organization_auth = sign_up(
            SignUpRequest(
                email="owner@example.com",
                password="LaunchOwner123",
                display_name="Launch Owner",
                account_type="organization",
                organization_name="Launch Basketball Operations",
                accepted_terms=True,
                accepted_privacy=True,
                terms_version=TERMS_VERSION,
                privacy_version=PRIVACY_VERSION,
            )
        )
        assert organization_auth["user"]["role"] == "organization_admin"
        assert organization_auth["organizations"][0]["membership_role"] == "owner"
        assert organization_auth["legal"]["current"] is True

        checkpoint("versioned customer workspace")
        individual_user_id = individual_auth["user"]["id"]
        workspace = upsert_primary_workspace(
            WorkspaceUpsert(
                actor_user_id=individual_user_id,
                scope="personal",
                owner_user_id=individual_user_id,
                title="Launch Analyst Workbook",
                active_sheet="Watchlist",
                sheets={
                    "Watchlist": {
                        "A1": "Player",
                        "B1": "PPG",
                        "A2": "Shai Gilgeous-Alexander",
                        "B2": "32.7",
                    }
                },
            )
        )
        assert workspace["version"] == 1
        assert workspace["sheets"]["Watchlist"]["B2"] == "32.7"
        workspace = upsert_primary_workspace(
            WorkspaceUpsert(
                actor_user_id=individual_user_id,
                scope="personal",
                owner_user_id=individual_user_id,
                title="Launch Analyst Workbook",
                active_sheet="Watchlist",
                sheets={
                    "Watchlist": {
                        "A1": "Player",
                        "B1": "PPG",
                        "A2": "Shai Gilgeous-Alexander",
                        "B2": "33.0",
                    }
                },
            )
        )
        assert workspace["version"] == 2
        assert get_primary_workspace(individual_user_id)["version"] == 2
        assert len(list_workspace_versions(individual_user_id)) == 2

        checkpoint("organization creation")
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

        checkpoint("personal and organization cases")
        upsert_transaction_case(
            "case-test",
            CaseUpsert(
                actor_user_id="analyst-test",
                scope="personal",
                case=case_payload,
            ),
        )
        upsert_transaction_case(
            "case-test",
            CaseUpsert(
                actor_user_id="analyst-test",
                scope="organization",
                case=case_payload,
            ),
        )
        personal = list_transaction_cases(
            owner_user_id="analyst-test",
            scope="personal",
        )
        shared = list_transaction_cases(
            organization_id="org-test",
            scope="organization",
        )
        assert len(personal) == 1
        assert len(shared) == 1
        assert shared[0]["title"] == "Test trade review"
        memberships = list_memberships("org-test")
        analyst_membership = next(
            item for item in memberships if item["user_id"] == "analyst-test"
        )
        assert analyst_membership["role"] == "analyst"

        checkpoint("activity and notification")
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
        upsert_notification(
            "notification-test",
            PayloadUpsert(payload=notification),
        )
        assert list_notifications("admin-test")[0]["isRead"] is False

        checkpoint("organization member records")
        member = {
            "userId": "reviewer-test",
            "displayName": "Test Reviewer",
            "roleLabel": "Reviewer",
            "createdAtIso": "2026-07-24T00:00:00Z",
            "teamFocus": "Eastern Conference",
            "active": True,
            "reviewCapacity": 8,
        }
        upsert_member_record(
            "org-test",
            "reviewer-test",
            PayloadUpsert(payload=member),
        )
        assert any(
            item["userId"] == "reviewer-test"
            for item in list_member_records("org-test")
        )

        checkpoint("certified data release")
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
            DataReleaseUpsert(
                actor_user_id="pipeline-test",
                release=release,
            ),
        )
        assert current_data_release("2025-26")["validation"]["status"] == "pass"

        checkpoint("launch readiness")
        readiness = launch_readiness_v2()
        assert readiness["data_release"]["season"] == "2025-26"
        assert "transaction_case_snapshots" in readiness["tables"]
        assert "auth_credentials" in readiness["tables"]
        assert "legal_acceptances" in readiness["tables"]
        assert "workspace_snapshots" in readiness["tables"]

    print("Sports Terminal launch backend contract test passed.")
except Exception as error:
    print(
        f"BACKEND_CONTRACT_FAILURE: {type(error).__name__}: {error}",
        flush=True,
    )
    traceback.print_exc()
    raise
