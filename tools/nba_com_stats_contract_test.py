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
    LINEUPS_ADVANCED_ENDPOINT, LINEUPS_ADVANCED_HEADERS, LINEUPS_ADVANCED_PARAMETER_DEFAULTS,
    LINEUPS_ADVANCED_RESOURCE, LINEUPS_ADVANCED_RESULT_SET,
    PLAYERS_ADVANCED_ENDPOINT, PLAYERS_ADVANCED_GAME_LOGS_ENDPOINT,
    PLAYERS_ADVANCED_GAME_LOGS_HEADERS, PLAYERS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS,
    PLAYERS_ADVANCED_GAME_LOGS_RESOURCE, PLAYERS_ADVANCED_GAME_LOGS_RESULT_SET,
    PLAYERS_ADVANCED_PARAMETER_DEFAULTS, PLAYERS_ADVANCED_RESULT_SET,
    TEAMS_ADVANCED_GAME_LOGS_ENDPOINT, TEAMS_ADVANCED_GAME_LOGS_HEADERS,
    TEAMS_ADVANCED_GAME_LOGS_PARAMETER_DEFAULTS, TEAMS_ADVANCED_GAME_LOGS_RESOURCE,
    TEAMS_ADVANCED_GAME_LOGS_RESULT_SET, SENSITIVE_HEADER_NAMES,
    lineups_advanced_url, players_advanced_game_logs_url, players_advanced_url,
    teams_advanced_game_logs_url, request_contracts, safe_headers,
)
from tools.nba_com_stats_registry import SURFACES, registry_payload, surface_for_referer  # noqa: E402


def check_registry() -> None:
    assert len(SURFACES) >= 25
    assert SURFACES["players_advanced"].minimum_season == "1996-97"
    assert SURFACES["players_advanced_box_scores"].grain == "player-game"
    assert SURFACES["teams_advanced_box_scores"].grain == "team-game"
    assert SURFACES["lineups_advanced"].minimum_season == "2008-09"
    assert SURFACES["lineups_advanced"].endpoint_hint == "leaguedashlineups"
    assert SURFACES["lineups_advanced"].discovery_status == "confirmed_browser_capture_schema_confirmed"
    assert surface_for_referer("https://www.nba.com/stats/lineups/advanced?Season=2025-26").key == "lineups_advanced"
    assert registry_payload()["contract"] == "sports-terminal-nba-com-stats-surface-registry-v1"


def check_confirmed_request_contracts() -> None:
    contract = request_contracts()
    assert contract["contract"] == "sports-terminal-nba-com-confirmed-requests-v6"
    assert contract["sensitive_headers_persisted"] is False

    aggregate = contract["requests"]["players_advanced"]
    assert aggregate["path"] == PLAYERS_ADVANCED_ENDPOINT
    assert aggregate["result_set"] == PLAYERS_ADVANCED_RESULT_SET

    player_logs = contract["requests"]["players_advanced_box_scores"]
    assert player_logs["path"] == PLAYERS_ADVANCED_GAME_LOGS_ENDPOINT
    assert player_logs["resource"] == PLAYERS_ADVANCED_GAME_LOGS_RESOURCE == "gamelogs"
    assert player_logs["result_set"] == PLAYERS_ADVANCED_GAME_LOGS_RESULT_SET == "PlayerGameLogs"
    assert tuple(player_logs["headers"]) == PLAYERS_ADVANCED_GAME_LOGS_HEADERS

    team_logs = contract["requests"]["teams_advanced_box_scores"]
    assert team_logs["path"] == TEAMS_ADVANCED_GAME_LOGS_ENDPOINT
    assert team_logs["resource"] == TEAMS_ADVANCED_GAME_LOGS_RESOURCE == "gamelogs"
    assert team_logs["result_set"] == TEAMS_ADVANCED_GAME_LOGS_RESULT_SET == "TeamGameLogs"
    assert tuple(team_logs["headers"]) == TEAMS_ADVANCED_GAME_LOGS_HEADERS

    lineups = contract["requests"]["lineups_advanced"]
    assert lineups["path"] == LINEUPS_ADVANCED_ENDPOINT == "/stats/leaguedashlineups"
    assert lineups["resource"] == LINEUPS_ADVANCED_RESOURCE == "leaguedashlineups"
    assert lineups["result_set"] == LINEUPS_ADVANCED_RESULT_SET == "Lineups"
    assert lineups["group_quantity_default"] == 5
    assert lineups["parameters"]["MeasureType"] == "Advanced"
    assert lineups["parameters"]["PerMode"] == "PerGame"
    assert lineups["parameters"]["GroupQuantity"] == "5"
    assert tuple(lineups["headers"]) == LINEUPS_ADVANCED_HEADERS
    required_lineup = {"GROUP_ID","GROUP_NAME","TEAM_ID","TEAM_ABBREVIATION","GP","MIN","OFF_RATING","DEF_RATING","NET_RATING","AST_PCT","OREB_PCT","DREB_PCT","REB_PCT","TM_TOV_PCT","EFG_PCT","TS_PCT","PACE","POSS","PIE","SUM_TIME_PLAYED"}
    assert required_lineup.issubset(LINEUPS_ADVANCED_HEADERS)

    url = lineups_advanced_url(Season="2024-25", SeasonType="Playoffs", GroupQuantity=3)
    parsed = urlparse(url)
    query = parse_qs(parsed.query, keep_blank_values=True)
    assert parsed.netloc == "stats.nba.com"
    assert parsed.path == "/stats/leaguedashlineups"
    assert query["Season"] == ["2024-25"]
    assert query["SeasonType"] == ["Playoffs"]
    assert query["MeasureType"] == ["Advanced"]
    assert query["GroupQuantity"] == ["3"]
    assert set(query) == set(LINEUPS_ADVANCED_PARAMETER_DEFAULTS)

    headers = safe_headers(user_agent="Browser")
    assert not ({name.lower() for name in headers} & SENSITIVE_HEADER_NAMES)


def check_har_privacy_and_inventory() -> None:
    har = {"log":{"entries":[{"_resourceType":"xhr","request":{"method":"GET","url":"https://stats.nba.com/stats/leaguedashplayerstats?Season=2025-26&MeasureType=Advanced&token=DO_NOT_KEEP","headers":[{"name":"Referer","value":"https://www.nba.com/stats/players/advanced?Season=2025-26"},{"name":"Cookie","value":"private=1"},{"name":"Authorization","value":"Bearer private"}]},"response":{"status":200,"content":{"mimeType":"application/json"}}}]}}
    inventory = inventory_har(har)
    serialized = json.dumps(inventory)
    assert "private=1" not in serialized and "Bearer private" not in serialized and "DO_NOT_KEEP" not in serialized


def check_response_normalization() -> None:
    lineup_headers = list(LINEUPS_ADVANCED_HEADERS)
    lineup_row = [None] * len(lineup_headers)
    for key, value in {"GROUP_NAME":"A - B - C - D - E","TEAM_ABBREVIATION":"BOS","GP":12,"MIN":140.0,"OFF_RATING":121.4,"DEF_RATING":108.2,"NET_RATING":13.2,"POSS":300,"PIE":0.61,"SUM_TIME_PLAYED":8400}.items():
        lineup_row[lineup_headers.index(key)] = value
    response = {"resource":"leaguedashlineups","resultSets":[{"name":"Lineups","headers":lineup_headers,"rowSet":[lineup_row]}]}
    tables = normalize_nba_stats_response(response)
    assert tables[0]["name"] == "Lineups"
    assert tables[0]["rows"][0]["NET_RATING"] == 13.2
    assert tables[0]["rows"][0]["SUM_TIME_PLAYED"] == 8400


def check_importer_has_no_network_dependency() -> None:
    source = (ROOT / "tools/import_nba_com_authorized_response.py").read_text(encoding="utf-8")
    for token in ("requests.get(", "urllib.request", "httpx.", "stats.nba.com/stats/"):
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
