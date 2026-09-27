from __future__ import annotations

import argparse
import hashlib
import json
import re
import unicodedata
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[1] if Path(__file__).resolve().parent.name == "tools" else Path.cwd()
DEFAULT_RAW_ROOTS = (ROOT / "raw/nba_com_stats", ROOT.parent / "raw/nba_com_stats")
DEFAULT_OUTPUT = ROOT / "web/data/nba_static"
CONTRACT = "sports-terminal-nba-com-part1-season-enrichment-v1"

PLAYER_ID_KEYS = ("PLAYER_ID", "CLOSE_DEF_PERSON_ID", "PERSON_ID", "playerId", "personId")
PLAYER_NAME_KEYS = ("PLAYER_NAME", "PLAYER", "playerName")


def number(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).replace(",", "").replace("%", "").strip())
    except ValueError:
        return None


def name_token(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or "").strip().lower())
    text = "".join(char for char in text if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", "", text)


def first(row: dict[str, Any], keys: Iterable[str]) -> Any:
    lookup = {str(key).lower(): value for key, value in row.items()}
    for key in keys:
        if key in row and row[key] not in (None, ""):
            return row[key]
        value = lookup.get(key.lower())
        if value not in (None, ""):
            return value
    return None


def raw_roots(candidates: Iterable[Path] | None = None) -> list[Path]:
    result: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates or DEFAULT_RAW_ROOTS:
        path = Path(candidate).expanduser().resolve()
        if str(path) in seen or not path.is_dir():
            continue
        seen.add(str(path))
        result.append(path)
    return result


def capture_path(roots: list[Path], surface: str, variant: str, season: str, season_type: str) -> Path | None:
    folder = "playoffs" if "play" in season_type.lower() else "regular"
    candidates: list[Path] = []
    for root in roots:
        path = root / surface / variant / season / folder / "normalized.json"
        if path.is_file():
            candidates.append(path)
    candidates.sort(key=lambda item: item.stat().st_mtime_ns, reverse=True)
    return candidates[0] if candidates else None


def metadata_for(normalized: Path) -> dict[str, Any]:
    path = normalized.with_name("metadata.json")
    if not path.is_file():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        return payload if isinstance(payload, dict) else {}
    except Exception:
        return {}


def rows_for(normalized: Path) -> list[dict[str, Any]]:
    try:
        payload = json.loads(normalized.read_text(encoding="utf-8"))
    except Exception:
        return []
    tables = payload.get("tables") if isinstance(payload, dict) else None
    result: list[dict[str, Any]] = []
    if isinstance(tables, list):
        for table in tables:
            if not isinstance(table, dict):
                continue
            rows = table.get("rows")
            if isinstance(rows, list):
                result.extend(dict(row) for row in rows if isinstance(row, dict))
    return result


def publish(target: dict[str, Any], key: str, value: Any, *, overwrite: bool = True) -> None:
    if value is None or str(value).strip() == "":
        return
    if not overwrite and target.get(key) not in (None, ""):
        return
    target[key] = value
    keys = target.setdefault("nba_com_part1_enriched_keys", [])
    if isinstance(keys, list) and key not in keys:
        keys.append(key)


def publish_ratio(target: dict[str, Any], key: str, numerator: Any, denominator: Any) -> None:
    a, b = number(numerator), number(denominator)
    if a is not None and b not in (None, 0):
        publish(target, key, a / b)


def publish_sum_ratio(
    target: dict[str, Any],
    key: str,
    numerators: Iterable[Any],
    denominators: Iterable[Any],
) -> None:
    top = [number(value) for value in numerators]
    bottom = [number(value) for value in denominators]
    if any(value is None for value in top + bottom):
        return
    denominator = sum(value or 0 for value in bottom)
    if denominator:
        publish(target, key, sum(value or 0 for value in top) / denominator)


def publish_per_game(target: dict[str, Any], key: str, source: dict[str, Any], field: str) -> None:
    gp = number(first(source, ("GP", "G")))
    value = number(source.get(field))
    if gp not in (None, 0) and value is not None:
        publish(target, key, value / gp)


def canonical_totals(target: dict[str, Any]) -> tuple[float | None, float | None]:
    fga = number(first(target, ("field_goal_attempts", "fga")))
    three_a = number(first(target, ("three_point_attempts", "three_pa", "fg3a")))
    return fga, three_a


def apply_metrics(target: dict[str, Any], surface: str, variant: str, source: dict[str, Any]) -> None:
    if surface == "players_clutch":
        if variant == "base":
            for key, field in {
                "clutch_ppg": "PTS", "clutch_rpg": "REB", "clutch_apg": "AST",
                "clutch_spg": "STL", "clutch_bpg": "BLK",
            }.items():
                publish_per_game(target, key, source, field)
            for key, field in {"clutch_fg_pct": "FG_PCT", "clutch_three_pct": "FG3_PCT", "clutch_ft_pct": "FT_PCT"}.items():
                publish(target, key, source.get(field))
        elif variant == "advanced":
            publish(target, "clutch_net_rating", source.get("NET_RATING"))

    if surface == "players_synergy":
        ppp = source.get("PPP")
        synergy_map = {
            "isolation_offensive": "isolation_ppp",
            "transition_offensive": "transition_offense_ppp",
            "transition_defensive": "transition_defense_ppp",
            "transition_defence": "transition_defense_ppp",
            "prballhandler_offensive": "pnr_ball_handler_ppp",
            "prrollman_offensive": "pnr_roll_man_ppp",
            "postup_offensive": "post_up_ppp",
            "spotup_offensive": "spot_up_ppp",
        }
        metric = synergy_map.get(variant)
        if metric:
            publish(target, metric, ppp)
        if variant == "transition_offensive":
            publish(target, "transition_ppp", ppp)

    if surface == "players_tracking":
        if variant == "drives":
            publish_per_game(target, "drive_ppg", source, "DRIVE_PTS")
            publish_per_game(target, "drive_apg", source, "DRIVE_AST")
        elif variant == "defense":
            publish(target, "rim_dfg_pct", source.get("DEF_RIM_FG_PCT"), overwrite=False)
        elif variant == "catchshoot":
            publish(target, "catch_shoot_three_pct", source.get("CATCH_SHOOT_FG3_PCT"))
            fga, _ = canonical_totals(target)
            publish_ratio(target, "catch_shoot_three_frequency", source.get("CATCH_SHOOT_FG3A"), fga)
        elif variant == "passing":
            for key, field in {
                "passes_pg": "PASSES_MADE", "secondary_apg": "SECONDARY_AST",
                "potential_apg": "POTENTIAL_AST", "ft_apg": "FT_AST",
            }.items():
                publish_per_game(target, key, source, field)
            # NBA's adjusted assist-to-pass percentage already includes its
            # adjusted-assist definition (direct, FT and secondary creation).
            publish(
                target,
                "adjusted_assist_ratio",
                source.get("AST_TO_PASS_PCT_ADJ"),
            )
        elif variant == "possessions":
            publish_per_game(target, "touches_pg", source, "TOUCHES")
            publish(target, "time_per_touch", source.get("AVG_SEC_PER_TOUCH"))
            publish(target, "dribbles_per_touch", source.get("AVG_DRIB_PER_TOUCH"))
        elif variant == "pullupshot":
            publish(target, "pull_up_three_pct", source.get("PULL_UP_FG3_PCT"))
            fga, _ = canonical_totals(target)
            publish_ratio(target, "pull_up_three_frequency", source.get("PULL_UP_FG3A"), fga)
        elif variant == "rebounding":
            for key, field in {
                "contested_rpg": "REB_CONTEST", "uncontested_rpg": "REB_UNCONTEST",
                "contested_dreb_pg": "DREB_CONTEST", "uncontested_dreb_pg": "DREB_UNCONTEST",
                "contested_orb_pg": "OREB_CONTEST", "uncontested_orb_pg": "OREB_UNCONTEST",
                "deferred_rebounds_pg": "REB_CHANCE_DEFER",
            }.items():
                publish_per_game(target, key, source, field)
        elif variant == "speeddistance":
            publish(target, "distance_traveled", source.get("DIST_MILES"))
            publish(target, "average_speed", source.get("AVG_SPEED"))

    if surface == "players_defense_dashboard":
        if variant == "overall":
            publish(target, "dfg_pct", first(source, ("D_FG_PCT", "FG_PCT")))
            publish(target, "dfgm", first(source, ("D_FGM", "FGM")))
            publish(target, "dfga", first(source, ("D_FGA", "FGA")))
        elif variant == "3_pointers":
            publish(target, "three_dfg_pct", first(source, ("FG3_PCT", "D_FG_PCT")))
        elif variant == "less_than_6ft":
            publish(target, "rim_dfg_pct", first(source, ("LT_06_PCT", "D_FG_PCT")))

    if surface == "players_shot_dashboard":
        if variant == "general_overall":
            # The canonical historical warehouse can contain made threes while
            # lacking 3PA/3P% for some source rows. NBA.com's overall shot
            # dashboard carries the exact season totals, so fill only missing
            # canonical shooting fields from that source-backed row.
            for key, field in {
                "three_pointers_made": "FG3M",
                "three_point_attempts": "FG3A",
                "three_point_percentage": "FG3_PCT",
                "two_pointers_made": "FG2M",
                "two_point_attempts": "FG2A",
                "two_point_percentage": "FG2_PCT",
            }.items():
                publish(target, key, source.get(field), overwrite=False)
            # Keep the short canonical aliases synchronized because the
            # workstation engine consumes these keys directly.
            for key, field in {
                "three_pm": "FG3M",
                "three_pa": "FG3A",
                "three_pct": "FG3_PCT",
                "two_pm": "FG2M",
                "two_pa": "FG2A",
                "two_pct": "FG2_PCT",
            }.items():
                publish(target, key, source.get(field), overwrite=False)
        elif variant == "general_catch_and_shoot":
            # FGA_FREQUENCY is the share of all shots that are catch-and-shoot;
            # FG3A_FREQUENCY is the three share inside that selected bucket.
            bucket = number(source.get("FGA_FREQUENCY"))
            three_share = number(source.get("FG3A_FREQUENCY"))
            if bucket is not None and three_share is not None:
                publish(target, "catch_shoot_three_frequency", bucket * three_share)
            publish(target, "catch_shoot_three_pct", source.get("FG3_PCT"))
        elif variant == "general_pullups":
            bucket = number(source.get("FGA_FREQUENCY"))
            three_share = number(source.get("FG3A_FREQUENCY"))
            if bucket is not None and three_share is not None:
                publish(target, "pull_up_three_frequency", bucket * three_share)
            publish(target, "pull_up_three_pct", source.get("FG3_PCT"))

    if surface == "players_shot_locations" and variant == "base_by_zone":
        fga, _ = canonical_totals(target)
        zone_map = {
            "Restricted Area": ("rim_frequency", "rim_fg_pct"),
            "Mid-Range": ("midrange_frequency", "midrange_fg_pct"),
            "Left Corner 3": ("left_corner_three_frequency", "left_corner_three_pct"),
            "Right Corner 3": ("right_corner_three_frequency", "right_corner_three_pct"),
            "Corner 3": ("corner_three_frequency", "corner_three_pct"),
        }
        for zone, (freq_key, pct_key) in zone_map.items():
            attempts = source.get(f"{zone}__FGA")
            pct = source.get(f"{zone}__FG_PCT")
            publish_ratio(target, freq_key, attempts, fga)
            publish(target, pct_key, pct)

        # "Paint" in the catalog means the whole painted area, so combine the
        # Restricted Area and non-RA paint buckets instead of silently treating
        # only the latter as paint.
        restricted_fga = source.get("Restricted Area__FGA")
        non_ra_fga = source.get("In The Paint (Non-RA)__FGA")
        restricted_fgm = source.get("Restricted Area__FGM")
        non_ra_fgm = source.get("In The Paint (Non-RA)__FGM")
        paint_attempts = sum(
            value or 0
            for value in (number(restricted_fga), number(non_ra_fga))
        )
        if fga not in (None, 0) and paint_attempts:
            publish(target, "paint_frequency", paint_attempts / fga)
        publish_sum_ratio(
            target,
            "paint_fg_pct",
            (restricted_fgm, non_ra_fgm),
            (restricted_fga, non_ra_fga),
        )

    if surface == "players_hustle":
        for key, field in {
            "deflections_pg": "DEFLECTIONS", "charges_drawn_pg": "CHARGES_DRAWN",
            "contested_shots_pg": "CONTESTED_SHOTS", "loose_balls_recovered_pg": "LOOSE_BALLS_RECOVERED",
            "screen_apg": "SCREEN_ASSISTS",
        }.items():
            publish_per_game(target, key, source, field)
        # NBA exposes PCT_BOX_OUTS_REB as BOX_OUT_PLAYER_REBS / BOX_OUTS:
        # the share of the player's box outs on which that player secures the
        # rebound. Preserve that native percentage rather than inventing a rate.
        box_out_pct = first(source, ("PCT_BOX_OUTS_REB", "PCT_BOX_OUTS_TEAM_REB"))
        publish(target, "box_out_pct", box_out_pct)


def clear_previous(row: dict[str, Any]) -> None:
    keys = row.pop("nba_com_part1_enriched_keys", None)
    if isinstance(keys, list):
        for key in keys:
            if isinstance(key, str):
                row.pop(key, None)
    row.pop("nba_com_part1", None)
    row.pop("nba_com_part1_sources", None)


def capture_inventory(roots: list[Path], season: str, season_type: str) -> list[tuple[str, str, Path]]:
    folder = "playoffs" if "play" in season_type.lower() else "regular"
    found: dict[tuple[str, str], Path] = {}
    for root in roots:
        for path in root.glob(f"*/*/{season}/{folder}/normalized.json"):
            try:
                surface, variant = path.parts[-5], path.parts[-4]
            except IndexError:
                continue
            metadata = metadata_for(path)
            if str(metadata.get("grain") or "") != "player_season":
                continue
            if str(metadata.get("validation_status") or "") not in {"success", "empty"}:
                continue
            key = (surface, variant)
            current = found.get(key)
            if current is None or path.stat().st_mtime_ns > current.stat().st_mtime_ns:
                found[key] = path
    return [(surface, variant, path) for (surface, variant), path in sorted(found.items())]


def enrich_payload(payload: dict[str, Any], *, season: str, season_type: str, roots: list[Path]) -> dict[str, Any]:
    totals = payload.get("player_season_totals")
    if not isinstance(totals, list):
        return payload
    targets = [row for row in totals if isinstance(row, dict)]
    for row in targets:
        clear_previous(row)

    profiles = payload.get("players") if isinstance(payload.get("players"), list) else []
    canonical_by_nba_id: dict[str, str] = {}
    for profile in profiles:
        if not isinstance(profile, dict):
            continue
        nba_id = profile.get("nba_id")
        canonical_id = profile.get("player_id") or profile.get("id")
        if nba_id not in (None, "") and canonical_id not in (None, ""):
            canonical_by_nba_id[str(nba_id)] = str(canonical_id)

    by_id: dict[str, list[dict[str, Any]]] = {}
    by_name: dict[str, list[dict[str, Any]]] = {}
    for row in targets:
        pid = str(row.get("player_id") or "").strip()
        if pid:
            by_id.setdefault(pid, []).append(row)
        token = name_token(row.get("player_name") or row.get("player_label"))
        if token:
            by_name.setdefault(token, []).append(row)

    surface_summaries: list[dict[str, Any]] = []
    total_matched = total_unmatched = 0
    for surface, variant, path in capture_inventory(roots, season, season_type):
        source_rows = rows_for(path)
        matched = unmatched = 0
        for source in source_rows:
            target: dict[str, Any] | None = None
            nba_id = first(source, PLAYER_ID_KEYS)
            if nba_id not in (None, ""):
                canonical_id = canonical_by_nba_id.get(str(nba_id))
                candidates = by_id.get(canonical_id or "", [])
                if len(candidates) == 1:
                    target = candidates[0]
            if target is None:
                token = name_token(first(source, PLAYER_NAME_KEYS))
                candidates = by_name.get(token, []) if token else []
                if len(candidates) == 1:
                    target = candidates[0]
            if target is None:
                unmatched += 1
                continue
            nested = target.setdefault("nba_com_part1", {})
            if isinstance(nested, dict):
                surface_bucket = nested.setdefault(surface, {})
                if isinstance(surface_bucket, dict):
                    surface_bucket[variant] = source
            sources = target.setdefault("nba_com_part1_sources", [])
            source_label = f"{surface}/{variant}"
            if isinstance(sources, list) and source_label not in sources:
                sources.append(source_label)
            apply_metrics(target, surface, variant, source)
            matched += 1
        metadata = metadata_for(path)
        surface_summaries.append({
            "surface": surface,
            "variant": variant,
            "rows": len(source_rows),
            "matched": matched,
            "unmatched": unmatched,
            "source_sha256": metadata.get("source_sha256"),
            "schema_sha256": metadata.get("schema_sha256"),
        })
        total_matched += matched
        total_unmatched += unmatched

    payload["nba_com_part1_enrichment"] = {
        "contract": CONTRACT,
        "season": season,
        "season_type": season_type,
        "surfaces": surface_summaries,
        "matched_rows": total_matched,
        "unmatched_rows": total_unmatched,
        "enriched_players": sum(1 for row in targets if row.get("nba_com_part1_sources")),
        "unmatched_policy": "reported-not-fabricated",
    }
    return payload


def fingerprint(roots: list[Path]) -> dict[str, Any]:
    records: list[str] = []
    count = 0
    for root in roots:
        for path in sorted(root.glob("*/*/*/*/normalized.json")):
            stat = path.stat()
            records.append(f"{root}:{path.relative_to(root)}:{stat.st_size}:{stat.st_mtime_ns}")
            count += 1
    return {"contract": CONTRACT, "normalized_file_count": count, "digest": hashlib.sha256("\n".join(records).encode()).hexdigest()}


def write_json(path: Path, payload: Any) -> None:
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str), encoding="utf-8")
    temp.replace(path)


def enrich_corpus(output: Path, *, roots: list[Path], force: bool = False) -> dict[str, Any]:
    manifest_path = output / "manifest.json"
    if not manifest_path.is_file():
        raise FileNotFoundError(f"Static NBA manifest is missing: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    fp = fingerprint(roots)
    previous = manifest.get("nba_com_part1_enrichment") if isinstance(manifest, dict) else None
    if not force and isinstance(previous, dict) and previous.get("fingerprint") == fp:
        return previous

    files = sorted((output / "seasons").glob("*/regular.json")) + sorted((output / "seasons").glob("*/playoffs.json"))
    files_enriched = players_enriched = matched = unmatched = 0
    for path in files:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if not isinstance(payload, dict):
            continue
        season, season_type = path.parent.name, path.stem
        enrich_payload(payload, season=season, season_type=season_type, roots=roots)
        info = payload.get("nba_com_part1_enrichment") or {}
        if int(info.get("enriched_players") or 0):
            files_enriched += 1
        players_enriched += int(info.get("enriched_players") or 0)
        matched += int(info.get("matched_rows") or 0)
        unmatched += int(info.get("unmatched_rows") or 0)
        write_json(path, payload)

    summary = {
        "contract": CONTRACT,
        "fingerprint": fp,
        "season_files_scanned": len(files),
        "season_files_enriched": files_enriched,
        "enriched_player_rows": players_enriched,
        "matched_source_rows": matched,
        "unmatched_source_rows": unmatched,
        "runtime_api_required": False,
    }
    manifest["nba_com_part1_enrichment"] = summary
    runtime = manifest.setdefault("runtime", {})
    if isinstance(runtime, dict):
        runtime["nba_com_part1_static"] = True
        runtime["nba_com_part1_network_required_by_browser"] = False
    write_json(manifest_path, manifest)
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description="Join Part 1 NBA.com player-season captures into Sports Terminal static season shards. Performs no network requests.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--raw-root", action="append", default=[])
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    roots = raw_roots([Path(value) for value in args.raw_root] if args.raw_root else None)
    if not roots:
        print(json.dumps({"contract": CONTRACT, "normalized_file_count": 0, "message": "No Part 1 NBA.com captures installed; static corpus left unchanged."}, indent=2))
        return 0
    summary = enrich_corpus(args.output.expanduser().resolve(), roots=roots, force=args.force)
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
