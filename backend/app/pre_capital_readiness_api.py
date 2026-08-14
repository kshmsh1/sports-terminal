from __future__ import annotations

from pathlib import Path
from typing import Any

from fastapi import APIRouter

from .completion_status_api import platform_completion_status
from .nba_modern_metrics_api import modern_metric_status

ROOT = Path(__file__).resolve().parents[2]
CURRENT_SEED_MANIFEST = (
    ROOT / "assets" / "data" / "nba" / "terminal_seed" / "nba_2026" / "manifest.json"
)

router = APIRouter(prefix="/v2/completion/pre-capital", tags=["pre-capital-readiness"])


IMPLEMENTED_PRODUCT_DOMAINS: tuple[str, ...] = (
    "80-year NBA/BAA/ABA historical warehouse and canonical identity graph",
    "basic statistics and 187-metric Advanced Stats architecture",
    "regular-season/playoff separation and historical/current research context",
    "player, team, franchise, season and game entity pages/routing",
    "NBA Hub, awards/voting, historical intelligence and all-time research",
    "trade machine, cap/apron modeling, contracts/assets and transaction workflows",
    "research boards, multi-sheet workspaces and bounded Python notebook",
    "community network, threaded discussion, reputation, moderation and messaging",
    "user profiles, preferences, team/player following and badge/reputation surfaces",
    "team publications and multi-sport editorial product architecture",
    "authentication, organizations, entitlements, support, incidents and automation",
    "versioned Terms/Privacy acceptance and comprehensive legal-information surfaces",
    "horizontal terminal navigation, dark default, global command layer and persistence",
    "source-aware NBA API schema audit and modern-stat collection/materialization code",
)


def pre_capital_readiness() -> dict[str, Any]:
    platform = platform_completion_status()
    modern = modern_metric_status()

    local_tasks: list[dict[str, Any]] = []
    if not modern.get("ready"):
        local_tasks.append(
            {
                "key": "collect_modern_nba_api_overlay",
                "type": "local_data_population",
                "capital_required": False,
                "description": (
                    "Run the rate-limited nba_api collector for the modern seasons/endpoints, "
                    "review failed scopes and materialize source-backed Advanced Stats metrics."
                ),
                "command": (
                    "bash scripts/collect_nba_api_modern_stats.sh --season 2025-26 "
                    "--season-type both --replace-scope"
                ),
            }
        )
    if not CURRENT_SEED_MANIFEST.exists():
        local_tasks.append(
            {
                "key": "build_current_season_release",
                "type": "local_data_population",
                "capital_required": False,
                "description": (
                    "Build the complete current-season terminal seed/release so current-labelled "
                    "screens no longer depend on the validated prior-season fallback."
                ),
            }
        )

    source_blockers = list(platform.get("source_blockers") or [])
    source_descriptions = {
        "verified_2025_26_player_contract_catalog": (
            "Populate and verify the current player-contract catalog to the launch threshold."
        ),
        "verified_2025_26_team_financial_positions": (
            "Populate and verify all 30 current team salary/cap/apron financial positions."
        ),
        "verified_draft_asset_ownership_catalog": (
            "Populate and verify the current draft-pick ownership/protection ledger."
        ),
    }
    for blocker in source_blockers:
        local_tasks.append(
            {
                "key": blocker,
                "type": "source_verification",
                "capital_required": False,
                "description": source_descriptions.get(blocker, blocker.replace("_", " ")),
                "note": (
                    "The software can store/validate this now; whether the underlying source may "
                    "be redistributed commercially is a separate data-rights question."
                ),
            }
        )

    local_tasks.extend(
        [
            {
                "key": "full_browser_runtime_qa",
                "type": "quality_assurance",
                "capital_required": False,
                "description": (
                    "Aggressively click through every major route in desktop/narrow browser modes, "
                    "repair runtime-only Flutter/layout/state defects and verify entity links."
                ),
            },
            {
                "key": "trade_machine_edge_case_certification",
                "type": "rules_hardening",
                "capital_required": False,
                "description": (
                    "Continue encoding/test-fixturing CBA edge cases such as sign-and-trades, "
                    "BYC/poison-pill structures, acquisition/aggregation timing, TPE expiry and "
                    "full Stepien/protection interactions against authoritative rule text."
                ),
            },
            {
                "key": "content_and_empty_state_polish",
                "type": "product_polish",
                "capital_required": False,
                "description": (
                    "Replace remaining demo/editorial seed copy where appropriate, tighten empty/error "
                    "states, and finish cross-page visual consistency without adding new architecture."
                ),
            },
        ]
    )

    external_state = dict(platform.get("external_state") or {})
    capital_dependencies = [
        {
            "key": "commercial_data_rights",
            "ready": bool(external_state.get("commercial_data_rights")),
            "category": "data/licensing",
            "description": "Commercial rights to distribute every paid/proprietary/live data feed used in production.",
        },
        {
            "key": "managed_database",
            "ready": bool(external_state.get("managed_database")),
            "category": "infrastructure",
            "description": "Managed production relational database, backups, failover and operational retention.",
        },
        {
            "key": "hosting_domains_storage_cdn",
            "ready": False,
            "category": "infrastructure",
            "description": "Production hosting, domains/TLS, object storage for user media and CDN delivery.",
        },
        {
            "key": "payment_provider",
            "ready": bool(external_state.get("payment_provider")),
            "category": "commerce",
            "description": "Payment/subscription provider if Sports Terminal launches paid plans.",
        },
        {
            "key": "transactional_email",
            "ready": bool(external_state.get("transactional_email")),
            "category": "identity/communications",
            "description": "Production email for verification, password recovery, security alerts and notifications.",
        },
        {
            "key": "production_monitoring",
            "ready": bool(external_state.get("production_monitoring")),
            "category": "operations",
            "description": "Production logs, metrics, traces, alerting, analytics and error monitoring.",
        },
        {
            "key": "security_and_legal_review",
            "ready": False,
            "category": "professional_services",
            "description": "External security review/penetration testing and qualified counsel review of launch legal/data practices.",
        },
        {
            "key": "licensed_media_and_proprietary_metrics",
            "ready": False,
            "category": "data/licensing",
            "description": (
                "Optional licensed logos/headshots/media plus proprietary metrics such as EPM, "
                "LEBRON or DARKO if commercial agreements permit their use."
            ),
        },
        {
            "key": "moderation_support_incident_staffing",
            "ready": bool(
                external_state.get("moderation_operations_staffed")
                and external_state.get("customer_support_staffed")
                and external_state.get("incident_response_staffed")
            ),
            "category": "people/operations",
            "description": "Human moderation, customer support, data QA and incident-response coverage for a public network product.",
        },
        {
            "key": "editorial_and_live_content_operations",
            "ready": False,
            "category": "people/content",
            "description": "Writers/editors or licensed content feeds if the editorial product is launched as a live publication rather than product architecture/demo content.",
        },
    ]

    unpaid_remaining = [task for task in local_tasks if not task.get("capital_required")]
    paid_remaining = [item for item in capital_dependencies if not item["ready"]]
    near_finished_without_capital = bool(platform.get("internal_ready")) and not unpaid_remaining
    return {
        "status": (
            "capital_boundary_reached"
            if near_finished_without_capital
            else "pre_capital_work_remaining"
        ),
        "definition": (
            "The capital boundary is reached when core NBA product architecture is implemented, "
            "local/source data that can legally be obtained without paid services is populated, "
            "and the remaining blockers are primarily licensed data, production infrastructure, "
            "professional review or operating staff."
        ),
        "implemented_product_domains": list(IMPLEMENTED_PRODUCT_DOMAINS),
        "internal_ready": bool(platform.get("internal_ready")),
        "current_seed_built": CURRENT_SEED_MANIFEST.exists(),
        "modern_metric_overlay": modern,
        "remaining_without_capital": unpaid_remaining,
        "remaining_capital_external": paid_remaining,
        "platform_completion_status": platform.get("status"),
        "generated_at": platform.get("generated_at"),
    }


@router.get("")
def get_pre_capital_readiness() -> dict[str, Any]:
    return pre_capital_readiness()
