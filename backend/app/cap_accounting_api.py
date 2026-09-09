from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from .cap_accounting import (
    CapCharge,
    CapPlayer,
    FreeAgentHold,
    RookiePickHold,
    TeamCapInput,
    WaivedSalary,
    evaluate_team_cap,
    minimum_salary,
    rookie_scale_amount,
    rookie_scale_cap_hold,
    team_cap_result_to_dict,
)
from .trade_machine import DEFAULT_SEASON, load_cap_levels

router = APIRouter(prefix="/v2/nba/cap-accounting", tags=["nba-cap-accounting"])


class CapPlayerInput(BaseModel):
    player_id: str
    player_name: str
    salary: int = Field(ge=0)
    likely_bonus: int = Field(default=0, ge=0)
    unlikely_bonus: int = Field(default=0, ge=0)
    years_of_service: int | None = Field(default=None, ge=0)
    roster_status: str = "active"
    fully_guaranteed: bool | None = None
    source_url: str | None = None


class FreeAgentHoldInput(BaseModel):
    player_id: str
    player_name: str
    prior_salary: int = Field(ge=0)
    rights_type: str
    prior_salary_at_or_above_estimated_average: bool | None = None
    rookie_scale_second_option_year: bool = False
    prior_salary_at_or_below_minimum: bool = False
    minimum_non_reimbursed_amount: int | None = Field(default=None, ge=0)
    max_salary: int | None = Field(default=None, ge=0)


class RookiePickHoldInput(BaseModel):
    pick: int = Field(ge=1, le=30)
    player_name: str | None = None
    scale_percentage: float = Field(default=1.20, ge=0.80, le=1.20)


class WaivedSalaryInput(BaseModel):
    player_name: str
    current_season_salary: int = Field(ge=0)
    future_season_salaries: list[int] = Field(default_factory=list)
    stretched: bool = False
    election_period: str = "sep_jun"


class OtherChargeInput(BaseModel):
    label: str
    amount: int
    category: str
    cba_reference: str
    source: str = "reported_or_manual"
    note: str | None = None


class TeamCapRequest(BaseModel):
    season: str = DEFAULT_SEASON
    team_id: str
    team_name: str
    players: list[CapPlayerInput] = Field(default_factory=list)
    free_agent_holds: list[FreeAgentHoldInput] = Field(default_factory=list)
    rookie_pick_holds: list[RookiePickHoldInput] = Field(default_factory=list)
    waived_salaries: list[WaivedSalaryInput] = Field(default_factory=list)
    other_team_salary_charges: list[OtherChargeInput] = Field(default_factory=list)
    exception_amounts_in_team_salary: int = Field(default=0, ge=0)
    restricted_free_agent_apron_amounts: int = Field(default=0, ge=0)
    required_tender_apron_amounts: int = Field(default=0, ge=0)
    excluded_long_term_injury_salary_for_apron: int = Field(default=0, ge=0)
    official_team_salary_override: int | None = Field(default=None, ge=0)
    official_apron_team_salary_override: int | None = Field(default=None, ge=0)


@router.get("/config")
def cap_accounting_config(season: str = Query(DEFAULT_SEASON)) -> dict[str, Any]:
    cap = load_cap_levels(season)
    return {
        "season": season,
        "cap_levels": cap.__dict__,
        "minimum_salary_scale": {str(yos): minimum_salary(yos, season) for yos in range(0, 11)},
        "rookie_scale": [
            {
                "pick": pick,
                "rookie_scale_amount": rookie_scale_amount(pick, season),
                "unsigned_pick_cap_hold_120pct": rookie_scale_cap_hold(pick, season),
            }
            for pick in range(1, 31)
        ],
        "scale_method": "CBA Exhibit B/C baseline amounts scaled by the 2026-27 Salary Cap / 2022-23 Salary Cap, which is algebraically equivalent to the CBA's annual roll-forward adjustments.",
        "references": ["Article I 1(hhh)-(iii)", "Article II 6", "Article VII 2(e), 3(d), 4", "Article VIII 1", "Exhibits B and C"],
    }


@router.post("/evaluate-team")
def evaluate_team_cap_request(payload: TeamCapRequest) -> dict[str, Any]:
    try:
        result = evaluate_team_cap(
            TeamCapInput(
                team_id=payload.team_id,
                team_name=payload.team_name,
                players=[CapPlayer(**p.model_dump()) for p in payload.players],
                free_agent_holds=[FreeAgentHold(**h.model_dump()) for h in payload.free_agent_holds],
                rookie_pick_holds=[RookiePickHold(**h.model_dump()) for h in payload.rookie_pick_holds],
                waived_salaries=[WaivedSalary(**w.model_dump()) for w in payload.waived_salaries],
                other_team_salary_charges=[CapCharge(**c.model_dump()) for c in payload.other_team_salary_charges],
                exception_amounts_in_team_salary=payload.exception_amounts_in_team_salary,
                restricted_free_agent_apron_amounts=payload.restricted_free_agent_apron_amounts,
                required_tender_apron_amounts=payload.required_tender_apron_amounts,
                excluded_long_term_injury_salary_for_apron=payload.excluded_long_term_injury_salary_for_apron,
                official_team_salary_override=payload.official_team_salary_override,
                official_apron_team_salary_override=payload.official_apron_team_salary_override,
            ),
            payload.season,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return team_cap_result_to_dict(result)
