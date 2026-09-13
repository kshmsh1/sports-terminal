from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"

# Basketball Reference regular-season totals label made threes as 3P and
# attempts as 3PA. Historical import layers can expose those same facts under
# several normalized aliases. Keep one canonical static contract for the
# Flutter Stats / Advanced Stats surfaces without fabricating unavailable eras.
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
            "NBA season shards. No network requests are performed."
        )
    )
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    return parser.parse_args()


def _present(value: Any) -> bool:
    return value is not None and str(value).strip() != ""


def _first(row: dict[str, Any], aliases: tuple[str, ...]) -> Any:
    for alias in aliases:
        if _present(row.get(alias)):
            return row[alias]
    return None


def normalize_row(row: dict[str, Any]) -> bool:
    changed = False
    for canonical, aliases in THREE_POINT_ALIASES.items():
        if _present(row.get(canonical)):
            continue
        value = _first(row, aliases)
        if not _present(value):
            continue
        row[canonical] = value
        changed = True

    # Publish the aliases consumed directly by NbaStatsWorkstationEngine too.
    if not _present(row.get("three_pm")) and _present(row.get("three_pointers_made")):
        row["three_pm"] = row["three_pointers_made"]
        changed = True
    if not _present(row.get("three_pa")) and _present(row.get("three_point_attempts")):
        row["three_pa"] = row["three_point_attempts"]
        changed = True
    if not _present(row.get("three_pct")) and _present(row.get("three_point_percentage")):
        row["three_pct"] = row["three_point_percentage"]
        changed = True
    return changed


def _write(path: Path, payload: Any) -> None:
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    temp.replace(path)


def main() -> int:
    args = parse_args()
    output = Path(args.output).expanduser().resolve()
    seasons_root = output / "seasons"
    if not seasons_root.is_dir():
        raise SystemExit(f"Static NBA season corpus is missing: {seasons_root}")

    files_scanned = 0
    files_changed = 0
    rows_changed = 0
    for path in sorted(seasons_root.glob("*/regular.json")):
        files_scanned += 1
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        raw_rows = payload.get("player_season_totals")
        if not isinstance(raw_rows, list):
            continue
        changed_here = 0
        for row in raw_rows:
            if isinstance(row, dict) and normalize_row(row):
                changed_here += 1
        if changed_here:
            _write(path, payload)
            files_changed += 1
            rows_changed += changed_here

    print(
        json.dumps(
            {
                "contract": "sports-terminal-static-three-point-normalization-v1",
                "files_scanned": files_scanned,
                "files_changed": files_changed,
                "rows_changed": rows_changed,
                "source_labels": ["3P", "3PA", "3P%"],
                "network_requests": 0,
            },
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
