from __future__ import annotations

import json
import sys
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.import_nba_com_authorized_response import normalize_nba_stats_response  # noqa: E402
from tools.inventory_nba_com_stats_har import inventory_har  # noqa: E402
from tools.nba_com_confirmed_requests import (  # noqa: E402
    PLAYERS_ADVANCED_ENDPOINT,
    PLAYERS_ADVANCED_GAME_LOGS_ENDPOINT,
    PLAYERS_ADVANCED_GAME_LOGS_HEADERS,
    PLAYERS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS,
    PLAYERS_ADVANCED_GAME_LOGS_RESOURCE,
    PLAYERS_ADVANCED_GAME_LOGS_RESULT_SET,
    PLAYERS_ADVANCED_PARAMETER_DEFAULTS,
    PLAYERS_ADVANCED_RESULT_SET,
    SENSITIVE_HEADER_NAMES,
    players_advanced_game_logs_url,
    players_advanced_url,
    request_contracts,
    safe_headers,
)
from tools.nba_com_stats_registry import SURFACES, registry_payload, surface_for_referer  # noqa: E402


def check_registry() -> None:
    assert len(SURFACES) >= 25
    assert SURFACES["players_advanced"].minimum_season == "1996-97"
    assert SURFACES["players_advanced_box_scores"].grain == "player-game"
    assert SURFACES["players_advanced_box_scores"].endpoint_hint == "playergamelogs"
    assert SURFACES["players_advanced_box_scores"].discovery_status == "confirmed_browser_capture_schema_confirmed"
    assert SURFACES["lineups_advanced"].minimum_season == "2008-09"
    assert SURFACES["players_advanced"].discovery_status == "confirmed_browser_capture"
    assert SURFACES["players_advanced"].endpoint_hint == "leaguedashplayerstats"
    assert surface_for_referer("https://www.nba.com/stats/players/advanced?Season=2025-26").key == "players_advanced"
    payload = registry_payload()
    assert payload["contract"] == "sports-terminal-nba-com-stats-surface-registry-v1"


def check_confirmed_request_contracts() -> None:
    contract = request_contracts()
    assert contract["contract"] == "sports-terminal-nba-com-confirmed-requests-v3"
    assert contract["confirmed_from"] == "normal_browser_capture"
    assert contract["sensitive_headers_persisted"] is False

    aggregate = contract["requests"]["players_advanced"]
    assert aggregate["path"] == PLAYERS_ADVANCED_ENDPOINT
    assert aggregate["result_set"] == PLAYERS_ADVANCED_RESULT_SET

    game_logs = contract["requests"]["players_advanced_box_scores"]
    assert game_logs["path"] == PLAYERS_ADVANCED_GAME_LOGS_ENDPOINT
    assert game_logs["resource"] == PLAYERS_ADVANCED_GAME_LOGS_RESOURCE == "gamelogs"
    assert game_logs["result_set"] == PLAYERS_ADVANCED_GAME_LOGS_RESULT_SET == "PlayerGameLogs"
    assert game_logs["grain"] == "player-game"
    assert game_logs["parameters"]["MeasureType"] == "Advanced"
    assert game_logs["parameters"]["PerMode"] == "Totals"
    assert tuple(game_logs["headers"]) == PLAYERS_ADVANCED_GAME_LOGS_HEADERS
    required = {
        "SEASON_YEAR", "PLAYER_ID", "PLAYER_NAME", "TEAM_ID", "TEAM_ABBREVIATION",
        "GAME_ID", "GAME_DATE", "MATCHUP", "WL", "MIN", "OFF_RATING",
        "DEF_RATING", "NET_RATING", "AST_PCT", "AST_TO", "AST_RATIO",
        "OREB_PCT", "DREB_PCT", "REB_PCT", "TM_TOV_PCT", "EFG_PCT",
        "TS_PCT", "USG_PCT", "PACE", "PIE", "POSS",
    }
    assert required.issubset(PLAYERS_ADVANCED_GAME_LOGS_HEADERS)

    url = players_advanced_url(Season="2024-25", SeasonType="Playoffs", PlayerPosition="F")
    parsed = urlparse(url)
    query = parse_qs(parsed.query, keep_blank_values=True)
    assert parsed.netloc == "stats.nba.com"
    assert parsed.path == "/stats/leaguedashplayerstats"
    assert query["Season"] == ["2024-25"]
    assert query["SeasonType"] == ["Playoffs"]
    assert query["MeasureType"] == ["Advanced"]
    assert query["PlayerPosition"] == ["F"]
    assert set(query) == set(PLAYERS_ADVANCED_PARAMETER_DEFAULTS)

    game_url = players_advanced_game_logs_url(Season="2024-25", SeasonType="Playoffs")
    game_parsed = urlparse(game_url)
    game_query = parse_qs(game_parsed.query, keep_blank_values=True)
    assert game_parsed.netloc == "stats.nba.com"
    assert game_parsed.path == "/stats/playergamelogs"
    assert game_query["Season"] == ["2024-25"]
    assert game_query["SeasonType"] == ["Playoffs"]
    assert game_query["MeasureType"] == ["Advanced"]
    assert game_query["PerMode"] == ["Totals"]
    assert set(game_query) == set(PLAYERS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS)

    headers = safe_headers(user_agent="Browser")
    lowered = {name.lower() for name in headers}
    assert not (lowered & SENSITIVE_HEADER_NAMES)
    assert headers["Origin"] == "https://www.nba.com"
    assert headers["Referer"] == "https://www.nba.com/"


def check_har_privacy_and_inventory() -> None:
    har = {
        "log": {
            "entries": [
                {
                    "_resourceType": "xhr",
                    "request": {
                        "method": "GET",
                        "url": "https://stats.nba.com/stats/leaguedashplayerstats?Season=2025-26&MeasureType=Advanced&token=DO_NOT_KEEP",
                        "headers": [
                            {"name": "Referer", "value": "https://www.nba.com/stats/players/advanced?Season=2025-26"},
                            {"name": "Cookie", "value": "private=1"},
                            {"name": "Authorization", "value": "Bearer private"},
                            {"name": "User-Agent", "value": "Browser"},
                        ],
                    },
                    "response": {"status": 200, "content": {"mimeType": "application/json"}},
                }
            ]
        }
    }
    inventory = inventory_har(har)
    assert inventory["endpoint_count"] == 1
    endpoint = inventory["endpoints"][0]
    assert endpoint["surface_keys"] == ["players_advanced"]
    assert endpoint["query_parameters"]["Season"] == ["2025-26"]
    assert endpoint["query_parameters"]["MeasureType"] == ["Advanced"]
    assert "token" not in endpoint["query_parameters"]
    assert inventory["privacy"]["cookies_persisted"] is False
    serialized = json.dumps(inventory)
    assert "private=1" not in serialized
    assert "Bearer private" not in serialized
    assert "DO_NOT_KEEP" not in serialized


def check_response_normalization() -> None:
    aggregate_response = {
        "resource": "leaguedashplayerstats",
        "parameters": {
            "MeasureType": "Advanced",
            "PerMode": "PerGame",
            "Season": "2025-26",
            "SeasonType": "Regular Season",
        },
        "resultSets": [
            {
                "name": "LeagueDashPlayerStats",
                "headers": ["PLAYER_ID", "PLAYER_NAME", "OFF_RATING", "DEF_RATING", "NET_RATING", "AST_PCT", "TS_PCT", "USG_PCT", "PACE", "PIE"],
                "rowSet": [[1, "Example Player", 118.2, 112.8, 5.4, 0.22, 0.61, 0.28, 99.4, 0.16]],
            }
        ],
    }
    tables = normalize_nba_stats_response(aggregate_response)
    assert len(tables) == 1
    assert tables[0]["name"] == PLAYERS_ADVANCED_RESULT_SET
    assert tables[0]["row_count"] == 1
    assert tables[0]["rows"][0]["PLAYER_NAME"] == "Example Player"
    assert tables[0]["rows"][0]["OFF_RATING"] == 118.2
    assert tables[0]["rows"][0]["TS_PCT"] == 0.61
    assert tables[0]["rows"][0]["PIE"] == 0.16

    game_headers = list(PLAYERS_ADVANCED_GAME_LOGS_HEADERS)
    game_row = [None] * len(game_headers)
    example_values = {
        "SEASON_YEAR": "2025-26",
        "PLAYER_ID": 1,
        "PLAYER_NAME": "Example Player",
        "TEAM_ID": 1610612738,
        "TEAM_ABBREVIATION": "BOS",
        "GAME_ID": "0022500001",
        "GAME_DATE": "2025-10-22",
        "MATCHUP": "BOS vs. NYK",
        "WL": "W",
        "MIN": 36.0,
        "OFF_RATING": 121.4,
        "DEF_RATING": 110.0,
        "NET_RATING": 11.4,
        "TS_PCT": 0.622,
        "USG_PCT": 0.287,
        "PIE": 0.18,
        "POSS": 75,
    }
    for key, value in example_values.items():
        game_row[game_headers.index(key)] = value
    game_response = {
        "resource": PLAYERS_ADVANCED_GAME_LOGS_RESOURCE,
        "parameters": {"MeasureType": "Advanced", "PerMode": "Totals", "SeasonYear": "2025-26"},
        "resultSets": [{"name": PLAYERS_ADVANCED_GAME_LOGS_RESULT_SET, "headers": game_headers, "rowSet": [game_row]}],
    }
    game_tables = normalize_nba_stats_response(game_response)
    assert game_tables[0]["name"] == PLAYERS_ADVANCED_GAME_LOGS_RESULT_SET
    assert game_tables[0]["row_count"] == 1
    assert game_tables[0]["rows"][0]["GAME_ID"] == "0022500001"
    assert game_tables[0]["rows"][0]["NET_RATING"] == 11.4
    assert game_tables[0]["rows"][0]["POSS"] == 75


def check_importer_has_no_network_dependency() -> None:
    source = (ROOT / "tools/import_nba_com_authorized_response.py").read_text(encoding="utf-8")
    forbidden = ("requests.get(", "urllib.request", "httpx.", "stats.nba.com/stats/")
    for token in forbidden:
        assert token not in source, f"Authorized importer must not perform network collection: {token}"


def main() -> int:
    check_registry()
    check_confirmed_request_contracts()
    check_har_privacy_and_inventory()
    check_response_normalization()
    check_importer_has_no_network_dependency()
    print("NBA.com Stats endpoint discovery/import contract: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
