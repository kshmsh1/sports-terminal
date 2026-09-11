from __future__ import annotations

import argparse
import inspect
import json
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]

DATASET_FUNCTIONS: dict[str, tuple[str, ...]] = {
    "pbp": ("load_nba_pbp",),
    "schedule": ("load_nba_schedule",),
    "team_box": ("load_nba_team_box",),
    "player_box": ("load_nba_player_box",),
    "standings": ("load_nba_standings",),
    "rosters": ("load_nba_rosters",),
    "player_stats": ("load_nba_player_stats",),
    "team_stats": ("load_nba_team_stats",),
    "shots": ("load_nba_shots",),
    "player_impact": ("load_nba_player_impact",),
    "player_core": ("load_nba_player_core",),
    "officials": ("load_nba_officials",),
    "draft": ("load_nba_draft",),
    "stats_pbp": ("load_nba_stats_pbp",),
    "stats_possessions": ("load_nba_stats_possessions",),
    "stats_lineups": ("load_nba_stats_lineups",),
    "stats_shots": ("load_nba_stats_shots",),
    "stats_rosters": ("load_nba_stats_rosters",),
    "stats_boxscores": ("load_nba_stats_boxscores", "load_nba_stats_box_scores"),
    "stats_game_logs": ("load_nba_stats_game_logs",),
    "stats_leaguedash": ("load_nba_stats_leaguedash",),
    "stats_standings": ("load_nba_stats_standings",),
    "stats_officials": ("load_nba_stats_officials",),
    "stats_coaches": ("load_nba_stats_coaches",),
    "stats_draft": ("load_nba_stats_draft",),
}

DEFAULT_DATASETS = (
    "schedule",
    "team_box",
    "player_box",
    "rosters",
    "standings",
    "player_stats",
    "team_stats",
)

def _season_values(raw: str) -> list[int]:
    values: set[int] = set()
    for token in (piece.strip() for piece in raw.split(",") if piece.strip()):
        if ":" in token:
            start_raw, end_raw = token.split(":", 1)
            start = int(start_raw)
            end = int(end_raw)
            if end < start:
                start, end = end, start
            values.update(range(start, end + 1))
        else:
            values.add(int(token))
    if not values:
        raise ValueError("No seasons were supplied.")
    return sorted(values)

def _resolve_function(module: Any, dataset: str) -> tuple[str, Callable[..., Any]]:
    names = DATASET_FUNCTIONS.get(dataset)
    if not names:
        raise KeyError(f"Unknown dataset: {dataset}")
    for name in names:
        candidate = getattr(module, name, None)
        if callable(candidate):
            return name, candidate
    raise AttributeError(
        f"Installed sportsdataverse does not expose a supported loader for {dataset}: "
        + ", ".join(names)
    )

def _row_count(value: Any) -> int | None:
    try:
        return int(len(value))
    except Exception:
        return None

def _write_frame(value: Any, target: Path) -> tuple[str, int | None]:
    target.parent.mkdir(parents=True, exist_ok=True)

    if hasattr(value, "write_parquet") and callable(value.write_parquet):
        value.write_parquet(target)
        return target.name, _row_count(value)

    if hasattr(value, "to_parquet") and callable(value.to_parquet):
        value.to_parquet(target, index=False)
        return target.name, _row_count(value)

    if isinstance(value, dict):
        json_target = target.with_suffix(".json")
        payload: dict[str, Any] = {}
        row_count = 0
        counted = False
        for key, item in value.items():
            if hasattr(item, "to_dicts") and callable(item.to_dicts):
                payload[str(key)] = item.to_dicts()
                row_count += len(payload[str(key)])
                counted = True
            elif hasattr(item, "to_dict") and callable(item.to_dict):
                try:
                    payload[str(key)] = item.to_dict(orient="records")
                except TypeError:
                    payload[str(key)] = item.to_dict()
                try:
                    row_count += len(item)
                    counted = True
                except Exception:
                    pass
            else:
                payload[str(key)] = item
        json_target.write_text(
            json.dumps(payload, indent=2, ensure_ascii=False, default=str) + "\n",
            encoding="utf-8",
        )
        return json_target.name, row_count if counted else None

    if hasattr(value, "to_dicts") and callable(value.to_dicts):
        json_target = target.with_suffix(".json")
        rows = value.to_dicts()
        json_target.write_text(
            json.dumps(rows, indent=2, ensure_ascii=False, default=str) + "\n",
            encoding="utf-8",
        )
        return json_target.name, len(rows)

    if hasattr(value, "to_dict") and callable(value.to_dict):
        json_target = target.with_suffix(".json")
        try:
            rows = value.to_dict(orient="records")
        except TypeError:
            rows = value.to_dict()
        json_target.write_text(
            json.dumps(rows, indent=2, ensure_ascii=False, default=str) + "\n",
            encoding="utf-8",
        )
        return json_target.name, _row_count(value)

    json_target = target.with_suffix(".json")
    json_target.write_text(
        json.dumps(value, indent=2, ensure_ascii=False, default=str) + "\n",
        encoding="utf-8",
    )
    return json_target.name, _row_count(value)

def _call_loader(loader: Callable[..., Any], seasons: list[int]) -> Any:
    parameters = inspect.signature(loader).parameters
    kwargs: dict[str, Any] = {}
    if "seasons" in parameters:
        kwargs["seasons"] = seasons
    elif "season" in parameters and len(seasons) == 1:
        kwargs["season"] = seasons[0]
    elif "years" in parameters:
        kwargs["years"] = seasons
    elif seasons:
        raise TypeError(
            f"{loader.__name__} does not expose a seasons/season/years argument; "
            "run this dataset through its provider-specific loader instead."
        )

    if "return_as_pandas" in parameters:
        kwargs["return_as_pandas"] = False

    return loader(**kwargs)

def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Download selected prebuilt SportsDataverse NBA release datasets into "
            "Sports Terminal raw storage. This is an explicit acquisition command; "
            "the website never invokes it at runtime."
        )
    )
    parser.add_argument(
        "--seasons",
        help="Season end years, e.g. 2024 or 2022:2025 or 2022,2024,2025.",
    )
    parser.add_argument(
        "--dataset",
        action="append",
        choices=sorted(DATASET_FUNCTIONS),
        help="Dataset to import. Repeat for multiple datasets.",
    )
    parser.add_argument(
        "--output",
        default=str(ROOT / "raw" / "sportsdataverse" / "nba"),
    )
    parser.add_argument("--list", action="store_true", help="List supported dataset aliases.")
    parser.add_argument(
        "--all-defaults",
        action="store_true",
        help="Import the practical default release bundle (schedule/boxes/rosters/standings/season stats).",
    )
    args = parser.parse_args()

    if args.list:
        for key in sorted(DATASET_FUNCTIONS):
            print(f"{key:24} {' | '.join(DATASET_FUNCTIONS[key])}")
        return 0

    if not args.seasons:
        parser.error("--seasons is required unless --list is used.")

    datasets = list(args.dataset or ())
    if args.all_defaults:
        for dataset in DEFAULT_DATASETS:
            if dataset not in datasets:
                datasets.append(dataset)
    if not datasets:
        parser.error("Choose at least one --dataset or use --all-defaults.")

    seasons = _season_values(args.seasons)
    output = Path(args.output).expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)

    try:
        import sportsdataverse as sdv
    except Exception as exc:
        raise SystemExit(
            "sportsdataverse is not installed in this environment. Install it only for "
            "explicit acquisition (for example: python3 -m pip install sportsdataverse), "
            "then rerun this command. It is intentionally not a Sports Terminal runtime dependency."
        ) from exc

    records: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []

    for dataset in datasets:
        try:
            function_name, loader = _resolve_function(sdv, dataset)
            print(
                f"Importing SportsDataverse NBA {dataset} "
                f"for season end years {seasons[0]}-{seasons[-1]} via {function_name}"
            )
            value = _call_loader(loader, seasons)
            dataset_dir = output / dataset
            file_name, rows = _write_frame(
                value,
                dataset_dir / f"{seasons[0]}_{seasons[-1]}.parquet",
            )
            records.append(
                {
                    "dataset": dataset,
                    "loader": function_name,
                    "seasons": seasons,
                    "file": str((dataset_dir / file_name).relative_to(output)),
                    "rows": rows,
                }
            )
        except Exception as exc:
            failures.append(
                {
                    "dataset": dataset,
                    "seasons": seasons,
                    "error": f"{type(exc).__name__}: {exc}",
                }
            )
            print(f"FAILED {dataset}: {type(exc).__name__}: {exc}")

    manifest_path = output / "manifest.json"
    previous = {}
    if manifest_path.is_file():
        try:
            previous = json.loads(manifest_path.read_text(encoding="utf-8"))
        except Exception:
            previous = {}
    existing = list(previous.get("datasets") or []) if isinstance(previous, dict) else []
    by_key: dict[tuple[str, tuple[int, ...]], dict[str, Any]] = {
        (str(item.get("dataset")), tuple(item.get("seasons") or ())): item
        for item in existing
        if isinstance(item, dict)
    }
    for record in records:
        by_key[(record["dataset"], tuple(record["seasons"]))] = record

    manifest = {
        "contract": "sports-terminal-sportsdataverse-nba-import-v1",
        "source": "SportsDataverse release datasets",
        "runtime_dependency": False,
        "season_semantics": "integer values are season end years (2024 = 2023-24)",
        "datasets": sorted(
            by_key.values(),
            key=lambda item: (str(item.get("dataset")), tuple(item.get("seasons") or ())),
        ),
        "last_failures": failures,
    }
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(
        f"SportsDataverse import complete: {len(records)} datasets written; "
        f"{len(failures)} failures; manifest={manifest_path}"
    )
    return 1 if failures and not records else 0

if __name__ == "__main__":
    raise SystemExit(main())
