from __future__ import annotations

import argparse
import dataclasses
import json
from datetime import date, datetime
from decimal import Decimal
from enum import Enum
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[1]

DATASETS: dict[str, tuple[str, str]] = {
    "schedule": ("season_schedule", "game"),
    "player_totals": ("players_season_totals", "player-season"),
    "player_advanced": ("players_advanced_season_totals", "player-season"),
    "standings": ("standings", "team-season"),
    "shooting": ("players_regular_season_shooting_statistics", "player-season-shot-zone"),
}

PLAYER_DATASETS: dict[str, tuple[str, str]] = {
    "regular_game_logs": ("regular_season_player_box_scores", "player-game"),
    "playoff_game_logs": ("playoff_player_box_scores", "player-game"),
}


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


def _jsonable(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, Enum):
        return _jsonable(value.value)
    if dataclasses.is_dataclass(value):
        return _jsonable(dataclasses.asdict(value))
    if isinstance(value, dict):
        return {str(key): _jsonable(item) for key, item in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_jsonable(item) for item in value]
    if hasattr(value, "model_dump") and callable(value.model_dump):
        return _jsonable(value.model_dump())
    if hasattr(value, "to_dict") and callable(value.to_dict):
        return _jsonable(value.to_dict())
    if hasattr(value, "__dict__"):
        return {
            key: _jsonable(item)
            for key, item in vars(value).items()
            if not key.startswith("_")
        }
    return str(value)


def _write_json(path: Path, value: Any) -> int | None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = _jsonable(value)
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    if isinstance(payload, list):
        return len(payload)
    if isinstance(payload, dict):
        return len(payload)
    return None


def _client() -> Any:
    try:
        from basketball_reference_web_scraper import client
    except Exception as exc:
        raise SystemExit(
            "basketball-reference-web-scraper is not installed. Install it only for "
            "explicit acquisition (for example: python3 -m pip install "
            "basketball-reference-web-scraper), then rerun this command. It is not "
            "a Sports Terminal runtime dependency."
        ) from exc
    return client


def _call_season_method(client: Any, method_name: str, season_end_year: int) -> Any:
    method: Callable[..., Any] = getattr(client, method_name)
    return method(season_end_year=season_end_year)


def _call_player_method(
    client: Any,
    method_name: str,
    player_identifier: str,
    season_end_year: int,
) -> Any:
    method: Callable[..., Any] = getattr(client, method_name)
    return method(
        player_identifier=player_identifier,
        season_end_year=season_end_year,
    )


def _record(
    *,
    dataset: str,
    method: str,
    file: Path,
    output: Path,
    rows: int | None,
    grain: str,
    season_end_year: int | None = None,
    player_identifier: str | None = None,
) -> dict[str, Any]:
    return {
        "dataset": dataset,
        "method": method,
        "grain": grain,
        "file": str(file.relative_to(output)),
        "rows": rows,
        "season_end_year": season_end_year,
        "player_identifier": player_identifier,
        "runtime_dependency": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Acquire Basketball-Reference data explicitly through the "
            "basketball_reference_web_scraper Python client and save raw JSON for "
            "later Sports Terminal canonicalization. The website never invokes this "
            "tool at runtime."
        )
    )
    parser.add_argument(
        "--seasons",
        help="Season end years, e.g. 2024 or 2022:2026.",
    )
    parser.add_argument(
        "--dataset",
        action="append",
        choices=sorted(DATASETS),
        help="Season-level dataset to acquire. Repeat for multiple datasets.",
    )
    parser.add_argument(
        "--player-dataset",
        action="append",
        choices=sorted(PLAYER_DATASETS),
        help="Player game-log dataset. Requires --player.",
    )
    parser.add_argument(
        "--player",
        action="append",
        help="Basketball-Reference player identifier accepted by the client, e.g. jamesle01.",
    )
    parser.add_argument(
        "--search",
        action="append",
        help="Run the library search(term=...) endpoint and save the result.",
    )
    parser.add_argument(
        "--output",
        default=str(ROOT / "raw" / "basketball_reference"),
    )
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    if args.list:
        print("Season datasets:")
        for key, (method, grain) in DATASETS.items():
            print(f"  {key:22} {grain:28} {method}")
        print("Player datasets:")
        for key, (method, grain) in PLAYER_DATASETS.items():
            print(f"  {key:22} {grain:28} {method}")
        print("Other supported operation: --search TERM")
        return 0

    datasets = list(args.dataset or ())
    player_datasets = list(args.player_dataset or ())
    searches = list(args.search or ())
    players = list(args.player or ())

    if not datasets and not player_datasets and not searches:
        parser.error("Choose --dataset, --player-dataset or --search.")
    if player_datasets and not players:
        parser.error("--player-dataset requires at least one --player identifier.")
    if (datasets or player_datasets) and not args.seasons:
        parser.error("--seasons is required for season/player datasets.")

    seasons = _season_values(args.seasons) if args.seasons else []
    output = Path(args.output).expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    client = _client()

    records: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []

    for dataset in datasets:
        method_name, grain = DATASETS[dataset]
        for season_end_year in seasons:
            try:
                print(
                    f"Acquiring Basketball-Reference {dataset} for "
                    f"season end year {season_end_year} via {method_name}"
                )
                payload = _call_season_method(client, method_name, season_end_year)
                target = output / dataset / f"{season_end_year}.json"
                rows = _write_json(target, payload)
                records.append(
                    _record(
                        dataset=dataset,
                        method=method_name,
                        file=target,
                        output=output,
                        rows=rows,
                        grain=grain,
                        season_end_year=season_end_year,
                    )
                )
            except Exception as exc:
                failures.append(
                    {
                        "dataset": dataset,
                        "season_end_year": season_end_year,
                        "error": f"{type(exc).__name__}: {exc}",
                    }
                )
                print(
                    f"FAILED {dataset} {season_end_year}: "
                    f"{type(exc).__name__}: {exc}"
                )

    for dataset in player_datasets:
        method_name, grain = PLAYER_DATASETS[dataset]
        for player_identifier in players:
            for season_end_year in seasons:
                try:
                    print(
                        f"Acquiring Basketball-Reference {dataset} for "
                        f"{player_identifier} / {season_end_year} via {method_name}"
                    )
                    payload = _call_player_method(
                        client,
                        method_name,
                        player_identifier,
                        season_end_year,
                    )
                    target = (
                        output
                        / dataset
                        / player_identifier
                        / f"{season_end_year}.json"
                    )
                    rows = _write_json(target, payload)
                    records.append(
                        _record(
                            dataset=dataset,
                            method=method_name,
                            file=target,
                            output=output,
                            rows=rows,
                            grain=grain,
                            season_end_year=season_end_year,
                            player_identifier=player_identifier,
                        )
                    )
                except Exception as exc:
                    failures.append(
                        {
                            "dataset": dataset,
                            "player_identifier": player_identifier,
                            "season_end_year": season_end_year,
                            "error": f"{type(exc).__name__}: {exc}",
                        }
                    )
                    print(
                        f"FAILED {dataset} {player_identifier} {season_end_year}: "
                        f"{type(exc).__name__}: {exc}"
                    )

    for term in searches:
        try:
            print(f"Searching Basketball-Reference for {term!r}")
            payload = client.search(term=term)
            safe = "".join(ch.lower() if ch.isalnum() else "_" for ch in term).strip("_")
            target = output / "search" / f"{safe or 'query'}.json"
            rows = _write_json(target, payload)
            records.append(
                _record(
                    dataset="search",
                    method="search",
                    file=target,
                    output=output,
                    rows=rows,
                    grain="search-result",
                )
            )
        except Exception as exc:
            failures.append(
                {
                    "dataset": "search",
                    "term": term,
                    "error": f"{type(exc).__name__}: {exc}",
                }
            )
            print(f"FAILED search {term!r}: {type(exc).__name__}: {exc}")

    manifest_path = output / "manifest.json"
    previous = {}
    if manifest_path.is_file():
        try:
            previous = json.loads(manifest_path.read_text(encoding="utf-8"))
        except Exception:
            previous = {}
    existing = list(previous.get("datasets") or []) if isinstance(previous, dict) else []
    keyed: dict[tuple[str, str, int | None, str | None], dict[str, Any]] = {}
    for row in existing:
        if not isinstance(row, dict):
            continue
        keyed[
            (
                str(row.get("dataset")),
                str(row.get("method")),
                row.get("season_end_year") if isinstance(row.get("season_end_year"), int) else None,
                str(row.get("player_identifier")) if row.get("player_identifier") else None,
            )
        ] = row
    for row in records:
        keyed[
            (
                str(row.get("dataset")),
                str(row.get("method")),
                row.get("season_end_year") if isinstance(row.get("season_end_year"), int) else None,
                str(row.get("player_identifier")) if row.get("player_identifier") else None,
            )
        ] = row

    manifest = {
        "contract": "sports-terminal-basketball-reference-import-v1",
        "source": "basketball_reference_web_scraper",
        "runtime_dependency": False,
        "canonicalization_required": True,
        "season_semantics": "season_end_year: 2024 means the 2023-24 season",
        "datasets": sorted(
            keyed.values(),
            key=lambda row: (
                str(row.get("dataset")),
                int(row.get("season_end_year") or 0),
                str(row.get("player_identifier") or ""),
            ),
        ),
        "last_failures": failures,
    }
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(
        f"Basketball-Reference acquisition complete: {len(records)} files written; "
        f"{len(failures)} failures; manifest={manifest_path}"
    )
    return 1 if failures and not records else 0


if __name__ == "__main__":
    raise SystemExit(main())
