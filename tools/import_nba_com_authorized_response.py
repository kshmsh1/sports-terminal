from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.nba_com_stats_registry import SURFACES  # noqa: E402


def _slug(value: str) -> str:
    return "-".join(part for part in value.strip().lower().replace("/", " ").replace("_", " ").split() if part)


def _unique_headers(headers: list[Any]) -> list[str]:
    counts: dict[str, int] = {}
    result: list[str] = []
    for index, raw in enumerate(headers):
        base = str(raw or f"column_{index + 1}").strip() or f"column_{index + 1}"
        count = counts.get(base, 0) + 1
        counts[base] = count
        result.append(base if count == 1 else f"{base}__{count}")
    return result


def _table_from_result_set(result_set: dict[str, Any], fallback_name: str) -> dict[str, Any]:
    headers = _unique_headers(list(result_set.get("headers") or []))
    raw_rows = result_set.get("rowSet") or result_set.get("rows") or []
    rows: list[dict[str, Any]] = []
    for raw_row in raw_rows:
        if isinstance(raw_row, dict):
            rows.append(dict(raw_row))
            continue
        if not isinstance(raw_row, list):
            continue
        row = {headers[index]: value for index, value in enumerate(raw_row[: len(headers)])}
        rows.append(row)
    return {
        "name": str(result_set.get("name") or fallback_name),
        "headers": headers,
        "row_count": len(rows),
        "rows": rows,
    }


def normalize_nba_stats_response(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        if all(isinstance(row, dict) for row in payload):
            headers = sorted({key for row in payload for key in row})
            return [{"name": "data", "headers": headers, "row_count": len(payload), "rows": payload}]
        raise ValueError("Unsupported top-level JSON list shape; expected a list of objects.")
    if not isinstance(payload, dict):
        raise ValueError("NBA Stats response must be a JSON object or list of objects.")

    result_sets = payload.get("resultSets")
    if isinstance(result_sets, dict):
        result_sets = [result_sets]
    if isinstance(result_sets, list):
        return [
            _table_from_result_set(item, f"result_set_{index + 1}")
            for index, item in enumerate(result_sets)
            if isinstance(item, dict)
        ]

    result_set = payload.get("resultSet")
    if isinstance(result_set, dict):
        return [_table_from_result_set(result_set, "result_set")]

    data = payload.get("data")
    if isinstance(data, list) and all(isinstance(row, dict) for row in data):
        headers = sorted({key for row in data for key in row})
        return [{"name": "data", "headers": headers, "row_count": len(data), "rows": data}]

    raise ValueError("Unrecognized NBA Stats response shape. Preserve the raw file and add a parser before importing it.")


def import_response(
    source: Path,
    *,
    surface_key: str,
    season: str,
    season_type: str,
    output_root: Path,
    force: bool = False,
) -> Path:
    if surface_key not in SURFACES:
        raise ValueError(f"Unknown surface: {surface_key}")
    raw_bytes = source.read_bytes()
    payload = json.loads(raw_bytes.decode("utf-8"))
    tables = normalize_nba_stats_response(payload)

    destination = output_root / surface_key / season / _slug(season_type)
    if destination.exists() and not force:
        raise FileExistsError(f"Destination already exists: {destination}. Use --force to replace it explicitly.")
    destination.mkdir(parents=True, exist_ok=True)

    shutil.copy2(source, destination / "source.json")
    normalized = {
        "contract": "sports-terminal-nba-com-authorized-import-v1",
        "surface": SURFACES[surface_key].to_dict(),
        "season": season,
        "season_type": season_type,
        "tables": tables,
    }
    (destination / "normalized.json").write_text(json.dumps(normalized, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    metadata = {
        "contract": "sports-terminal-source-provenance-v1",
        "source_kind": "user_supplied_or_authorized_nba_stats_response",
        "surface_key": surface_key,
        "season": season,
        "season_type": season_type,
        "imported_at": datetime.now(timezone.utc).isoformat(),
        "source_file": source.name,
        "source_sha256": hashlib.sha256(raw_bytes).hexdigest(),
        "source_bytes": len(raw_bytes),
        "table_count": len(tables),
        "row_count": sum(int(table.get("row_count") or 0) for table in tables),
        "rights": {
            "commercial_use_verified": False,
            "redistribution_verified": False,
            "license_review_required": True,
        },
    }
    (destination / "metadata.json").write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return destination


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Normalize a user-supplied or otherwise authorized NBA Stats JSON response into Sports Terminal raw/provenance files. This command performs no network requests."
    )
    parser.add_argument("source", help="Path to an authorized JSON response saved locally.")
    parser.add_argument("--surface", required=True, choices=sorted(SURFACES))
    parser.add_argument("--season", required=True, help="Season label such as 2025-26.")
    parser.add_argument("--season-type", default="Regular Season")
    parser.add_argument("--output", default="raw/nba_com_stats")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    destination = import_response(
        Path(args.source).expanduser().resolve(),
        surface_key=args.surface,
        season=args.season,
        season_type=args.season_type,
        output_root=Path(args.output).expanduser().resolve(),
        force=args.force,
    )
    print(f"Imported authorized NBA Stats response: {destination}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
