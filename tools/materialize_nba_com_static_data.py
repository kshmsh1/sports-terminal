from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1] if Path(__file__).resolve().parent.name == "tools" else Path.cwd()
DEFAULT_RAW = ROOT / "raw/nba_com_stats"
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"
CONTRACT = "sports-terminal-nba-com-static-corpus-v1"


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str), encoding="utf-8")
    temp.replace(path)


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def file_token(value: str) -> str:
    safe = "".join(char for char in value if char.isalnum() or char in "-_").strip("-_")
    if safe and len(safe) <= 48:
        return safe
    return hashlib.sha1(value.encode("utf-8")).hexdigest()[:24]


def capture_records(raw_root: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    if not raw_root.is_dir():
        return records
    for metadata_path in sorted(raw_root.glob("*/*/*/*/metadata.json")):
        try:
            metadata = read_json(metadata_path)
        except Exception:
            continue
        if not isinstance(metadata, dict):
            continue
        normalized_path = metadata_path.with_name("normalized.json")
        status = str(metadata.get("validation_status") or "")
        record = dict(metadata)
        record["metadata_path"] = str(metadata_path)
        record["normalized_path"] = str(normalized_path) if normalized_path.is_file() else ""
        if status in {"success", "empty"} and not normalized_path.is_file():
            record["validation_status"] = "incomplete"
        records.append(record)
    return records


def normalized_tables(path: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    payload = read_json(path)
    if not isinstance(payload, dict):
        return {}, []
    tables = payload.get("tables")
    return payload, [dict(item) for item in tables if isinstance(item, dict)] if isinstance(tables, list) else []


def rows_from_tables(tables: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for table in tables:
        source = table.get("rows")
        if isinstance(source, list):
            rows.extend(dict(row) for row in source if isinstance(row, dict))
    return rows


def first(row: dict[str, Any], keys: tuple[str, ...]) -> Any:
    lookup = {str(key).lower(): value for key, value in row.items()}
    for key in keys:
        if key in row and row[key] not in (None, ""):
            return row[key]
        value = lookup.get(key.lower())
        if value not in (None, ""):
            return value
    return None


PLAYER_ID_KEYS = ("PLAYER_ID", "PERSON_ID", "playerId", "personId")
PLAYER_NAME_KEYS = ("PLAYER_NAME", "PLAYER", "playerName")
GAME_ID_KEYS = ("GAME_ID", "gameId")
GAME_DATE_KEYS = ("GAME_DATE", "GAME_DATE_EST", "gameDate")
TEAM_ID_KEYS = ("TEAM_ID", "teamId")
TEAM_ABBR_KEYS = ("TEAM_ABBREVIATION", "TEAM_ABBR", "teamTricode")


def _identity(row: dict[str, Any], season: str, season_type: str) -> dict[str, Any]:
    return {
        "season": season,
        "season_type": season_type,
        "player_id": first(row, PLAYER_ID_KEYS),
        "player_name": first(row, PLAYER_NAME_KEYS),
        "game_id": first(row, GAME_ID_KEYS),
        "game_date": first(row, GAME_DATE_KEYS),
        "team_id": first(row, TEAM_ID_KEYS),
        "team_abbreviation": first(row, TEAM_ABBR_KEYS),
    }


def _scope_key(record: dict[str, Any]) -> str:
    return "/".join(
        str(record.get(key) or "")
        for key in ("surface", "variant", "season", "season_type")
    )


def _static_surface_path(root: Path, record: dict[str, Any]) -> Path:
    season_type = "playoffs" if "play" in str(record.get("season_type") or "").lower() else "regular"
    return root / "surfaces" / str(record.get("surface")) / str(record.get("variant")) / str(record.get("season")) / f"{season_type}.json"


def materialize(raw_root: Path, output: Path) -> dict[str, Any]:
    records = capture_records(raw_root)
    target = output / "nba_com"
    staging = output / ".nba_com.staging"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True, exist_ok=True)

    manifest_scopes: list[dict[str, Any]] = []
    game_rows: dict[tuple[str, str, str], dict[tuple[str, str], dict[str, Any]]] = {}
    copied_rows = 0
    success_scopes = empty_scopes = unavailable_scopes = failure_scopes = 0

    for record in records:
        status = str(record.get("validation_status") or "")
        manifest_item = {
            key: record.get(key)
            for key in (
                "surface", "variant", "endpoint", "grain", "season", "season_type",
                "result_set", "row_count", "row_ceiling", "validation_status", "schema_sha256", "source_sha256",
            )
        }
        manifest_item["scope_key"] = _scope_key(record)
        if status == "success":
            success_scopes += 1
        elif status == "empty":
            empty_scopes += 1
        elif status == "unavailable":
            unavailable_scopes += 1
        else:
            failure_scopes += 1
        normalized_path = Path(str(record.get("normalized_path") or ""))
        if status not in {"success", "empty"} or not normalized_path.is_file():
            manifest_scopes.append(manifest_item)
            continue

        payload, tables = normalized_tables(normalized_path)
        static_payload = {
            "contract": CONTRACT,
            "surface": record.get("surface"),
            "variant": record.get("variant"),
            "grain": record.get("grain"),
            "season": record.get("season"),
            "season_type": record.get("season_type"),
            "resource": payload.get("resource"),
            "parameters": payload.get("parameters") or {},
            "schema_sha256": payload.get("schema_sha256") or record.get("schema_sha256"),
            "tables": [
                {
                    "name": table.get("name"),
                    "headers": table.get("headers") or [],
                    "rows": table.get("rows") or [],
                }
                for table in tables
            ],
        }
        relative = _static_surface_path(staging, record).relative_to(staging)
        write_json(staging / relative, static_payload)
        manifest_item["file"] = str(relative).replace("\\", "/")
        rows = rows_from_tables(tables)
        copied_rows += len(rows)

        if str(record.get("grain")) == "player_game" and rows:
            season = str(record.get("season") or "")
            season_type = "playoffs" if "play" in str(record.get("season_type") or "").lower() else "regular"
            source_key = f"{record.get('surface')}/{record.get('variant')}"
            bucket = game_rows.setdefault((season, season_type, source_key), {})
            for row_number, row in enumerate(rows):
                player_id = str(first(row, PLAYER_ID_KEYS) or "").strip()
                game_id = str(first(row, GAME_ID_KEYS) or "").strip()
                if not player_id:
                    continue
                if not game_id:
                    game_id = f"row-{row_number}"
                bucket[(player_id, game_id)] = dict(row)
        manifest_scopes.append(manifest_item)

    # Merge all player-game surfaces into lossless per-player files. Each source
    # remains nested so similarly named fields from Base/Advanced/Misc/etc. never
    # overwrite one another.
    by_scope: dict[tuple[str, str], dict[str, dict[str, Any]]] = {}
    for (season, season_type, source_key), rows in game_rows.items():
        scope = by_scope.setdefault((season, season_type), {})
        for (player_id, game_id), row in rows.items():
            player = scope.setdefault(player_id, {"player_id": player_id, "player_name": first(row, PLAYER_NAME_KEYS), "games": {}})
            if not player.get("player_name"):
                player["player_name"] = first(row, PLAYER_NAME_KEYS)
            game = player["games"].setdefault(game_id, {"identity": _identity(row, season, season_type), "sources": {}})
            identity = game.get("identity") or {}
            for key, value in _identity(row, season, season_type).items():
                if identity.get(key) in (None, "") and value not in (None, ""):
                    identity[key] = value
            game["identity"] = identity
            game["sources"][source_key] = row

    game_log_players = game_log_games = 0
    for (season, season_type), players in sorted(by_scope.items()):
        index: list[dict[str, Any]] = []
        for player_id, player in sorted(players.items(), key=lambda item: str(item[1].get("player_name") or item[0])):
            games = list(player["games"].values())
            games.sort(key=lambda item: (str(item.get("identity", {}).get("game_date") or ""), str(item.get("identity", {}).get("game_id") or "")), reverse=True)
            filename = f"{file_token(player_id)}.json"
            relative = Path("player_game_logs") / season / season_type / "players" / filename
            write_json(staging / relative, {
                "contract": CONTRACT,
                "season": season,
                "season_type": season_type,
                "player_id": player_id,
                "player_name": player.get("player_name"),
                "game_count": len(games),
                "games": games,
            })
            index.append({"player_id": player_id, "player_name": player.get("player_name"), "game_count": len(games), "file": f"players/{filename}"})
            game_log_players += 1
            game_log_games += len(games)
        write_json(staging / "player_game_logs" / season / season_type / "index.json", index)

    manifest = {
        "contract": CONTRACT,
        "source_root": str(raw_root),
        "scope_count": len(records),
        "success_scopes": success_scopes,
        "empty_scopes": empty_scopes,
        "unavailable_scopes": unavailable_scopes,
        "other_scopes": failure_scopes,
        "static_rows": copied_rows,
        "player_game_files": game_log_players,
        "player_game_records": game_log_games,
        "scopes": manifest_scopes,
        "runtime_api_required": False,
    }
    write_json(staging / "manifest.json", manifest)

    if target.exists():
        shutil.rmtree(target)
    staging.replace(target)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Materialize normalized local NBA.com captures into the generated static Sports Terminal corpus. Performs no network requests.")
    parser.add_argument("--raw-root", type=Path, default=DEFAULT_RAW)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    raw_root = args.raw_root.expanduser().resolve()
    output = args.output.expanduser().resolve()
    if not raw_root.is_dir():
        print(json.dumps({"contract": CONTRACT, "source_root": str(raw_root), "scope_count": 0, "message": "No NBA.com capture directory is installed; static NBA.com layer remains empty."}, indent=2))
        return 0
    manifest = materialize(raw_root, output)
    print(json.dumps({key: manifest[key] for key in ("contract", "scope_count", "success_scopes", "empty_scopes", "unavailable_scopes", "static_rows", "player_game_files", "player_game_records")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
