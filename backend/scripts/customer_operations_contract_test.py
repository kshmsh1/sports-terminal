from __future__ import annotations

import os
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="sports-terminal-customer-ops-") as temp_dir:
    os.environ["SPORTS_TERMINAL_DB_PATH"] = str(Path(temp_dir) / "customer_ops.sqlite")

    from fastapi import HTTPException

    from app.customer_operations_api import (
        IncidentCreate,
        NotificationCreate,
        OnboardingUpdate,
        SupportCaseCreate,
        SupportCommentCreate,
        create_incident,
        create_notification,
        create_support_case,
        customer_operations_snapshot,
        init_customer_operations_db,
        mark_all_notifications_read,
        update_onboarding,
        add_support_comment,
    )
    from app.main import connect, now_iso

    init_customer_operations_db()
    timestamp = now_iso()
    with connect() as connection:
        for user_id, role in (
            ("analyst-a", "analyst"),
            ("analyst-b", "analyst"),
            ("org-owner", "organization_admin"),
            ("org-member", "analyst"),
        ):
            connection.execute(
                "INSERT INTO users (id, email, display_name, role, status, created_at, updated_at) VALUES (?, ?, ?, ?, 'active', ?, ?)",
                (user_id, f"{user_id}@example.com", user_id, role, timestamp, timestamp),
            )
        connection.execute(
            "INSERT INTO organizations (id, name, slug, status, plan_id, created_by_user_id, created_at, updated_at) VALUES ('org-1', 'NBA Operations', 'nba-operations', 'active', 'org', 'org-owner', ?, ?)",
            (timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES ('org-1', 'org-owner', 'owner', 'active', ?, ?)",
            (timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES ('org-1', 'org-member', 'analyst', 'active', ?, ?)",
            (timestamp, timestamp),
        )
        connection.commit()

    personal = customer_operations_snapshot(
        actor_user_id="analyst-a",
        scope="personal",
        owner_user_id="analyst-a",
    )
    assert personal["scope"] == "personal"
    assert personal["entitlement"]["plan_id"] == "individual"
    assert personal["usage"]["seat_limit"] == 1

    try:
        customer_operations_snapshot(
            actor_user_id="analyst-b",
            scope="personal",
            owner_user_id="analyst-a",
        )
        raise AssertionError("Cross-user personal access should be rejected")
    except HTTPException as error:
        assert error.status_code == 403

    update_onboarding(
        OnboardingUpdate(
            actor_user_id="analyst-a",
            scope="personal",
            owner_user_id="analyst-a",
            completed_steps=["profile", "workspace", "profile"],
        )
    )
    personal = customer_operations_snapshot(
        actor_user_id="analyst-a",
        scope="personal",
        owner_user_id="analyst-a",
    )
    assert personal["onboarding"]["completed_steps"] == ["profile", "workspace"]

    first_notification = create_notification(
        NotificationCreate(
            actor_user_id="analyst-a",
            user_id="analyst-a",
            category="data_release",
            title="2025-26 release available",
            body="The certified release has changed.",
            dedupe_key="release-2025-26-v1",
        )
    )
    duplicate_notification = create_notification(
        NotificationCreate(
            actor_user_id="analyst-a",
            user_id="analyst-a",
            category="data_release",
            title="Duplicate",
            body="Should not create another row.",
            dedupe_key="release-2025-26-v1",
        )
    )
    assert duplicate_notification["id"] == first_notification["id"]
    personal = customer_operations_snapshot(
        actor_user_id="analyst-a",
        scope="personal",
        owner_user_id="analyst-a",
    )
    assert personal["usage"]["unread_notifications"] == 1
    marked = mark_all_notifications_read(actor_user_id="analyst-a")
    assert marked["updated"] == 1

    support = create_support_case(
        SupportCaseCreate(
            actor_user_id="analyst-a",
            scope="personal",
            owner_user_id="analyst-a",
            category="data",
            priority="high",
            subject="Source mismatch",
            description="The displayed source date needs review.",
            diagnostics={"route": "NBA Hub"},
        )
    )
    assert support["status"] == "open"
    comment = add_support_comment(
        support["id"],
        SupportCommentCreate(
            actor_user_id="analyst-a",
            body="The issue reproduces after refresh.",
        ),
    )
    assert comment["case_id"] == support["id"]
    personal = customer_operations_snapshot(
        actor_user_id="analyst-a",
        scope="personal",
        owner_user_id="analyst-a",
    )
    assert personal["usage"]["open_support_cases"] == 1
    assert len(personal["support_cases"][0]["comments"]) == 1

    organization = customer_operations_snapshot(
        actor_user_id="org-member",
        scope="organization",
        owner_user_id="org-member",
        organization_id="org-1",
    )
    assert organization["scope"] == "organization"
    assert organization["entitlement"]["plan_id"] == "organization"
    assert organization["usage"]["active_members"] == 2
    assert "incident_management" in organization["entitlement"]["features"]

    try:
        create_incident(
            IncidentCreate(
                actor_user_id="org-member",
                organization_id="org-1",
                title="Workspace latency",
                summary="Workbook writes are delayed.",
            )
        )
        raise AssertionError("Analysts should not create organization incidents")
    except HTTPException as error:
        assert error.status_code == 403

    incident = create_incident(
        IncidentCreate(
            actor_user_id="org-owner",
            organization_id="org-1",
            title="Workspace latency",
            summary="Workbook writes are delayed.",
            severity="major",
            affected_modules=["Workspace", "API"],
        )
    )
    assert incident["status"] == "investigating"
    organization = customer_operations_snapshot(
        actor_user_id="org-owner",
        scope="organization",
        owner_user_id="org-owner",
        organization_id="org-1",
    )
    assert organization["usage"]["active_incidents"] == 1

print("Sports Terminal customer operations contract test passed.")
