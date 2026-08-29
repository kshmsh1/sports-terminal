from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_ROOTS = (ROOT / "raw/nba_com_stats", ROOT.parent / "raw/nba_com_stats")
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"
SURFACES = ("lineups_base", "lineups_advanced")
GROUP_QUANTITIES = (2, 3, 4, 5)


def _number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).strip().replace(",", "").replace("%", ""))
    except ValueError:
        return None


def _raw_roots(raw_roots: Iterable[Path] | None = None) -> list[Path]:
    result: list[Path] = []
    seen: set[str] = set()
    for candidate in raw_roots or DEFAULT_RAW_ROOTS:
        path = Path(candidate).expanduser().resolve()
        if not path.is_dir() or str(path) in seen:
            continue
        seen.add(str(path))
        result.append(path)
    return result


def _season_type(folder: str) -> str:
    return "playoffs" if "play" in folder.lower() or "post" in folder.lower() else "regular"


def _surface_folder(surface: str, group_quantity: int) -> str:
    return surface if group_quantity == 5 else f"{surface}_q{group_quantity}"


def _rows(path: Path) -> list[dict[str, Any]]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return []
    tables = payload.get("tables") if isinstance(payload, dict) else None
    result: list[dict[str, Any]] = []
    if isinstance(tables, list):
        for table in tables:
            rows = table.get("rows") if isinstance(table, dict) else None
            if isinstance(rows, list):
                result.extend(row for row in rows if isinstance(row, dict))
    return result


def _normalized(row: dict[str, Any], group_quantity: int) -> dict[str, Any]:
    def pick(*keys: str) -> Any:
        for key in keys:
            if key in row and row[key] not in (None, ""):
                return row[key]
        return None

    result = dict(row)
    result.update(
        {
            "group_quantity": group_quantity,
            "group_id": str(pick("GROUP_ID", "group_id") or ""),
            "group_name": str(pick("GROUP_NAME", "group_name") or ""),
            "team_id": str(pick("TEAM_ID", "team_id") or ""),
            "team": str(pick("TEAM_ABBREVIATION", "team") or ""),
            "gp": _number(pick("GP", "gp")),
            "wins": _number(pick("W", "wins")),
            "losses": _number(pick("L", "losses")),
            "win_pct": _number(pick("W_PCT", "win_pct")),
            "min": _number(pick("MIN", "min")),
            "poss": _number(pick("POSS", "poss")),
            "off_rating": _number(pick("OFF_RATING", "off_rating")),
            "def_rating": _number(pick("DEF_RATING", "def_rating")),
            "net_rating": _number(pick("NET_RATING", "net_rating")),
            "ast_pct": _number(pick("AST_PCT", "ast_pct")),
            "ast_to": _number(pick("AST_TO", "ast_to")),
            "ast_ratio": _number(pick("AST_RATIO", "ast_ratio")),
            "oreb_pct": _number(pick("OREB_PCT", "oreb_pct")),
            "dreb_pct": _number(pick("DREB_PCT", "dreb_pct")),
            "reb_pct": _number(pick("REB_PCT", "reb_pct")),
            "tov_pct": _number(pick("TM_TOV_PCT", "tov_pct")),
            "efg_pct": _number(pick("EFG_PCT", "efg_pct")),
            "ts_pct": _number(pick("TS_PCT", "ts_pct")),
            "pace": _number(pick("PACE", "pace")),
            "pie": _number(pick("PIE", "pie")),
        }
    )
    return result


def _destination(output: Path, group_quantity: int, season: str, season_type: str) -> Path:
    if group_quantity == 5:
        # Backward-compatible path used by the first Lineup Analysis release.
        return output / "lineups" / season / f"{season_type}.json"
    return output / "lineups" / f"q{group_quantity}" / season / f"{season_type}.json"


def materialize_lineups(
    output: Path = DEFAULT_OUTPUT,
    raw_roots: Iterable[Path] | None = None,
) -> dict[str, int]:
    output = Path(output).expanduser().resolve()
    roots = _raw_roots(raw_roots)
    buckets: dict[tuple[int, str, str], dict[str, dict[str, Any]]] = {}
    capture_count = 0

    for root in roots:
        for group_quantity in GROUP_QUANTITIES:
            for surface in SURFACES:
                base = root / _surface_folder(surface, group_quantity)
                if not base.is_dir():
                    continue
                for path in base.glob("*/*/normalized.json"):
                    parts = path.relative_to(base).parts
                    if len(parts) < 3:
                        continue
                    season, folder = parts[0], parts[1]
                    season_type = _season_type(folder)
                    rows = _rows(path)
                    if not rows:
                        continue
                    capture_count += 1
                    bucket = buckets.setdefault((group_quantity, season, season_type), {})
                    for source_row in rows:
                        row = _normalized(source_row, group_quantity)
                        identity = row.get("group_id") or f"{row.get('team')}:{row.get('group_name')}"
                        if not identity:
                            continue
                        current = bucket.setdefault(str(identity), {})
                        # Base and Advanced captures complement each other; later
                        # non-null fields merge rather than replacing the object.
                        for key, value in row.items():
                            if value not in (None, ""):
                                current[key] = value

    row_count = 0
    dataset_summaries: list[dict[str, Any]] = []
    for (group_quantity, season, season_type), by_id in buckets.items():
        rows = list(by_id.values())
        rows.sort(
            key=lambda row: (
                -float(row.get("min") or 0),
                str(row.get("team") or ""),
                str(row.get("group_name") or ""),
            )
        )
        destination = _destination(output, group_quantity, season, season_type)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(
            json.dumps(rows, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        row_count += len(rows)
        dataset_summaries.append(
            {
                "group_quantity": group_quantity,
                "season": season,
                "season_type": season_type,
                "rows": len(rows),
                "path": str(destination.relative_to(output)),
            }
        )

    manifest_path = output / "lineups" / "manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(
            {
                "contract": "sports-terminal-static-lineups-v2",
                "source": "NBA.com LeagueDashLineups",
                "capture_count": capture_count,
                "row_count": row_count,
                "group_quantities": list(GROUP_QUANTITIES),
                "datasets": sorted(
                    dataset_summaries,
                    key=lambda item: (
                        -int(item["group_quantity"]),
                        str(item["season"]),
                        str(item["season_type"]),
                    ),
                ),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    return {"captures": capture_count, "rows": row_count, "datasets": len(buckets)}


if __name__ == "__main__":
    result = materialize_lineups()
    print(
        "Static NBA.com lineup materialization: "
        f"{result['captures']} captures; {result['rows']} rows; {result['datasets']} datasets"
    )
