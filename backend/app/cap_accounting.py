from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

from .trade_machine import DEFAULT_SEASON, CapLevels, load_cap_levels

BACKEND_ROOT = Path(__file__).resolve().parents[1]
CONTRACT_RULES_PATH = BACKEND_ROOT / "data" / "cba_2023_contract_rules.json"
BASE_SCALE_CAP_2022_23 = 123_655_000


@dataclass(frozen=True)
class CapCharge:
    label: str
    amount: int
    category: str
    cba_reference: str
    source: str = "cba_derived"
    note: str | None = None


@dataclass
class CapPlayer:
    player_id: str
    player_name: str
    salary: int
    likely_bonus: int = 0
    unlikely_bonus: int = 0
    years_of_service: int | None = None
    roster_status: str = "active"
    fully_guaranteed: bool | None = None
    source_url: str | None = None


@dataclass
class FreeAgentHold:
    player_id: str
    player_name: str
    prior_salary: int
    rights_type: str
    prior_salary_at_or_above_estimated_average: bool | None = None
    rookie_scale_second_option_year: bool = False
    prior_salary_at_or_below_minimum: bool = False
    minimum_non_reimbursed_amount: int | None = None
    max_salary: int | None = None


@dataclass
class RookiePickHold:
    pick: int
    player_name: str | None = None
    scale_percentage: float = 1.20


@dataclass
class WaivedSalary:
    player_name: str
    current_season_salary: int
    future_season_salaries: list[int] = field(default_factory=list)
    stretched: bool = False
    election_period: str = "sep_jun"  # sep_jun or jul_aug


@dataclass
class TeamCapInput:
    team_id: str
    team_name: str
    players: list[CapPlayer] = field(default_factory=list)
    free_agent_holds: list[FreeAgentHold] = field(default_factory=list)
    rookie_pick_holds: list[RookiePickHold] = field(default_factory=list)
    waived_salaries: list[WaivedSalary] = field(default_factory=list)
    other_team_salary_charges: list[CapCharge] = field(default_factory=list)
    exception_amounts_in_team_salary: int = 0
    restricted_free_agent_apron_amounts: int = 0
    required_tender_apron_amounts: int = 0
    excluded_long_term_injury_salary_for_apron: int = 0
    official_team_salary_override: int | None = None
    official_apron_team_salary_override: int | None = None


@dataclass
class TeamCapResult:
    season: str
    team_id: str
    team_name: str
    team_salary: int
    apron_team_salary: int
    room: int
    tax_overage: int
    first_apron_room: int
    second_apron_room: int
    status: str
    included_player_count: int
    charges: list[CapCharge]
    warnings: list[str]
    authoritative_team_salary: bool
    authoritative_apron_salary: bool


def load_contract_rules(path: Path = CONTRACT_RULES_PATH) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def scale_amount(baseline: int, cap: CapLevels, base_cap: int = BASE_SCALE_CAP_2022_23) -> int:
    return round(baseline * cap.salary_cap / base_cap)


def minimum_salary(years_of_service: int, season: str = DEFAULT_SEASON) -> int:
    cap = load_cap_levels(season)
    rules = load_contract_rules()
    key = "10+" if years_of_service >= 10 else str(max(years_of_service, 0))
    row = next(r for r in rules["minimum_annual_salary_scale"]["rows"] if r["years_of_service"] == key)
    return scale_amount(int(row["year1"]), cap)


def rookie_scale_amount(pick: int, season: str = DEFAULT_SEASON) -> int:
    if pick < 1 or pick > 30:
        raise ValueError("Rookie scale pick must be 1-30")
    cap = load_cap_levels(season)
    rules = load_contract_rules()
    row = next(r for r in rules["rookie_scale"]["rows"] if int(r["pick"]) == pick)
    return scale_amount(int(row["year1"]), cap)


def rookie_scale_cap_hold(pick: int, season: str = DEFAULT_SEASON) -> int:
    return round(1.20 * rookie_scale_amount(pick, season))


def free_agent_amount(hold: FreeAgentHold, season: str = DEFAULT_SEASON) -> tuple[int, str]:
    if hold.prior_salary_at_or_below_minimum:
        if hold.minimum_non_reimbursed_amount is None:
            raise ValueError(f"{hold.player_name}: minimum non-reimbursed amount is required for minimum-salary free-agent hold")
        amount = hold.minimum_non_reimbursed_amount
        return amount, "Article VII 4(d)(4): minimum-salary override"

    rights = hold.rights_type.lower()
    if rights == "bird":
        if hold.prior_salary_at_or_above_estimated_average is None:
            raise ValueError(f"{hold.player_name}: Bird hold requires prior_salary_at_or_above_estimated_average")
        if hold.rookie_scale_second_option_year:
            pct = 2.50 if hold.prior_salary_at_or_above_estimated_average else 3.00
            ref = "Article VII 4(d)(1)(ii)"
        else:
            pct = 1.50 if hold.prior_salary_at_or_above_estimated_average else 1.90
            ref = "Article VII 4(d)(1)(i)"
    elif rights == "early_bird":
        pct, ref = 1.30, "Article VII 4(d)(2)"
    elif rights == "non_bird":
        pct, ref = 1.20, "Article VII 4(d)(3)"
    elif rights == "two_way_completed":
        return minimum_salary(0, season), "Article VII 4(d)(7)"
    else:
        raise ValueError(f"Unsupported free-agent rights type: {hold.rights_type}")

    amount = round(hold.prior_salary * pct)
    if hold.max_salary is not None:
        amount = min(amount, hold.max_salary)
    return amount, ref


def stretched_salary_schedule(waived: WaivedSalary) -> list[int]:
    future = [max(int(x), 0) for x in waived.future_season_salaries]
    if not waived.stretched:
        return [max(waived.current_season_salary, 0), *future]
    if waived.election_period == "sep_jun":
        years = 2 * len(future) + 1
        future_total = sum(future)
        allocation = round(future_total / years) if years else 0
        return [max(waived.current_season_salary, 0), *([allocation] * years)]
    if waived.election_period == "jul_aug":
        total = max(waived.current_season_salary, 0) + sum(future)
        years = 2 * (1 + len(future)) + 1
        allocation = round(total / years)
        return [allocation] * years
    raise ValueError("election_period must be sep_jun or jul_aug")


def evaluate_team_cap(team: TeamCapInput, season: str = DEFAULT_SEASON) -> TeamCapResult:
    cap = load_cap_levels(season)
    charges: list[CapCharge] = []
    warnings: list[str] = []

    for p in team.players:
        charges.append(CapCharge(p.player_name, p.salary + p.likely_bonus, "player_salary", "Article VII 3(d); 4(a)", note="Likely bonuses included in Salary." if p.likely_bonus else None))

    for hold in team.free_agent_holds:
        amount, ref = free_agent_amount(hold, season)
        charges.append(CapCharge(hold.player_name, amount, "free_agent_hold", ref))

    for pick in team.rookie_pick_holds:
        amount = round(rookie_scale_amount(pick.pick, season) * pick.scale_percentage)
        charges.append(CapCharge(pick.player_name or f"Unsigned first-round pick #{pick.pick}", amount, "rookie_pick_hold", "Article VII 4(e)(1)", note="Default cap hold is 120% of applicable Rookie Scale Amount."))

    for waived in team.waived_salaries:
        schedule = stretched_salary_schedule(waived)
        amount = schedule[0]
        charges.append(CapCharge(waived.player_name, amount, "waived_salary", "Article VII 4(a)(1)(i); 7(d)(6)", note=f"Stretch schedule: {schedule}"))
        if waived.stretched:
            warnings.append(f"{waived.player_name}: future stretch charges must also satisfy the 15% former-player Team Salary limit in Article VII 7(d)(6)(iii).")

    charges.extend(team.other_team_salary_charges)
    derived_team_salary = sum(c.amount for c in charges) + max(team.exception_amounts_in_team_salary, 0)

    included_players = len(team.players) + len(team.free_agent_holds) + len(team.rookie_pick_holds)
    incomplete_slots = max(12 - included_players, 0)
    incomplete_amount = incomplete_slots * minimum_salary(0, season)
    if incomplete_amount:
        charges.append(CapCharge("Incomplete roster charge", incomplete_amount, "incomplete_roster", "Article VII 4(f)(1)", note=f"{incomplete_slots} slot(s) × zero-YOS minimum."))
        derived_team_salary += incomplete_amount

    team_salary = team.official_team_salary_override if team.official_team_salary_override is not None else derived_team_salary

    # Article VII 2(e)(1): Apron Team Salary starts with Team Salary, adds excluded
    # performance bonuses and specified RFA/required-tender amounts, then removes
    # specified free-agent, exception and incomplete-roster amounts.
    excluded_performance_bonuses = sum(max(p.unlikely_bonus, 0) for p in team.players)
    free_agent_hold_total = sum(c.amount for c in charges if c.category == "free_agent_hold")
    rookie_hold_total = sum(c.amount for c in charges if c.category == "rookie_pick_hold")
    apron_derived = (
        team_salary
        + excluded_performance_bonuses
        + max(team.restricted_free_agent_apron_amounts, 0)
        + max(team.required_tender_apron_amounts, 0)
        + max(team.excluded_long_term_injury_salary_for_apron, 0)
        - free_agent_hold_total
        - rookie_hold_total
        - max(team.exception_amounts_in_team_salary, 0)
        - incomplete_amount
    )
    apron_salary = team.official_apron_team_salary_override if team.official_apron_team_salary_override is not None else apron_derived

    if team.official_team_salary_override is None:
        warnings.append("Team Salary is CBA-derived from supplied inputs; omitted cap holds, exception charges, bonuses or former-player amounts can change it.")
    if team.official_apron_team_salary_override is None:
        warnings.append("Apron Team Salary is CBA-derived from supplied inputs, not an official Team Salary Summary; trade-apron results remain qualified until all Article VII 2(e)(1) adjustments are complete.")

    if apron_salary > cap.second_apron:
        status = "above_second_apron"
    elif apron_salary > cap.first_apron:
        status = "above_first_apron"
    elif team_salary > cap.tax_level:
        status = "taxpayer"
    elif team_salary > cap.salary_cap:
        status = "over_cap"
    else:
        status = "under_cap"

    return TeamCapResult(
        season=season,
        team_id=team.team_id,
        team_name=team.team_name,
        team_salary=team_salary,
        apron_team_salary=apron_salary,
        room=max(cap.salary_cap - team_salary, 0),
        tax_overage=max(team_salary - cap.tax_level, 0),
        first_apron_room=cap.first_apron - apron_salary,
        second_apron_room=cap.second_apron - apron_salary,
        status=status,
        included_player_count=included_players,
        charges=charges,
        warnings=warnings,
        authoritative_team_salary=team.official_team_salary_override is not None,
        authoritative_apron_salary=team.official_apron_team_salary_override is not None,
    )


def team_cap_result_to_dict(result: TeamCapResult) -> dict[str, Any]:
    return asdict(result)
