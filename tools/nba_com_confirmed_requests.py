from __future__ import annotations

import argparse
import json
from collections import OrderedDict
from urllib.parse import urlencode

STATS_ORIGIN = "https://stats.nba.com"
NBA_ORIGIN = "https://www.nba.com"

# Confirmed from a normal Chrome browser request captured on 2026-08-16 from
# https://www.nba.com/stats/players/advanced. This module intentionally only
# models the request shape. It performs no network requests and persists no
# cookies, tokens, authorization headers, or browser session material.
PLAYERS_ADVANCED_ENDPOINT = "/stats/leaguedashplayerstats"
PLAYERS_ADVANCED_RESULT_SET = "LeagueDashPlayerStats"

PLAYERS_ADVANCED_PARAMETER_DEFAULTS: "OrderedDict[str, str]" = OrderedDict(
    [
        ("College", ""),
        ("Conference", ""),
        ("Country", ""),
        ("DateFrom", ""),
        ("DateTo", ""),
        ("Division", ""),
        ("DraftPick", ""),
        ("DraftYear", ""),
        ("GameScope", ""),
        ("GameSegment", ""),
        ("Height", ""),
        ("ISTRound", ""),
        ("LastNGames", "0"),
        ("LeagueID", "00"),
        ("Location", ""),
        ("MeasureType", "Advanced"),
        ("Month", "0"),
        ("OpponentTeamID", "0"),
        ("Outcome", ""),
        ("PORound", "0"),
        ("PaceAdjust", "N"),
        ("PerMode", "PerGame"),
        ("Period", "0"),
        ("PlayerExperience", ""),
        ("PlayerPosition", ""),
        ("PlusMinus", "N"),
        ("Rank", "N"),
        ("Season", "2025-26"),
        ("SeasonSegment", ""),
        ("SeasonType", "Regular Season"),
        ("ShotClockRange", ""),
        ("StarterBench", ""),
        ("TeamID", "0"),
        ("VsConference", ""),
        ("VsDivision", ""),
        ("Weight", ""),
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


def players_advanced_params(**overrides: object) -> OrderedDict[str, str]:
    params = OrderedDict(PLAYERS_ADVANCED_PARAMETER_DEFAULTS)
    unknown = sorted(set(overrides) - set(params))
    if unknown:
        raise KeyError(f"Unknown confirmed NBA Stats parameter(s): {', '.join(unknown)}")
    for key, value in overrides.items():
        params[key] = "" if value is None else str(value)
    return params


def players_advanced_url(**overrides: object) -> str:
    return f"{STATS_ORIGIN}{PLAYERS_ADVANCED_ENDPOINT}?{urlencode(players_advanced_params(**overrides))}"


def safe_headers(*, user_agent: str | None = None) -> OrderedDict[str, str]:
    headers = OrderedDict(SAFE_BROWSER_HEADERS)
    if user_agent:
        headers["User-Agent"] = user_agent
    return headers


def request_contract() -> dict[str, object]:
    return {
        "contract": "sports-terminal-nba-com-confirmed-request-v1",
        "surface": "players_advanced",
        "method": "GET",
        "host": "stats.nba.com",
        "path": PLAYERS_ADVANCED_ENDPOINT,
        "result_set": PLAYERS_ADVANCED_RESULT_SET,
        "confirmed_from": "normal_browser_capture",
        "confirmed_on": "2026-08-16",
        "parameters": dict(PLAYERS_ADVANCED_PARAMETER_DEFAULTS),
        "safe_headers": dict(SAFE_BROWSER_HEADERS),
        "sensitive_headers_persisted": False,
        "network_behavior": "none; this module only builds reviewed request shapes",
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Print the confirmed NBA.com Players Advanced request contract without making a network request."
    )
    parser.add_argument("--season", default="2025-26")
    parser.add_argument("--season-type", default="Regular Season")
    parser.add_argument("--per-mode", default="PerGame")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if args.json:
        payload = request_contract()
        payload["example_url"] = players_advanced_url(
            Season=args.season,
            SeasonType=args.season_type,
            PerMode=args.per_mode,
        )
        print(json.dumps(payload, indent=2, sort_keys=True))
        return 0

    print(
        players_advanced_url(
            Season=args.season,
            SeasonType=args.season_type,
            PerMode=args.per_mode,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
