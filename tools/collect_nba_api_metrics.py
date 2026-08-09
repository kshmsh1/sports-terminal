#!/usr/bin/env python3
"""Collect high-yield NBA Stats endpoint responses for Sports Terminal metrics.

The collector is intentionally conservative:
- Regular Season and Playoffs are always separate partitions.
- Bulk league endpoints are preferred before player/game fan-out endpoints.
- Every request is cached as source evidence before transformation.
- Existing cache entries are reused unless --replace is supplied.
- Failures are recorded and collection continues unless --strict is supplied.
- CI should use --plan or synthetic cache fixtures, never live NBA.com traffic.

This script requires the pinned ``nba_api`` package used by the repository quality
workflow. It dynamically inspects endpoint constructor signatures so upstream
optional-parameter additions do not require a collector rewrite.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib
import inspect
import json
import os
import random
import re
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CACHE_ROOT = ROOT / "data" / "warehouse" / "nba_api_raw"
DEFAULT_REPORT = ROOT / "data" / "warehouse" / "nba_api_collection_report.json"
DEFAULT_RECIPES = ROOT / "assets" / "data" / "nba" / "metadata" / "nba_api_metric_recipes.json"

SEASON_TYPE_LABELS = {
    "regular": "Regular Season",
    "playoffs": "Playoffs",
}

PT_MEASURE_VARIANTS = (
    "Passing",
    "Drives",
    "Rebounding",
    "Possessions",
    "CatchShoot",
    "PullUpShot",
    "Defense",
    "SpeedDistance",
)

SYNERGY_PLAY_TYPES = (
    "Isolation",
    "Transition",
    "PRBallHandler",
    "PRRollman",
    "Postup",
    "Spotup",
)


@dataclass(frozen=True)
class EndpointSpec:
    endpoint: str
    module: str
    tier: str = "bulk"
    variants: tuple[dict[str, Any], ...] = ({},)
    notes: str = ""


BULK_ENDPOINTS: tuple[EndpointSpec, ...] = (
    EndpointSpec("LeagueDashPlayerStats", "leaguedashplayerstats"),
    EndpointSpec("LeagueHustleStatsPlayer", "leaguehustlestatsplayer"),
    EndpointSpec("LeagueDashPtDefend", "leaguedashptdefend"),
    EndpointSpec("LeagueDashPlayerBioStats", "leaguedashplayerbiostats"),
    EndpointSpec("LeagueDashPlayerPtShot", "leaguedashplayerptshot"),
    EndpointSpec("LeagueDashPlayerShotLocations", "leaguedashplayershotlocations"),
    EndpointSpec("LeagueDashPlayerClutch", "leaguedashplayerclutch"),
    EndpointSpec("PlayerEstimatedMetrics", "playerestimatedmetrics"),
    EndpointSpec(
        "LeagueDashPtStats",
        "leaguedashptstats",
        tier="tracking",
        variants=tuple({"pt_measure_type": value} for value in PT_MEASURE_VARIANTS),
        notes="Parameter-dependent player tracking datasets.",
    ),
    EndpointSpec(
        "SynergyPlayTypes",
        "synergyplaytypes",
        tier="tracking",
        variants=tuple(
            {"play_type_nullable": value, "type_grouping_nullable": "offensive"}
            for value in SYNERGY_PLAY_TYPES
        )
        + tuple(
            {"play_type_nullable": "Transition", "type_grouping_nullable": "defensive"}
            for _ in range(1)
        ),
        notes="Play-type PPP. Endpoint availability and parameter names are runtime validated.",
    ),
    EndpointSpec(
        "GravityLeaders",
        "gravityleaders",
        tier="tracking",
        notes="NBA gravity endpoint introduced in recent nba_api releases.",
    ),
)


@dataclass
class CollectionRecord:
    endpoint: str
    variant: dict[str, Any]
    season: str
    season_type: str
    cache_path: str
    status: str
    elapsed_ms: int = 0
    result_sets: int = 0
    rows: int = 0
    columns: int = 0
    error: str = ""
    parameters: dict[str, Any] = field(default_factory=dict)
    sha256: str = ""


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def safe_slug(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or "default"


def json_sha256(payload: Any) -> str:
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def installed_nba_api_version() -> str:
    try:
        from importlib.metadata import version

        return version("nba_api")
    except Exception:
        return "unknown"


def load_recipe_endpoints(path: Path) -> dict[str, list[str]]:
    if not path.exists():
        return {}
    payload = json.loads(path.read_text(encoding="utf-8"))
    result: dict[str, list[str]] = {}
    for recipe in payload.get("recipes", []):
        if not isinstance(recipe, dict):
            continue
        endpoint = str(recipe.get("endpoint") or "")
        metric = str(recipe.get("metric") or "")
        if endpoint and metric:
            result.setdefault(endpoint, []).append(metric)
    return result


def endpoint_class(spec: EndpointSpec):
    module = importlib.import_module(f"nba_api.stats.endpoints.{spec.module}")
    return getattr(module, spec.endpoint)


def default_for_parameter(name: str, season: str, season_type: str) -> Any:
    """Resolve common required nba_api constructor parameters by Python arg name."""
    exact: dict[str, Any] = {
        "season": season,
        "season_nullable": season,
        "season_year": season,
        "season_year_nullable": season,
        "season_type": season_type,
        "season_type_all_star": season_type,
        "season_type_nullable": season_type,
        "league_id": "00",
        "league_id_nullable": "00",
        "per_mode_simple": "Totals",
        "per_mode_simple_nullable": "Totals",
        "per_mode_detailed": "Totals",
        "per_mode_detailed_nullable": "Totals",
        "measure_type_detailed_defense": "Base",
        "measure_type_detailed_defense_nullable": "Base",
        "pace_adjust": "N",
        "plus_minus": "N",
        "rank": "N",
        "month": 0,
        "month_nullable": 0,
        "last_n_games": 0,
        "last_n_games_nullable": 0,
        "period": 0,
        "period_nullable": 0,
        "opp_team_id": 0,
        "opp_team_id_nullable": 0,
        "team_id": 0,
        "team_id_nullable": 0,
        "player_or_team_abbreviation": "P",
        "player_or_team": "P",
        "timeout": 60,
    }
    if name in exact:
        return exact[name]
    if name.endswith("_nullable"):
        return ""
    raise KeyError(name)


def build_constructor_kwargs(
    cls: type,
    *,
    season: str,
    season_type: str,
    overrides: dict[str, Any],
    timeout: int,
) -> tuple[dict[str, Any], list[str]]:
    signature = inspect.signature(cls.__init__)
    kwargs: dict[str, Any] = {}
    unresolved: list[str] = []
    params = signature.parameters
    for raw_key, value in overrides.items():
        if raw_key in params:
            kwargs[raw_key] = value
            continue
        # Allow manifests to use a semantic key when nba_api changes suffixes.
        matches = [name for name in params if name.replace("_nullable", "") == raw_key]
        if len(matches) == 1:
            kwargs[matches[0]] = value
        else:
            unresolved.append(raw_key)
    for name, parameter in params.items():
        if name in {"self", "get_request"} or name in kwargs:
            continue
        if name == "timeout":
            kwargs[name] = timeout
            continue
        if parameter.default is not inspect.Parameter.empty:
            continue
        try:
            kwargs[name] = default_for_parameter(name, season, season_type)
        except KeyError:
            unresolved.append(name)
    return kwargs, sorted(set(unresolved))


def normalized_result_sets(instance: Any) -> dict[str, list[dict[str, Any]]]:
    """Return nba_api result sets as JSON-safe row dictionaries."""
    if hasattr(instance, "get_normalized_dict"):
        payload = instance.get_normalized_dict()
        if isinstance(payload, dict):
            result: dict[str, list[dict[str, Any]]] = {}
            for key, value in payload.items():
                if isinstance(value, list):
                    result[str(key)] = [
                        {str(k): v for k, v in row.items()}
                        for row in value
                        if isinstance(row, dict)
                    ]
            if result:
                return result
    if hasattr(instance, "get_dict"):
        raw = instance.get_dict()
        if isinstance(raw, dict):
            result_sets = raw.get("resultSets") or raw.get("resultSet") or []
            if isinstance(result_sets, dict):
                result_sets = [result_sets]
            result: dict[str, list[dict[str, Any]]] = {}
            if isinstance(result_sets, list):
                for index, item in enumerate(result_sets):
                    if not isinstance(item, dict):
                        continue
                    headers = [str(value) for value in item.get("headers", [])]
                    rows = item.get("rowSet", [])
                    name = str(item.get("name") or f"result_{index}")
                    result[name] = [
                        dict(zip(headers, row, strict=False))
                        for row in rows
                        if isinstance(row, list)
                    ]
            if result:
                return result
    raise RuntimeError("Endpoint did not expose a supported normalized result-set interface")


def cache_path_for(
    root: Path,
    *,
    season: str,
    season_type_key: str,
    endpoint: str,
    variant: dict[str, Any],
) -> Path:
    variant_label = "default" if not variant else "__".join(
        f"{safe_slug(key)}-{safe_slug(str(value))}" for key, value in sorted(variant.items())
    )
    return root / safe_slug(season) / season_type_key / f"{safe_slug(endpoint)}__{variant_label}.json"


def summarize_result_sets(result_sets: dict[str, list[dict[str, Any]]]) -> tuple[int, int, int]:
    rows = sum(len(items) for items in result_sets.values())
    columns = len(
        {
            key
            for items in result_sets.values()
            for row in items
            for key in row.keys()
        }
    )
    return len(result_sets), rows, columns


def collect_one(
    spec: EndpointSpec,
    variant: dict[str, Any],
    *,
    season: str,
    season_type_key: str,
    cache_root: Path,
    replace: bool,
    timeout: int,
    retries: int,
    min_delay: float,
    max_delay: float,
    recipe_metrics: list[str],
) -> CollectionRecord:
    season_type = SEASON_TYPE_LABELS[season_type_key]
    cache_path = cache_path_for(
        cache_root,
        season=season,
        season_type_key=season_type_key,
        endpoint=spec.endpoint,
        variant=variant,
    )
    if cache_path.exists() and not replace:
        try:
            cached = json.loads(cache_path.read_text(encoding="utf-8"))
            result_sets = cached.get("result_sets", {})
            if isinstance(result_sets, dict):
                count, rows, columns = summarize_result_sets(result_sets)
                return CollectionRecord(
                    endpoint=spec.endpoint,
                    variant=variant,
                    season=season,
                    season_type=season_type_key,
                    cache_path=str(cache_path.relative_to(ROOT)),
                    status="cached",
                    result_sets=count,
                    rows=rows,
                    columns=columns,
                    parameters=cached.get("parameters", {}),
                    sha256=json_sha256(cached),
                )
        except Exception:
            pass

    try:
        cls = endpoint_class(spec)
        kwargs, unresolved = build_constructor_kwargs(
            cls,
            season=season,
            season_type=season_type,
            overrides=variant,
            timeout=timeout,
        )
    except Exception as exc:
        return CollectionRecord(
            endpoint=spec.endpoint,
            variant=variant,
            season=season,
            season_type=season_type_key,
            cache_path=str(cache_path.relative_to(ROOT)),
            status="unavailable",
            error=f"{type(exc).__name__}: {exc}",
        )
    if unresolved:
        return CollectionRecord(
            endpoint=spec.endpoint,
            variant=variant,
            season=season,
            season_type=season_type_key,
            cache_path=str(cache_path.relative_to(ROOT)),
            status="unresolved_parameters",
            error=", ".join(unresolved),
            parameters=kwargs,
        )

    last_error = ""
    started = time.perf_counter()
    for attempt in range(retries + 1):
        if attempt > 0:
            backoff = min(30.0, (2 ** (attempt - 1)) + random.uniform(0.25, 1.25))
            time.sleep(backoff)
        if min_delay > 0 or max_delay > 0:
            low = min(min_delay, max_delay)
            high = max(min_delay, max_delay)
            time.sleep(random.uniform(low, high))
        try:
            instance = cls(**kwargs)
            result_sets = normalized_result_sets(instance)
            count, rows, columns = summarize_result_sets(result_sets)
            payload = {
                "schema_version": 1,
                "source": "nba_api",
                "nba_api_version": installed_nba_api_version(),
                "endpoint": spec.endpoint,
                "module": spec.module,
                "tier": spec.tier,
                "season": season,
                "season_type": season_type_key,
                "season_type_label": season_type,
                "variant": variant,
                "parameters": kwargs,
                "collected_at": now_iso(),
                "recipe_metrics": sorted(set(recipe_metrics)),
                "result_sets": result_sets,
            }
            cache_path.parent.mkdir(parents=True, exist_ok=True)
            cache_path.write_text(json.dumps(payload, indent=2, default=str), encoding="utf-8")
            elapsed_ms = int((time.perf_counter() - started) * 1000)
            return CollectionRecord(
                endpoint=spec.endpoint,
                variant=variant,
                season=season,
                season_type=season_type_key,
                cache_path=str(cache_path.relative_to(ROOT)),
                status="collected",
                elapsed_ms=elapsed_ms,
                result_sets=count,
                rows=rows,
                columns=columns,
                parameters=kwargs,
                sha256=json_sha256(payload),
            )
        except KeyboardInterrupt:
            raise
        except Exception as exc:
            last_error = f"{type(exc).__name__}: {exc}"
    return CollectionRecord(
        endpoint=spec.endpoint,
        variant=variant,
        season=season,
        season_type=season_type_key,
        cache_path=str(cache_path.relative_to(ROOT)),
        status="failed",
        elapsed_ms=int((time.perf_counter() - started) * 1000),
        error=last_error,
        parameters=kwargs,
    )


def iter_requests(
    specs: Iterable[EndpointSpec],
    *,
    endpoint_filter: set[str],
    tiers: set[str],
) -> Iterable[tuple[EndpointSpec, dict[str, Any]]]:
    for spec in specs:
        if endpoint_filter and spec.endpoint not in endpoint_filter:
            continue
        if tiers and spec.tier not in tiers:
            continue
        for variant in spec.variants:
            yield spec, dict(variant)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", default="2025-26")
    parser.add_argument("--season-types", default="regular,playoffs")
    parser.add_argument("--endpoint", action="append", default=[])
    parser.add_argument("--tier", action="append", default=[])
    parser.add_argument("--cache-root", type=Path, default=DEFAULT_CACHE_ROOT)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--recipes", type=Path, default=DEFAULT_RECIPES)
    parser.add_argument("--replace", action="store_true")
    parser.add_argument("--plan", action="store_true")
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--timeout", type=int, default=60)
    parser.add_argument("--retries", type=int, default=2)
    parser.add_argument("--min-delay", type=float, default=0.6)
    parser.add_argument("--max-delay", type=float, default=1.4)
    args = parser.parse_args()

    season_types = [value.strip().lower() for value in args.season_types.split(",") if value.strip()]
    invalid = [value for value in season_types if value not in SEASON_TYPE_LABELS]
    if invalid:
        parser.error(f"Unsupported season type(s): {', '.join(invalid)}")
    endpoint_filter = {value.strip() for value in args.endpoint if value.strip()}
    tiers = {value.strip() for value in args.tier if value.strip()}
    recipe_map = load_recipe_endpoints(args.recipes)
    requests = list(iter_requests(BULK_ENDPOINTS, endpoint_filter=endpoint_filter, tiers=tiers))

    plan = [
        {
            "endpoint": spec.endpoint,
            "module": spec.module,
            "tier": spec.tier,
            "variant": variant,
            "recipe_metrics": sorted(recipe_map.get(spec.endpoint, [])),
            "notes": spec.notes,
        }
        for spec, variant in requests
    ]
    if args.plan:
        print(json.dumps({"season": args.season, "season_types": season_types, "requests": plan}, indent=2))
        return 0

    records: list[CollectionRecord] = []
    for season_type in season_types:
        for index, (spec, variant) in enumerate(requests, start=1):
            print(
                f"[{season_type} {index}/{len(requests)}] {spec.endpoint}"
                f"{f' {variant}' if variant else ''}",
                flush=True,
            )
            record = collect_one(
                spec,
                variant,
                season=args.season,
                season_type_key=season_type,
                cache_root=args.cache_root,
                replace=args.replace,
                timeout=args.timeout,
                retries=args.retries,
                min_delay=args.min_delay,
                max_delay=args.max_delay,
                recipe_metrics=recipe_map.get(spec.endpoint, []),
            )
            records.append(record)
            suffix = f"{record.rows} rows / {record.columns} cols" if record.status in {"cached", "collected"} else record.error
            print(f"  -> {record.status}: {suffix}", flush=True)
            if args.strict and record.status not in {"cached", "collected"}:
                break
        if args.strict and records and records[-1].status not in {"cached", "collected"}:
            break

    summary = {
        "schema_version": 1,
        "generated_at": now_iso(),
        "season": args.season,
        "season_types": season_types,
        "nba_api_version": installed_nba_api_version(),
        "requests": len(records),
        "collected": sum(record.status == "collected" for record in records),
        "cached": sum(record.status == "cached" for record in records),
        "failed": sum(record.status == "failed" for record in records),
        "unavailable": sum(record.status == "unavailable" for record in records),
        "unresolved_parameters": sum(record.status == "unresolved_parameters" for record in records),
        "rows": sum(record.rows for record in records),
        "records": [asdict(record) for record in records],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in summary.items() if key != "records"}, indent=2))
    print(f"Report: {args.report}")
    bad = summary["failed"] + summary["unavailable"] + summary["unresolved_parameters"]
    return 1 if args.strict and bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
