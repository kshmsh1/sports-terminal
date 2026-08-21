from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from typing import Iterable

NBA_STATS_BASE = "https://www.nba.com"


@dataclass(frozen=True)
class NbaStatsSurface:
    key: str
    label: str
    entity: str
    family: str
    page_path: str
    grain: str
    minimum_season: str | None
    endpoint_hint: str | None = None
    measure_type_hint: str | None = None
    discovery_status: str = "har_required"
    notes: tuple[str, ...] = ()

    @property
    def page_url(self) -> str:
        return f"{NBA_STATS_BASE}{self.page_path}"

    def to_dict(self) -> dict[str, object]:
        payload = asdict(self)
        payload["page_url"] = self.page_url
        return payload


def _surface(key: str, label: str, entity: str, family: str, page_path: str, grain: str,
             minimum_season: str | None, *, endpoint_hint: str | None = None,
             measure_type_hint: str | None = None, discovery_status: str = "har_required",
             notes: Iterable[str] = ()) -> NbaStatsSurface:
    return NbaStatsSurface(key, label, entity, family, page_path, grain, minimum_season,
                           endpoint_hint, measure_type_hint, discovery_status, tuple(notes))


GENERAL_CAPTURE_NOTE = "User-supplied browser captures confirm Regular Season and Playoffs for 2023-24, 2024-25, and 2025-26."

SURFACES: dict[str, NbaStatsSurface] = {
    "players_season_leaders": _surface(
        "players_season_leaders","Players / Season Leaders","player","traditional_leaders",
        "/stats/players/traditional","player-season leaderboard aggregate","1951-52",
        endpoint_hint="leagueLeaders",discovery_status="confirmed_browser_capture_schema_confirmed",
        notes=(
            "User-supplied captures confirm GET stats.nba.com/stats/leagueLeaders with PerMode=Totals, Scope=S and StatCategory=PTS.",
            "Regular Season and Playoffs are confirmed for every season from 1951-52 through 2025-26 across the supplied historical captures.",
            "Response resource is leagueleaders; the singular resultSet object is named LeagueLeaders.",
            "This is a leaderboard-oriented source and must not be treated as the canonical complete player-season population without independent completeness validation.",
            "Schema includes player/team identity, GP/MIN, shooting totals and percentages, OREB/DREB/REB, AST/STL/BLK/TOV/PF/PTS, EFF, AST_TOV and STL_TOV.",
        ),
    ),
    "players_base": _surface(
        "players_base","Players / General / Traditional","player","base","/stats/players/traditional",
        "player-season filtered aggregate",None,endpoint_hint="leaguedashplayerstats",measure_type_hint="Base",
        discovery_status="confirmed_browser_capture_schema_confirmed",notes=(
            GENERAL_CAPTURE_NOTE,
            "Confirmed with PerMode=Totals and result set LeagueDashPlayerStats.",
            "This is the preferred complete-population player-season source over leagueLeaders for captured modern seasons.",
            "Schema includes PLAYER_ID/PLAYER_NAME/team/age, GP/W/L/W%, MIN, complete traditional shooting/counting totals, PLUS_MINUS, fantasy points, DD2, TD3, ranks, and TEAM_COUNT.",
        ),
    ),
    "players_advanced": _surface(
        "players_advanced","Players / General / Advanced","player","advanced","/stats/players/advanced",
        "player-season filtered aggregate","1996-97",endpoint_hint="leaguedashplayerstats",measure_type_hint="Advanced",
        discovery_status="confirmed_browser_capture_schema_confirmed",notes=(
            "NBA FAQ says advanced statistics go back to 1996-97.",GENERAL_CAPTURE_NOTE,
            "Confirmed with PerMode=Totals and result set LeagueDashPlayerStats.",
            "Schema includes estimated/standard offensive, defensive and net ratings, AST%, AST/TO, AST ratio, rebound rates, turnover rates, eFG%, TS%, usage, pace, PIE and possessions.",
        ),
    ),
    "players_misc": _surface(
        "players_misc","Players / General / Misc","player","misc","/stats/players/misc",
        "player-season filtered aggregate","1996-97",endpoint_hint="leaguedashplayerstats",measure_type_hint="Misc",
        discovery_status="confirmed_browser_capture_schema_confirmed",notes=(GENERAL_CAPTURE_NOTE,
            "Schema includes points off turnovers, second-chance points, fast-break points, paint points and opponent counterparts, plus blocks, blocks against, fouls and fouls drawn.")),
    "players_scoring": _surface(
        "players_scoring","Players / General / Scoring","player","scoring","/stats/players/scoring",
        "player-season filtered aggregate","1996-97",endpoint_hint="leaguedashplayerstats",measure_type_hint="Scoring",
        discovery_status="confirmed_browser_capture_schema_confirmed",notes=(GENERAL_CAPTURE_NOTE,
            "Schema includes 2PT/3PT attempt share, point-source shares, paint/fast-break/FT/off-turnover shares and assisted/unassisted make shares.")),
    "players_usage": _surface(
        "players_usage","Players / General / Usage","player","usage","/stats/players/usage",
        "player-season filtered aggregate","1996-97",endpoint_hint="leaguedashplayerstats",measure_type_hint="Usage",
        discovery_status="confirmed_browser_capture_schema_confirmed",notes=(GENERAL_CAPTURE_NOTE,
            "Schema includes USG_PCT and player shares of team FGM/FGA/3PM/3PA/FTM/FTA/rebounds/assists/turnovers/steals/blocks/fouls/fouls drawn/points.")),
    "players_opponent": _surface(
        "players_opponent","Players / General / Opponent","player","opponent","/stats/players/opponent",
        "player-on-court opponent aggregate",None,endpoint_hint="leagueplayerondetails",measure_type_hint="Opponent",
        discovery_status="confirmed_browser_capture_schema_confirmed",notes=(GENERAL_CAPTURE_NOTE,
            "Response resource is leagueplayerondetails and result set is PlayersOnCourtLeaguePlayerDetails.",
            "Schema includes GROUP_SET, team identity, VS_PLAYER identity, COURT_STATUS and opponent traditional production while that player is on court.")),
    "players_defense": _surface(
        "players_defense","Players / General / Defense","player","defense","/stats/players/defense",
        "player-season filtered aggregate",None,endpoint_hint="leaguedashplayerstats",measure_type_hint="Defense",
        discovery_status="confirmed_browser_capture_schema_confirmed",notes=(GENERAL_CAPTURE_NOTE,
            "Schema includes DEF_RATING, defensive rebound totals/rates, steal/block totals and shares, opponent context scoring, DEF_WS and DEF_WS_RAW.")),
    "players_violations": _surface(
        "players_violations","Players / General / Violations","player","violations","/stats/players/violations",
        "player-season violation aggregate",None,endpoint_hint="leaguedashplayerstats",measure_type_hint="Violations",
        discovery_status="confirmed_browser_capture_schema_confirmed",notes=(GENERAL_CAPTURE_NOTE,
            "Schema includes travel, double/discontinued dribble, three-second, inbound, backcourt, goaltending, palming, offensive foul, charge, lane, jump-ball and kicked-ball violations.")),
    "players_estimated_advanced": _surface(
        "players_estimated_advanced","Players / General / Estimated Advanced","player","estimated_advanced",
        "/stats/players/estimated-advanced","player-season estimated metric aggregate",None,
        endpoint_hint="playerestimatedmetrics",measure_type_hint="Estimated",discovery_status="confirmed_browser_capture_schema_confirmed",
        notes=(GENERAL_CAPTURE_NOTE,
            "Response resource is playerestimatedmetrics and singular resultSet is PlayerEstimatedMetrics.",
            "Schema includes estimated offensive/defensive/net rating, assist ratio, offensive/defensive/total rebound percentages, turnover percentage, usage percentage and pace.")),
    "teams_advanced": _surface("teams_advanced","Teams / General / Advanced","team","advanced","/stats/teams/advanced","team-season filtered aggregate","1996-97",endpoint_hint="leaguedashteamstats",measure_type_hint="Advanced",discovery_status="har_confirmation_required"),
    "lineups_advanced": _surface("lineups_advanced","Lineups / General / Advanced","lineup","lineups","/stats/lineups/advanced","lineup-season aggregate","2008-09",endpoint_hint="leaguedashlineups",measure_type_hint="Advanced",discovery_status="confirmed_browser_capture_schema_confirmed",notes=("NBA FAQ says lineup data goes back to 2008; exact first season should still be checked empirically.","Chrome capture on 2026-08-16 confirmed GET stats.nba.com/stats/leaguedashlineups with MeasureType=Advanced, PerMode=PerGame and GroupQuantity=5.","Response resource is leaguedashlineups and result set is Lineups.","Schema includes group identity, team identity, GP/W/L/W%, minutes, estimated and standard ratings, assist/rebound/turnover rates, eFG%, TS%, pace, possessions, PIE, rank metadata, and SUM_TIME_PLAYED.")),
    "players_advanced_box_scores": _surface("players_advanced_box_scores","Players / Advanced Box Scores / Advanced","player","advanced_box_score","/stats/players/boxscores-advanced","player-game","1996-97",endpoint_hint="playergamelogs",measure_type_hint="Advanced",discovery_status="confirmed_browser_capture_schema_confirmed",notes=("NBA.com states Advanced Box Score Stats only go back to the 1996-97 season.","Chrome capture on 2026-08-16 confirmed GET stats.nba.com/stats/playergamelogs with MeasureType=Advanced and PerMode=Totals.","Response resource is gamelogs and result set is PlayerGameLogs.")),
    "teams_advanced_box_scores": _surface("teams_advanced_box_scores","Teams / Advanced Box Scores / Advanced","team","advanced_box_score","/stats/teams/boxscores-advanced","team-game","1996-97",endpoint_hint="teamgamelogs",measure_type_hint="Advanced",discovery_status="confirmed_browser_capture_schema_confirmed",notes=("Chrome capture on 2026-08-16 confirmed GET stats.nba.com/stats/teamgamelogs with MeasureType=Advanced and PerMode=Totals.","Response resource is gamelogs and result set is TeamGameLogs.")),
    "players_clutch": _surface("players_clutch","Players / Clutch","player","clutch","/stats/players/clutch-traditional","player-season clutch split",None),
    "teams_clutch": _surface("teams_clutch","Teams / Clutch","team","clutch","/stats/teams/clutch-traditional","team-season clutch split",None),
    "players_tracking": _surface("players_tracking","Players / Tracking","player","tracking","/stats/players/tracking","player tracking aggregate",None),
    "teams_tracking": _surface("teams_tracking","Teams / Tracking","team","tracking","/stats/teams/tracking","team tracking aggregate",None),
    "players_defense_dashboard": _surface("players_defense_dashboard","Players / Defense Dashboard","player","defense_dashboard","/stats/players/defense-dash-overall","player defensive matchup/shot aggregate",None),
    "teams_defense_dashboard": _surface("teams_defense_dashboard","Teams / Defense Dashboard","team","defense_dashboard","/stats/teams/defense-dash-overall","team defensive matchup/shot aggregate",None),
    "players_shot_dashboard": _surface("players_shot_dashboard","Players / Shot Dashboard","player","shot_dashboard","/stats/players/shots-general","player shooting split",None),
    "teams_shot_dashboard": _surface("teams_shot_dashboard","Teams / Shot Dashboard","team","shot_dashboard","/stats/teams/shots-general","team shooting split",None),
    "players_playtype": _surface("players_playtype","Players / Play Type","player","playtype","/stats/players/isolation","player play-type possession aggregate",None),
    "teams_playtype": _surface("teams_playtype","Teams / Play Type","team","playtype","/stats/teams/isolation","team play-type possession aggregate",None),
    "players_shooting": _surface("players_shooting","Players / Shooting","player","shooting","/stats/players/shooting","player shooting aggregate",None),
    "teams_shooting": _surface("teams_shooting","Teams / Shooting","team","shooting","/stats/teams/shooting","team shooting aggregate",None),
    "players_opponent_shooting": _surface("players_opponent_shooting","Players / Opponent Shooting","player","opponent_shooting","/stats/players/opponent-shooting","player opponent shooting aggregate",None),
    "teams_opponent_shooting": _surface("teams_opponent_shooting","Teams / Opponent Shooting","team","opponent_shooting","/stats/teams/opponent-shooting","team opponent shooting aggregate",None),
    "players_hustle": _surface("players_hustle","Players / Hustle","player","hustle","/stats/players/hustle","player hustle aggregate",None),
    "teams_hustle": _surface("teams_hustle","Teams / Hustle","team","hustle","/stats/teams/hustle","team hustle aggregate",None),
    "players_boxouts": _surface("players_boxouts","Players / Box Outs","player","boxouts","/stats/players/box-outs","player box-out aggregate",None),
    "teams_boxouts": _surface("teams_boxouts","Teams / Box Outs","team","boxouts","/stats/teams/box-outs","team box-out aggregate",None),
}


def surface_for_referer(referer: str | None) -> NbaStatsSurface | None:
    if not referer:
        return None
    path = referer.split("?", 1)[0]
    matches = [surface for surface in SURFACES.values() if surface.page_path in path]
    return max(matches, key=lambda surface: len(surface.page_path)) if matches else None


def registry_payload() -> dict[str, object]:
    return {"contract":"sports-terminal-nba-com-stats-surface-registry-v1","official_coverage":{"advanced_stats_start":"1996-97","lineup_data_note":"NBA FAQ says lineup data goes back to 2008.","season_leaders_confirmed_range":"1951-52 through 2025-26 for both Regular Season and Playoffs from user-supplied browser captures.","player_general_confirmed_range":"2023-24 through 2025-26 for both Regular Season and Playoffs across Base, Advanced, Misc, Scoring, Usage, Opponent, Defense, Violations and Estimated Metrics captures.","season_leaders_completeness_note":"leagueLeaders is leaderboard-oriented and is not the canonical complete player-season population source.","transport_policy":"Confirm request schemas from normal browser captures; do not assume unconfirmed endpoint hints are supported public APIs."},"surfaces":[SURFACES[key].to_dict() for key in sorted(SURFACES)]}


def main() -> int:
    parser = argparse.ArgumentParser(description="List the Sports Terminal NBA.com Stats surface registry.")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--surface", choices=sorted(SURFACES))
    args = parser.parse_args()
    if args.surface:
        print(json.dumps(SURFACES[args.surface].to_dict(), indent=2)); return 0
    if args.json:
        print(json.dumps(registry_payload(), indent=2)); return 0
    for surface in SURFACES.values():
        print(f"{surface.key:30} {surface.minimum_season or 'discover':8} {surface.page_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
