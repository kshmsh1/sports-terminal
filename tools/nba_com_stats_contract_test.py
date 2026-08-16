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
    TEAMS_ADVANCED_GAME_LOGS_ENDPOINT,
    TEAMS_ADVANCED_GAME_LOGS_HEADERS,
    TEAMS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS,
    TEAMS_ADVANCED_GAME_LOGS_RESOURCE,
    TEAMS_ADVANCED_GAME_LOGS_RESULT_SET,
    SENSITIVE_HEADER_NAMES,
    players_advanced_game_logs_url,
    players_advanced_url,
    teams_advanced_game_logs_url,
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
    assert SURFACES["teams_advanced_box_scores"].grain == "team-game"
    assert SURFACES["teams_advanced_box_scores"].endpoint_hint == "teamgamelogs"
    assert SURFACES["teams_advanced_box_scores"].discovery_status == "confirmed_browser_capture_schema_confirmed"
    assert SURFACES["lineups_advanced"].minimum_season == "2008-09"
    assert SURFACES["players_advanced"].discovery_status == "confirmed_browser_capture"
    assert surface_for_referer("https://www.nba.com/stats/players/advanced?Season=2025-26").key == "players_advanced"
    payload = registry_payload()
    assert payload["contract"] == "sports-terminal-nba-com-stats-surface-registry-v1"


def check_confirmed_request_contracts() -> None:
    contract = request_contracts()
    assert contract["contract"] == "sports-terminal-nba-com-confirmed-requests-v4"
    assert contract["confirmed_from"] == "normal_browser_capture"
    assert contract["sensitive_headers_persisted"] is False

    aggregate = contract["requests"]["players_advanced"]
    assert aggregate["path"] == PLAYERS_ADVANCED_ENDPOINT
    assert aggregate["result_set"] == PLAYERS_ADVANCED_RESULT_SET

    player_logs = contract["requests"]["players_advanced_box_scores"]
    assert player_logs["path"] == PLAYERS_ADVANCED_GAME_LOGS_ENDPOINT
    assert player_logs["resource"] == PLAYERS_ADVANCED_GAME_LOGS_RESOURCE == "gamelogs"
    assert player_logs["result_set"] == PLAYERS_ADVANCED_GAME_LOGS_RESULT_SET == "PlayerGameLogs"
    assert player_logs["grain"] == "player-game"
    assert player_logs["parameters"]["MeasureType"] == "Advanced"
    assert player_logs["parameters"]["PerMode"] == "Totals"
    assert tuple(player_logs["headers"]) == PLAYERS_ADVANCED_GAME_LOGS_HEADERS

    team_logs = contract["requests"]["teams_advanced_box_scores"]
    assert team_logs["path"] == TEAMS_ADVANCED_GAME_LOGS_ENDPOINT
    assert team_logs["resource"] == TEAMS_ADVANCED_GAME_LOGS_RESOURCE == "gamelogs"
    assert team_logs["result_set"] == TEAMS_ADVANCED_GAME_LOGS_RESULT_SET == "TeamGameLogs"
    assert team_logs["grain"] == "team-game"
    assert team_logs["parameters"]["MeasureType"] == "Advanced"
    assert team_logs["parameters"]["PerMode"] == "Totals"
    assert tuple(team_logs["headers"]) == TEAMS_ADVANCED_GAME_LOGS_HEADERS
    required_team = {
        "SEASON_YEAR", "TEAM_ID", "TEAM_ABBREVIATION", "TEAM_NAME", "GAME_ID",
        "GAME_DATE", "MATCHUP", "WL", "MIN", "OFF_RATING", "DEF_RATING",
        "NET_RATING", "AST_PCT", "AST_TO", "AST_RATIO", "OREB_PCT", "DREB_PCT",
        "REB_PCT", "TM_TOV_PCT", "EFG_PCT", "TS_PCT", "PACE", "POSS", "PIE",
    }
    assert required_team.issubset(TEAMS_ADVANCED_GAME_LOGS_HEADERS)

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

    player_url = players_advanced_game_logs_url(Season="2024-25", SeasonType="Playoffs")
    player_parsed = urlparse(player_url)
    player_query = parse_qs(player_parsed.query, keep_blank_values=True)
    assert player_parsed.path == "/stats/playergamelogs"
    assert player_query["MeasureType"] == ["Advanced"]
    assert player_query["PerMode"] == ["Totals"]
    assert set(player_query) == set(PLAYERS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS)

    team_url = teams_advanced_game_logs_url(Season="2024-25", SeasonType="Playoffs")
    team_parsed = urlparse(team_url)
    team_query = parse_qs(team_parsed.query, keep_blank_values=True)
    assert team_parsed.path == "/stats/teamgamelogs"
    assert team_query["Season"] == ["2024-25"]
    assert team_query["SeasonType"] == ["Playoffs"]
    assert team_query["MeasureType"] == ["Advanced"]
    assert team_query["PerMode"] == ["Totals"]
    assert set(team_query) == set(TEAMS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS)

    headers = safe_headers(user_agent="Browser")
    lowered = {name.lower() for name in headers}
    assert not (lowered & SENSITIVE_HEADER_NAMES)


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
    assert "token" not in endpoint["query_parameters"]
    serialized = json.dumps(inventory)
    assert "private=1" not in serialized
    assert "Bearer private" not in serialized
    assert "DO_NOT_KEEP" not in serialized


def check_response_normalization() -> None:
    aggregate_response = {
        "resource": "leaguedashplayerstats",
        "parameters": {"MeasureType": "Advanced", "PerMode": "PerGame", "Season": "2025-26", "SeasonType": "Regular Season"},
        "resultSets": [{"name": "LeagueDashPlayerStats", "headers": ["PLAYER_ID", "PLAYER_NAME", "OFF_RATING"], "rowSet": [[1, "Example Player", 118.2]]}],
    }
    tables = normalize_nba_stats_response(aggregate_response)
    assert tables[0]["name"] == PLAYERS_ADVANCED_RESULT_SET
    assert tables[0]["rows"][0]["PLAYER_NAME"] == "Example Player"

    player_headers = list(PLAYERS_ADVANCED_GAME_LOGS_HEADERS)
    player_row = [None] * len(player_headers)
    for key, value in {"PLAYER_NAME": "Example Player", "GAME_ID": "0022500001", "NET_RATING": 11.4, "POSS": 75}.items():
        player_row[player_headers.index(key)] = value
    player_response = {"resource": "gamelogs", "resultSets": [{"name": "PlayerGameLogs", "headers": player_headers, "rowSet": [player_row]}]}
    player_tables = normalize_nba_stats_response(player_response)
    assert player_tables[0]["rows"][0]["NET_RATING"] == 11.4

    team_headers = list(TEAMS_ADVANCED_GAME_LOGS_HEADERS)
    team_row = [None] * len(team_headers)
    for key, value in {"TEAM_ABBREVIATION": "BOS", "GAME_ID": "0022500001", "OFF_RATING": 121.4, "DEF_RATING": 110.0, "NET_RATING": 11.4, "POSS": 98}.items():
        team_row[team_headers.index(key)] = value
    team_response = {"resource": "gamelogs", "resultSets": [{"name": "TeamGameLogs", "headers": team_headers, "rowSet": [team_row]}]}
    team_tables = normalize_nba_stats_response(team_response)
    assert team_tables[0]["name"] == "TeamGameLogs"
    assert team_tables[0]["rows"][0]["TEAM_ABBREVIATION"] == "BOS"
    assert team_tables[0]["rows"][0]["NET_RATING"] == 11.4


def check_importer_has_no_network_dependency() -> None:
    source = (ROOT / "tools/import_nba_com_authorized_response.py").read_text(encoding="utf-8")
    forbidden = ("requests.get(", "urllib.request", "httpx.", "stats.nba.com/stats/")
    for token in forbidden:
        assert token not in source


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
