from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter

from .main import connect

router = APIRouter(prefix="/v2/entitlements", tags=["entitlements"])

PLAN_ORDER = {"free": 0, "pro": 1, "org": 2, "enterprise": 3}
PLAN_ENTITLEMENTS: dict[str, frozenset[str]] = {
    "free": frozenset(
        {
            "nba.discovery",
            "nba.basic_stats",
            "community.read",
            "workspace.local",
        }
    ),
    "pro": frozenset(
        {
            "nba.discovery",
            "nba.basic_stats",
            "nba.history.full",
            "nba.compare",
            "exports.structured",
            "watchlists.unlimited",
            "workspace.saved",
            "python.limited",
            "community.read",
        }
    ),
    "org": frozenset(
        {
            "nba.discovery",
            "nba.basic_stats",
            "nba.history.full",
            "nba.compare",
            "exports.structured",
            "watchlists.unlimited",
            "workspace.saved",
            "workspace.shared",
            "python.limited",
            "front_office",
            "organization.governance",
            "community.read",
        }
    ),
    "enterprise": frozenset(
        {
            "nba.discovery",
            "nba.basic_stats",
            "nba.history.full",
            "nba.compare",
            "exports.structured",
            "watchlists.unlimited",
            "workspace.saved",
            "workspace.shared",
            "python.limited",
            "front_office",
            "organization.governance",
            "enterprise.sso",
            "enterprise.audit",
            "api.data",
            "api.exports",
            "community.read",
        }
    ),
}


@dataclass(frozen=True)
class EntitlementSnapshot:
    subject_type: str
    subject_id: str
    plan_id: str
    entitlements: frozenset[str]
    explicit_grants: tuple[str, ...]

    def allows(self, key: str) -> bool:
        return key in self.entitlements

    def to_dict(self) -> dict[str, Any]:
        return {
            "subject_type": self.subject_type,
            "subject_id": self.subject_id,
            "plan_id": self.plan_id,
            "entitlements": sorted(self.entitlements),
            "explicit_grants": list(self.explicit_grants),
        }


class EntitlementService:
    def for_user(self, user_id: str, *, at: datetime | None = None) -> EntitlementSnapshot:
        when = at or datetime.now(timezone.utc)
        with connect() as connection:
            rows = connection.execute(
                "SELECT plan_id, status FROM subscriptions WHERE user_id = ?",
                (user_id,),
            ).fetchall()
            active_plans = [
                str(row["plan_id"])
                for row in rows
                if str(row["status"]).lower() in {"active", "trialing"}
            ]
            plan_id = max(
                active_plans or ["free"],
                key=lambda item: PLAN_ORDER.get(item, -1),
            )
            grants = self._active_grants(connection, "user", user_id, when)
        entitlements = set(PLAN_ENTITLEMENTS.get(plan_id, PLAN_ENTITLEMENTS["free"]))
        entitlements.update(grants)
        return EntitlementSnapshot(
            subject_type="user",
            subject_id=user_id,
            plan_id=plan_id,
            entitlements=frozenset(entitlements),
            explicit_grants=tuple(sorted(grants)),
        )

    def for_organization(
        self,
        organization_id: str,
        *,
        plan_id: str = "org",
        at: datetime | None = None,
    ) -> EntitlementSnapshot:
        when = at or datetime.now(timezone.utc)
        with connect() as connection:
            grants = self._active_grants(connection, "organization", organization_id, when)
        entitlements = set(PLAN_ENTITLEMENTS.get(plan_id, PLAN_ENTITLEMENTS["org"]))
        entitlements.update(grants)
        return EntitlementSnapshot(
            subject_type="organization",
            subject_id=organization_id,
            plan_id=plan_id,
            entitlements=frozenset(entitlements),
            explicit_grants=tuple(sorted(grants)),
        )

    def _active_grants(
        self,
        connection: Any,
        subject_type: str,
        subject_id: str,
        when: datetime,
    ) -> set[str]:
        rows = connection.execute(
            "SELECT entitlement_key, starts_at, ends_at, revoked_at "
            "FROM entitlement_grants WHERE subject_type = ? AND subject_id = ?",
            (subject_type, subject_id),
        ).fetchall()
        active: set[str] = set()
        for row in rows:
            if row["revoked_at"]:
                continue
            starts = _parse(row["starts_at"])
            ends = _parse(row["ends_at"])
            if starts and starts > when:
                continue
            if ends and ends <= when:
                continue
            active.add(str(row["entitlement_key"]))
        return active


def _parse(value: Any) -> datetime | None:
    if value is None or str(value).strip() == "":
        return None
    parsed = datetime.fromisoformat(str(value))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


@router.get("/users/{user_id}")
def user_entitlements(user_id: str) -> dict[str, Any]:
    return EntitlementService().for_user(user_id).to_dict()


@router.get("/organizations/{organization_id}")
def organization_entitlements(organization_id: str) -> dict[str, Any]:
    return EntitlementService().for_organization(organization_id).to_dict()
