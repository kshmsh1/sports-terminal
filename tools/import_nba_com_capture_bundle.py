from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SURFACE_CONFIG: dict[str, dict[str, Any]] = {
    "players_hustle": {
        "resource": "leaguehustlestatsplayer",
        "season_keys": ("SeasonYear", "Season"),
        "category": None,
    },
    "players_defense_dashboard": {
        "resource": "leaguedashptdefend",
        "season_keys": ("Season", "SeasonYear"),
        "category": "Overall",
    },
    "players_defense_dashboard_3pt": {
        "resource": "leaguedashptdefend",
        "season_keys": ("Season", "SeasonYear"),
        "category": "3 Pointers",
    },
    "players_defense_dashboard_2pt": {
        "resource": "leaguedashptdefend",
        "season_keys": ("Season", "SeasonYear"),
        "category": "2 Pointers",
    },
    "players_defense_dashboard_lt6ft": {
        "resource": "leaguedashptdefend",
        "season_keys": ("Season", "SeasonYear"),
        "category": "Less Than 6Ft",
    },
}


def _collapse_spaces(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def _season_type_folder(value: str) -> str:
    return "playoffs" if "play" in value.lower() or "post" in value.lower() else "regular"


def _iter_json_objects(text: str):
    decoder = json.JSONDecoder()
    index = 0
    while index < len(text):
        start = text.find("{", index)
        if start < 0:
            return
        try:
            payload, consumed = decoder.raw_decode(text[start:])
        except json.JSONDecodeError:
            index = start + 1
            continue
        if isinstance(payload, dict):
            yield payload
        index = start + consumed


def _normalize_result_sets(payload: dict[str, Any]) -> list[dict[str, Any]]:
    result_sets = payload.get("resultSets")
    if result_sets is None:
        result_sets = payload.get("resultSet")
    if isinstance(result_sets, dict):
        result_sets = [result_sets]
    if not isinstance(result_sets, list):
        return []
    output: list[dict[str, Any]] = []
    for result_set in result_sets:
        if not isinstance(result_set, dict):
            continue
        headers = result_set.get("headers")
        row_set = result_set.get("rowSet") or result_set.get("rowset") or []
        if not isinstance(headers, list) or not isinstance(row_set, list):
            continue
        rows: list[dict[str, Any]] = []
        for raw in row_set:
            if isinstance(raw, dict):
                rows.append({str(k): v for k, v in raw.items()})
            elif isinstance(raw, list):
                rows.append({str(headers[i]): raw[i] for i in range(min(len(headers), len(raw)))})
        output.append({"name": result_set.get("name") or "ResultSet", "headers": [str(v) for v in headers], "rows": rows})
    return output


def _match_surface(payload: dict[str, Any]) -> str | None:
    resource = str(payload.get("resource") or "").lower()
    params = payload.get("parameters") if isinstance(payload.get("parameters"), dict) else {}
    category = _collapse_spaces(str(params.get("DefenseCategory") or ""))
    for surface, config in SURFACE_CONFIG.items():
        if resource != str(config["resource"]).lower():
            continue
        expected = config.get("category")
        if expected is None or category.lower() == str(expected).lower():
            return surface
    return None


def _season(payload: dict[str, Any], surface: str) -> str:
    params = payload.get("parameters") if isinstance(payload.get("parameters"), dict) else {}
    for key in SURFACE_CONFIG[surface]["season_keys"]:
        value = _collapse_spaces(str(params.get(key) or ""))
        if re.fullmatch(r"\d{4}-\d{2}", value):
            return value
    return ""


def _season_type(payload: dict[str, Any]) -> str:
    params = payload.get("parameters") if isinstance(payload.get("parameters"), dict) else {}
    return _collapse_spaces(str(params.get("SeasonType") or "Regular Season"))


def import_bundle(source: Path, output: Path) -> dict[str, int]:
    raw_bytes = source.read_bytes()
    text = raw_bytes.decode("utf-8", errors="replace")
    digest = hashlib.sha256(raw_bytes).hexdigest()
    counts: dict[str, int] = {}
    for payload in _iter_json_objects(text):
        surface = _match_surface(payload)
        if surface is None:
            continue
        season = _season(payload, surface)
        if not season:
            continue
        season_type = _season_type(payload)
        tables = _normalize_result_sets(payload)
        if not tables:
            continue
        target = output / surface / season / _season_type_folder(season_type)
        target.mkdir(parents=True, exist_ok=True)
        normalized = {
            "contract": "sports-terminal-nba-com-normalized-capture-v1",
            "surface": surface,
            "season": season,
            "season_type": season_type,
            "resource": payload.get("resource"),
            "parameters": payload.get("parameters") or {},
            "tables": tables,
        }
        (target / "normalized.json").write_text(json.dumps(normalized, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        metadata = {
            "source_file": str(source),
            "source_sha256": digest,
            "rights": "user-provided NBA.com capture bundle; redistribution rights not inferred",
            "surface": surface,
            "season": season,
            "season_type": season_type,
        }
        (target / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        counts[surface] = counts.get(surface, 0) + 1
    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description="Import user-authorized NBA.com JSON/cURL capture text into Sports Terminal normalized capture folders.")
    parser.add_argument("inputs", nargs="+")
    parser.add_argument("--output", default="raw/nba_com_stats")
    args = parser.parse_args()
    output = Path(args.output).expanduser().resolve()
    total: dict[str, int] = {}
    for raw in args.inputs:
        source = Path(raw).expanduser().resolve()
        counts = import_bundle(source, output)
        print(f"Imported {source}: {counts or 'no complete NBA.com JSON responses found'}")
        for surface, count in counts.items():
            total[surface] = total.get(surface, 0) + count
    print(f"NBA.com capture import summary: {total or 'none'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
