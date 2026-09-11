from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SEASON_RE = re.compile(r"^(\d{4})-(\d{2})$")


def _load_json(path: Path) -> Any:
    raw = path.read_text(encoding="utf-8")
    stripped = raw.lstrip()
    if stripped.startswith("<"):
        raise ValueError("HTML document found where JSON was expected")
    return json.loads(raw)


def _season_is_valid(value: str) -> bool:
    match = SEASON_RE.fullmatch(value)
    if match is None:
        return False
    start = int(match.group(1))
    end = int(match.group(2))
    return end == (start + 1) % 100


def _map_list(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [dict(item) for item in value if isinstance(item, dict)]


def _numeric(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        number = float(value)
        return number if math.isfinite(number) else None
    try:
        number = float(str(value).strip())
        return number if math.isfinite(number) else None
    except Exception:
        return None


def _candidate_rows(payload: dict[str, Any]) -> list[dict[str, Any]]:
    candidates = []
    for key in (
        "player_season_totals",
        "players",
        "rows",
        "player_rows",
        "playerStats",
        "player_stats",
    ):
        candidates.extend(_map_list(payload.get(key)))
    return candidates


def _check_rate_sanity(rows: list[dict[str, Any]], path: Path, errors: list[str], warnings: list[str]) -> None:
    for index, row in enumerate(rows[:5000]):
        label = str(row.get("player_name") or row.get("name") or row.get("PLAYER_NAME") or f"row {index}")
        gp = _numeric(row.get("gp") if "gp" in row else row.get("GP"))
        mpg = _numeric(row.get("mpg") if "mpg" in row else row.get("MPG"))
        ppg = _numeric(row.get("ppg") if "ppg" in row else row.get("PPG"))
        if gp is not None and (gp < 0 or gp > 90):
            errors.append(f"{path}: implausible GP={gp:g} for {label}")
        if mpg is not None and (mpg < 0 or mpg > 60):
            errors.append(f"{path}: implausible MPG={mpg:g} for {label}")
        if ppg is not None and (ppg < 0 or ppg > 100):
            errors.append(f"{path}: implausible PPG={ppg:g} for {label}")

        for pct_key in (
            "fg_pct",
            "three_pct",
            "fg3_pct",
            "ft_pct",
            "efg_pct",
            "ts_pct",
            "FG_PCT",
            "FG3_PCT",
            "FT_PCT",
        ):
            pct = _numeric(row.get(pct_key))
            if pct is None:
                continue
            # Source families use either 0-1 or 0-100 conventions. Anything
            # above 100 is necessarily corrupt at this layer.
            if pct < 0 or pct > 100:
                errors.append(f"{path}: implausible {pct_key}={pct:g} for {label}")


def validate(root: Path) -> dict[str, Any]:
    root = root.expanduser().resolve()
    errors: list[str] = []
    warnings: list[str] = []
    checked_files = 0

    manifest_path = root / "manifest.json"
    seasons_path = root / "seasons.json"
    if not manifest_path.is_file():
        errors.append(f"Missing {manifest_path}")
    if not seasons_path.is_file():
        errors.append(f"Missing {seasons_path}")

    try:
        manifest = _load_json(manifest_path) if manifest_path.is_file() else {}
        checked_files += int(manifest_path.is_file())
    except Exception as exc:
        errors.append(f"{manifest_path}: {type(exc).__name__}: {exc}")
        manifest = {}

    try:
        seasons = _map_list(_load_json(seasons_path)) if seasons_path.is_file() else []
        checked_files += int(seasons_path.is_file())
    except Exception as exc:
        errors.append(f"{seasons_path}: {type(exc).__name__}: {exc}")
        seasons = []

    seen: set[str] = set()
    for row in seasons:
        season_id = str(row.get("season_id") or row.get("id") or "")
        if not season_id:
            errors.append("Season catalog row has no season_id")
            continue
        if season_id in seen:
            errors.append(f"Duplicate season in catalog: {season_id}")
        seen.add(season_id)
        if not _season_is_valid(season_id):
            errors.append(f"Malformed season id: {season_id}")

        for season_type in ("regular", "playoffs"):
            shard = root / "seasons" / season_id / f"{season_type}.json"
            if not shard.is_file():
                errors.append(f"Missing season shard: {shard}")
                continue
            try:
                payload = _load_json(shard)
                checked_files += 1
            except Exception as exc:
                errors.append(f"{shard}: {type(exc).__name__}: {exc}")
                continue
            if not isinstance(payload, dict):
                errors.append(f"{shard}: expected object payload")
                continue
            _check_rate_sanity(_candidate_rows(payload), shard, errors, warnings)

    for relative in (
        "players/index.json",
        "teams/index.json",
        "games/index.json",
        "history/awards.json",
        "history/draft.json",
        "data_foundation.json",
        "research_catalog.json",
    ):
        path = root / relative
        if not path.is_file():
            warnings.append(f"Optional static document not present: {path}")
            continue
        try:
            _load_json(path)
            checked_files += 1
        except Exception as exc:
            errors.append(f"{path}: {type(exc).__name__}: {exc}")

    if isinstance(manifest, dict):
        contract = str(manifest.get("contract") or manifest.get("schema") or "")
        if not contract:
            warnings.append("Static manifest has no contract/schema identifier")

    return {
        "contract": "sports-terminal-static-nba-validation-v2",
        "root": str(root),
        "checked_files": checked_files,
        "season_count": len(seasons),
        "errors": errors,
        "warnings": warnings,
        "ok": not errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate the compiled static NBA website corpus before launching Flutter Web."
    )
    parser.add_argument(
        "--root",
        default=str(ROOT / "web" / "data" / "nba_static"),
        help="Compiled NBA static directory.",
    )
    parser.add_argument(
        "--report",
        help="Optional JSON report path.",
    )
    args = parser.parse_args()

    result = validate(Path(args.root))
    if args.report:
        report = Path(args.report).expanduser().resolve()
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(
        f"Static NBA validation: {result['checked_files']} files; "
        f"{result['season_count']} seasons; "
        f"{len(result['errors'])} errors; {len(result['warnings'])} warnings"
    )
    for message in result["errors"]:
        print(f"ERROR: {message}")
    for message in result["warnings"][:25]:
        print(f"WARN: {message}")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
