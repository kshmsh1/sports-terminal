from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path


def load_fixture_module(repo_root: Path):
    path = repo_root / "backend" / "scripts" / "historical_research_contract_test.py"
    spec = importlib.util.spec_from_file_location("historical_research_fixture", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load historical research fixture: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def route_paths(router) -> list[str]:
    return sorted(getattr(route, "path", "") for route in router.routes)


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    fixture = load_fixture_module(repo_root)

    with tempfile.TemporaryDirectory(prefix="sports-terminal-history-launch-") as temp:
        temp_root = Path(temp)
        database = temp_root / "history.sqlite"
        fixture.seed(database)
        os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"] = str(database)
        os.environ["SPORTS_TERMINAL_DB_PATH"] = str(temp_root / "launch.sqlite")
        sys.path.insert(0, str(repo_root / "backend"))

        # This mirrors backend/scripts/launch_contract_test.py and uvicorn:
        # compose the launch entrypoint before importing endpoint modules directly.
        from app import main_launch as launch  # noqa: PLC0415
        from app import historical_nba_api as canonical  # noqa: PLC0415
        from app import historical_nba_compat_api as compat  # noqa: PLC0415
        from app import historical_nba_research_api as research  # noqa: PLC0415

        paths = {getattr(route, "path", "") for route in launch.app.routes}
        required = {
            "/v2/nba/history/status",
            "/v2/nba/history/seed/{season}",
            "/v2/nba/history/research/summary",
            "/v2/nba/history/all-time",
            "/v2/nba/history/compare",
            "/v2/nba/history/players/{player_key}/games",
            "/v2/nba/history/franchises",
            "/v2/nba/history/franchises/{franchise_key}",
        }
        missing = sorted(required - paths)
        assert not missing, {
            "launch_file": getattr(launch, "__file__", ""),
            "launch_title": launch.app.title,
            "launch_version": launch.app.version,
            "missing_routes": missing,
            "history_paths": sorted(path for path in paths if "/v2/nba/history" in path),
            "canonical_router_paths": route_paths(canonical.router),
            "compat_router_paths": route_paths(compat.router),
            "research_router_paths": route_paths(research.router),
            "launch_router_is_canonical_router": getattr(launch, "historical_nba_router", None) is canonical.router,
            "launch_compat_is_compat_router": getattr(launch, "historical_nba_compat_router", None) is compat.router,
        }

        summary = research.historical_research_summary()
        assert summary["counts"]["players"] == 2, summary
        assert summary["counts"]["material_conflicts"] == 1, summary
        assert len(summary["sources"]) == 3, summary

        all_time = research.historical_all_time(
            metric="pts",
            basis="totals",
            mode="career",
            best_n=5,
            league="NBA",
            season_type="regular",
            season_from="",
            season_to="",
            min_seasons=1,
            min_games=0,
            offset=0,
            limit=100,
        )
        assert all_time["rows"][0]["player_name"] == "Example Star", all_time
        assert all_time["rows"][0]["metric_value"] == 4500.0, all_time

        peak = research.historical_all_time(
            metric="bpm",
            basis="per_game",
            mode="peak",
            best_n=5,
            league="NBA",
            season_type="regular",
            season_from="",
            season_to="",
            min_seasons=1,
            min_games=0,
            offset=0,
            limit=100,
        )
        assert peak["rows"][0]["peak_season"] == "2023-24", peak

        compare = research.historical_compare(
            player_keys="p_star,p_other",
            metric="pts",
            basis="per_game",
            league="NBA",
            season_type="regular",
            min_games=1,
        )
        assert len(compare["players"]) == 2, compare
        assert compare["players"][0]["peak_era"] is not None, compare

        player_games = research.historical_player_games(
            player_key="p_star",
            season="",
            season_type="combined",
            offset=0,
            limit=100,
        )
        assert player_games["matched_rows"] == 1, player_games
        assert player_games["rows"][0]["pts"] == 32.0, player_games

        franchises = research.historical_franchises(query="", league="NBA", limit=100)
        assert len(franchises["rows"]) == 2, franchises
        franchise = research.historical_franchise("fr_alpha")
        assert franchise["teams"][0]["abbreviation"] == "AAA", franchise
        assert franchise["seasons"][0]["wins"] == 58.0, franchise

        print(
            json.dumps(
                {
                    "launch_title": launch.app.title,
                    "launch_version": launch.app.version,
                    "historical_routes": len(
                        [path for path in paths if "/v2/nba/history" in path]
                    ),
                    "all_time_leader": all_time["rows"][0]["player_name"],
                    "franchises": len(franchises["rows"]),
                },
                indent=2,
            )
        )

    print("Historical NBA launch/research contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
