from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"

THREE_POINT_ALIASES: dict[str, tuple[str, ...]] = {
    "three_pointers_made": (
        "three_pointers_made",
        "three_pm",
        "fg3",
        "3P",
        "3p",
    ),
    "three_point_attempts": (
        "three_point_attempts",
        "three_pa",
        "fg3a",
        "3PA",
        "3pa",
    ),
    "three_point_percentage": (
        "three_point_percentage",
        "three_pct",
        "three_point_pct",
        "fg3_pct",
        "3P%",
        "3p%",
        "3P_pct",
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Normalize and repair source-backed three-point totals in already-built "
            "static NBA season shards and player dossiers. No network requests are performed."
        )
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    return parser.parse_args()


def _present(value: Any) -> bool:
    return value is not None and str(value).strip() != ""


def _number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        result = float(value)
        return result if math.isfinite(result) else None
    text = str(value).strip().replace(",", "").replace("%", "")
    if not text:
        return None
    try:
        result = float(text)
    except ValueError:
        return None
    return result if math.isfinite(result) else None


def _first(row: dict[str, Any], aliases: tuple[str, ...]) -> Any:
    for alias in aliases:
        if _present(row.get(alias)):
            return row[alias]
    return None


def _ratio_value(value: Any) -> float | None:
    number = _number(value)
    if number is None:
        return None
    return number / 100.0 if abs(number) > 1.5 else number


def _near_integer(value: float, *, tolerance: float = 1e-6) -> int | None:
    rounded = int(round(value))
    return rounded if abs(value - rounded) <= tolerance else None


def _derived_makes_from_scoring(row: dict[str, Any]) -> int | None:
    # Exact basketball identity for season totals:
    # PTS = 2 * FGM + 3PM + FTM.
    points = _number(_first(row, ("points", "pts")))
    fgm = _number(_first(row, ("field_goals_made", "fgm", "fg")))
    ftm = _number(_first(row, ("free_throws_made", "ftm", "ft")))
    if points is None or fgm is None or ftm is None:
        return None
    made = _near_integer(points - (2.0 * fgm) - ftm)
    if made is None or made < 0 or made > int(round(fgm)):
        return None
    return made


def _derived_attempts_from_two_point_attempts(row: dict[str, Any]) -> int | None:
    # Exact attempt identity when 2PA is source-backed: FGA = 2PA + 3PA.
    fga = _number(_first(row, ("field_goal_attempts", "fga")))
    two_pa = _number(_first(row, ("two_point_attempts", "two_pa", "fg2a")))
    if fga is None or two_pa is None:
        return None
    attempts = _near_integer(fga - two_pa)
    if attempts is None or attempts < 0 or attempts > int(round(fga)):
        return None
    return attempts


def _infer_integer_makes(attempts: Any, percentage: Any) -> int | None:
    attempts_number = _number(attempts)
    percentage_number = _ratio_value(percentage)
    if attempts_number is None or attempts_number <= 0 or percentage_number is None:
        return None
    attempts_int = int(round(attempts_number))
    estimate = attempts_int * percentage_number
    lower = max(0, int(math.floor(estimate)) - 2)
    upper = min(attempts_int, int(math.ceil(estimate)) + 2)
    target = round(percentage_number, 3)
    matches = [
        made
        for made in range(lower, upper + 1)
        if round(made / attempts_int, 3) == target
    ]
    return matches[0] if len(matches) == 1 else None


def _replace_if_different(row: dict[str, Any], key: str, value: Any) -> bool:
    if value is None:
        return False
    current = _number(row.get(key))
    candidate = _number(value)
    if candidate is not None and current is not None and abs(current - candidate) <= 1e-9:
        return False
    if candidate is None and row.get(key) == value:
        return False
    row[key] = value
    return True


def normalize_row(row: dict[str, Any]) -> bool:
    changed = False
    for canonical, aliases in THREE_POINT_ALIASES.items():
        if not _present(row.get(canonical)):
            value = _first(row, aliases)
            if _present(value):
                row[canonical] = value
                changed = True

    made = _number(row.get("three_pointers_made"))
    attempts = _number(row.get("three_point_attempts"))
    percentage = _ratio_value(row.get("three_point_percentage"))

    # Prefer exact identities from other source-backed box-score totals. This
    # repairs the observed bad import shape where 3P was materialized as 0.0
    # even though PTS/FGM/FTM and the source PDF imply a nonzero integer total.
    exact_made = _derived_makes_from_scoring(row)
    if exact_made is not None and (made is None or abs(made - exact_made) > 1e-9):
        row["three_pointers_made"] = exact_made
        made = float(exact_made)
        changed = True

    exact_attempts = _derived_attempts_from_two_point_attempts(row)
    if exact_attempts is not None and (
        attempts is None or abs(attempts - exact_attempts) > 1e-9
    ):
        row["three_point_attempts"] = exact_attempts
        attempts = float(exact_attempts)
        changed = True

    # If the exact scoring identity is unavailable, the published rounded 3P%
    # may still identify one and only one integer make total.
    if (made is None or made == 0) and (attempts or 0) > 0 and (percentage or 0) > 0:
        inferred = _infer_integer_makes(attempts, percentage)
        if inferred is not None:
            row["three_pointers_made"] = inferred
            made = float(inferred)
            changed = True

    # Once exact makes/attempts are known, percentage is deterministic. This
    # also fixes rows where a stale/misaligned percentage survived canonical import.
    if made is not None and attempts is not None and attempts > 0:
        exact_pct = made / attempts
        if percentage is None or abs(percentage - exact_pct) > 0.0005:
            row["three_point_percentage"] = exact_pct
            percentage = exact_pct
            changed = True
    elif made == 0 and attempts == 0:
        row["three_point_percentage"] = None

    canonical_made = row.get("three_pointers_made")
    canonical_attempts = row.get("three_point_attempts")
    canonical_pct = row.get("three_point_percentage")
    changed = _replace_if_different(row, "three_pm", canonical_made) or changed
    changed = _replace_if_different(row, "three_pa", canonical_attempts) or changed
    if canonical_pct is not None:
        changed = _replace_if_different(row, "three_pct", canonical_pct) or changed
    return changed


def _normalize_rows(value: Any) -> int:
    if not isinstance(value, list):
        return 0
    changed = 0
    for row in value:
        if isinstance(row, dict) and normalize_row(row):
            changed += 1
    return changed


def _write(path: Path, payload: Any) -> None:
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    temp.replace(path)


def _normalize_file(path: Path, row_lists: tuple[str, ...]) -> int:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return 0
    if not isinstance(payload, dict):
        return 0
    changed = sum(_normalize_rows(payload.get(key)) for key in row_lists)
    if changed:
        _write(path, payload)
    return changed


def main() -> int:
    args = parse_args()
    output = Path(args.output).expanduser().resolve()
    seasons_root = output / "seasons"
    players_root = output / "players"
    if not seasons_root.is_dir():
        raise SystemExit(f"Static NBA season corpus is missing: {seasons_root}")

    season_files_scanned = 0
    season_files_changed = 0
    dossier_files_scanned = 0
    dossier_files_changed = 0
    rows_changed = 0

    for path in sorted(seasons_root.glob("*/regular.json")):
        season_files_scanned += 1
        changed = _normalize_file(path, ("player_season_totals",))
        if changed:
            season_files_changed += 1
            rows_changed += changed

    if players_root.is_dir():
        for path in sorted(players_root.glob("*.json")):
            if path.name == "index.json":
                continue
            dossier_files_scanned += 1
            changed = _normalize_file(path, ("regular_seasons", "seasons"))
            if changed:
                dossier_files_changed += 1
                rows_changed += changed

    print(
        json.dumps(
            {
                "contract": "sports-terminal-static-three-point-normalization-v4",
                "season_files_scanned": season_files_scanned,
                "season_files_changed": season_files_changed,
                "dossier_files_scanned": dossier_files_scanned,
                "dossier_files_changed": dossier_files_changed,
                "rows_changed": rows_changed,
                "source_labels": ["3P", "3PA", "3P%"],
                "repair_policy": "exact-box-score-identities-then-unique-rounded-percentage",
                "network_requests": 0,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
