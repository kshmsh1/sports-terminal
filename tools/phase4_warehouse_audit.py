"""Read-only Phase 4 comparison of the local canonical warehouse, published index,
and already captured NBA.com traditional game logs. Never scrapes or mutates inputs.
"""
from __future__ import annotations

import argparse
import os
import collections
import hashlib
import json
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def normalized_season(value):
    match = re.search(r"(?<!\d)((?:19|20)\d{2})(?!\d)", str(value or ""))
    if not match:
        return "UNKNOWN"
    year = int(match.group(1))
    return f"{year}-{(year + 1) % 100:02d}"


def normalized_segment(value):
    raw = str(value or "").lower()
    if "play" in raw or "post" in raw:
        return "playoffs"
    if "reg" in raw:
        return "regular"
    return "UNKNOWN"


def nba_id(value):
    raw = str(value or "").strip()
    return raw.lstrip("0") or "0" if raw.isdigit() else ""


def group_key(row):
    return normalized_season(row.get("season_id")) + "|" + normalized_segment(row.get("season_type"))


def audit(db_path: Path, static: Path, verify_details=False):
    manifest_bytes = (static / "manifest.json").read_bytes()
    manifest = json.loads(manifest_bytes)
    if manifest.get("contract") != "sports-terminal-static-nba-website-v5" or manifest.get("static_schema_version") != 5:
        raise ValueError("Original v5 manifest required")
    index = json.loads((static / "games/index.json").read_bytes())
    if not isinstance(index, list) or any(not isinstance(g, dict) for g in index):
        raise ValueError("Invalid published game index")
    groups = collections.defaultdict(collections.Counter)
    examples = collections.defaultdict(list)

    def example(kind, value):
        if len(examples[kind]) < 20:
            examples[kind].append(value)

    with sqlite3.connect(db_path.resolve().as_uri() + "?mode=ro", uri=True) as db:
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA query_only=ON")
        tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        required = {"canon_dim_game", "canon_fact_player_game", "canon_fact_team_game"}
        if not required.issubset(tables):
            raise ValueError("Canonical game tables are missing: " + str(sorted(required - tables)))
        canonical = {str(row["game_key"]): dict(row) for row in db.execute(
            "SELECT game_key, nba_game_id, season_id, season_type, game_date FROM canon_dim_game WHERE league_id='NBA'"
        )}
        detail_counts = {}
        for table in ("canon_fact_player_game", "canon_fact_team_game"):
            columns = {r[1] for r in db.execute(f"PRAGMA table_info({table})")}
            where = " WHERE league_id='NBA'" if "league_id" in columns else ""
            detail_counts[table] = {str(k): n for k, n in db.execute(f"SELECT game_key, COUNT(*) FROM {table}{where} GROUP BY game_key")}
        lineup_candidates = []
        for name in sorted(tables):
            if re.search(r"lineup|stint|play.by.play|(^|_)pbp(_|$)", name, re.I):
                escaped = '"' + name.replace('"', '""') + '"'
                lineup_candidates.append({"table": name, "columns": [r[1] for r in db.execute(f"PRAGMA table_info({escaped})")],
                                          "hasRows": db.execute(f"SELECT 1 FROM {escaped} LIMIT 1").fetchone() is not None})
    by_key = {}
    indexed_nba = set()
    canonical_nba = {nba_id(g.get("nba_game_id")) for g in canonical.values()} - {""}
    duplicate_keys = 0
    for g in index:
        key = str(g.get("game_key") or "")
        scope = group_key(g)
        groups[scope]["published_index_rows"] += 1
        if not key:
            groups[scope]["missing_game_key"] += 1
            continue
        if key in by_key:
            duplicate_keys += 1
            example("duplicate_keys", key)
        by_key[key] = g
        ident = nba_id(g.get("nba_game_id"))
        if ident:
            indexed_nba.add(ident)
        if key not in canonical:
            groups[scope]["published_not_in_canonical"] += 1
            example("published_not_in_canonical", key)
        if g.get("box_score_available") is True:
            groups[scope]["flagged_player_box_score"] += 1
        ref = g.get("file")
        if isinstance(ref, str) and ref:
            groups[scope]["detail_references"] += 1
            target = (static / ref).resolve()
            if not target.is_relative_to(static.resolve()) or not target.is_file():
                groups[scope]["missing_or_unsafe_detail_file"] += 1
                example("missing_or_unsafe_detail_file", key)
            else:
                groups[scope]["detail_files_present"] += 1
                if verify_details:
                    try:
                        payload = json.loads(target.read_bytes())
                        embedded = payload.get("game") or {}
                        if str(embedded.get("game_key") or payload.get("game_key")) != key:
                            raise ValueError("game identity mismatch")
                        players = payload.get("player_box_scores")
                        teams = payload.get("team_box_scores")
                        if not isinstance(players, list) or not isinstance(teams, list):
                            raise ValueError("invalid detail arrays")
                        if g.get("box_score_available") is True and not players:
                            raise ValueError("flagged player detail empty")
                        groups[scope]["verified_detail_files"] += 1
                    except (ValueError, TypeError, AttributeError, OSError) as exc:
                        groups[scope]["invalid_detail_file"] += 1
                        example("invalid_detail_file", {"key": key, "error": str(exc)})
        elif g.get("box_score_available") is True:
            groups[scope]["flagged_missing_detail_reference"] += 1
            example("flagged_missing_detail_reference", key)
    for key, game in canonical.items():
        scope = group_key(game)
        counts = groups[scope]
        counts["canonical_games"] += 1
        if detail_counts["canon_fact_player_game"].get(key, 0):
            counts["canonical_player_detail_games"] += 1
        if detail_counts["canon_fact_team_game"].get(key, 0):
            counts["canonical_team_detail_games"] += 1
        if key not in by_key:
            counts["canonical_missing_from_index"] += 1
            example("canonical_missing_from_index", key)
        elif detail_counts["canon_fact_player_game"].get(key, 0) and by_key[key].get("box_score_available") is not True:
            counts["canonical_player_detail_not_flagged"] += 1
            example("canonical_player_detail_not_flagged", key)
    # Captured NBA.com files may include games that the older canonical index
    # never contained. Only count published IDs; don't infer dates/teams or insert.
    captured = static / "nba_com/surfaces/players_boxscores_traditional/default"
    captures = []
    for file in sorted(captured.glob("*/*.json")):
        scope = file.parent.name + "|" + file.stem
        try:
            payload = json.loads(file.read_bytes())
            tables_payload = payload.get("tables")
            if not isinstance(tables_payload, list):
                raise ValueError("missing tables array")
            ids = set()
            rows = 0
            for table in tables_payload:
                for row in table.get("rows", []):
                    if isinstance(row, dict):
                        rows += 1
                        ident = nba_id(row.get("GAME_ID"))
                        if ident:
                            ids.add(ident)
            absent = sorted(ids - indexed_nba)
            captures.append({"scope": scope, "rows": rows, "distinctGameIds": len(ids),
                             "missingFromPublishedIndex": len(absent), "missingFromCanonical": len(ids-canonical_nba),
                             "examplesMissingFromPublishedIndex": absent[:20]})
        except (ValueError, AttributeError, TypeError, OSError) as exc:
            captures.append({"scope": scope, "error": str(exc)})
    stat = db_path.stat()
    return {"kind": "ARCSIDE_PHASE4_WAREHOUSE_AUDIT_V1", "manifestSha256": hashlib.sha256(manifest_bytes).hexdigest(),
            "databaseFingerprint": {"size": stat.st_size, "mtime_ns": stat.st_mtime_ns},
            "manifestDatabaseFingerprint": manifest.get("database_fingerprint"),
            "canonicalGameCount": len(canonical), "publishedIndexRows": len(index),
            "duplicateGameKeys": duplicate_keys, "verifyDetails": verify_details,
            "gameCoverage": [{"scope": key, **dict(value)} for key, value in sorted(groups.items())],
            "capturedTraditionalGameLogs": captures, "lineupCandidateTables": lineup_candidates,
            "examples": dict(examples),
            "caveat": "Read-only inventory. Presence of candidate lineup tables does not establish valid pair splits. ID counts do not certify statistical contents."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, default=Path(os.environ["SPORTS_TERMINAL_NBA_HISTORY_DB"]) if os.environ.get("SPORTS_TERMINAL_NBA_HISTORY_DB") else ROOT / "data/warehouse/nba_history.sqlite")
    parser.add_argument("--static", type=Path, default=ROOT / "web/data/nba_static")
    parser.add_argument("--output", type=Path, default=ROOT / "experimental/arcside-react/evidence/coverage/warehouse-audit.json")
    parser.add_argument("--verify-details", action="store_true", help="Parse every referenced box score; otherwise check file presence.")
    args = parser.parse_args()
    result = audit(args.database, args.static, args.verify_details)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    summary = {key: result[key] for key in ("kind", "manifestSha256", "canonicalGameCount", "publishedIndexRows", "duplicateGameKeys", "lineupCandidateTables")}
    for metric in ("canonical_missing_from_index", "canonical_player_detail_not_flagged", "missing_or_unsafe_detail_file", "invalid_detail_file", "flagged_missing_detail_reference"):
        summary[metric] = sum(row.get(metric, 0) for row in result["gameCoverage"])
    summary["capturedMissingFromPublishedIndex"] = sum(row.get("missingFromPublishedIndex", 0) for row in result["capturedTraditionalGameLogs"])
    summary["output"] = str(args.output)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
