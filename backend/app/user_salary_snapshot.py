from __future__ import annotations

import csv
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

BACKEND_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = BACKEND_ROOT / "data"
PLAYER_GLOB = "nba_2026_27_user_player_salary_snapshot_part*.csv"
TEAM_FILE = DATA_DIR / "nba_2026_27_user_team_salary_snapshot.csv"
SEASON = "2026-27"
AS_OF_DATE = "2026-09-09"
SOURCE_LABEL = "User-supplied 2026-27 NBA salary snapshot"
SOURCE_DOCUMENT_ID = "chat-user-supplied-nba-salary-snapshot-2026-09-09"

SALARY_CAP = 164_961_000
LUXURY_TAX = 200_428_000
FIRST_APRON = 209_015_000
SECOND_APRON = 221_686_000
SEASONS = ("2026-27", "2027-28", "2028-29", "2029-30", "2030-31", "2031-32")
TEAM_ALIASES = {
    "BRK": "BKN",
    "CHO": "CHA",
    "PHO": "PHX",
}
ACTIVE_TEAM_OVERRIDES = {
    "Damian Lillard": {
        "team": "POR",
        "source_url": "https://www.nba.com/stats/player/203081/passes-dash",
    },
    "Bradley Beal": {
        "team": "LAC",
        "source_url": "https://www.nba.com/news/bradley-beal-clippers-free-agency",
    },
    "Klay Thompson": {
        "team": "MIA",
        "source_url": "https://www.nba.com/news/klay-thompson-heat-2026-free-agency",
    },
    "Jonathan Kuminga": {
        "team": "MIN",
        "source_url": "https://www.nba.com/timberwolves/news/timberwolves-sign-jonathan-kuminga",
    },
    "Kentavious Caldwell-Pope": {
        "team": "PHI",
        "source_url": "https://www.nba.com/player/203484/kentavious-caldwell-pope",
    },
    "Olivier-Maxence Prosper": {
        "team": "MEM",
        "source_url": "https://www.nba.com/team/1610612763",
    },
}


def _money(value: str | None) -> int:
    raw = (value or "").strip().replace("$", "").replace(",", "")
    if not raw:
        return 0
    return int(raw)


def _canonical_team(value: str | None) -> str:
    raw = (value or "").strip().upper()
    return TEAM_ALIASES.get(raw, raw)


def _slug(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]+", "-", ascii_value.lower()).strip("-")


def load_player_rows() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    files = sorted(DATA_DIR.glob(PLAYER_GLOB))
    if not files:
        return rows
    for path in files:
        with path.open(newline="", encoding="utf-8") as handle:
            for raw in csv.DictReader(handle):
                row = dict(raw)
                row["source_team"] = row.get("team", "")
                row["team"] = _canonical_team(row.get("team"))
                row["rank"] = int(row["rank"])
                for season in SEASONS:
                    row[season] = _money(row.get(season))
                row["guaranteed"] = _money(row.get("guaranteed"))
                rows.append(row)
    return sorted(rows, key=lambda row: int(row["rank"]))


def load_team_rows() -> list[dict[str, Any]]:
    if not TEAM_FILE.exists():
        return []
    rows: list[dict[str, Any]] = []
    with TEAM_FILE.open(newline="", encoding="utf-8") as handle:
        for raw in csv.DictReader(handle):
            row = dict(raw)
            row["source_team_id"] = row.get("team_id", "")
            row["team_id"] = _canonical_team(row.get("team_id"))
            for season in SEASONS:
                row[season] = _money(row.get(season))
            rows.append(row)
    return rows


def snapshot_diagnostics() -> dict[str, Any]:
    players = load_player_rows()
    teams = load_team_rows()
    name_teams: dict[str, set[str]] = defaultdict(set)
    exact_keys: Counter[tuple[Any, ...]] = Counter()
    team_player_sum: Counter[str] = Counter()
    for row in players:
        name_teams[str(row["player"])].add(str(row["team"]))
        key = (
            row["player"],
            row["team"],
            *(row[season] for season in SEASONS),
            row["guaranteed"],
        )
        exact_keys[key] += 1
        team_player_sum[str(row["team"])] += int(row[SEASON])
    multi_team = sorted(name for name, values in name_teams.items() if len(values) > 1)
    exact_duplicate_rows = sum(count - 1 for count in exact_keys.values() if count > 1)
    team_variance = {
        str(row["team_id"]): int(row[SEASON]) - team_player_sum[str(row["team_id"])]
        for row in teams
    }
    return {
        "player_rows": len(players),
        "team_rows": len(teams),
        "multi_team_player_names": multi_team,
        "exact_duplicate_rows": exact_duplicate_rows,
        "team_player_sum": dict(team_player_sum),
        "team_aggregate_variance": team_variance,
        "team_aliases": dict(TEAM_ALIASES),
        "active_team_overrides": {
            name: value["team"] for name, value in ACTIVE_TEAM_OVERRIDES.items()
        },
    }


def _unique_player_rows() -> tuple[list[dict[str, Any]], set[str]]:
    rows = load_player_rows()
    teams_by_name: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        teams_by_name[str(row["player"])].add(str(row["team"]))
    ambiguous_names = {name for name, teams in teams_by_name.items() if len(teams) > 1}

    seen_exact: set[tuple[Any, ...]] = set()
    unique: list[dict[str, Any]] = []
    for row in rows:
        key = (
            row["player"],
            row["team"],
            *(row[season] for season in SEASONS),
            row["guaranteed"],
        )
        if key in seen_exact:
            continue
        seen_exact.add(key)
        unique.append(row)
    return unique, ambiguous_names


def contract_seed_records() -> list[dict[str, Any]]:
    rows, ambiguous_names = _unique_player_rows()
    out: list[dict[str, Any]] = []
    for row in rows:
        player_name = str(row["player"])
        team = str(row["team"])
        player_slug = _slug(player_name)
        ambiguous = player_name in ambiguous_names
        active_override = ACTIVE_TEAM_OVERRIDES.get(player_name)
        active_team = str(active_override["team"]) if active_override else ""
        active_reconciled = bool(active_team)
        is_active_contract = not ambiguous or team == active_team
        retained_obligation = ambiguous and active_reconciled and team != active_team
        unresolved_ambiguous = ambiguous and not active_reconciled
        tradeable = is_active_contract and not unresolved_ambiguous
        years = [
            {
                "season": season,
                "salary": int(row[season]),
                "guaranteed_amount": 0,
                "likely_incentives": 0,
                "unlikely_incentives": 0,
                "dead_money": 0,
                "option_type": "none",
                "option_deadline": "",
                "guarantee_date": "",
                "cap_charge_override": None,
            }
            for season in SEASONS
            if int(row[season]) > 0
        ]
        record_id = f"user-salary-2026-27:{team}:{player_slug}:{row['rank']}"
        if retained_obligation:
            contract_type = "retained_payroll_obligation"
            notes = (
                "The supplied salary table contains this player on multiple teams. NBA.com identifies a different current team, so this row is retained as a non-transferable payroll obligation rather than an active contract."
            )
            restriction_reason = f"retained payroll obligation; current NBA team is {active_team}"
        elif unresolved_ambiguous:
            contract_type = "payroll_obligation"
            notes = (
                "Multi-team payroll obligation in the supplied table; active contract team is unresolved and the row must not be treated as tradeable."
            )
            restriction_reason = "multi-team payroll obligation requires active-team reconciliation"
        else:
            contract_type = "standard"
            notes = (
                "Salary schedule transcribed from the user-supplied 2026-27 salary table. Contract clauses not shown in the table remain unknown."
            )
            restriction_reason = ""
        record = {
            "id": record_id,
            "player_id": player_slug,
            "player_name": player_name,
            "team_id": team,
            "season": SEASON,
            "contract_type": contract_type,
            "years": years,
            "no_trade_clause": False,
            "trade_bonus_percent": 0,
            "bird_rights": "unknown",
            "two_way": False,
            "source_status": "uploaded",
            "source_label": SOURCE_LABEL,
            "source_url": str(active_override["source_url"]) if active_override else "",
            "source_document_id": SOURCE_DOCUMENT_ID,
            "as_of_date": AS_OF_DATE,
            "notes": notes,
            "metadata": {
                "rank": int(row["rank"]),
                "remaining_guaranteed_total": int(row["guaranteed"]),
                "snapshot_kind": "user_supplied_salary_table",
                "source_team_abbreviation": row.get("source_team", team),
                "canonical_team_abbreviation": team,
                "multi_team_obligation": ambiguous,
                "active_team_reconciled": active_reconciled,
                "official_current_team": active_team or None,
                "retained_payroll_obligation": retained_obligation,
                "tradeable": tradeable,
                "trade_restricted": not tradeable,
                "restriction_reason": restriction_reason,
                "guarantee_total_is_not_year_allocation": True,
            },
        }
        out.append(_wrapper("contract", record_id, team, player_slug, record))
    return out


def team_position_seed_records() -> list[dict[str, Any]]:
    diagnostics = snapshot_diagnostics()
    row_sum = diagnostics["team_player_sum"]
    out: list[dict[str, Any]] = []
    for row in load_team_rows():
        team = str(row["team_id"])
        reported = int(row[SEASON])
        summed = int(row_sum.get(team, 0))
        record_id = f"user-team-salary-2026-27:{team}"
        record = {
            "id": record_id,
            "team_id": team,
            "season": SEASON,
            "salary_cap": SALARY_CAP,
            "luxury_tax": LUXURY_TAX,
            "first_apron": FIRST_APRON,
            "second_apron": SECOND_APRON,
            "active_salary": reported,
            "cap_holds": 0,
            "dead_money": 0,
            "incomplete_roster_charges": 0,
            "hard_cap": 0,
            "cash_sent": 0,
            "cash_received": 0,
            "exceptions": [],
            "source_status": "uploaded",
            "source_label": SOURCE_LABEL,
            "source_url": "",
            "source_document_id": SOURCE_DOCUMENT_ID,
            "as_of_date": AS_OF_DATE,
            "notes": "Aggregate payroll salary from the user-supplied table. This is an uploaded payroll control total, not an official CBA Team Salary or Apron Team Salary statement.",
            "metadata": {
                "team_name": row["team"],
                "source_team_abbreviation": row.get("source_team_id", team),
                "canonical_team_abbreviation": team,
                "reported_payroll_total": reported,
                "player_row_sum": summed,
                "player_row_sum_variance": reported - summed,
                "payroll_total_not_cba_team_salary": True,
                "future_payroll": {season: int(row[season]) for season in SEASONS},
            },
        }
        out.append(_wrapper("team_position", record_id, team, "", record))
    return out


def _wrapper(record_type: str, record_id: str, team: str, player_id: str, record: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": record_id,
        "record_type": record_type,
        "season": SEASON,
        "team_id": team,
        "player_id": player_id,
        "organization_id": "",
        "source_status": "uploaded",
        "record_status": "active",
        "record": record,
        "validation": {
            "status": "warning",
            "errors": [],
            "warnings": [
                "User-supplied snapshot: salary/payroll values are usable as uploaded evidence but contract clauses and CBA Team Salary components require separate verification."
            ],
            "computed": {},
        },
        "version": 1,
        "created_by_user_id": "user-supplied-snapshot",
        "created_at": f"{AS_OF_DATE}T00:00:00Z",
        "updated_at": f"{AS_OF_DATE}T00:00:00Z",
    }


def merge_seed_records(
    live_rows: list[dict[str, Any]],
    seed_rows: list[dict[str, Any]],
    *,
    team_id: str = "",
    player_id: str = "",
    source_status: str = "",
    record_status: str = "active",
    limit: int = 1000,
) -> list[dict[str, Any]]:
    if record_status and record_status != "active":
        return live_rows
    canonical_team_id = _canonical_team(team_id)
    filtered = [
        row
        for row in seed_rows
        if (not canonical_team_id or row["team_id"] == canonical_team_id)
        and (not player_id or row["player_id"] == player_id)
        and (not source_status or row["source_status"] == source_status)
    ]
    occupied = {(row.get("team_id", ""), row.get("player_id", "")) for row in live_rows}
    merged = list(live_rows)
    for row in filtered:
        identity = (row.get("team_id", ""), row.get("player_id", ""))
        if identity not in occupied:
            merged.append(row)
    return merged[: max(1, min(limit, 1000))]
