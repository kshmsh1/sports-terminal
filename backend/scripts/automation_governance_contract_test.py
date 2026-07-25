from __future__ import annotations

import os
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="sports-terminal-automation-") as temp_dir:
    os.environ["SPORTS_TERMINAL_DB_PATH"] = str(Path(temp_dir) / "automation.sqlite")

    from app.main import connect, init_db
    from app.launch_api import OrganizationCreate, create_organization
    from app.automation_governance_api import (
        AccountDeletionRequest,
        AlertRuleUpsert,
        DataReleaseEventCreate,
        DeliveryJobCreate,
        ExportRequestCreate,
        OrganizationInviteCreate,
        ScheduledReportUpsert,
        accept_invite,
        automation_snapshot,
        create_delivery_job,
        create_invite,
        create_release_event,
        init_automation_governance_db,
        list_alert_rules,
        list_invites,
        list_scheduled_reports,
        request_account_deletion,
        request_export,
        upsert_alert_rule,
        upsert_scheduled_report,
        InviteAccept,
    )

    init_db()
    init_automation_governance_db()
    create_organization(
        OrganizationCreate(
            id="org_test",
            name="Test Organization",
            created_by_user_id="owner_test",
            created_by_name="Owner Test",
        )
    )

    personal_rule = upsert_alert_rule(
        "rule_personal",
        AlertRuleUpsert(
            actor_user_id="owner_test",
            owner_user_id="owner_test",
            name="Cap threshold",
            category="salary_cap",
            condition={"operator": "gte", "threshold": 10},
        ),
    )
    assert personal_rule["name"] == "Cap threshold"
    assert list_alert_rules("owner_test")[0]["id"] == "rule_personal"

    org_report = upsert_scheduled_report(
        "report_org",
        ScheduledReportUpsert(
            actor_user_id="owner_test",
            scope="organization",
            owner_user_id="owner_test",
            organization_id="org_test",
            title="Weekly pipeline",
            report_type="transaction_pipeline",
            schedule="weekly",
        ),
    )
    assert org_report["schedule"] == "weekly"
    assert len(list_scheduled_reports("owner_test", "organization", "org_test")) == 1

    invite = create_invite(
        "org_test",
        OrganizationInviteCreate(
            actor_user_id="owner_test",
            organization_id="org_test",
            email="new-member@example.com",
            role="reviewer",
        ),
    )
    assert invite["status"] == "pending"
    assert len(list_invites("org_test", "owner_test")) == 1
    accepted = accept_invite(
        invite["token"],
        InviteAccept(actor_user_id="reviewer_test", display_name="Reviewer Test"),
    )
    assert accepted["role"] == "reviewer"

    release = create_release_event(
        DataReleaseEventCreate(
            actor_user_id="owner_test",
            release_id="nba-2025-26-v1",
            stage="validated",
            validation={"status": "pass"},
        )
    )
    assert release["stage"] == "validated"

    export = request_export(
        ExportRequestCreate(
            actor_user_id="owner_test",
            owner_user_id="owner_test",
            export_type="full",
        )
    )
    assert export["status"] == "queued"

    deletion = request_account_deletion(
        AccountDeletionRequest(
            actor_user_id="owner_test",
            owner_user_id="owner_test",
            confirmation="DELETE MY SPORTS TERMINAL ACCOUNT",
        )
    )
    assert deletion["status"] == "pending"

    first_job = create_delivery_job(
        DeliveryJobCreate(
            actor_user_id="owner_test",
            organization_id="org_test",
            job_type="report",
            channel="in_app",
            payload={"report_id": "report_org"},
            dedupe_key="report-org-week-1",
        )
    )
    second_job = create_delivery_job(
        DeliveryJobCreate(
            actor_user_id="owner_test",
            organization_id="org_test",
            job_type="report",
            channel="in_app",
            payload={"report_id": "report_org"},
            dedupe_key="report-org-week-1",
        )
    )
    assert first_job["id"] == second_job["id"]

    snapshot = automation_snapshot("owner_test", "organization", "org_test")
    assert snapshot["scheduled_reports"] == 1
    assert snapshot["pending_invites"] == 0
    assert snapshot["queued_delivery_jobs"] == 1

    with connect() as connection:
        audit_count = connection.execute(
            "SELECT COUNT(*) AS count FROM governance_audit_events"
        ).fetchone()["count"]
        assert audit_count >= 7

print("Sports Terminal automation governance contract test passed.")
