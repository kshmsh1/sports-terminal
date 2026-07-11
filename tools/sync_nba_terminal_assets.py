from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_SEED = "data/terminal_seed/nba_2025"
DEFAULT_ASSET_OUTPUT = "assets/data/nba/terminal_seed/nba_2025"
REQUIRED_FILES = [
    "manifest.json",
    "teams.json",
    "players.json",
    "games.json",
    "team_records.json",
    "team_game_logs.json",
    "player_season_totals.json",
    "player_leaders.json",
    "player_game_highs.json",
    "player_game_logs_top.json",
    "search_index.json",
    "data_dictionary.json",
    "validation_report.json",
]
OPTIONAL_FILES = ["pipeline_report.json"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Copy validated NBA terminal seed JSON into Flutter asset space. "
            "This makes no network requests and is safe to rerun."
        )
    )
    parser.add_argument("--seed", default=DEFAULT_SEED)
    parser.add_argument("--asset-output", default=DEFAULT_ASSET_OUTPUT)
    parser.add_argument("--clean", action="store_true", help="Remove existing JSON files in the asset directory before copying.")
    return parser.parse_args()


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_seed(seed: Path) -> None:
    missing = [filename for filename in REQUIRED_FILES if not (seed / filename).exists()]
    if missing:
        raise FileNotFoundError(f"Validated seed is missing required files: {missing}")
    validation = load_json(seed / "validation_report.json")
    if isinstance(validation, dict) and validation.get("status") != "pass":
        raise RuntimeError(f"Seed validation report is not pass: {validation.get('status')}")


def copy_seed(seed: Path, asset_output: Path, *, clean: bool) -> dict[str, object]:
    validate_seed(seed)
    asset_output.mkdir(parents=True, exist_ok=True)
    if clean:
        for path in asset_output.glob("*.json"):
            path.unlink()
    copied = []
    for filename in [*REQUIRED_FILES, *OPTIONAL_FILES]:
        source = seed / filename
        if source.exists():
            target = asset_output / filename
            shutil.copy2(source, target)
            copied.append(filename)
    asset_manifest = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sourceSeed": str(seed),
        "assetOutput": str(asset_output),
        "copiedFiles": copied,
        "usage": "Flutter asset mirror of the validated local NBA terminal seed.",
    }
    (asset_output / "asset_manifest.json").write_text(
        json.dumps(asset_manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    return asset_manifest


def main() -> int:
    args = parse_args()
    result = copy_seed(Path(args.seed), Path(args.asset_output), clean=args.clean)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
