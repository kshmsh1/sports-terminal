from __future__ import annotations

import argparse
import json
import re
import unicodedata
from datetime import datetime, timezone
from pathlib import Path


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKD", value)
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    value = value.lower().replace("’", "'")
    return " ".join(re.sub(r"[^a-z0-9]+", " ", value).split())


def iter_links(document: dict):
    for row in document.get("rows", []):
        for cell in row.get("cells", {}).values():
            for link in cell.get("links", []):
                yield link


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Map Basketball Reference source keys to current Sports Terminal entities."
    )
    parser.add_argument("--input", action="append", required=True)
    parser.add_argument("--output", default="raw/basketball_reference/source_entity_index.json")
    parser.add_argument("--held", default="raw/basketball_reference/source_entity_index_held.json")
    args = parser.parse_args()

    profiles = json.loads(
        Path("assets/data/nba/players/player_profiles.json").read_text(encoding="utf-8")
    ).get("players", [])
    teams = json.loads(
        Path("assets/data/nba/teams/teams.json").read_text(encoding="utf-8")
    ).get("teams", [])
    seasons = json.loads(
        Path("assets/data/nba/seasons/seasons.json").read_text(encoding="utf-8")
    ).get("seasons", [])

    players_by_name: dict[str, list[dict]] = {}
    for profile in profiles:
        players_by_name.setdefault(normalize(profile["displayName"]), []).append(profile)
    teams_by_abbreviation = {team["abbreviation"]: team for team in teams}
    seasons_by_end_year = {}
    for season in seasons:
        match = re.search(r"(\d{2})$", season["id"])
        if match:
            start = int(season["id"][:4])
            seasons_by_end_year[str(start + 1)] = season

    resolved: dict[str, dict] = {}
    held: dict[str, dict] = {}
    for input_path in args.input:
        document = json.loads(Path(input_path).read_text(encoding="utf-8"))
        for link in iter_links(document):
            source_key = link.get("sourceKey")
            if not source_key or source_key in resolved or source_key in held:
                continue
            entity_type = link.get("entityType")
            label = link.get("text") or ""
            target = None
            confidence = None
            reason = None

            if entity_type == "player":
                matches = players_by_name.get(normalize(label), [])
                if len(matches) == 1:
                    target = {"entityType": "player", "entityId": matches[0]["id"]}
                    confidence = "exact-normalized-name"
                elif not matches:
                    reason = "no-player-name-match"
                else:
                    reason = "ambiguous-player-name-match"
            elif entity_type in {"team", "team-season"}:
                match = re.search(r"basketball-reference:team(?:-season)?:([A-Z0-9]{2,3})", source_key)
                team = teams_by_abbreviation.get(match.group(1) if match else "")
                if team:
                    target = {"entityType": "team", "entityId": team["id"]}
                    confidence = "provider-team-abbreviation"
                else:
                    reason = "no-team-abbreviation-match"
            elif entity_type == "season":
                match = re.search(r":season:(\d{4})$", source_key)
                season = seasons_by_end_year.get(match.group(1) if match else "")
                if season:
                    target = {"entityType": "season", "entityId": season["id"]}
                    confidence = "provider-season-end-year"
                else:
                    reason = "no-season-match"
            else:
                reason = "terminal-entity-type-not-yet-modeled"

            base = {
                "provider": "basketball-reference",
                "sourceKey": source_key,
                "sourceEntityType": entity_type,
                "sourceLabel": label,
                "sourceUrl": link.get("href"),
            }
            if target:
                resolved[source_key] = {
                    **base,
                    **target,
                    "confidence": confidence,
                }
            else:
                held[source_key] = {**base, "reason": reason}

    generated_at = datetime.now(timezone.utc).isoformat()
    output_path = Path(args.output)
    held_path = Path(args.held)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    held_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(
            {
                "provider": "basketball-reference",
                "generatedAt": generated_at,
                "mappingCount": len(resolved),
                "mappings": sorted(resolved.values(), key=lambda item: item["sourceKey"]),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    held_path.write_text(
        json.dumps(
            {
                "provider": "basketball-reference",
                "generatedAt": generated_at,
                "heldCount": len(held),
                "held": sorted(held.values(), key=lambda item: item["sourceKey"]),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Resolved source entities: {len(resolved)}")
    print(f"Held source entities: {len(held)}")
    print(f"Index: {output_path}")
    print(f"Held: {held_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
