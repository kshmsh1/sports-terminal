from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="sports_terminal_pre_capital_") as temp:
        root = Path(temp)
        os.environ["SPORTS_TERMINAL_DB_PATH"] = str(root / "platform.sqlite")
        os.environ["SPORTS_TERMINAL_NBA_API_DB_PATH"] = str(root / "modern.sqlite")

        from backend.app.pre_capital_readiness_api import pre_capital_readiness
        from backend.app.main_launch import app

        payload = pre_capital_readiness()
        assert payload["internal_ready"] is True, payload
        assert payload["status"] == "pre_capital_work_remaining", payload
        unpaid = {item["key"] for item in payload["remaining_without_capital"]}
        assert "collect_modern_nba_api_overlay" in unpaid, unpaid
        assert "build_current_season_release" in unpaid, unpaid
        assert "verified_2025_26_player_contract_catalog" in unpaid, unpaid
        assert "verified_2025_26_team_financial_positions" in unpaid, unpaid
        assert "verified_draft_asset_ownership_catalog" in unpaid, unpaid
        assert "full_browser_runtime_qa" in unpaid, unpaid
        assert "trade_machine_edge_case_certification" in unpaid, unpaid

        capital = {item["key"] for item in payload["remaining_capital_external"]}
        assert "commercial_data_rights" in capital, capital
        assert "managed_database" in capital, capital
        assert "hosting_domains_storage_cdn" in capital, capital
        assert "production_monitoring" in capital, capital
        assert "security_and_legal_review" in capital, capital
        assert "moderation_support_incident_staffing" in capital, capital

        routes = {getattr(route, "path", "") for route in app.router.routes}
        assert "/v2/completion/pre-capital" in routes, routes

        print(
            {
                "implemented_domains": len(payload["implemented_product_domains"]),
                "remaining_without_capital": len(unpaid),
                "remaining_capital_external": len(capital),
                "status": payload["status"],
            }
        )
        print("Sports Terminal pre-capital readiness contract passed.")


if __name__ == "__main__":
    main()
