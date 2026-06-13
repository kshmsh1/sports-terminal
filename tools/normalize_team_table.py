from __future__ import annotations

import argparse
import json
import re
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

from sports_reference.linked_table import first_link, number, text


def normalized_name(value: str) -> str:
    value = value.replace("*", "")
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    return " ".join(re.sub(r"[^a-z0-9]+", " ", value.lower()).split())


def team_abbreviation(row: dict) -> str | None:
    link = first_link(row, "team", "team_name")
    source_key = None if link is None else link.get("sourceKey")
    if source_key:
        match = re.search(r"basketball-reference:team(?:-season)?:([A-Z0-9]{2,3})", source_key)
        if match:
            return match.group(1)
    return None


def team_label(row: dict) -> str | None:
    return text(row, "team", "team_name")


def load_team_map() -> tuple[dict[str, dict], dict[str, dict]]:
    document = json.loads(
        Path("assets/data/nba/teams/teams.json").read_text(encoding="utf-8")
    )
    teams = document.get("teams", [])
    by_abbreviation = {team["abbreviation"]: team for team in teams}
    by_name = {normalized_name(team["name"]): team for team in teams}
    return by_abbreviation, by_name


def resolve_team(row: dict, by_abbreviation: dict[str, dict], by_name: dict[str, dict]):
    abbreviation = team_abbreviation(row)
    if abbreviation and abbreviation in by_abbreviation:
        return by_abbreviation[abbreviation], "source-link-abbreviation"
    label = team_label(row)
    if label:
        team = by_name.get(normalized_name(label))
        if team:
            return team, "normalized-team-name"
    return None, None


def build_stats(row: dict, team_id: str, season_id: str, source_id: str, as_of: str) -> dict:
    offensive_rating = number(row, "off_rtg", "ortg")
    defensive_rating = number(row, "def_rtg", "drtg")
    net_rating = None
    if offensive_rating is not None and defensive_rating is not None:
        net_rating = offensive_rating - defensive_rating
    return {
        "id": f"basketball-reference-{season_id}-regular-{team_id}",
        "teamId": team_id,
        "seasonId": season_id,
        "seasonType": "Regular Season",
        "wins": None,
        "losses": None,
        "winPercentage": None,
        "pointsPerGame": number(row, "pts", "points"),
        "opponentPointsPerGame": None,
        "pace": number(row, "pace"),
        "offensiveRating": offensive_rating,
        "defensiveRating": defensive_rating,
        "netRating": net_rating,
        "personalFoulsPerGame": number(row, "pf"),
        "fieldGoalPercentage": number(row, "fg_pct"),
        "threePointPercentage": number(row, "fg3_pct", "x3p_pct", "3p_pct"),
        "freeThrowPercentage": number(row, "ft_pct"),
        "effectiveFieldGoalPercentage": number(row, "efg_pct"),
        "trueShootingPercentage": number(row, "ts_pct"),
        "turnoversPerGame": number(row, "tov"),
        "reboundsPerGame": number(row, "trb"),
        "assistsPerGame": number(row, "ast"),
        "stealsPerGame": number(row, "stl"),
        "blocksPerGame": number(row, "blk"),
        "sourceId": source_id,
        "asOf": as_of,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Normalize one link-aware team table into a Sports Terminal candidate."
    )
    parser.add_argument("--input", required=True)
    parser.add_argument("--season-id", required=True)
    parser.add_argument("--opponent-input")
    parser.add_argument("--as-of", default=datetime.now(timezone.utc).date().isoformat())
    parser.add_argument("--expected-teams", type=int, default=30)
    parser.add_argument("--output")
    parser.add_argument("--held")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    input_path = Path(args.input)
    document = json.loads(input_path.read_text(encoding="utf-8"))
    by_abbreviation, by_name = load_team_map()
    source_id = f"basketball-reference:{args.season_id}:team-regular-season"

    stats = []
    held = []
    resolution = []
    for row in document.get("rows", []):
        label = team_label(row)
        if not label or normalized_name(label) in {"league average", "average"}:
            continue
        team, method = resolve_team(row, by_abbreviation, by_name)
        if team is None:
            held.append({"reason": "unmatched-team", "teamLabel": label, "row": row})
            continue
        stats.append(build_stats(row, team["id"], args.season_id, source_id, args.as_of))
        resolution.append(
            {
                "teamId": team["id"],
                "teamLabel": label,
                "method": method,
                "sourceLink": first_link(row, "team", "team_name"),
            }
        )

    if args.opponent_input:
        opponent_doc = json.loads(Path(args.opponent_input).read_text(encoding="utf-8"))
        opponent_points = {}
        for row in opponent_doc.get("rows", []):
            team, _ = resolve_team(row, by_abbreviation, by_name)
            if team:
                opponent_points[team["id"]] = number(row, "pts", "points")
        for item in stats:
            item["opponentPointsPerGame"] = opponent_points.get(item["teamId"])

    duplicate_ids = sorted(
        team_id
        for team_id in {item["teamId"] for item in stats}
        if sum(1 for item in stats if item["teamId"] == team_id) > 1
    )
    if duplicate_ids:
        held.append({"reason": "duplicate-team-rows", "teamIds": duplicate_ids})

    output_path = Path(args.output) if args.output else input_path.with_name("team_by_season_candidate.json")
    held_path = Path(args.held) if args.held else input_path.with_name("team_by_season_held_rows.json")
    candidate = {
        "source": {
            "id": source_id,
            "asOf": args.as_of,
            "type": "public-web-snapshot",
            "usage": "Candidate team regular-season statistics pending validation",
        },
        "teamSeasonStats": sorted(stats, key=lambda item: item["teamId"]),
        "resolution": sorted(resolution, key=lambda item: item["teamId"]),
    }
    output_path.write_text(json.dumps(candidate, indent=2) + "\n", encoding="utf-8")
    held_path.write_text(json.dumps({"heldRows": held}, indent=2) + "\n", encoding="utf-8")

    print(f"Matched teams: {len(stats)}")
    print(f"Held rows: {len(held)}")
    print(f"Candidate: {output_path}")
    print(f"Held: {held_path}")

    can_apply = not held and len(stats) == args.expected_teams
    if args.apply:
        if not can_apply:
            raise SystemExit(
                f"Refusing --apply: expected {args.expected_teams} teams, "
                f"matched {len(stats)}, held {len(held)}."
            )
        canonical = Path("assets/data/nba/stats/team_by_season.json")
        canonical.write_text(
            json.dumps(
                {"source": candidate["source"], "teamSeasonStats": candidate["teamSeasonStats"]},
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        print(f"Applied: {canonical}")
    else:
        print("Canonical assets were not modified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
