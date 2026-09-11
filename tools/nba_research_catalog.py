from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CATALOG_CONTRACT = "sports-terminal-nba-research-catalog-v1"


def _load_json(path: Path, fallback: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return fallback


def _exists(path: Path) -> bool:
    return path.is_file() or (path.is_dir() and any(item.is_file() for item in path.rglob("*")))


def _manifest_rows(path: Path, key: str = "datasets") -> list[dict[str, Any]]:
    payload = _load_json(path, {})
    if not isinstance(payload, dict):
        return []
    rows = payload.get(key)
    if not isinstance(rows, list):
        return []
    return [dict(row) for row in rows if isinstance(row, dict)]


def _season_range(seasons: list[dict[str, Any]]) -> dict[str, Any]:
    ids = [str(row.get("season_id") or row.get("id") or "") for row in seasons]
    ids = [value for value in ids if value]
    return {
        "count": len(ids),
        "oldest": ids[-1] if ids else None,
        "newest": ids[0] if ids else None,
    }


def _dataset(
    key: str,
    label: str,
    *,
    grain: str,
    providers: list[str],
    surfaces: list[str],
    status: str,
    coverage: Any = None,
    notes: str = "",
    static_runtime: bool = True,
) -> dict[str, Any]:
    return {
        "key": key,
        "label": label,
        "grain": grain,
        "providers": providers,
        "surfaces": surfaces,
        "status": status,
        "coverage": coverage,
        "static_runtime": static_runtime,
        "notes": notes,
    }


def build_research_catalog(
    output: Path,
    *,
    project_root: Path = ROOT,
) -> dict[str, Any]:
    output = output.expanduser().resolve()
    project_root = project_root.expanduser().resolve()
    parent_root = project_root.parent

    manifest = _load_json(output / "manifest.json", {})
    seasons = _load_json(output / "seasons.json", [])
    if not isinstance(seasons, list):
        seasons = []
    season_coverage = _season_range([row for row in seasons if isinstance(row, dict)])

    foundation = _load_json(output / "data_foundation.json", {})
    providers = foundation.get("providers") if isinstance(foundation, dict) else []
    if not isinstance(providers, list):
        providers = []
    provider_status = {
        str(item.get("key")): bool(item.get("available"))
        for item in providers
        if isinstance(item, dict) and item.get("key")
    }

    raw_roots = {
        "nba_com": next(
            (
                path
                for path in (
                    project_root / "raw" / "nba_com_stats",
                    parent_root / "raw" / "nba_com_stats",
                )
                if path.exists()
            ),
            project_root / "raw" / "nba_com_stats",
        ),
        "sportsdataverse": next(
            (
                path
                for path in (
                    project_root / "raw" / "sportsdataverse" / "nba",
                    parent_root / "raw" / "sportsdataverse" / "nba",
                )
                if path.exists()
            ),
            project_root / "raw" / "sportsdataverse" / "nba",
        ),
        "pbpstats": next(
            (
                path
                for path in (
                    project_root / "raw" / "pbpstats",
                    parent_root / "raw" / "pbpstats",
                )
                if path.exists()
            ),
            project_root / "raw" / "pbpstats",
        ),
    }

    sdv_rows = _manifest_rows(raw_roots["sportsdataverse"] / "manifest.json")
    sdv_keys = {str(row.get("dataset")) for row in sdv_rows}
    lineup_rows = _manifest_rows(output / "lineups" / "manifest.json")

    history_awards = _load_json(output / "history" / "awards.json", [])
    awards_count = len(history_awards) if isinstance(history_awards, list) else 0
    game_index = _load_json(output / "games" / "index.json", [])
    game_count = len(game_index) if isinstance(game_index, list) else 0
    player_index = _load_json(output / "players" / "index.json", [])
    player_count = len(player_index) if isinstance(player_index, list) else 0
    team_index = _load_json(output / "teams" / "index.json", [])
    team_count = len(team_index) if isinstance(team_index, list) else 0

    pbp_inventory = _load_json(raw_roots["pbpstats"] / "inventory.json", {})
    pbp_ready = False
    if isinstance(pbp_inventory, dict):
        readiness = pbp_inventory.get("readiness")
        pbp_ready = bool(isinstance(readiness, dict) and readiness.get("pbp"))

    nba_com_available = provider_status.get("nba_com_captures", _exists(raw_roots["nba_com"]))
    sdv_available = provider_status.get("sportsdataverse_releases", _exists(raw_roots["sportsdataverse"]))
    canonical_available = provider_status.get("canonical_warehouse", bool(seasons))
    awards_available = provider_status.get("manual_awards", awards_count > 0)

    datasets = [
        _dataset(
            "identity",
            "Canonical players, teams and franchises",
            grain="entity",
            providers=["canonical_warehouse", "basketball_reference"],
            surfaces=["search", "player pages", "team pages", "cross-site links"],
            status="available" if player_count and team_count else "partial",
            coverage={"players": player_count, "teams": team_count},
            notes="One canonical entity graph must be reused by every product surface.",
        ),
        _dataset(
            "traditional_player_seasons",
            "Traditional player season statistics",
            grain="player-season",
            providers=["canonical_warehouse", "nba_com_captures", "basketball_reference"],
            surfaces=["Stats", "player pages", "dashboard", "comparisons"],
            status="available" if canonical_available else "missing",
            coverage=season_coverage,
        ),
        _dataset(
            "advanced_player_seasons",
            "Advanced player season statistics",
            grain="player-season",
            providers=["nba_com_captures", "canonical_warehouse", "basketball_reference"],
            surfaces=["Advanced Stats", "player pages", "comparisons"],
            status="available" if nba_com_available else "partial",
            coverage=season_coverage,
            notes="Unavailable metrics remain explicit dashes rather than being silently substituted.",
        ),
        _dataset(
            "hustle",
            "Hustle statistics",
            grain="player-season",
            providers=["nba_com_captures"],
            surfaces=["Advanced Stats · Defense", "Advanced Stats · Playmaking"],
            status="available" if nba_com_available else "missing",
            coverage="2015-16 onward where locally captured",
        ),
        _dataset(
            "defended_shooting",
            "Defended shooting / closest-defender statistics",
            grain="player-season-defense-category",
            providers=["nba_com_captures"],
            surfaces=["Advanced Stats · Defense", "player pages"],
            status="available" if nba_com_available else "missing",
            coverage="2013-14 onward where locally captured",
        ),
        _dataset(
            "games_boxscores",
            "Games and box scores",
            grain="game / player-game / team-game",
            providers=["canonical_warehouse", "sportsdataverse_releases", "nba_com_captures", "basketball_reference"],
            surfaces=["Games", "game pages", "player game logs", "team pages"],
            status="available" if game_count else ("partial" if sdv_available else "missing"),
            coverage={"indexed_games": game_count},
        ),
        _dataset(
            "play_by_play",
            "Play-by-play events",
            grain="event",
            providers=["sportsdataverse_releases", "pbpstats_cache", "canonical_warehouse", "basketball_reference"],
            surfaces=["game pages", "Research", "clutch", "event search"],
            status="available" if ("pbp" in sdv_keys or "stats_pbp" in sdv_keys or pbp_ready) else "partial",
            coverage="dataset-specific",
            notes="pbpstats can provide corrected event order and richer possession context from a local cache.",
        ),
        _dataset(
            "possessions",
            "Possession boundaries and possession context",
            grain="possession",
            providers=["sportsdataverse_releases", "pbpstats_cache", "nba_com_captures"],
            surfaces=["Research", "lineup analysis", "on/off", "clutch", "half-court / transition"],
            status="available" if ("stats_possessions" in sdv_keys or pbp_ready) else "partial",
            coverage="1996-97 onward where source data exists",
        ),
        _dataset(
            "lineups",
            "Lineups",
            grain="lineup-season / lineup-stint",
            providers=["sportsdataverse_releases", "nba_com_captures", "pbpstats_cache"],
            surfaces=["Lineup Analysis", "on/off", "player pages"],
            status="available" if lineup_rows or "stats_lineups" in sdv_keys else "partial",
            coverage={"compiled_datasets": len(lineup_rows)},
        ),
        _dataset(
            "shots",
            "Shot locations and shot events",
            grain="shot",
            providers=["sportsdataverse_releases", "nba_com_captures", "pbpstats_cache"],
            surfaces=["shot charts", "Shooting & Efficiency", "game pages"],
            status="available" if ("shots" in sdv_keys or "stats_shots" in sdv_keys) else "partial",
            coverage="dataset-specific",
        ),
        _dataset(
            "rosters_contracts",
            "Rosters, player core data and contracts",
            grain="player-team-season / contract",
            providers=["sportsdataverse_releases", "basketball_reference", "canonical_warehouse"],
            surfaces=["player pages", "team pages", "Trade Machine", "Front Office"],
            status="available" if ("rosters" in sdv_keys or canonical_available) else "partial",
            coverage="mixed historical coverage",
            notes="Contracts should remain source-specific and independently versioned from statistics.",
        ),
        _dataset(
            "awards",
            "Awards and honors",
            grain="player-season-award",
            providers=["canonical_warehouse", "manual_awards"],
            surfaces=["Awards", "player pages", "History"],
            status="available" if (awards_available or awards_count) else "missing",
            coverage={"rows": awards_count},
        ),
        _dataset(
            "draft",
            "Draft history",
            grain="draft-pick",
            providers=["canonical_warehouse", "sportsdataverse_releases", "nba_com_captures"],
            surfaces=["History", "player pages", "team pages"],
            status="available" if (output / "history" / "draft.json").is_file() else "partial",
            coverage="historical",
        ),
        _dataset(
            "officials_coaches",
            "Officials and coaches",
            grain="game-official / team-season-coach",
            providers=["sportsdataverse_releases", "nba_com_captures"],
            surfaces=["game pages", "team pages", "Research"],
            status="available" if ({"officials", "stats_officials", "stats_coaches"} & sdv_keys) else "partial",
            coverage="dataset-specific",
        ),
    ]

    available_count = sum(row["status"] == "available" for row in datasets)
    partial_count = sum(row["status"] == "partial" for row in datasets)
    missing_count = sum(row["status"] == "missing" for row in datasets)

    payload = {
        "contract": CATALOG_CONTRACT,
        "runtime_network_required": False,
        "canonical_entity_graph_required": True,
        "historical_delivery": "static",
        "live_season_policy": "overlay current season, snapshot locally, promote to immutable history after season close",
        "summary": {
            "dataset_families": len(datasets),
            "available": available_count,
            "partial": partial_count,
            "missing": missing_count,
            "players": player_count,
            "teams": team_count,
            "games": game_count,
            "awards": awards_count,
            "season_coverage": season_coverage,
        },
        "action_grammar": [
            "observe",
            "investigate",
            "compare",
            "model",
            "save",
            "share",
            "discuss",
            "monitor",
            "export",
        ],
        "datasets": datasets,
        "source_precedence": foundation.get("source_precedence") if isinstance(foundation, dict) else None,
        "static_manifest_contract": manifest.get("contract") if isinstance(manifest, dict) else None,
    }

    fingerprint_payload = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    payload["fingerprint"] = hashlib.sha256(fingerprint_payload.encode("utf-8")).hexdigest()

    target = output / "research_catalog.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return payload


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Build the local NBA research/data coverage catalog.")
    parser.add_argument(
        "--output",
        default=str(ROOT / "web" / "data" / "nba_static"),
        help="Compiled NBA static output directory.",
    )
    args = parser.parse_args()
    result = build_research_catalog(Path(args.output))
    summary = result["summary"]
    print(
        "NBA research catalog: "
        f"{summary['dataset_families']} families; "
        f"{summary['available']} available; "
        f"{summary['partial']} partial; "
        f"{summary['missing']} missing"
    )
