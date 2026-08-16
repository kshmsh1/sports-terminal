from __future__ import annotations

import argparse
import json
from collections import OrderedDict
from urllib.parse import urlencode

STATS_ORIGIN = "https://stats.nba.com"
NBA_ORIGIN = "https://www.nba.com"

# Confirmed from normal Chrome browser requests captured on 2026-08-16 from
# NBA.com Stats. This module intentionally only models reviewed request shapes.
# It performs no network requests and persists no cookies, tokens, authorization
# headers, or browser session material.
PLAYERS_ADVANCED_ENDPOINT = "/stats/leaguedashplayerstats"
PLAYERS_ADVANCED_RESULT_SET = "LeagueDashPlayerStats"
PLAYERS_ADVANCED_GAME_LOGS_ENDPOINT = "/stats/playergamelogs"
PLAYERS_ADVANCED_GAME_LOGS_RESOURCE = "gamelogs"
PLAYERS_ADVANCED_GAME_LOGS_RESULT_SET = "PlayerGameLogs"

PLAYERS_ADVANCED_GAME_LOGS_HEADERS: tuple[str, ...] = (
    "SEASON_YEAR",
    "PLAYER_ID",
    "PLAYER_NAME",
    "NICKNAME",
    "TEAM_ID",
    "TEAM_ABBREVIATION",
    "TEAM_NAME",
    "GAME_ID",
    "GAME_DATE",
    "MATCHUP",
    "WL",
    "MIN",
    "E_OFF_RATING",
    "OFF_RATING",
    "sp_work_OFF_RATING",
    "E_DEF_RATING",
    "DEF_RATING",
    "sp_work_DEF_RATING",
    "E_NET_RATING",
    "NET_RATING",
    "sp_work_NET_RATING",
    "AST_PCT",
    "AST_TO",
    "AST_RATIO",
    "OREB_PCT",
    "DREB_PCT",
    "REB_PCT",
    "TM_TOV_PCT",
    "E_TOV_PCT",
    "EFG_PCT",
    "TS_PCT",
    "USG_PCT",
    "E_USG_PCT",
    "E_PACE",
    "PACE",
    "PACE_PER40",
    "sp_work_PACE",
    "PIE",
    "POSS",
    "FGM",
    "FGA",
    "FGM_PG",
    "FGA_PG",
    "FG_PCT",
    "GP_RANK",
    "W_RANK",
    "L_RANK",
    "W_PCT_RANK",
    "MIN_RANK",
    "E_OFF_RATING_RANK",
    "OFF_RATING_RANK",
    "sp_work_OFF_RATING_RANK",
    "E_DEF_RATING_RANK",
    "DEF_RATING_RANK",
    "sp_work_DEF_RATING_RANK",
    "E_NET_RATING_RANK",
    "NET_RATING_RANK",
    "sp_work_NET_RATING_RANK",
    "AST_PCT_RANK",
    "AST_TO_RANK",
    "AST_RATIO_RANK",
    "OREB_PCT_RANK",
    "DREB_PCT_RANK",
    "REB_PCT_RANK",
    "TM_TOV_PCT_RANK",
    "E_TOV_PCT_RANK",
    "EFG_PCT_RANK",
    "TS_PCT_RANK",
    "USG_PCT_RANK",
    "E_USG_PCT_RANK",
    "E_PACE_RANK",
    "PACE_RANK",
    "sp_work_PACE_RANK",
    "PIE_RANK",
    "FGM_RANK",
    "FGA_RANK",
    "FGM_PG_RANK",
    "FGA_PG_RANK",
    "FG_PCT_RANK",
    "AVAILABLE_FLAG",
    "MIN_SEC",
    "TEAM_COUNT",
)

PLAYERS_ADVANCED_PARAMETER_DEFAULTS: "OrderedDict[str, str]" = OrderedDict(
    [
        ("College", ""), ("Conference", ""), ("Country", ""), ("DateFrom", ""),
        ("DateTo", ""), ("Division", ""), ("DraftPick", ""), ("DraftYear", ""),
        ("GameScope", ""), ("GameSegment", ""), ("Height", ""), ("ISTRound", ""),
        ("LastNGames", "0"), ("LeagueID", "00"), ("Location", ""),
        ("MeasureType", "Advanced"), ("Month", "0"), ("OpponentTeamID", "0"),
        ("Outcome", ""), ("PORound", "0"), ("PaceAdjust", "N"),
        ("PerMode", "PerGame"), ("Period", "0"), ("PlayerExperience", ""),
        ("PlayerPosition", ""), ("PlusMinus", "N"), ("Rank", "N"),
        ("Season", "2025-26"), ("SeasonSegment", ""),
        ("SeasonType", "Regular Season"), ("ShotClockRange", ""),
        ("StarterBench", ""), ("TeamID", "0"), ("VsConference", ""),
        ("VsDivision", ""), ("Weight", ""),
    ]
)

PLAYERS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS: "OrderedDict[str, str]" = OrderedDict(
    [
        ("DateFrom", ""), ("DateTo", ""), ("GameSegment", ""), ("ISTRound", ""),
        ("LastNGames", "0"), ("LeagueID", "00"), ("Location", ""),
        ("MeasureType", "Advanced"), ("Month", "0"), ("OpponentTeamID", "0"),
        ("Outcome", ""), ("PORound", "0"), ("PaceAdjust", "N"),
        ("PerMode", "Totals"), ("Period", "0"), ("PlusMinus", "N"),
        ("Rank", "N"), ("Season", "2025-26"), ("SeasonSegment", ""),
        ("SeasonType", "Regular Season"), ("ShotClockRange", ""),
        ("VsConference", ""), ("VsDivision", ""),
    ]
)

SAFE_BROWSER_HEADERS = OrderedDict(
    [
        ("Accept", "*/*"),
        ("Accept-Language", "en-US,en;q=0.9"),
        ("Origin", NBA_ORIGIN),
        ("Referer", f"{NBA_ORIGIN}/"),
        ("Sec-Fetch-Dest", "empty"),
        ("Sec-Fetch-Mode", "cors"),
        ("Sec-Fetch-Site", "same-site"),
    ]
)

SENSITIVE_HEADER_NAMES = {
    "authorization",
    "cookie",
    "proxy-authorization",
    "x-api-key",
    "x-auth-token",
}


def _params(defaults: OrderedDict[str, str], overrides: dict[str, object]) -> OrderedDict[str, str]:
    params = OrderedDict(defaults)
    unknown = sorted(set(overrides) - set(params))
    if unknown:
        raise KeyError(f"Unknown confirmed NBA Stats parameter(s): {', '.join(unknown)}")
    for key, value in overrides.items():
        params[key] = "" if value is None else str(value)
    return params


def players_advanced_params(**overrides: object) -> OrderedDict[str, str]:
    return _params(PLAYERS_ADVANCED_PARAMETER_DEFAULTS, overrides)


def players_advanced_url(**overrides: object) -> str:
    return f"{STATS_ORIGIN}{PLAYERS_ADVANCED_ENDPOINT}?{urlencode(players_advanced_params(**overrides))}"


def players_advanced_game_logs_params(**overrides: object) -> OrderedDict[str, str]:
    return _params(PLAYERS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS, overrides)


def players_advanced_game_logs_url(**overrides: object) -> str:
    return (
        f"{STATS_ORIGIN}{PLAYERS_ADVANCED_GAME_LOGS_ENDPOINT}?"
        f"{urlencode(players_advanced_game_logs_params(**overrides))}"
    )


def safe_headers(*, user_agent: str | None = None) -> OrderedDict[str, str]:
    headers = OrderedDict(SAFE_BROWSER_HEADERS)
    if user_agent:
        headers["User-Agent"] = user_agent
    return headers


def request_contracts() -> dict[str, object]:
    return {
        "contract": "sports-terminal-nba-com-confirmed-requests-v3",
        "confirmed_on": "2026-08-16",
        "confirmed_from": "normal_browser_capture",
        "network_behavior": "none; this module only builds reviewed request shapes",
        "sensitive_headers_persisted": False,
        "requests": {
            "players_advanced": {
                "method": "GET",
                "host": "stats.nba.com",
                "path": PLAYERS_ADVANCED_ENDPOINT,
                "result_set": PLAYERS_ADVANCED_RESULT_SET,
                "parameters": dict(PLAYERS_ADVANCED_PARAMETER_DEFAULTS),
            },
            "players_advanced_box_scores": {
                "method": "GET",
                "host": "stats.nba.com",
                "path": PLAYERS_ADVANCED_GAME_LOGS_ENDPOINT,
                "resource": PLAYERS_ADVANCED_GAME_LOGS_RESOURCE,
                "result_set": PLAYERS_ADVANCED_GAME_LOGS_RESULT_SET,
                "headers": list(PLAYERS_ADVANCED_GAME_LOGS_HEADERS),
                "parameters": dict(PLAYERS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS),
                "grain": "player-game",
            },
        },
        "safe_headers": dict(SAFE_BROWSER_HEADERS),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Print confirmed NBA.com Stats request contracts without making a network request."
    )
    parser.add_argument(
        "--surface",
        choices=("players_advanced", "players_advanced_box_scores"),
        default="players_advanced",
    )
    parser.add_argument("--season", default="2025-26")
    parser.add_argument("--season-type", default="Regular Season")
    parser.add_argument("--per-mode")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if args.surface == "players_advanced_box_scores":
        per_mode = args.per_mode or "Totals"
        url = players_advanced_game_logs_url(
            Season=args.season,
            SeasonType=args.season_type,
            PerMode=per_mode,
        )
    else:
        per_mode = args.per_mode or "PerGame"
        url = players_advanced_url(
            Season=args.season,
            SeasonType=args.season_type,
            PerMode=per_mode,
        )

    if args.json:
        payload = request_contracts()
        payload["selected_surface"] = args.surface
        payload["example_url"] = url
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0

    print(url)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
