#!/usr/bin/env python3
"""Normalize a saved CommonAllPlayers export into Sports Terminal player assets.

This script does not fetch remote data. Save the source export locally first, then run:

python tools/normalize_common_all_players.py \
  --input raw/common_all_players.json \
  --as-of 2026-06-05 \
  --profiles assets/data/nba/players/player_profiles.json \
  --aliases assets/data/nba/players/player_aliases.json
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Iterable

SOURCE_ID = "nba-api-common-all-players"


def main() -> None:
    parser = argparse.ArgumentParser(description="Normalize CommonAllPlayers into Sports Terminal player assets.")
    parser.add_argument("--input", required=True, help="Path to saved CommonAllPlayers JSON export")
    parser.add_argument("--as-of", required=True, help="Source as-of date, for example 2026-06-05")
    parser.add_argument("--profiles", default="assets/data/nba/players/player_profiles.json")
    parser.add_argument("--aliases", default="assets/data/nba/players/player_aliases.json")
    parser.add_argument("--held", default="raw/player_identity_held_rows.json")
    args = parser.parse_args()

    source = json.loads(Path(args.input).read_text())
    rows = extract_rows(source)
    profiles, aliases, held_rows = normalize_rows(rows, args.as_of)

    write_json(Path(args.profiles), {"source": source_header(args.as_of), "players": profiles})
    write_json(Path(args.aliases), {"source": source_header(args.as_of), "aliases": aliases})
    write_json(Path(args.held), {"source": source_header(args.as_of), "heldRows": held_rows})

    print(f"Normalized {len(profiles)} players, {len(aliases)} aliases, {len(held_rows)} held rows.")


def source_header(as_of: str) -> dict[str, Any]:
    return {"id": SOURCE_ID, "asOf": as_of, "type": "source-backed", "usage": "CommonAllPlayers normalized local import"}


def extract_rows(source: dict[str, Any]) -> list[dict[str, Any]]:
    if "rows" in source and isinstance(source["rows"], list):
        return [dict(row) for row in source["rows"]]
    if "resultSets" in source:
        for result_set in source["resultSets"]:
            name = str(result_set.get("name", "")).lower()
            if name in {"commonallplayers", "common_all_players"}:
                headers = result_set.get("headers", [])
                return [dict(zip(headers, row)) for row in result_set.get("rowSet", [])]
    if "data_sets" in source and "CommonAllPlayers" in source["data_sets"] and "rowSet" in source:
        headers = source["data_sets"]["CommonAllPlayers"]
        return [dict(zip(headers, row)) for row in source["rowSet"]]
    raise ValueError("Could not find CommonAllPlayers rows in the input JSON.")


def normalize_rows(rows: Iterable[dict[str, Any]], as_of: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    profiles: list[dict[str, Any]] = []
    aliases: list[dict[str, Any]] = []
    held_rows: list[dict[str, Any]] = []
    seen: set[str] = set()

    for row in rows:
        person_id = clean(row.get("PERSON_ID"))
        display_name = clean(row.get("DISPLAY_FIRST_LAST"))
        if not person_id or not display_name:
            held_rows.append({"reason": "missing required identity fields", "row": row})
            continue
        player_id = f"nba-{person_id}"
        if player_id in seen:
            held_rows.append({"reason": "duplicate PERSON_ID", "row": row})
            continue
        seen.add(player_id)

        first_name, last_name = split_name(display_name)
        profiles.append({
            "id": player_id,
            "displayName": display_name,
            "firstName": first_name,
            "lastName": last_name,
            "position": None,
            "height": None,
            "weightPounds": None,
            "birthDate": None,
            "birthCountry": None,
            "college": None,
            "draftYear": None,
            "draftRound": None,
            "draftPick": None,
            "nbaDebutYear": to_int(row.get("FROM_YEAR")),
            "isActive": active_from_roster_status(row.get("ROSTERSTATUS")),
            "primaryTeamAbbreviation": clean(row.get("TEAM_ABBREVIATION")),
            "sourceId": SOURCE_ID,
            "asOf": as_of,
        })

        aliases.append(alias(player_id, person_id, "providerId", person_id, as_of))
        player_code = clean(row.get("PLAYERCODE"))
        if player_code:
            aliases.append(alias(player_id, player_code, "providerCode", person_id, as_of))
        last_comma_first = clean(row.get("DISPLAY_LAST_COMMA_FIRST"))
        if last_comma_first and last_comma_first != display_name:
            aliases.append(alias(player_id, last_comma_first, "displayLastCommaFirst", person_id, as_of))

    return profiles, aliases, held_rows


def alias(player_id: str, value: str, alias_type: str, provider_id: str, as_of: str) -> dict[str, Any]:
    return {
        "playerId": player_id,
        "alias": value,
        "aliasType": alias_type,
        "providerId": provider_id,
        "providerName": "CommonAllPlayers",
        "effectiveFrom": None,
        "effectiveTo": None,
        "sourceId": SOURCE_ID,
        "asOf": as_of,
        "notes": None,
    }


def clean(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def to_int(value: Any) -> int | None:
    text = clean(value)
    if text is None:
        return None
    try:
        return int(text)
    except ValueError:
        return None


def split_name(value: str) -> tuple[str | None, str | None]:
    parts = value.split()
    if not parts:
        return None, None
    if len(parts) == 1:
        return parts[0], None
    return parts[0], " ".join(parts[1:])


def active_from_roster_status(value: Any) -> bool | None:
    text = clean(value)
    if text is None:
        return None
    normalized = text.lower()
    if normalized in {"1", "active", "true", "y"}:
        return True
    if normalized in {"0", "inactive", "false", "n"}:
        return False
    return None


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
