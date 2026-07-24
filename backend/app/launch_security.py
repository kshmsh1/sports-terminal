from __future__ import annotations

import sqlite3

from .main import now_iso


def ensure_organization(
    connection: sqlite3.Connection,
    organization_id: str,
    name: str,
    owner_user_id: str,
) -> None:
    """Create a missing organization without promoting users on later writes.

    The first launch implementation reused an owner argument as a convenient
    bootstrap identity. That is correct only while the organization is being
    created. Once it exists, a case owner, commenter, assignee, or saved-object
    owner must never be promoted to organization owner as a side effect of
    writing product data.
    """

    if not organization_id:
        return
    existing = connection.execute(
        "SELECT id FROM organizations WHERE id = ?",
        (organization_id,),
    ).fetchone()
    if existing is not None:
        return

    timestamp = now_iso()
    base_slug = _slug(name or organization_id, organization_id)
    slug = base_slug
    suffix = 1
    while connection.execute(
        "SELECT 1 FROM organizations WHERE slug = ?",
        (slug,),
    ).fetchone() is not None:
        suffix += 1
        slug = f"{base_slug}-{suffix}"
    connection.execute(
        """
        INSERT INTO organizations (
          id, name, slug, status, plan_id, created_by_user_id, created_at, updated_at
        ) VALUES (?, ?, ?, 'active', 'org', ?, ?, ?)
        """,
        (
            organization_id,
            name or organization_id,
            slug,
            owner_user_id,
            timestamp,
            timestamp,
        ),
    )
    if owner_user_id:
        connection.execute(
            """
            INSERT INTO organization_memberships (
              organization_id, user_id, role, status, joined_at, updated_at
            ) VALUES (?, ?, 'owner', 'active', ?, ?)
            """,
            (organization_id, owner_user_id, timestamp, timestamp),
        )


def _slug(value: str, fallback: str) -> str:
    output: list[str] = []
    previous_dash = False
    for character in value.strip().lower():
        if character.isalnum():
            output.append(character)
            previous_dash = False
        elif not previous_dash:
            output.append("-")
            previous_dash = True
    normalized = "".join(output).strip("-")
    return normalized or fallback
