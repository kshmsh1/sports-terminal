from __future__ import annotations

import hashlib
import json
import re
import unicodedata
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RAW_ROOTS = (ROOT / "raw/nba_com_stats", ROOT.parent / "raw/nba_com_stats")
ENRICHMENT_CONTRACT = "sports-terminal-nba-com-static-enrichment-v2"

PLAYER_SEASON_SURFACES = (
    "players_base",
    "players_advanced",
    "players_misc",
    "players_scoring",
    "players_usage",
    "players_defense",
    "players_estimated_advanced",
    "players_defense_dashboard",
    "players_defense_dashboard_3pt",
    "players_defense_dashboard_2pt",
    "players_defense_dashboard_lt6ft",
    "players_hustle",
    "players_violations",
)

SURFACE_FIELD_MAP: dict[str, dict[str, str]] = {
    "players_base": {
        "GP": "games", "MIN": "minutes", "PTS": "points", "REB": "rebounds",
        "OREB": "offensive_rebounds", "DREB": "defensive_rebounds", "AST": "assists",
        "STL": "steals", "BLK": "blocks", "TOV": "turnovers", "PF": "personal_fouls",
        "FGM": "field_goals_made", "FGA": "field_goal_attempts", "FG_PCT": "fg_pct",
        "FG3M": "three_pointers_made", "FG3A": "three_point_attempts", "FG3_PCT": "three_pct",
        "FTM": "free_throws_made", "FTA": "free_throw_attempts", "FT_PCT": "ft_pct",
        "PLUS_MINUS": "plus_minus",
    },
    "players_advanced": {
        "E_OFF_RATING": "e_off_rating", "OFF_RATING": "off_rating",
        "E_DEF_RATING": "e_def_rating", "DEF_RATING": "def_rating",
        "E_NET_RATING": "e_net_rating", "NET_RATING": "net_rating",
        "AST_PCT": "ast_pct", "AST_TO": "ast_to", "AST_RATIO": "ast_ratio",
        "OREB_PCT": "oreb_pct", "DREB_PCT": "dreb_pct", "REB_PCT": "reb_pct",
        "TM_TOV_PCT": "tm_tov_pct", "E_TOV_PCT": "e_tov_pct",
        "EFG_PCT": "efg_pct", "TS_PCT": "ts_pct", "USG_PCT": "usg_pct",
        "E_USG_PCT": "e_usg_pct", "E_PACE": "e_pace", "PACE": "pace",
        "PACE_PER40": "pace_per40", "PIE": "pie", "POSS": "possessions",
    },
    "players_misc": {
        "PTS_OFF_TOV": "pts_off_tov", "PTS_2ND_CHANCE": "pts_second_chance",
        "PTS_FB": "fast_break_points", "PTS_PAINT": "paint_points",
        "OPP_PTS_OFF_TOV": "opp_pts_off_tov", "OPP_PTS_2ND_CHANCE": "opp_pts_second_chance",
        "OPP_PTS_FB": "opp_fast_break_points", "OPP_PTS_PAINT": "opp_paint_points",
        "BLK": "blocks", "BLKA": "blocks_against", "PF": "personal_fouls", "PFD": "fouls_drawn",
    },
    "players_scoring": {
        "PCT_FGA_2PT": "two_point_attempt_share", "PCT_FGA_3PT": "three_freq",
        "PCT_PTS_2PT": "two_point_points_share", "PCT_PTS_2PT_MR": "midrange_points_share",
        "PCT_PTS_3PT": "three_point_points_share", "PCT_PTS_FB": "fast_break_points_share",
        "PCT_PTS_FT": "free_throw_points_share", "PCT_PTS_OFF_TOV": "off_turnover_points_share",
        "PCT_PTS_PAINT": "paint_points_share", "PCT_AST_2PM": "pct_ast_2pm",
        "PCT_UAST_2PM": "pct_uast_2pm", "PCT_AST_3PM": "pct_ast_3pm",
        "PCT_UAST_3PM": "pct_uast_3pm", "PCT_AST_FGM": "pct_ast_fgm",
        "PCT_UAST_FGM": "pct_uast_fgm",
    },
    "players_usage": {
        "USG_PCT": "usg_pct", "PCT_FGM": "pct_team_fgm", "PCT_FGA": "pct_team_fga",
        "PCT_FG3M": "pct_team_fg3m", "PCT_FG3A": "pct_team_fg3a", "PCT_FTM": "pct_team_ftm",
        "PCT_FTA": "pct_team_fta", "PCT_OREB": "pct_team_oreb", "PCT_DREB": "pct_team_dreb",
        "PCT_REB": "pct_team_reb", "PCT_AST": "pct_team_ast", "PCT_TOV": "pct_team_tov",
        "PCT_STL": "pct_team_stl", "PCT_BLK": "pct_team_blk", "PCT_PF": "pct_team_pf",
        "PCT_PFD": "pct_team_pfd", "PCT_PTS": "pct_team_pts",
    },
    "players_defense": {
        "DEF_RATING": "def_rating", "DREB": "defensive_rebounds", "DREB_PCT": "dreb_pct",
        "STL": "steals", "STL_PCT": "stl_pct", "BLK": "blocks", "BLK_PCT": "blk_pct",
        "OPP_PTS_OFF_TOV": "opp_pts_off_tov", "OPP_PTS_2ND_CHANCE": "opp_pts_second_chance",
        "OPP_PTS_FB": "opp_fast_break_points", "OPP_PTS_PAINT": "opp_paint_points",
        "DEF_WS": "def_ws", "DEF_WS_RAW": "def_ws_raw",
    },
    "players_estimated_advanced": {
        "E_OFF_RATING": "e_off_rating", "E_DEF_RATING": "e_def_rating",
        "E_NET_RATING": "e_net_rating", "E_AST_RATIO": "e_ast_ratio",
        "E_OREB_PCT": "e_oreb_pct", "E_DREB_PCT": "e_dreb_pct", "E_REB_PCT": "e_reb_pct",
        "E_TM_TOV_PCT": "e_tm_tov_pct", "E_USG_PCT": "e_usg_pct", "E_PACE": "e_pace",
    },
    "players_defense_dashboard": {
        "FREQ": "defense_freq", "D_FGM": "d_fgm", "D_FGA": "d_fga",
        "D_FG_PCT": "d_fg_pct", "NORMAL_FG_PCT": "normal_fg_pct", "PCT_PLUSMINUS": "dfg_pct_diff",
    },
    "players_defense_dashboard_3pt": {
        "FREQ": "three_defense_freq", "FG3M": "three_dfgm", "FG3A": "three_dfga",
        "FG3_PCT": "three_dfg_pct", "NS_FG3_PCT": "normal_three_fg_pct", "PLUSMINUS": "three_dfg_pct_diff",
    },
    "players_defense_dashboard_2pt": {
        "FREQ": "two_defense_freq", "FG2M": "two_dfgm", "FG2A": "two_dfga",
        "FG2_PCT": "two_dfg_pct", "NS_FG2_PCT": "normal_two_fg_pct", "PLUSMINUS": "two_dfg_pct_diff",
    },
    "players_defense_dashboard_lt6ft": {
        "FREQ": "lt6_defense_freq", "FGM_LT_06": "rim_dfgm", "FGA_LT_06": "rim_dfga",
        "LT_06_PCT": "rim_dfg_pct", "NS_LT_06_PCT": "normal_rim_fg_pct", "PLUSMINUS": "rim_dfg_pct_diff",
    },
    "players_hustle": {
        "CONTESTED_SHOTS": "contested_shots", "CONTESTED_SHOTS_2PT": "contested_shots_2pt",
        "CONTESTED_SHOTS_3PT": "contested_shots_3pt", "DEFLECTIONS": "deflections",
        "CHARGES_DRAWN": "charges_drawn", "SCREEN_ASSISTS": "screen_assists",
        "SCREEN_AST_PTS": "screen_ast_points", "OFF_LOOSE_BALLS_RECOVERED": "off_loose_balls_recovered",
        "DEF_LOOSE_BALLS_RECOVERED": "def_loose_balls_recovered", "LOOSE_BALLS_RECOVERED": "loose_balls_recovered",
        "OFF_BOXOUTS": "off_box_outs", "DEF_BOXOUTS": "def_box_outs", "BOX_OUTS": "box_outs",
        "BOX_OUT_PLAYER_TEAM_REBS": "box_out_player_team_rebs", "BOX_OUT_PLAYER_REBS": "box_out_player_rebs",
        "PCT_BOX_OUTS_OFF": "pct_box_outs_off", "PCT_BOX_OUTS_DEF": "pct_box_outs_def",
        "PCT_BOX_OUTS_TEAM_REB": "pct_box_outs_team_reb", "PCT_BOX_OUTS_REB": "pct_box_outs_reb",
    },
}

PER_GAME_DERIVATIONS: dict[str, tuple[str, str]] = {
    "deflections_pg": ("players_hustle", "deflections"),
    "charges_drawn_pg": ("players_hustle", "charges_drawn"),
    "contested_shots_pg": ("players_hustle", "contested_shots"),
    "loose_balls_recovered_pg": ("players_hustle", "loose_balls_recovered"),
    "screen_ast_pg": ("players_hustle", "screen_assists"),
    "box_outs_pg": ("players_hustle", "box_outs"),
    "pts_off_tov_pg": ("players_misc", "pts_off_tov"),
    "second_chance_pts_pg": ("players_misc", "pts_second_chance"),
    "fast_break_pts_pg": ("players_misc", "fast_break_points"),
    "paint_pts_pg": ("players_misc", "paint_points"),
}

PLAYER_MATCH_ID_FIELDS = ("PLAYER_ID", "CLOSE_DEF_PERSON_ID", "VS_PLAYER_ID")
PLAYER_MATCH_NAME_FIELDS = ("PLAYER_NAME", "PLAYER", "CLOSE_DEF_PERSON_NAME", "VS_PLAYER_NAME")
SKIP_IDENTITY_FIELDS = {
    *PLAYER_MATCH_ID_FIELDS,
    *PLAYER_MATCH_NAME_FIELDS,
    "TEAM_ID", "TEAM_NAME", "TEAM_ABBREVIATION", "GROUP_ID", "GROUP_NAME", "GROUP_SET",
}


def _number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace(",", "").replace("%", "")
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _name_token(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or "").strip().lower())
    text = "".join(char for char in text if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", "", text)


def _first(row: dict[str, Any], fields: Iterable[str]) -> Any:
    for field in fields:
        value = row.get(field)
        if value is not None and str(value).strip() != "":
            return value
    return None


def _season_type_dirs(season_type: str) -> tuple[str, ...]:
    normalized = season_type.strip().lower()
    if "play" in normalized or "post" in normalized:
        return ("playoffs", "postseason", "playoff")
    return ("regular-season", "regular", "regularseason")


def discover_raw_roots(raw_roots: Iterable[Path] | None = None) -> list[Path]:
    candidates = list(raw_roots or DEFAULT_RAW_ROOTS)
    result: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        path = Path(candidate).expanduser().resolve()
        key = str(path)
        if key in seen or not path.is_dir():
            continue
        seen.add(key)
        result.append(path)
    return result


def _normalized_candidates(raw_roots: Iterable[Path], surface: str, season: str, season_type: str) -> list[Path]:
    candidates: list[Path] = []
    for root in raw_roots:
        for folder in _season_type_dirs(season_type):
            path = root / surface / season / folder / "normalized.json"
            if path.is_file():
                candidates.append(path)
    candidates.sort(key=lambda path: path.stat().st_mtime_ns, reverse=True)
    return candidates


def _metadata_for(normalized_path: Path) -> dict[str, Any]:
    metadata_path = normalized_path.with_name("metadata.json")
    if not metadata_path.is_file():
        return {}
    try:
        payload = json.loads(metadata_path.read_text(encoding="utf-8"))
        return payload if isinstance(payload, dict) else {}
    except Exception:
        return {}


def enrichment_fingerprint(raw_roots: Iterable[Path] | None = None) -> dict[str, Any]:
    roots = discover_raw_roots(raw_roots)
    records: list[str] = []
    file_count = 0
    for root in roots:
        for path in sorted(root.glob("*/*/*/normalized.json")):
            stat = path.stat()
            try:
                relative = path.relative_to(root)
            except ValueError:
                relative = path
            records.append(f"{root}:{relative}:{stat.st_size}:{stat.st_mtime_ns}")
            file_count += 1
    digest = hashlib.sha256("\n".join(records).encode("utf-8")).hexdigest()
    return {
        "contract": ENRICHMENT_CONTRACT,
        "roots": [str(path) for path in roots],
        "normalized_file_count": file_count,
        "digest": digest,
    }


def _tables(normalized_path: Path) -> list[dict[str, Any]]:
    try:
        payload = json.loads(normalized_path.read_text(encoding="utf-8"))
    except Exception:
        return []
    raw_tables = payload.get("tables") if isinstance(payload, dict) else None
    return [table for table in raw_tables if isinstance(table, dict)] if isinstance(raw_tables, list) else []


def _surface_rows(normalized_path: Path) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for table in _tables(normalized_path):
        rows = table.get("rows")
        if not isinstance(rows, list):
            continue
        result.extend(row for row in rows if isinstance(row, dict))
    return result


def _clear_previous_enrichment(row: dict[str, Any]) -> None:
    keys = row.pop("nba_com_enriched_keys", None)
    if isinstance(keys, list):
        for key in keys:
            if isinstance(key, str):
                row.pop(key, None)
    row.pop("nba_com", None)
    row.pop("nba_com_sources", None)


def _publish(row: dict[str, Any], key: str, value: Any, *, overwrite: bool = False) -> None:
    if value is None or str(value).strip() == "":
        return
    if not overwrite and row.get(key) not in (None, ""):
        return
    row[key] = value
    keys = row.setdefault("nba_com_enriched_keys", [])
    if isinstance(keys, list) and key not in keys:
        keys.append(key)


def _safe_direct_key(source_key: str) -> str | None:
    key = source_key.strip().upper()
    if not key or key in SKIP_IDENTITY_FIELDS:
        return None
    if key == "RANK" or key.endswith("_RANK"):
        return None
    normalized = re.sub(r"[^a-z0-9]+", "_", key.lower()).strip("_")
    return normalized or None


def _merge_surface_fields(target: dict[str, Any], surface: str, source: dict[str, Any]) -> None:
    nba_com = target.setdefault("nba_com", {})
    if isinstance(nba_com, dict):
        nba_com[surface] = dict(source)
    for source_key, value in source.items():
        direct_key = _safe_direct_key(source_key)
        if direct_key:
            _publish(target, direct_key, value)
    for source_key, target_key in SURFACE_FIELD_MAP.get(surface, {}).items():
        if source_key in source:
            _publish(target, target_key, source[source_key])
    if surface == "players_violations":
        violation_aliases = {
            "DISCONTINUE_DRIBBLE": "discontinued_dribble",
            "DISCONTINUED_DRIBBLE": "discontinued_dribble",
            "OFFENSIVE_3_SECONDS": "off_three_sec",
            "OFF_3_SEC": "off_three_sec",
            "DEFENSIVE_3_SECONDS": "def_three_sec",
            "DEF_3_SEC": "def_three_sec",
            "KICKED_BALL": "kicked_ball",
            "KICK_BALL": "kicked_ball",
            "OFFENSIVE_GOALTENDING": "off_goaltending",
            "DEFENSIVE_GOALTENDING": "def_goaltending",
        }
        for source_key, target_key in violation_aliases.items():
            if source_key in source:
                _publish(target, target_key, source[source_key])


def _source_games(row: dict[str, Any], surface: str) -> float | None:
    nba_com = row.get("nba_com")
    source = nba_com.get(surface) if isinstance(nba_com, dict) else None
    if isinstance(source, dict):
        games = _number(_first(source, ("GP", "G")))
        if games is not None and games > 0:
            return games
    games = _number(row.get("games") or row.get("gp"))
    return games if games is not None and games > 0 else None


def _derive_player_metrics(row: dict[str, Any]) -> None:
    for target_key, (surface, source_key) in PER_GAME_DERIVATIONS.items():
        games = _source_games(row, surface)
        total = _number(row.get(source_key))
        if games is not None and total is not None:
            _publish(row, target_key, round(total / games, 6), overwrite=True)
    scoring_games = _source_games(row, "players_scoring")
    if scoring_games is not None:
        fgm = _number(row.get("field_goals_made"))
        threes = _number(row.get("three_pointers_made"))
        if fgm is not None and threes is not None:
            twos = max(0.0, fgm - threes)
            ast2 = _number(row.get("pct_ast_2pm"))
            ast3 = _number(row.get("pct_ast_3pm"))
            uast2 = _number(row.get("pct_uast_2pm"))
            uast3 = _number(row.get("pct_uast_3pm"))
            if ast2 is not None and ast3 is not None:
                _publish(row, "assisted_pts_pg", (2 * twos * ast2 + 3 * threes * ast3) / scoring_games, overwrite=True)
            if uast2 is not None and uast3 is not None:
                _publish(row, "unassisted_pts_pg", (2 * twos * uast2 + 3 * threes * uast3) / scoring_games, overwrite=True)
    dfgm = _number(row.get("d_fgm"))
    dfga = _number(row.get("d_fga"))
    if _number(row.get("d_fg_pct")) is None and dfgm is not None and dfga is not None and dfga > 0:
        _publish(row, "d_fg_pct", dfgm / dfga, overwrite=True)
    if row.get("d_fgm") is not None:
        _publish(row, "dfgm", row.get("d_fgm"), overwrite=True)
    if row.get("d_fga") is not None:
        _publish(row, "dfga", row.get("d_fga"), overwrite=True)
    if row.get("d_fg_pct") is not None:
        _publish(row, "dfg_pct", row.get("d_fg_pct"), overwrite=True)
    if row.get("pct_box_outs_reb") is not None:
        _publish(row, "box_out_pct", row.get("pct_box_outs_reb"), overwrite=True)


def enrich_seed_payload(payload: dict[str, Any], *, season: str, season_type: str, raw_roots: Iterable[Path] | None = None) -> dict[str, Any]:
    roots = discover_raw_roots(raw_roots)
    totals = payload.get("player_season_totals")
    if not isinstance(totals, list):
        payload["nba_com_enrichment"] = {"contract": ENRICHMENT_CONTRACT, "season": season, "season_type": season_type, "surfaces": [], "matched_rows": 0, "unmatched_rows": 0}
        return payload
    player_rows = [row for row in totals if isinstance(row, dict)]
    for row in player_rows:
        _clear_previous_enrichment(row)
    target_by_id = {str(row.get("player_id")): row for row in player_rows if row.get("player_id") not in (None, "")}
    target_by_name: dict[str, list[dict[str, Any]]] = {}
    for row in player_rows:
        token = _name_token(row.get("player_name") or row.get("player_label"))
        if token:
            target_by_name.setdefault(token, []).append(row)
    canonical_by_nba_id: dict[str, str] = {}
    profiles = payload.get("players")
    if isinstance(profiles, list):
        for profile in profiles:
            if not isinstance(profile, dict):
                continue
            nba_id = profile.get("nba_id")
            canonical_id = profile.get("player_id") or profile.get("id")
            if nba_id not in (None, "") and canonical_id not in (None, ""):
                canonical_by_nba_id[str(nba_id)] = str(canonical_id)
    summaries: list[dict[str, Any]] = []
    total_matched = 0
    total_unmatched = 0
    for surface in PLAYER_SEASON_SURFACES:
        candidates = _normalized_candidates(roots, surface, season, season_type)
        if not candidates:
            continue
        normalized_path = candidates[0]
        source_rows = _surface_rows(normalized_path)
        matched = 0
        unmatched = 0
        for source in source_rows:
            target: dict[str, Any] | None = None
            nba_id = _first(source, PLAYER_MATCH_ID_FIELDS)
            if nba_id not in (None, ""):
                canonical_id = canonical_by_nba_id.get(str(nba_id))
                if canonical_id:
                    target = target_by_id.get(canonical_id)
            if target is None:
                token = _name_token(_first(source, PLAYER_MATCH_NAME_FIELDS))
                matches = target_by_name.get(token, []) if token else []
                if len(matches) == 1:
                    target = matches[0]
            if target is None:
                unmatched += 1
                continue
            _merge_surface_fields(target, surface, source)
            sources = target.setdefault("nba_com_sources", [])
            if isinstance(sources, list) and surface not in sources:
                sources.append(surface)
            matched += 1
        metadata = _metadata_for(normalized_path)
        summary = {"surface": surface, "source_file": str(normalized_path), "source_rows": len(source_rows), "matched_rows": matched, "unmatched_rows": unmatched}
        if metadata:
            summary["source_sha256"] = metadata.get("source_sha256")
            summary["rights"] = metadata.get("rights")
        summaries.append(summary)
        total_matched += matched
        total_unmatched += unmatched
    enriched_players = 0
    for row in player_rows:
        if row.get("nba_com_sources"):
            _derive_player_metrics(row)
            enriched_players += 1
    payload["nba_com_enrichment"] = {
        "contract": ENRICHMENT_CONTRACT,
        "season": season,
        "season_type": season_type,
        "roots": [str(root) for root in roots],
        "surfaces": summaries,
        "enriched_players": enriched_players,
        "matched_rows": total_matched,
        "unmatched_rows": total_unmatched,
        "unmatched_policy": "reported-not-fabricated",
    }
    return payload


def _write_json(path: Path, payload: Any) -> None:
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str), encoding="utf-8")
    temp.replace(path)


def _print_no_capture_warning(fingerprint: dict[str, Any]) -> None:
    roots = fingerprint.get("roots") or [str(path.resolve()) for path in DEFAULT_RAW_ROOTS]
    print("NBA.com static enrichment has no local normalized captures to materialize.")
    print("  Expected normalized.json files below one of:")
    for root in roots:
        print(f"    {root}/<surface>/<season>/<regular|playoffs>/normalized.json")
    print("  The historical website remains usable, but NBA.com-only fields such as deflections and hustle metrics will display — until captures are installed.")


def enrich_static_corpus(output: Path, *, raw_roots: Iterable[Path] | None = None, force: bool = False) -> dict[str, Any]:
    output = Path(output).expanduser().resolve()
    manifest_path = output / "manifest.json"
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Static NBA manifest is missing: {manifest_path}")
    roots = discover_raw_roots(raw_roots)
    fingerprint = enrichment_fingerprint(roots)
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    previous = manifest.get("nba_com_enrichment") if isinstance(manifest, dict) else None
    if not force and isinstance(previous, dict) and previous.get("fingerprint") == fingerprint:
        if int(fingerprint.get("normalized_file_count") or 0) == 0:
            _print_no_capture_warning(fingerprint)
        else:
            print(f"NBA.com static enrichment is current: {output}")
        return previous
    season_files = sorted((output / "seasons").glob("*/regular.json")) + sorted((output / "seasons").glob("*/playoffs.json"))
    enriched_files = 0
    enriched_players = 0
    matched_rows = 0
    unmatched_rows = 0
    surface_counts: dict[str, int] = {}
    for path in season_files:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(payload, dict):
            continue
        season = path.parent.name
        season_type = path.stem
        enrich_seed_payload(payload, season=season, season_type=season_type, raw_roots=roots)
        info = payload.get("nba_com_enrichment")
        if isinstance(info, dict):
            if int(info.get("enriched_players") or 0) > 0:
                enriched_files += 1
            enriched_players += int(info.get("enriched_players") or 0)
            matched_rows += int(info.get("matched_rows") or 0)
            unmatched_rows += int(info.get("unmatched_rows") or 0)
            surfaces = info.get("surfaces")
            if isinstance(surfaces, list):
                for item in surfaces:
                    if isinstance(item, dict) and item.get("surface"):
                        key = str(item["surface"])
                        surface_counts[key] = surface_counts.get(key, 0) + 1
        _write_json(path, payload)
    summary = {
        "contract": ENRICHMENT_CONTRACT,
        "fingerprint": fingerprint,
        "raw_roots": [str(root) for root in roots],
        "season_files_scanned": len(season_files),
        "season_files_enriched": enriched_files,
        "enriched_player_rows": enriched_players,
        "matched_source_rows": matched_rows,
        "unmatched_source_rows": unmatched_rows,
        "surface_season_files": surface_counts,
        "rights_note": "Source metadata remains attached per imported surface; commercial/redistribution rights are not inferred by this enrichment step.",
    }
    manifest["nba_com_enrichment"] = summary
    runtime = manifest.setdefault("runtime", {})
    if isinstance(runtime, dict):
        runtime["nba_com_enrichment_static"] = True
        runtime["nba_com_network_required_by_browser"] = False
    _write_json(manifest_path, manifest)
    if int(fingerprint.get("normalized_file_count") or 0) == 0:
        _print_no_capture_warning(fingerprint)
    else:
        print("NBA.com static enrichment complete: " f"{enriched_files} season files, {enriched_players} player rows, " f"{matched_rows} matched source rows, {unmatched_rows} unmatched")
    return summary


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description="Join already-authorized NBA.com normalized player-season captures into the immutable website season corpus. Performs no network requests.")
    parser.add_argument("--output", default=str(ROOT / "web/data/nba_static"))
    parser.add_argument("--raw-root", action="append", default=[])
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    roots = [Path(value) for value in args.raw_root] if args.raw_root else None
    enrich_static_corpus(Path(args.output), raw_roots=roots, force=args.force)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
