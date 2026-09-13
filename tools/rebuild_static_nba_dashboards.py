from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Refresh lightweight NBA dashboard leader rows from the already-built "
            "static season shards. This never downloads sports data."
        )
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    return parser.parse_args()


def number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def player_id(row: dict[str, Any]) -> str:
    return str(row.get("player_id") or row.get("player_key") or "").strip()


def player_name(row: dict[str, Any]) -> str:
    return str(row.get("player_name") or row.get("player_label") or "").strip()


def per_game(row: dict[str, Any], total_key: str, direct_key: str) -> float | None:
    direct = number(row.get(direct_key))
    if direct is not None:
        return direct
    total = number(row.get(total_key))
    games = number(row.get("games") or row.get("gp"))
    if total is None or games is None or games <= 0:
        return None
    return total / games


def deflection_leaders(rows: list[dict[str, Any]], limit: int = 10) -> list[dict[str, Any]]:
    ranked: list[tuple[float, dict[str, Any]]] = []
    for row in rows:
        value = per_game(row, "deflections", "deflections_pg")
        pid = player_id(row)
        if value is None or not pid:
            continue
        ranked.append((value, row))
    ranked.sort(key=lambda item: item[0], reverse=True)
    return [
        {
            "rank": index,
            "value": round(value, 3),
            "player_id": player_id(row),
            "player_name": player_name(row),
            "team_id": row.get("team_id"),
            "team": row.get("team_ids") or row.get("team") or "",
            "position": row.get("positions") or row.get("position") or "",
        }
        for index, (value, row) in enumerate(ranked[:limit], start=1)
    ]


def main() -> int:
    args = parse_args()
    output = Path(args.output).expanduser().resolve()
    dashboards = output / "dashboard"
    seasons = output / "seasons"
    if not dashboards.is_dir() or not seasons.is_dir():
        raise SystemExit(f"Static NBA corpus is incomplete under {output}")

    updated = 0
    for dashboard_path in sorted(dashboards.glob("*.json")):
        season_id = dashboard_path.stem
        regular_path = seasons / season_id / "regular.json"
        if not regular_path.is_file():
            continue
        try:
            dashboard = json.loads(dashboard_path.read_text(encoding="utf-8"))
            regular = json.loads(regular_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        raw_rows = regular.get("player_season_totals")
        rows = [row for row in raw_rows if isinstance(row, dict)] if isinstance(raw_rows, list) else []
        leaders = dashboard.get("leaders")
        if not isinstance(leaders, dict):
            leaders = {}
            dashboard["leaders"] = leaders
        leaders["deflections"] = deflection_leaders(rows)

        compact = dashboard.get("players")
        if isinstance(compact, list):
            deflections_by_id = {
                player_id(row): per_game(row, "deflections", "deflections_pg")
                for row in rows
                if player_id(row)
            }
            for player in compact:
                if not isinstance(player, dict):
                    continue
                value = deflections_by_id.get(str(player.get("player_id") or ""))
                if value is not None:
                    player["deflections_pg"] = round(value, 3)

        temp = dashboard_path.with_suffix(".json.tmp")
        temp.write_text(
            json.dumps(dashboard, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        temp.replace(dashboard_path)
        updated += 1

    print(
        json.dumps(
            {
                "contract": "sports-terminal-static-dashboard-refresh-v1",
                "dashboards_updated": updated,
                "network_requests": 0,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
