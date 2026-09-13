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
            "Normalize source-backed three-point totals in already-built static "
            "NBA season shards and player dossiers. No network requests are performed."
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


def normalize_row(row: dict[str, Any]) -> bool:
    changed = False
    for canonical, aliases in THREE_POINT_ALIASES.items():
        current = row.get(canonical)
        value = _first(row, aliases)
        if not _present(current) and _present(value):
            row[canonical] = value
            changed = True

    made = _number(row.get("three_pointers_made"))
    attempts = row.get("three_point_attempts")
    percentage = row.get("three_point_percentage")

    # Repair the impossible import shape 3PM=0, 3PA>0, 3P%>0 only when the
    # source-backed attempts + rounded percentage identify exactly one integer
    # made-shot total. Ambiguous rows stay untouched.
    if (
        (made is None or made == 0)
        and (_number(attempts) or 0) > 0
        and (_ratio_value(percentage) or 0) > 0
    ):
        inferred = _infer_integer_makes(attempts, percentage)
        if inferred is not None:
            row["three_pointers_made"] = inferred
            changed = True

    canonical_made = row.get("three_pointers_made")
    if _present(canonical_made):
        current = _number(row.get("three_pm"))
        if current is None or (
            current == 0 and (_number(canonical_made) or 0) > 0
        ):
            row["three_pm"] = canonical_made
            changed = True
    if not _present(row.get("three_pa")) and _present(row.get("three_point_attempts")):
        row["three_pa"] = row["three_point_attempts"]
        changed = True
    if not _present(row.get("three_pct")) and _present(row.get("three_point_percentage")):
        row["three_pct"] = row["three_point_percentage"]
        changed = True
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
                "contract": "sports-terminal-static-three-point-normalization-v3",
                "season_files_scanned": season_files_scanned,
                "season_files_changed": season_files_changed,
                "dossier_files_scanned": dossier_files_scanned,
                "dossier_files_changed": dossier_files_changed,
                "rows_changed": rows_changed,
                "source_labels": ["3P", "3PA", "3P%"],
                "repair_policy": "unique-integer-from-source-attempts-and-rounded-percentage",
                "network_requests": 0,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
