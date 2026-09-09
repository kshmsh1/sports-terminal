from __future__ import annotations

import csv
import os
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .trade_machine import (
    DEFAULT_SEASON,
    TeamTradeLeg,
    TeamTradeState,
    TradePlayer,
    annual_cash_limit,
    evaluate_trade,
    expanded_tpe_limit,
    load_cap_levels,
    load_trade_rules,
    scaled_expanded_additive,
    trade_evaluation_to_dict,
)

router = APIRouter(prefix="/v2/nba/trade-machine", tags=["nba-trade-machine"])
BACKEND_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONTRACTS_PATH = BACKEND_ROOT.parent / "raw" / "nba" / "contracts" / "contracts_long.csv"


class TradePlayerInput(BaseModel):
    player_id: str
    player_name: str
    salary: int = Field(ge=0)
    outgoing_salary_for_matching: int | None = Field(default=None, ge=0)
    incoming_salary_for_matching: int | None = Field(default=None, ge=0)
    trade_eligible: bool = True
    restriction_reason: str | None = None
    consent_required: bool = False
    consent_given: bool = False
    trade_bonus: int = Field(default=0, ge=0)
    source_url: str | None = None


class TeamStateInput(BaseModel):
    team_id: str
    team_name: str
    apron_team_salary: int = Field(ge=0)
    team_salary: int | None = Field(default=None, ge=0)
    hard_cap: str | None = None
    cash_sent_ytd: int = Field(default=0, ge=0)
    cash_received_ytd: int = Field(default=0, ge=0)
    prior_restriction_rows: list[str] = Field(default_factory=list)
    apron_salary_is_estimate: bool = False
    source_urls: list[str] = Field(default_factory=list)


class TeamLegInput(BaseModel):
    team_id: str
    outgoing: list[TradePlayerInput] = Field(default_factory=list)
    incoming: list[TradePlayerInput] = Field(default_factory=list)
    cash_sent: int = Field(default=0, ge=0)
    cash_received: int = Field(default=0, ge=0)
    receiving_sign_and_trade_player: bool = False
    using_prior_standard_tpe_after_regular_season: bool = False


class TradeRequest(BaseModel):
    season: str = DEFAULT_SEASON
    teams: list[TeamStateInput]
    legs: list[TeamLegInput]


def _player(value: TradePlayerInput) -> TradePlayer:
    return TradePlayer(**value.model_dump())


def _state(value: TeamStateInput) -> TeamTradeState:
    if value.hard_cap not in {None, "first_apron", "second_apron"}:
        raise HTTPException(status_code=422, detail=f"Invalid hard_cap for {value.team_id}")
    return TeamTradeState(**value.model_dump())


def _leg(value: TeamLegInput) -> TeamTradeLeg:
    payload = value.model_dump(exclude={"outgoing", "incoming"})
    return TeamTradeLeg(
        **payload,
        outgoing=[_player(player) for player in value.outgoing],
        incoming=[_player(player) for player in value.incoming],
    )


@router.get("/config")
def trade_machine_config(season: str = Query(DEFAULT_SEASON)) -> dict[str, Any]:
    cap = load_cap_levels(season)
    rules = load_trade_rules()
    return {
        "season": season,
        "cap_levels": cap.__dict__,
        "expanded_tpe_scaled_additive": scaled_expanded_additive(cap, rules),
        "annual_cash_send_or_receive_limit": annual_cash_limit(cap, rules),
        "example_expanded_limits": {
            "5m_outgoing": expanded_tpe_limit(5_000_000, cap, rules),
            "10m_outgoing": expanded_tpe_limit(10_000_000, cap, rules),
            "20m_outgoing": expanded_tpe_limit(20_000_000, cap, rules),
        },
        "references": rules["references"],
        "data_note": "Salary, Team Salary and Apron Team Salary are distinct CBA concepts. Use an authoritative Apron Team Salary when available; contract-sum estimates produce qualified results.",
    }


@router.post("/evaluate")
def evaluate_trade_request(payload: TradeRequest) -> dict[str, Any]:
    try:
        result = evaluate_trade(
            states=[_state(team) for team in payload.teams],
            legs=[_leg(leg) for leg in payload.legs],
            season=payload.season,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return trade_evaluation_to_dict(result)


def _contracts_path() -> Path:
    configured = os.getenv("SPORTS_TERMINAL_CONTRACTS_LONG_PATH")
    return Path(configured) if configured else DEFAULT_CONTRACTS_PATH


def _read_contract_rows(season: str) -> list[dict[str, str]]:
    path = _contracts_path()
    if not path.exists():
        raise HTTPException(
            status_code=503,
            detail={
                "message": "Canonical contract data has not been generated yet.",
                "expected_path": str(path),
                "command": "python backend/scripts/nba_contracts_pipeline.py --output-dir raw/nba/contracts",
            },
        )
    with path.open(newline="", encoding="utf-8") as handle:
        return [row for row in csv.DictReader(handle) if row.get("season") == season]


@router.get("/teams")
def trade_machine_teams(season: str = Query(DEFAULT_SEASON)) -> list[dict[str, Any]]:
    cap = load_cap_levels(season)
    rows = _read_contract_rows(season)
    grouped: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        team = (row.get("team_abbr") or "").strip()
        if team:
            grouped.setdefault(team, []).append(row)

    out: list[dict[str, Any]] = []
    for team, team_rows in sorted(grouped.items()):
        players = []
        salary_sum = 0
        source_urls: list[str] = []
        for row in team_rows:
            salary_text = row.get("reported_salary") or ""
            try:
                salary = int(salary_text) if salary_text else 0
            except ValueError:
                salary = 0
            salary_sum += salary
            if row.get("source_urls"):
                source_urls.extend(url for url in row["source_urls"].split(";") if url)
            players.append({
                "player_id": row.get("player_external_id") or row.get("player_name"),
                "player_name": row.get("player_name"),
                "salary": salary,
                "option_type": row.get("option_type") or None,
                "fully_guaranteed": row.get("reported_salary_fully_guaranteed") or None,
                "salary_source": row.get("salary_source") or None,
            })
        out.append({
            "team_id": team,
            "team_name": team,
            "season": season,
            "players": sorted(players, key=lambda p: (-p["salary"], p["player_name"] or "")),
            "reported_contract_salary_sum": salary_sum,
            "estimated_apron_status": (
                "above_second_apron" if salary_sum > cap.second_apron else
                "above_first_apron" if salary_sum > cap.first_apron else
                "taxpayer" if salary_sum > cap.tax_level else
                "over_cap" if salary_sum > cap.salary_cap else
                "under_cap"
            ),
            "apron_team_salary": salary_sum,
            "apron_salary_is_estimate": True,
            "source_urls": list(dict.fromkeys(source_urls)),
            "warning": "This is a contract-salary sum, not the CBA-defined Apron Team Salary. Supply an authoritative TeamState override for unqualified apron legality.",
        })
    return out
