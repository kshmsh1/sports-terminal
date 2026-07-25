from __future__ import annotations

import tempfile
from pathlib import Path

from app import main as main_module
from app.customer_ops_api import (
    BackupRunCreate,
    IncidentCreate,
    IncidentUpdateCreate,
    InvitationAction,
    InvitationCreate,
    NotificationAction,
    NotificationCreate,
    OnboardingUpdate,
    PrivacyRequestAction,
    PrivacyRequestCreate,
    ProviderOutboxAction,
    RetentionPolicyUpsert,
    ServiceComponentUpsert,
    SubscriptionUpsert,
    SupportTicketCreate,
    SupportTicketEventCreate,
    account_overview,
    act_on_invitation,
    act_on_notification,
    act_on_privacy_request,
    act_on_provider_outbox,
    add_incident_update,
    add_support_ticket_event,
    create_customer_notification,
    create_incident,
    create_invitation,
    create_privacy_request,
    create_support_ticket,
    customer_ops_readiness,
    get_entitlements,
    get_onboarding,
    get_subscription,
    init_customer_ops_db,
    list_backup_runs,
    list_customer_notifications,
    list_customer_plans,
    list_incidents,
    list_invitations,
    list_privacy_requests,
    list_provider_outbox,
    list_retention_policies,
    list_support_tickets,
    organization_overview,
    record_backup_run,
    update_onboarding,
    upsert_retention_policy,
    upsert_service_component,
    upsert_subscription,
)
from app.launch_api import _ensure_shadow_user
from app.main import connect, now_iso


def checkpoint(label: str) -> None:
    print(f"CUSTOMER_OPS_CHECKPOINT: {label}", flush=True)


with tempfile.TemporaryDirectory(prefix="sports-terminal-customer-ops-") as temp_dir:
    main_module.DB_PATH = Path(temp_dir) / "customer_ops.sqlite"
    init_customer_ops_db()

    with connect() as connection:
        _ensure_shadow_user(connection, "customer-one", "Customer One", "analyst")
        _ensure_shadow_user(connection, "org-admin", "Organization Admin", "organization_admin")
        _ensure_shadow_user(connection, "invitee-one", "Invited Analyst", "analyst")
        _ensure_shadow_user(connection, "platform-admin", "Platform Admin", "platform_admin")
        timestamp = now_iso()
        connection.execute(
            "INSERT INTO organizations (id, name, slug, status, plan_id, created_by_user_id, created_at, updated_at) VALUES ('org-one', 'Launch Organization', 'launch-organization', 'active', 'org', 'org-admin', ?, ?)",
            (timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES ('org-one', 'org-admin', 'owner', 'active', ?, ?)",
            (timestamp, timestamp),
        )
        connection.commit()

    checkpoint("plans and entitlements")
    plans = list_customer_plans()
    assert {item["id"] for item in plans} >= {"free", "pro", "org"}
    pro_plan = next(item for item in plans if item["id"] == "pro")
    assert any(item["entitlement_key"] == "python_runtime_rows" for item in pro_plan["entitlements"])

    checkpoint("personal subscription")
    personal_subscription = upsert_subscription(
        "personal",
        "customer-one",
        SubscriptionUpsert(
            actor_user_id="customer-one",
            scope_type="personal",
            scope_id="customer-one",
            plan_id="pro",
            status="trialing",
            trial_ends_at="2026-08-15T00:00:00+00:00",
        ),
    )
    assert personal_subscription["plan_id"] == "pro"
    assert personal_subscription["version"] == 1
    personal_entitlements = get_entitlements("personal", "customer-one", "customer-one")
    assert personal_entitlements["entitlements"]["trade_machine"]["enabled"] is True

    checkpoint("organization subscription and seats")
    org_subscription = upsert_subscription(
        "organization",
        "org-one",
        SubscriptionUpsert(
            actor_user_id="org-admin",
            scope_type="organization",
            scope_id="org-one",
            plan_id="org",
            status="active",
            seat_count=12,
        ),
    )
    assert org_subscription["seat_count"] == 12
    assert get_subscription("organization", "org-one", "org-admin")["status"] == "active"

    checkpoint("personal and organization onboarding")
    personal_onboarding = update_onboarding(
        "personal",
        "customer-one",
        OnboardingUpdate(
            actor_user_id="customer-one",
            scope_type="personal",
            scope_id="customer-one",
            completed_steps=["profile", "favorites", "workspace"],
            current_step="route_data",
        ),
    )
    assert personal_onboarding["completed_steps"] == ["favorites", "profile", "workspace"]
    org_onboarding = update_onboarding(
        "organization",
        "org-one",
        OnboardingUpdate(
            actor_user_id="org-admin",
            scope_type="organization",
            scope_id="org-one",
            completed_steps=["organization_profile", "billing"],
            current_step="invite_team",
        ),
    )
    assert get_onboarding("organization", "org-one", "org-admin")["current_step"] == "invite_team"
    assert org_onboarding["scope_type"] == "organization"

    checkpoint("organization invitation lifecycle")
    invitation = create_invitation(
        "org-one",
        InvitationCreate(
            actor_user_id="org-admin",
            email="invitee@example.com",
            role="analyst",
            message="Join the launch workspace.",
        ),
    )
    assert invitation["status"] == "pending"
    accepted = act_on_invitation(
        "org-one",
        invitation["id"],
        InvitationAction(
            actor_user_id="invitee-one",
            action="accept",
            accepting_user_id="invitee-one",
        ),
    )
    assert accepted["status"] == "accepted"
    with connect() as connection:
        membership = connection.execute(
            "SELECT role, status FROM organization_memberships WHERE organization_id = 'org-one' AND user_id = 'invitee-one'"
        ).fetchone()
        assert membership is not None
        assert membership["status"] == "active"
    assert list_invitations("org-one", "org-admin")[0]["id"] == invitation["id"]

    checkpoint("support ticket lifecycle")
    ticket = create_support_ticket(
        SupportTicketCreate(
            actor_user_id="customer-one",
            scope_type="personal",
            scope_id="customer-one",
            category="workspace",
            priority="high",
            subject="Workbook import question",
            body="The routed data package needs review.",
        )
    )
    assert ticket["status"] == "open"
    updated_ticket = add_support_ticket_event(
        ticket["id"],
        SupportTicketEventCreate(
            actor_user_id="platform-admin",
            event_type="resolved",
            message="The import was restored from version history.",
            status="resolved",
            assigned_user_id="platform-admin",
        ),
    )
    assert updated_ticket["status"] == "resolved"
    assert list_support_tickets("customer-one", "personal", "customer-one")[0]["events"]

    checkpoint("privacy request lifecycle")
    privacy_request = create_privacy_request(
        PrivacyRequestCreate(
            actor_user_id="customer-one",
            user_id="customer-one",
            request_type="export",
            details="Export my Sports Terminal account data.",
        )
    )
    assert privacy_request["status"] == "requested"
    completed_privacy = act_on_privacy_request(
        privacy_request["id"],
        PrivacyRequestAction(
            actor_user_id="platform-admin",
            action="complete",
            note="Export generated and delivered through the secure download workflow.",
            export_location="exports/customer-one/export-001.json",
        ),
    )
    assert completed_privacy["status"] == "completed"
    assert list_privacy_requests("customer-one", "customer-one")[0]["export_location"]

    checkpoint("notifications and provider outbox")
    notification = create_customer_notification(
        NotificationCreate(
            actor_user_id="platform-admin",
            user_id="customer-one",
            kind="support",
            title="Support request resolved",
            body="Your workbook import request has been resolved.",
            channel="email",
        )
    )
    assert notification["status"] == "unread"
    read_notification = act_on_notification(
        notification["id"],
        NotificationAction(actor_user_id="customer-one", action="read"),
    )
    assert read_notification["status"] == "read"
    assert list_customer_notifications("customer-one", "customer-one")[0]["id"] == notification["id"]
    outbox = list_provider_outbox("platform-admin")
    assert any(item["provider_type"] == "email" for item in outbox)
    delivered = act_on_provider_outbox(
        outbox[0]["id"],
        ProviderOutboxAction(actor_user_id="platform-admin", action="deliver"),
    )
    assert delivered["status"] == "delivered"

    checkpoint("service reliability and incident lifecycle")
    component = upsert_service_component(
        "workspace",
        ServiceComponentUpsert(
            actor_user_id="platform-admin",
            name="Workspace",
            status="operational",
            description="Shared workbook service",
        ),
    )
    assert component["status"] == "operational"
    incident = create_incident(
        IncidentCreate(
            actor_user_id="platform-admin",
            severity="sev2",
            title="Workspace synchronization degradation",
            summary="Shared workbook saves are delayed.",
            component_ids=["workspace"],
        )
    )
    assert incident["status"] == "investigating"
    resolved_incident = add_incident_update(
        incident["id"],
        IncidentUpdateCreate(
            actor_user_id="platform-admin",
            status="resolved",
            message="Database contention was cleared.",
            public_message="Workspace synchronization has returned to normal.",
            component_statuses={"workspace": "operational"},
        ),
    )
    assert resolved_incident["status"] == "resolved"
    assert list_incidents()[0]["updates"]

    checkpoint("backup evidence and retention")
    backup = record_backup_run(
        BackupRunCreate(
            actor_user_id="platform-admin",
            backup_type="database",
            status="verified",
            location="backups/customer-ops.sqlite",
            checksum="sha256:test-checksum",
            size_bytes=4096,
            restore_tested=True,
        )
    )
    assert backup["restore_tested"] is True
    assert list_backup_runs("platform-admin")[0]["id"] == backup["id"]
    policy = upsert_retention_policy(
        "support_tickets",
        RetentionPolicyUpsert(
            actor_user_id="platform-admin",
            key="support_tickets",
            retention_days=1460,
            action="anonymize",
            enabled=True,
            legal_basis="Customer support and dispute resolution",
        ),
    )
    assert policy["retention_days"] == 1460
    assert any(item["key"] == "support_tickets" for item in list_retention_policies("platform-admin"))

    checkpoint("individual and organization launch overviews")
    account = account_overview("customer-one", "customer-one")
    assert account["subscription"]["plan_id"] == "pro"
    assert account["open_support_tickets"] == 0
    organization = organization_overview("org-one", "org-admin")
    assert organization["subscription"]["plan_id"] == "org"
    assert organization["active_seats"] == 2
    assert organization["seat_limit"] == 12

    checkpoint("customer operations readiness")
    readiness = customer_ops_readiness()
    assert readiness["internal_ready"] is True
    assert readiness["internal_modules"]["incident_management"] == "implemented"
    assert readiness["record_counts"]["subscriptions"] == 2

print("Sports Terminal customer operations contract test passed.")
