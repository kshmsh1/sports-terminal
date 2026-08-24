from __future__ import annotations

import json
import tempfile
from pathlib import Path

from tools.nba_com_static_enrichment import enrich_seed_payload, enrichment_fingerprint


def _write_capture(root: Path, surface: str, rows: list[dict], *, season: str = "2025-26", season_type: str = "regular-season") -> None:
    destination = root / surface / season / season_type
    destination.mkdir(parents=True, exist_ok=True)
    headers = sorted({key for row in rows for key in row})
    payload = {
        "contract": "sports-terminal-nba-com-authorized-import-v1",
        "season": season,
        "season_type": "Regular Season" if season_type == "regular-season" else "Playoffs",
        "tables": [{"name": surface, "headers": headers, "row_count": len(rows), "rows": rows}],
    }
    (destination / "normalized.json").write_text(json.dumps(payload), encoding="utf-8")
    (destination / "metadata.json").write_text(json.dumps({
        "source_sha256": f"fixture-{surface}",
        "rights": {"commercial_use_verified": False, "redistribution_verified": False, "license_review_required": True},
    }), encoding="utf-8")


def _snapshot() -> dict:
    return {
        "players": [{"player_id": "player:1", "id": "player:1", "player_name": "Test Player", "nba_id": 12345}],
        "player_season_totals": [{
            "player_id": "player:1",
            "player_name": "Test Player",
            "player_label": "Test Player",
            "team_ids": "TST",
            "season_type": "regular",
            "games": 10,
            "minutes": 300,
            "points": 200,
            "field_goals_made": 70,
            "field_goal_attempts": 150,
            "three_pointers_made": 20,
            "three_point_attempts": 60,
        }],
    }


def check_player_season_join() -> None:
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        _write_capture(root, "players_base", [{
            "PLAYER_ID": 12345, "PLAYER_NAME": "Test Player", "GP": 10, "MIN": 300,
            "PTS": 200, "REB": 50, "OREB": 10, "DREB": 40, "AST": 60, "STL": 12,
            "BLK": 5, "TOV": 22, "PF": 18, "FGM": 70, "FGA": 150, "FG_PCT": .4667,
            "FG3M": 20, "FG3A": 60, "FG3_PCT": .3333, "FTM": 40, "FTA": 50, "FT_PCT": .8,
        }])
        _write_capture(root, "players_advanced", [{
            "PLAYER_ID": 12345, "PLAYER_NAME": "Test Player", "OFF_RATING": 118.4,
            "DEF_RATING": 109.7, "NET_RATING": 8.7, "AST_PCT": .31, "AST_TO": 2.73,
            "OREB_PCT": .04, "DREB_PCT": .18, "REB_PCT": .11, "TM_TOV_PCT": .09,
            "EFG_PCT": .533, "TS_PCT": .59, "USG_PCT": .27, "PACE": 99.8, "PIE": .145,
            "POSS": 520,
        }])
        _write_capture(root, "players_hustle", [{
            "PLAYER_ID": 12345, "PLAYER_NAME": "Test Player", "G": 10,
            "CONTESTED_SHOTS": 80, "CONTESTED_SHOTS_2PT": 50, "CONTESTED_SHOTS_3PT": 30,
            "DEFLECTIONS": 34, "CHARGES_DRAWN": 3, "SCREEN_ASSISTS": 9,
            "LOOSE_BALLS_RECOVERED": 14, "BOX_OUTS": 25, "PCT_BOX_OUTS_REB": .64,
        }])
        _write_capture(root, "players_defense_dashboard", [{
            "CLOSE_DEF_PERSON_ID": 12345, "PLAYER_NAME": "Test Player", "GP": 10, "G": 10,
            "FREQ": .42, "D_FGM": 45, "D_FGA": 110, "D_FG_PCT": .409,
            "NORMAL_FG_PCT": .472, "PCT_PLUSMINUS": -.063,
        }])
        _write_capture(root, "players_violations", [{
            "PLAYER_ID": 12345, "PLAYER_NAME": "Test Player", "TRAVEL": 4,
            "DOUBLE_DRIBBLE": 2, "DISCONTINUE_DRIBBLE": 1, "KICKED_BALL": 3,
        }])

        payload = _snapshot()
        enrich_seed_payload(payload, season="2025-26", season_type="regular", raw_roots=[root])
        row = payload["player_season_totals"][0]

        assert row["net_rating"] == 8.7
        assert row["ast_pct"] == .31
        assert row["usg_pct"] == .27
        assert row["pace"] == 99.8
        assert row["pie"] == .145
        assert row["deflections_pg"] == 3.4
        assert row["charges_drawn_pg"] == .3
        assert row["contested_shots_pg"] == 8.0
        assert row["loose_balls_recovered_pg"] == 1.4
        assert row["screen_ast_pg"] == .9
        assert row["box_outs_pg"] == 2.5
        assert row["box_out_pct"] == .64
        assert row["dfgm"] == 45
        assert row["dfga"] == 110
        assert row["dfg_pct"] == .409
        assert row["travel"] == 4
        assert row["double_dribble"] == 2
        assert row["discontinued_dribble"] == 1
        assert row["kicked_ball"] == 3
        assert set(row["nba_com_sources"]) == {
            "players_base", "players_advanced", "players_defense_dashboard", "players_hustle", "players_violations"
        }
        assert row["nba_com"]["players_hustle"]["DEFLECTIONS"] == 34
        assert payload["nba_com_enrichment"]["unmatched_rows"] == 0


def check_unmatched_is_reported_not_fabricated() -> None:
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        _write_capture(root, "players_hustle", [{"PLAYER_ID": 99999, "PLAYER_NAME": "Unknown Player", "DEFLECTIONS": 99}])
        payload = _snapshot()
        enrich_seed_payload(payload, season="2025-26", season_type="regular", raw_roots=[root])
        assert "deflections_pg" not in payload["player_season_totals"][0]
        assert payload["nba_com_enrichment"]["unmatched_rows"] == 1


def check_fingerprint_changes_with_capture() -> None:
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        before = enrichment_fingerprint([root])
        _write_capture(root, "players_hustle", [{"PLAYER_ID": 12345, "PLAYER_NAME": "Test Player", "DEFLECTIONS": 10}])
        after = enrichment_fingerprint([root])
        assert before["digest"] != after["digest"]
        assert after["normalized_file_count"] == 1


def main() -> int:
    check_player_season_join()
    check_unmatched_is_reported_not_fabricated()
    check_fingerprint_changes_with_capture()
    print("NBA.com static player-season enrichment: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
