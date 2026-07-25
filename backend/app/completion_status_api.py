from __future__ import annotations

import os
from typing import Any

from fastapi import APIRouter

from .front_office_api import init_front_office_db
from .main import connect, now_iso
from .trust_safety_api import init_trust_safety_db
from .workspace_api import init_workspace_db

router = APIRouter(prefix="/v2/completion", tags=["completion-status"])


def _table_count(connection: Any, table: str, where: str = "", values: tuple[Any, ...] = ()) -> int:
    row = connection.execute(
        f"SELECT COUNT(*) AS count FROM {table} {where}",
        values,
    ).fetchone()
    return int(row["count"] if row is not None else 0)


def platform_completion_status() -> dict[str, Any]:
    init_front_office_db()
    init_trust_safety_db()
    init_workspace_db()
    with connect() as connection:
        tables = {
            row["name"]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        }
        counts = {
            "contracts": _table_count(
                connection,
                "front_office_records",
                "WHERE record_type = 'contract' AND record_status = 'active'",
            ),
            "verified_contracts": _table_count(
                connection,
                "front_office_records",
                "WHERE record_type = 'contract' AND record_status = 'active' AND source_status = 'verified'",
            ),
            "team_positions": _table_count(
                connection,
                "front_office_records",
                "WHERE record_type = 'team_position' AND record_status = 'active'",
            ),
            "verified_team_positions": _table_count(
                connection,
                "front_office_records",
                "WHERE record_type = 'team_position' AND record_status = 'active' AND source_status = 'verified'",
            ),
            "draft_assets": _table_count(
                connection,
                "front_office_records",
                "WHERE record_type = 'draft_asset' AND record_status = 'active'",
            ),
            "verified_draft_assets": _table_count(
                connection,
                "front_office_records",
                "WHERE record_type = 'draft_asset' AND record_status = 'active' AND source_status = 'verified'",
            ),
            "ledger_transactions": _table_count(
                connection,
                "front_office_records",
                "WHERE record_type = 'ledger' AND record_status = 'active'",
            ),
            "open_moderation_cases": _table_count(
                connection,
                "moderation_cases",
                "WHERE status IN ('open', 'monitoring')",
            ),
            "moderation_actions": _table_count(connection, "moderation_actions"),
            "moderation_audit_events": _table_count(
                connection,
                "moderation_audit_events",
            ),
            "active_sanctions": _table_count(
                connection,
                "user_sanctions",
                "WHERE status = 'active'",
            ),
            "blocks": _table_count(connection, "user_blocks"),
            "mutes": _table_count(connection, "user_mutes"),
            "conversations": _table_count(connection, "conversations"),
            "messages": _table_count(connection, "messages"),
            "workspaces": _table_count(connection, "workspace_snapshots"),
            "workspace_versions": _table_count(connection, "workspace_versions"),
            "workspace_permissions": _table_count(
                connection,
                "workspace_permissions",
            ),
        }

    internal_modules = {
        "front_office_registry": "implemented",
        "contract_versions": "implemented",
        "team_financial_positions": "implemented",
        "draft_asset_ledger": "implemented",
        "transaction_ledger": "implemented",
        "team_reconciliation": "implemented",
        "moderated_community": "implemented",
        "protected_messages": "implemented",
        "blocks_and_mutes": "implemented",
        "sanctions_and_audit": "implemented",
        "multi_sheet_workspace": "implemented",
        "workspace_conflicts": "implemented",
        "workspace_restore": "implemented",
        "workspace_permissions": "implemented",
        "isolated_python_runtime": "implemented",
    }
    required_tables = {
        "front_office_records",
        "front_office_record_versions",
        "transaction_ledger_events",
        "moderation_cases",
        "moderation_actions",
        "moderation_audit_events",
        "user_sanctions",
        "user_blocks",
        "user_mutes",
        "workspace_snapshots",
        "workspace_versions",
        "workspace_permissions",
    }
    missing_tables = sorted(required_tables - tables)
    source_blockers: list[str] = []
    if counts["verified_contracts"] < 400:
        source_blockers.append("verified_2025_26_player_contract_catalog")
    if counts["verified_team_positions"] < 30:
        source_blockers.append("verified_2025_26_team_financial_positions")
    if counts["verified_draft_assets"] == 0:
        source_blockers.append("verified_draft_asset_ownership_catalog")

    external_state = {
        "managed_database": bool(os.getenv("DATABASE_URL")),
        "commercial_data_rights": os.getenv(
            "SPORTS_TERMINAL_DATA_RIGHTS_APPROVED"
        )
        == "true",
        "payment_provider": bool(
            os.getenv("SPORTS_TERMINAL_PAYMENT_PROVIDER")
        ),
        "transactional_email": bool(
            os.getenv("SPORTS_TERMINAL_EMAIL_PROVIDER")
        ),
        "production_monitoring": bool(
            os.getenv("SPORTS_TERMINAL_MONITORING_PROVIDER")
        ),
        "public_community_approved": os.getenv(
            "SPORTS_TERMINAL_PUBLIC_COMMUNITY"
        )
        == "true",
        "moderation_operations_staffed": os.getenv(
            "SPORTS_TERMINAL_MODERATION_STAFFED"
        )
        == "true",
    }
    external_blockers = [
        key for key, value in external_state.items() if not value
    ]
    internal_ready = not missing_tables
    source_ready = not source_blockers
    return {
        "status": (
            "public_launch_ready"
            if internal_ready and source_ready and not external_blockers
            else "externally_blocked"
            if internal_ready and source_ready
            else "source_population_required"
            if internal_ready
            else "internal_implementation_incomplete"
        ),
        "internal_ready": internal_ready,
        "source_ready": source_ready,
        "internal_modules": internal_modules,
        "record_counts": counts,
        "missing_tables": missing_tables,
        "source_blockers": source_blockers,
        "external_state": external_state,
        "external_blockers": external_blockers,
        "generated_at": now_iso(),
    }


@router.get("/status")
def completion_status() -> dict[str, Any]:
    return platform_completion_status()


@router.get("/catalog-readiness")
def catalog_readiness() -> dict[str, Any]:
    status = platform_completion_status()
    return {
        "source_ready": status["source_ready"],
        "record_counts": status["record_counts"],
        "blocking_items": status["source_blockers"],
        "requirements": {
            "verified_contracts": 400,
            "verified_team_positions": 30,
            "verified_draft_assets": "> 0",
        },
        "generated_at": status["generated_at"],
    }
