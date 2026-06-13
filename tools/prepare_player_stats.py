from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

from sports_reference.linked_table import first_link, integer, number, text


def normalized_name(value: str) -> str:
    value = value.replace("*", "")
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    return " ".join(re.sub(r"[^a-z0-9]+", " ", value.lower()).split())


def player_label(row: dict) -> str | None:
    return text(row, "player", "player_name")


def player_source_key(row: dict) -> str | None:
    link = first_link(row, "player", "player_name")
    return None if link is None else link.get("sourceKey")


def team_label(row: dict) -> str | None:
    return text(row, "team", "team_name", "tm")


def team_abbreviation(row: dict) -> str | None:
    link = first_link(row, "team", "team_name", "tm")
    source_key = None if link is None else link.get("sourceKey")
    if source_key:
        match = re.search(r"basketball-reference:team(?:-season)?:([A-Z0-9]{2,3})", source_key)
        if match:
            return match.group(1)
    label = team_label(row)
    if label and re.fullmatch(r"[A-Z0-9]{2,3}", label):
        return label
    return None


def group_rows(rows: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        label = player_label(row)
        if not label:
            continue
        key = player_source_key(row) or f"name:{normalized_name(label)}"
        grouped[key].append(row)
    return grouped


def choose_aggregate(rows: list[dict]) -> tuple[dict, str]:
    total = next(
        (
            row
            for row in rows
            if (team_label(row) or "").upper() in {"TOT", "TOTAL"}
        ),
        None,
    )
    if total is not None:
        return total, "provider-total-row"
    if len(rows) == 1:
        return rows[0], "single-row"
    return max(rows, key=lambda row: integer(row, "g", "games") or 0), "highest-games-row"


def metric(row: dict, *keys: str) -> float | None:
    return number(row, *keys)


def build_row(
    raw: dict,
    advanced: dict | None,
    player_id: str,
    team_id: str | None,
    season_id: str,
    source_id: str,
    as_of: str,
) -> dict:
    advanced = advanced or {}
    offensive = metric(advanced, "off_rtg", "ortg")
    defensive = metric(advanced, "def_rtg", "drtg")
    return {
        "id": f"basketball-reference-{season_id}-regular-{player_id}",
        "playerId": player_id,
        "seasonId": season_id,
        "teamId": team_id,
        "seasonType": "Regular Season",
        "gamesPlayed": integer(raw, "g", "games"),
        "minutesPerGame": metric(raw, "mp_per_g", "mp", "minutes_per_game"),
        "pointsPerGame": metric(raw, "pts_per_g", "pts", "points_per_game"),
        "reboundsPerGame": metric(raw, "trb_per_g", "trb", "rebounds_per_game"),
        "assistsPerGame": metric(raw, "ast_per_g", "ast", "assists_per_game"),
        "stealsPerGame": metric(raw, "stl_per_g", "stl", "steals_per_game"),
        "blocksPerGame": metric(raw, "blk_per_g", "blk", "blocks_per_game"),
        "turnoversPerGame": metric(raw, "tov_per_g", "tov", "turnovers_per_game"),
        "personalFoulsPerGame": metric(raw, "pf_per_g", "pf", "personal_fouls_per_game"),
        "fieldGoalPercentage": metric(raw, "fg_pct"),
        "threePointPercentage": metric(raw, "fg3_pct", "x3p_pct", "3p_pct"),
        "freeThrowPercentage": metric(raw, "ft_pct"),
        "effectiveFieldGoalPercentage": metric(raw, "efg_pct"),
        "trueShootingPercentage": metric(advanced, "ts_pct"),
        "usagePercentage": metric(advanced, "usg_pct"),
        "offensiveRating": offensive,
        "defensiveRating": defensive,
        "netRating": None if offensive is None or defensive is None else offensive - defensive,
        "sourceId": source_id,
        "asOf": as_of,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Normalize link-aware player tables into Sports Terminal candidates."
    )
    parser.add_argument("--input", required=True)
    parser.add_argument("--advanced-input")
    parser.add_argument("--season-id", required=True)
    parser.add_argument("--as-of", default=datetime.now(timezone.utc).date().isoformat())
    parser.add_argument("--minimum-rows", type=int, default=350)
    parser.add_argument("--output")
    parser.add_argument("--held")
    parser.add_argument("--source-index")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    input_path = Path(args.input)
    document = json.loads(input_path.read_text(encoding="utf-8"))
    advanced_document = (
        json.loads(Path(args.advanced_input).read_text(encoding="utf-8"))
        if args.advanced_input
        else {"rows": []}
    )

    profiles = json.loads(
        Path("assets/data/nba/players/player_profiles.json").read_text(encoding="utf-8")
    ).get("players", [])
    teams = json.loads(
        Path("assets/data/nba/teams/teams.json").read_text(encoding="utf-8")
    ).get("teams", [])
    players_by_name: dict[str, list[dict]] = defaultdict(list)
    for profile in profiles:
        players_by_name[normalized_name(profile["displayName"])].append(profile)
    teams_by_abbreviation = {team["abbreviation"]: team for team in teams}

    advanced_groups = group_rows(advanced_document.get("rows", []))
    stats = []
    held = []
    source_links = []
    source_id = f"basketball-reference:{args.season_id}:player-regular-season"

    for provider_key, player_rows in group_rows(document.get("rows", [])).items():
        raw, selection_method = choose_aggregate(player_rows)
        label = player_label(raw)
        matches = players_by_name.get(normalized_name(label or ""), [])
        if len(matches) != 1:
            held.append(
                {
                    "reason": "unmatched-player" if not matches else "ambiguous-player",
                    "playerLabel": label,
                    "providerKey": provider_key,
                    "candidatePlayerIds": [item["id"] for item in matches],
                    "rows": player_rows,
                }
            )
            continue

        team_id = None
        abbreviation = team_abbreviation(raw)
        current_team_label = (team_label(raw) or "").upper()
        if current_team_label not in {"TOT", "TOTAL", ""}:
            team = teams_by_abbreviation.get(abbreviation or "")
            if team is None:
                held.append(
                    {
                        "reason": "unmatched-team",
                        "playerLabel": label,
                        "providerKey": provider_key,
                        "teamLabel": team_label(raw),
                        "teamAbbreviation": abbreviation,
                    }
                )
                continue
            team_id = team["id"]

        advanced = None
        if provider_key in advanced_groups:
            advanced, _ = choose_aggregate(advanced_groups[provider_key])
        profile = matches[0]
        stats.append(
            build_row(
                raw,
                advanced,
                profile["id"],
                team_id,
                args.season_id,
                source_id,
                args.as_of,
            )
        )
        player_link = first_link(raw, "player", "player_name")
        source_links.append(
            {
                "provider": "basketball-reference",
                "sourceKey": provider_key,
                "sourceUrl": None if player_link is None else player_link.get("href"),
                "sourceLabel": label,
                "entityType": "player",
                "entityId": profile["id"],
                "confidence": "exact-normalized-name",
                "rowSelection": selection_method,
            }
        )

    output_path = Path(args.output) if args.output else input_path.with_name("player_traditional_candidate.json")
    held_path = Path(args.held) if args.held else input_path.with_name("player_traditional_held_rows.json")
    source_index_path = (
        Path(args.source_index)
        if args.source_index
        else input_path.with_name("player_source_index_candidate.json")
    )
    source = {
        "id": source_id,
        "asOf": args.as_of,
        "type": "public-web-snapshot",
        "usage": "Candidate player regular-season statistics pending validation",
    }
    output_path.write_text(
        json.dumps({"source": source, "stats": sorted(stats, key=lambda item: item["playerId"])}, indent=2) + "\n",
        encoding="utf-8",
    )
    held_path.write_text(json.dumps({"heldRows": held}, indent=2) + "\n", encoding="utf-8")
    source_index_path.write_text(
        json.dumps({"mappings": sorted(source_links, key=lambda item: item["sourceKey"])}, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Matched players: {len(stats)}")
    print(f"Held players: {len(held)}")
    print(f"Candidate: {output_path}")
    print(f"Held: {held_path}")
    print(f"Source index: {source_index_path}")

    can_apply = not held and len(stats) >= args.minimum_rows
    if args.apply:
        if not can_apply:
            raise SystemExit(
                f"Refusing --apply: minimum {args.minimum_rows} rows, "
                f"matched {len(stats)}, held {len(held)}."
            )
        canonical = Path("assets/data/nba/stats/player_traditional_by_season.json")
        canonical.write_text(
            json.dumps({"source": source, "stats": sorted(stats, key=lambda item: item["playerId"])}, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Applied: {canonical}")
    else:
        print("Canonical assets were not modified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
