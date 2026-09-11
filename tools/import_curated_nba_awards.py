from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = "sports-terminal-curated-nba-awards-v1"
SEASON_RE = re.compile(r"^(\d{4})-(\d{2})$")

AWARD_ALIASES = {
    "1st team all-nba": ("all_nba_first", "First-Team All-NBA"),
    "first team all-nba": ("all_nba_first", "First-Team All-NBA"),
    "2nd team all-nba": ("all_nba_second", "Second-Team All-NBA"),
    "second team all-nba": ("all_nba_second", "Second-Team All-NBA"),
    "3rd team all-nba": ("all_nba_third", "Third-Team All-NBA"),
    "third team all-nba": ("all_nba_third", "Third-Team All-NBA"),
    "1st team all-defense": ("all_defense_first", "First-Team All-Defense"),
    "first team all-defense": ("all_defense_first", "First-Team All-Defense"),
    "2nd team all-defense": ("all_defense_second", "Second-Team All-Defense"),
    "second team all-defense": ("all_defense_second", "Second-Team All-Defense"),
    "1st team all-rookie": ("all_rookie_first", "First-Team All-Rookie"),
    "first team all-rookie": ("all_rookie_first", "First-Team All-Rookie"),
    "2nd team all-rookie": ("all_rookie_second", "Second-Team All-Rookie"),
    "second team all-rookie": ("all_rookie_second", "Second-Team All-Rookie"),
}


def _season_valid(value: str) -> bool:
    match = SEASON_RE.fullmatch(value)
    if match is None:
        return False
    start = int(match.group(1))
    return int(match.group(2)) == (start + 1) % 100


def _bool(value: Any, default: bool = True) -> bool:
    if isinstance(value, bool):
        return value
    text = str(value or "").strip().lower()
    if not text:
        return default
    return text not in {"0", "false", "no", "n"}


def _slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")


def _normalize_row(raw: dict[str, Any]) -> dict[str, Any]:
    season_id = str(raw.get("season_id") or raw.get("season") or "").strip()
    player_name = str(raw.get("player_name") or raw.get("player") or "").strip()
    award = str(raw.get("award") or raw.get("award_name") or raw.get("honor") or "").strip()
    award_key = str(raw.get("award_key") or "").strip().lower()
    selection_team = str(raw.get("selection_team") or raw.get("tier") or "").strip()

    alias = AWARD_ALIASES.get(award.lower())
    if alias is not None:
        award_key, award = alias
    elif not award_key:
        award_key = _slug(award)

    if not _season_valid(season_id):
        raise ValueError(f"invalid one-year season_id: {season_id!r}")
    if not player_name:
        raise ValueError("player_name is required")
    if not award or not award_key:
        raise ValueError("award / award_key is required")

    return {
        "league_id": "NBA",
        "season_id": season_id,
        "award_key": award_key,
        "award": award,
        "award_name": award,
        "player_name": player_name,
        "winner": _bool(raw.get("winner"), True),
        "selected": _bool(raw.get("selected"), bool(selection_team)),
        "player_honor": _bool(raw.get("player_honor"), True),
        "source_key": str(raw.get("source_key") or "curated_nba_awards_import").strip(),
        "curated_static_import": True,
        **(
            {"team_text": str(raw.get("team_text") or raw.get("team") or "").strip()}
            if str(raw.get("team_text") or raw.get("team") or "").strip()
            else {}
        ),
        **(
            {
                "selection_team": selection_team,
                "rank_text": selection_team,
            }
            if selection_team
            else {}
        ),
    }


def _load(path: Path) -> list[dict[str, Any]]:
    suffix = path.suffix.lower()
    if suffix == ".csv":
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            return [dict(row) for row in csv.DictReader(handle)]
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict):
        payload = payload.get("rows") or payload.get("awards") or payload.get("data") or []
    if not isinstance(payload, list):
        raise ValueError("JSON input must be a list or an object containing rows/awards/data")
    return [dict(row) for row in payload if isinstance(row, dict)]


def _key(row: dict[str, Any]) -> tuple[str, str, str, str]:
    return (
        str(row.get("season_id") or ""),
        str(row.get("award_key") or ""),
        re.sub(r"[^a-z0-9]+", "", str(row.get("player_name") or "").lower()),
        str(row.get("selection_team") or "").lower(),
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Normalize a curated CSV/JSON NBA awards table into Sports Terminal's "
            "static award supplement contract. This is the preferred path for large "
            "All-NBA / All-Defense / All-Rookie histories where tier fidelity matters."
        )
    )
    parser.add_argument("input", help="CSV or JSON award rows")
    parser.add_argument(
        "--output",
        default=str(ROOT / "raw" / "curated" / "nba_awards.json"),
    )
    args = parser.parse_args()

    source = Path(args.input).expanduser().resolve()
    output = Path(args.output).expanduser().resolve()
    raw_rows = _load(source)

    rows: list[dict[str, Any]] = []
    errors: list[str] = []
    seen: set[tuple[str, str, str, str]] = set()
    for index, raw in enumerate(raw_rows, 1):
        try:
            row = _normalize_row(raw)
            key = _key(row)
            if key in seen:
                continue
            seen.add(key)
            rows.append(row)
        except Exception as exc:
            errors.append(f"row {index}: {type(exc).__name__}: {exc}")

    rows.sort(
        key=lambda row: (
            str(row.get("season_id") or ""),
            str(row.get("award_key") or ""),
            str(row.get("player_name") or ""),
        )
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(
            {
                "contract": CONTRACT,
                "source_file": source.name,
                "runtime_dependency": False,
                "rows": rows,
                "validation_errors": errors,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    print(
        f"Curated NBA awards import: {len(rows)} rows; "
        f"{len(errors)} validation errors; output={output}"
    )
    for error in errors[:25]:
        print(f"WARN: {error}")
    return 0 if rows and not errors else 1 if not rows else 0


if __name__ == "__main__":
    raise SystemExit(main())
