"""Attach the *same* materialized player-season rows used by Stats to dossiers.

The canonical player-season record is often narrower than the published Stats
snapshot (which contains NBA.com overlays and enrichment). Merging by stable
player key + normalized season segment avoids losing advanced metrics.
Do not overwrite canonical identity/team information or invent null measures.
"""
from __future__ import annotations

from typing import Any

_IDENTITY = frozenset({
    "player_id", "id", "player_key", "player_name", "name", "team_key",
    "team_id", "team_abbreviation", "team_ids", "team_name", "positions",
    "position", "season_id", "season_type", "season", "league_id",
    "games", "gp", "minutes", "min", "points", "pts", "rebounds",
    "reb", "assists", "ast", "steals", "stl", "blocks", "blk",
    "turnovers", "tov", "personal_fouls", "pf",
})


def overlay_published_season(dossier: dict[str, Any],
                             snapshot: dict[str, Any],
                             season_id: str, segment: str) -> int:
    """Merge source-backed non-null metrics for matching player/season.

    Aggregate player totals remain attached to season records. When the
    dossier has multiple team-stint rows we attach the combined overlay only
    to the combined row (if one exists); never stamp combined numbers on a
    single team's statistics.
    """
    rows = snapshot.get("player_season_totals")
    if not isinstance(rows, list):
        return 0
    player = dossier.get("profile") or {}
    key = str(player.get("player_key") or "")
    if not key:
        return 0
    targets = [
        row for row in dossier.get("seasons", [])
        if isinstance(row, dict)
        and str(row.get("season_id")) == season_id
        and str(row.get("season_type", "")).lower() == segment
    ]
    if not targets:
        return 0
    combined = [
        row for row in targets
        if not str(row.get("team_abbreviation") or "").strip()
        or str(row.get("team_abbreviation")).upper() in {
            "TOT", "2TM", "3TM", "4TM"
        }
    ]

    def merge(target: dict[str, Any], source: dict[str, Any]) -> int:
        applied = 0
        for metric, value in source.items():
            if metric in _IDENTITY or value is None or value == "":
                continue
            if metric not in target or target[metric] is None:
                target[metric] = value
                applied += 1
        return applied

    updated = 0
    for row in rows:
        if not isinstance(row, dict) or str(row.get("player_id")) != key:
            continue
        destinations = combined
        if not destinations and len(targets) == 1:
            team = str(row.get("team_ids") or row.get("team_abbreviation")
                       or "").upper()
            target_team = str(targets[0].get("team_abbreviation") or "").upper()
            if team not in {"TOT", "2TM", "3TM", "4TM"} and (
                not team or not target_team or team == target_team
            ):
                destinations = targets
        for target in destinations:
            updated += merge(target, row)

        # Traded-player aggregate rows must never be assigned to individual
        # team seasons. A source-provided matching team stint is safe.
        stints = row.get("team_stints")
        if isinstance(stints, list):
            for stint in stints:
                if not isinstance(stint, dict):
                    continue
                team = str(stint.get("team_abbreviation") or
                           stint.get("team_ids") or "").upper()
                if not team:
                    continue
                for target in targets:
                    if str(target.get("team_abbreviation") or "").upper() == team:
                        updated += merge(target, stint)
    # The dossier stores these as distinct lists pointing to original rows.
    # Rebuild copies to support callers that do not preserve object identity.
    dossier["regular_seasons"] = [
        r for r in dossier.get("seasons", [])
        if str(r.get("season_type", "")).lower() == "regular"
    ]
    dossier["playoff_seasons"] = [
        r for r in dossier.get("seasons", [])
        if str(r.get("season_type", "")).lower() == "playoffs"
    ]
    return updated
