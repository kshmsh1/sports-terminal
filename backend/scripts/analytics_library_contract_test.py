from __future__ import annotations

import os
import tempfile
from pathlib import Path

with tempfile.TemporaryDirectory(prefix="sports-terminal-analytics-library-") as directory:
    os.environ["SPORTS_TERMINAL_DB_PATH"] = str(Path(directory) / "analytics.sqlite")

    from app import main_launch  # noqa: F401
    from app.analytics_library_api import (
        AnalyticsAssetClone,
        AnalyticsAssetUpsert,
        AnalyticsRecentEvent,
        analytics_summary,
        clone_asset,
        get_asset,
        list_assets,
        list_recent,
        list_versions,
        record_recent,
        upsert_asset,
    )
    from app.launch_api import MembershipUpsert, create_organization, upsert_membership
    from app.launch_api import OrganizationCreate

    owner = "analytics-owner"
    analyst = "analytics-analyst"
    organization = "analytics-org"
    create_organization(
        OrganizationCreate(
            id=organization,
            name="Analytics Organization",
            slug="analytics-organization",
            created_by_user_id=owner,
            created_by_name="Analytics Owner",
        )
    )
    upsert_membership(
        organization,
        analyst,
        MembershipUpsert(
            actor_user_id=owner,
            user_id=analyst,
            display_name="Analytics Analyst",
            role="analyst",
            status="active",
        ),
    )

    personal = upsert_asset(
        "view-1",
        AnalyticsAssetUpsert(
            actor_user_id=analyst,
            scope="personal",
            owner_user_id=analyst,
            asset_type="stats_view",
            title="Scoring and creation",
            description="Primary guard view",
            configuration={
                "basis": "per_game",
                "metrics": ["pts", "ast", "ts_pct"],
                "position": "PG",
            },
            source_snapshot={"season": "2025-26", "dataset": "nba_2026"},
            tags=["guards", "scoring"],
            pinned=True,
            expected_version=0,
        ),
    )
    assert personal["version"] == 1
    assert personal["pinned"] is True
    assert personal["configuration"]["position"] == "PG"

    updated = upsert_asset(
        "view-1",
        AnalyticsAssetUpsert(
            actor_user_id=analyst,
            scope="personal",
            owner_user_id=analyst,
            asset_type="stats_view",
            title="Scoring, creation and efficiency",
            configuration={
                "basis": "per_75",
                "metrics": ["pts", "ast", "ts_pct", "ast_tov"],
            },
            source_snapshot={"season": "2025-26", "dataset": "nba_2026"},
            tags=["guards", "efficiency"],
            pinned=True,
            expected_version=1,
        ),
    )
    assert updated["version"] == 2
    assert len(list_versions("view-1")) == 2

    organization_asset = upsert_asset(
        "team-board-1",
        AnalyticsAssetUpsert(
            actor_user_id=analyst,
            scope="organization",
            owner_user_id=analyst,
            organization_id=organization,
            asset_type="team_board",
            title="Front office team board",
            visibility="organization",
            configuration={"teams": ["BOS", "OKC"], "x": "win_pct", "y": "margin"},
            expected_version=0,
        ),
    )
    assert organization_asset["organization_id"] == organization

    clone = clone_asset(
        "team-board-1",
        AnalyticsAssetClone(
            actor_user_id=analyst,
            owner_user_id=analyst,
            organization_id=organization,
            scope="organization",
            title="Team board scenario copy",
        ),
    )
    assert clone["id"] != organization_asset["id"]
    assert clone["version"] == 1

    record_recent(
        AnalyticsRecentEvent(
            actor_user_id=analyst,
            owner_user_id=analyst,
            scope="personal",
            asset_id="view-1",
            route="stats-workstation",
            label="Opened scoring view",
            context={"basis": "per_75"},
        )
    )
    assert len(list_recent(analyst)) == 1

    personal_assets = list_assets(analyst, query="efficiency")
    assert len(personal_assets) == 1
    assert get_asset("view-1")["title"] == "Scoring, creation and efficiency"

    personal_summary = analytics_summary(analyst)
    assert personal_summary["total_assets"] == 1
    assert personal_summary["pinned_assets"] == 1
    assert personal_summary["recent_events"] == 1

    organization_summary = analytics_summary(
        analyst,
        scope="organization",
        organization_id=organization,
    )
    assert organization_summary["total_assets"] == 2

print("Sports Terminal analytics library contract test passed.")
