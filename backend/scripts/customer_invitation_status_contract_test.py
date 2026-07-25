from __future__ import annotations

import json
import tempfile
from pathlib import Path

from fastapi import HTTPException

from app import main as main_module
from app import main_launch as _main_launch  # noqa: F401
from app.customer_invitation_api import (
    InvitationAccept,
    InvitationRotate,
    accept_invitation,
    rotate_invitation_token,
)
from app.customer_ops_api import (
    IncidentCreate,
    IncidentUpdateCreate,
    InvitationCreate,
    SubscriptionUpsert,
    add_incident_update,
    create_incident,
    create_invitation,
    init_customer_ops_db,
    upsert_subscription,
)
from app.launch_api import _ensure_shadow_user
from app.main import connect, now_iso
from app.public_status_api import public_incident, public_incidents, public_status


def token_for_outbox(connection: object, outbox_id: str) -> str:
    row = connection.execute(
        "SELECT payload_json FROM provider_outbox WHERE id = ?",
        (outbox_id,),
    ).fetchone()
    assert row is not None
    return str(json.loads(row["payload_json"])["token"])


with tempfile.TemporaryDirectory(prefix="sports-terminal-invitation-status-") as temp_dir:
    main_module.DB_PATH = Path(temp_dir) / "invitation_status.sqlite"
    init_customer_ops_db()
    with connect() as connection:
        _ensure_shadow_user(connection, "invite-admin", "Invite Admin", "organization_admin")
        _ensure_shadow_user(connection, "invite-user", "Invite User", "analyst")
        _ensure_shadow_user(connection, "seat-user", "Seat User", "analyst")
        _ensure_shadow_user(connection, "platform-status", "Platform Status", "platform_admin")
        connection.execute(
            "UPDATE users SET email = 'admin@example.com' WHERE id = 'invite-admin'"
        )
        connection.execute(
            "UPDATE users SET email = 'invitee@example.com' WHERE id = 'invite-user'"
        )
        connection.execute(
            "UPDATE users SET email = 'seat@example.com' WHERE id = 'seat-user'"
        )
        timestamp = now_iso()
        connection.execute(
            "INSERT INTO organizations (id, name, slug, status, plan_id, created_by_user_id, created_at, updated_at) VALUES ('invite-org', 'Invitation Organization', 'invitation-organization', 'active', 'org', 'invite-admin', ?, ?)",
            (timestamp, timestamp),
        )
        connection.execute(
            "INSERT INTO organization_memberships (organization_id, user_id, role, status, joined_at, updated_at) VALUES ('invite-org', 'invite-admin', 'owner', 'active', ?, ?)",
            (timestamp, timestamp),
        )
        connection.commit()

    upsert_subscription(
        "organization",
        "invite-org",
        SubscriptionUpsert(
            actor_user_id="invite-admin",
            scope_type="organization",
            scope_id="invite-org",
            plan_id="org",
            status="active",
            seat_count=2,
        ),
    )

    first = create_invitation(
        "invite-org",
        InvitationCreate(
            actor_user_id="invite-admin",
            email="invitee@example.com",
            role="analyst",
        ),
    )
    with connect() as connection:
        first_token = token_for_outbox(connection, str(first["delivery_outbox_id"]))
    accepted = accept_invitation(
        InvitationAccept(actor_user_id="invite-user", token=first_token)
    )
    assert accepted["accepted"] is True
    assert accepted["membership"]["role"] == "analyst"

    second = create_invitation(
        "invite-org",
        InvitationCreate(
            actor_user_id="invite-admin",
            email="seat@example.com",
            role="reviewer",
        ),
    )
    with connect() as connection:
        second_token = token_for_outbox(connection, str(second["delivery_outbox_id"]))
    try:
        accept_invitation(
            InvitationAccept(actor_user_id="seat-user", token=second_token)
        )
    except HTTPException as error:
        assert error.status_code == 409
        assert error.detail["message"] == "Organization seat limit has been reached"
    else:
        raise AssertionError("Seat limit did not block invitation acceptance")

    rotation = rotate_invitation_token(
        str(second["id"]),
        InvitationRotate(actor_user_id="invite-admin", expires_in_days=10),
    )
    with connect() as connection:
        rotated_token = token_for_outbox(connection, str(rotation["delivery_outbox_id"]))
    assert rotated_token != second_token
    try:
        accept_invitation(
            InvitationAccept(actor_user_id="seat-user", token=second_token)
        )
    except HTTPException as error:
        assert error.status_code == 404
    else:
        raise AssertionError("Rotating an invitation did not invalidate the prior token")

    upsert_subscription(
        "organization",
        "invite-org",
        SubscriptionUpsert(
            actor_user_id="invite-admin",
            scope_type="organization",
            scope_id="invite-org",
            plan_id="org",
            status="active",
            seat_count=3,
        ),
    )
    rotated_acceptance = accept_invitation(
        InvitationAccept(actor_user_id="seat-user", token=rotated_token)
    )
    assert rotated_acceptance["membership"]["role"] == "reviewer"

    baseline = public_status()
    assert baseline["status"] == "operational"
    assert all("metadata" not in component for component in baseline["components"])

    incident = create_incident(
        IncidentCreate(
            actor_user_id="platform-status",
            severity="sev2",
            title="Public status contract incident",
            summary="Workspace synchronization is degraded.",
            impact="Some workbook saves are delayed.",
            component_ids=["workspace"],
        )
    )
    degraded = public_status()
    assert degraded["status"] == "degraded"
    assert degraded["active_incidents"] == 1
    incident_list = public_incidents()
    assert incident_list[0]["id"] == incident["id"]
    assert "created_by_user_id" not in incident_list[0]

    add_incident_update(
        str(incident["id"]),
        IncidentUpdateCreate(
            actor_user_id="platform-status",
            status="resolved",
            message="Internal database contention cleared.",
            public_message="Workspace synchronization has returned to normal.",
            component_statuses={"workspace": "operational"},
        ),
    )
    resolved = public_incident(str(incident["id"]))
    assert resolved["status"] == "resolved"
    assert resolved["updates"][-1]["message"] == (
        "Workspace synchronization has returned to normal."
    )
    assert public_status()["status"] == "operational"

print("Sports Terminal invitation and public status contract test passed.")
