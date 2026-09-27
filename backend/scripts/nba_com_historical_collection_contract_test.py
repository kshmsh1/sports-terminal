from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FETCH = ROOT / "tools/fetch_nba_com_historical_stats.py"
MATERIALIZE = ROOT / "tools/materialize_nba_com_static_data.py"
ENRICH = ROOT / "tools/nba_com_capture_enrichment.py"
AUDIT = ROOT / "tools/audit_nba_com_historical_capture.py"
PLAN = ROOT / "assets/data/nba/metadata/nba_com_capture_plan_part1.json"


def load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


fetcher = load("sports_terminal_nba_com_fetcher", FETCH)
materializer = load("sports_terminal_nba_com_materializer", MATERIALIZE)
enricher = load("sports_terminal_nba_com_enricher", ENRICH)
auditor = load("sports_terminal_nba_com_auditor", AUDIT)


def result_payload(name: str, headers, rows, *, resource: str = "fixture"):
    return {"resource": resource, "parameters": {}, "resultSets": [{"name": name, "headers": headers, "rowSet": rows}]}


def main() -> None:
    plan_payload, surfaces = fetcher.load_plan(PLAN)
    summary = fetcher.plan_summary(plan_payload, surfaces)
    assert summary["first_season"] == "1946-47", summary
    assert summary["last_season"] == "2025-26", summary
    assert summary["seasons"] == 80, summary
    assert summary["surfaces"] == 9, summary
    assert summary["variants"] == 84, summary
    assert summary["planned_scopes"] == 13440, summary

    by_key = {surface.key: surface for surface in surfaces}
    assert set(by_key) == {
        "players_boxscores_traditional", "players_shot_locations", "players_clutch",
        "players_synergy", "players_tracking", "players_defense_dashboard",
        "players_shot_dashboard", "players_game_logs", "players_hustle",
    }
    assert len(by_key["players_tracking"].variants) == 12
    assert len(by_key["players_synergy"].variants) == 22
    assert len(by_key["players_shot_dashboard"].variants) == 26
    assert {item.key for item in by_key["players_tracking"].variants}.issuperset({"passing", "rebounding", "speeddistance"})

    league = by_key["players_boxscores_traditional"]
    url = fetcher.request_url(league, league.variants[0], "1946-47", "Playoffs")
    assert "Season=1946-47" in url and "SeasonType=Playoffs" in url and "PlayerOrTeam=P" in url, url
    synergy = by_key["players_synergy"]
    transition_def = next(item for item in synergy.variants if item.key == "transition_defensive")
    url = fetcher.request_url(synergy, transition_def, "2025-26", "Regular Season")
    assert "SeasonYear=2025-26" in url and "PlayType=Transition" in url and "TypeGrouping=defensive" in url, url

    grouped_headers = [
        {"name": "SHOT_CATEGORY", "columnsToSkip": 2, "columnSpan": 3, "columnNames": ["Restricted Area", "Mid-Range"]},
        {"name": "columns", "columnNames": ["PLAYER_ID", "PLAYER_NAME", "FGM", "FGA", "FG_PCT", "FGM", "FGA", "FG_PCT"]},
    ]
    table = fetcher.normalize_result_set({"name": "ShotLocations", "headers": grouped_headers, "rowSet": [[1, "Fixture", 2, 4, .5, 1, 3, .333]]})
    assert table["headers"] == [
        "PLAYER_ID", "PLAYER_NAME", "Restricted Area__FGM", "Restricted Area__FGA", "Restricted Area__FG_PCT",
        "Mid-Range__FGM", "Mid-Range__FGA", "Mid-Range__FG_PCT",
    ], table["headers"]
    assert table["rows"][0]["Restricted Area__FGA"] == 4

    payload = result_payload("LeagueGameLog", ["PLAYER_ID", "GAME_ID"], [[1, "g1"]], resource="leaguegamelog")
    validation = fetcher.validate_capture(league, "Regular Season", payload, fetcher.normalize_payload(payload))
    assert validation["status"] == "success", validation
    empty = result_payload("LeagueGameLog", ["PLAYER_ID", "GAME_ID"], [], resource="leaguegamelog")
    validation = fetcher.validate_capture(league, "Regular Season", empty, fetcher.normalize_payload(empty))
    assert validation["status"] == "empty", validation

    with tempfile.TemporaryDirectory(prefix="sports-terminal-nba-com-part1-") as temp:
        root = Path(temp)
        raw = root / "raw"
        static = root / "static"
        static.mkdir()
        (static / "manifest.json").write_text(json.dumps({"runtime": {}}), encoding="utf-8")
        season_dir = static / "seasons/2025-26"
        season_dir.mkdir(parents=True)
        base_snapshot = {
            "players": [{"player_id": "canonical-1", "nba_id": "1", "player_name": "Fixture Star"}],
            "player_season_totals": [{
                "player_id": "canonical-1", "player_name": "Fixture Star", "games": 10,
                "field_goal_attempts": 100, "three_point_attempts": 40,
            }],
        }
        (season_dir / "regular.json").write_text(json.dumps(base_snapshot), encoding="utf-8")
        (season_dir / "playoffs.json").write_text(json.dumps({"players": [], "player_season_totals": []}), encoding="utf-8")

        raw_bytes = json.dumps(payload, separators=(",", ":")).encode()
        metadata = fetcher.write_capture(
            output=raw, surface=league, variant=league.variants[0], season="2025-26",
            season_type="Regular Season", url="https://stats.nba.com/fixture", raw=raw_bytes, payload=payload,
        )
        assert metadata["validation_status"] == "success"

        tracking = by_key["players_tracking"]
        passing = next(item for item in tracking.variants if item.key == "passing")
        passing_payload = result_payload(
            "LeagueDashPtStats",
            ["PLAYER_ID", "PLAYER_NAME", "GP", "PASSES_MADE", "FT_AST", "SECONDARY_AST", "POTENTIAL_AST", "AST_TO_PASS_PCT_ADJ"],
            [[1, "Fixture Star", 10, 500, 6, 12, 70, 0.04]],
            resource="leaguedashptstats",
        )
        fetcher.write_capture(
            output=raw, surface=tracking, variant=passing, season="2025-26",
            season_type="Regular Season", url="https://stats.nba.com/passing", raw=json.dumps(passing_payload).encode(), payload=passing_payload,
        )

        isolation = next(item for item in synergy.variants if item.key == "isolation_offensive")
        iso_payload = result_payload(
            "SynergyPlayType", ["PLAYER_ID", "PLAYER_NAME", "GP", "PPP"], [[1, "Fixture Star", 10, 1.11]], resource="synergyplaytype"
        )
        fetcher.write_capture(
            output=raw, surface=synergy, variant=isolation, season="2025-26",
            season_type="Regular Season", url="https://stats.nba.com/isolation", raw=json.dumps(iso_payload).encode(), payload=iso_payload,
        )

        manifest = materializer.materialize(raw, static)
        assert manifest["success_scopes"] == 3, manifest
        surface_file = static / "nba_com/surfaces/players_boxscores_traditional/default/2025-26/regular.json"
        assert surface_file.is_file(), surface_file
        game_index = static / "nba_com/player_game_logs/2025-26/regular/index.json"
        assert game_index.is_file(), game_index
        assert json.loads(game_index.read_text())[0]["game_count"] == 1

        enriched = enricher.enrich_corpus(static, roots=[raw], force=True)
        assert enriched["matched_source_rows"] == 2, enriched
        row = json.loads((season_dir / "regular.json").read_text())["player_season_totals"][0]
        assert abs(row["passes_pg"] - 50.0) < 1e-9, row
        assert abs(row["secondary_apg"] - 1.2) < 1e-9, row
        assert abs(row["potential_apg"] - 7.0) < 1e-9, row
        assert abs(row["adjusted_assist_ratio"] - 0.04) < 1e-9, row
        assert abs(row["isolation_ppp"] - 1.11) < 1e-9, row

        # Missing canonical shooting fields are repaired from NBA.com's
        # source-backed overall shot-dashboard totals without overwriting an
        # existing canonical value.
        shooting_fixture = {
            "FG3M": 33, "FG3A": 91, "FG3_PCT": 33 / 91,
            "FG2M": 67, "FG2A": 109, "FG2_PCT": 67 / 109,
        }
        row["three_pointers_made"] = 32
        enricher.apply_metrics(row, "players_shot_dashboard", "general_overall", shooting_fixture)
        assert row["three_pointers_made"] == 32, row
        assert row["three_point_attempts"] == 91, row
        assert row["three_pa"] == 91, row
        assert abs(row["three_point_percentage"] - (33 / 91)) < 1e-9, row
        assert row["two_point_attempts"] == 109, row
        assert row["two_pa"] == 109, row

        assert "players_tracking/passing" in row["nba_com_part1_sources"]
        assert row["nba_com_part1"]["players_synergy"]["isolation_offensive"]["PPP"] == 1.11

        # Audit completeness accepts older, unqueried scopes only when the same
        # evidence-based historical cutoff inference proves they precede support.
        clutch = by_key["players_clutch"]
        clutch_base = next(item for item in clutch.variants if item.key == "base")
        for season, status in [("1997-98", "success"), ("1996-97", "empty"), ("1995-96", "empty")]:
            for season_type in ("Regular Season", "Playoffs"):
                folder = fetcher.capture_dir(raw, clutch, clutch_base, season, season_type)
                folder.mkdir(parents=True, exist_ok=True)
                (folder / "metadata.json").write_text(json.dumps({
                    "surface": clutch.key,
                    "variant": clutch_base.key,
                    "season": season,
                    "season_type": season_type,
                    "validation_status": status,
                    "row_count": 1 if status == "success" else 0,
                }), encoding="utf-8")
        inferred = fetcher.infer_earliest_supported_by_variant(
            scopes=auditor.actual_scopes(raw),
            surfaces=[clutch],
            min_empty_seasons=2,
        )
        assert inferred[(clutch.key, clutch_base.key)] == 1997, inferred

    print(summary)
    print("NBA.com Part 1 historical capture/static materialization contract passed.")


if __name__ == "__main__":
    main()
