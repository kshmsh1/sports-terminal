from __future__ import annotations

import csv
import json
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

BACKEND_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CAP_LEVELS = BACKEND_ROOT / "data" / "nba_cap_levels.csv"
DEFAULT_TRADE_RULES = BACKEND_ROOT / "data" / "cba_2023_trade_rules.json"
DEFAULT_SEASON = "2026-27"


@dataclass(frozen=True)
class CapLevels:
    season: str
    salary_cap: int
    minimum_team_salary: int
    tax_level: int
    first_apron: int
    second_apron: int
    non_taxpayer_mle: int
    taxpayer_mle: int
    room_mle: int
    source_url: str


@dataclass(frozen=True)
class TradePlayer:
    player_id: str
    player_name: str
    salary: int
    outgoing_salary_for_matching: int | None = None
    incoming_salary_for_matching: int | None = None
    trade_eligible: bool = True
    restriction_reason: str | None = None
    consent_required: bool = False
    consent_given: bool = False
    trade_bonus: int = 0
    source_url: str | None = None

    @property
    def outgoing_match_salary(self) -> int:
        return self.outgoing_salary_for_matching if self.outgoing_salary_for_matching is not None else self.salary

    @property
    def incoming_match_salary(self) -> int:
        if self.incoming_salary_for_matching is not None:
            return self.incoming_salary_for_matching
        return self.salary + max(self.trade_bonus, 0)


@dataclass
class TeamTradeState:
    team_id: str
    team_name: str
    apron_team_salary: int
    team_salary: int | None = None
    hard_cap: str | None = None
    cash_sent_ytd: int = 0
    cash_received_ytd: int = 0
    prior_restriction_rows: list[str] = field(default_factory=list)
    apron_salary_is_estimate: bool = False
    source_urls: list[str] = field(default_factory=list)


@dataclass
class TeamTradeLeg:
    team_id: str
    outgoing: list[TradePlayer] = field(default_factory=list)
    incoming: list[TradePlayer] = field(default_factory=list)
    cash_sent: int = 0
    cash_received: int = 0
    receiving_sign_and_trade_player: bool = False
    using_prior_standard_tpe_after_regular_season: bool = False


@dataclass
class MatchingPath:
    mechanism: str
    salary_limit: int
    incoming_matching_salary: int
    outgoing_matching_salary: int
    salary_match_passes: bool
    applicable_apron: str | None
    hard_cap_trigger_row: str | None
    hard_cap_passes: bool
    reason: str


@dataclass
class TeamTradeEvaluation:
    team_id: str
    team_name: str
    legal: bool
    qualified: bool
    pre_trade_apron_salary: int
    post_trade_apron_salary: int
    outgoing_salary: int
    incoming_salary: int
    outgoing_matching_salary: int
    incoming_matching_salary: int
    selected_mechanism: str | None
    hard_cap_after_trade: str | None
    matching_paths: list[MatchingPath]
    failures: list[dict[str, str]]
    warnings: list[str]
    cba_references: list[str]


@dataclass
class TradeEvaluation:
    season: str
    legal: bool
    qualified: bool
    cap_levels: CapLevels
    teams: list[TeamTradeEvaluation]
    cba_source: str
    cap_source: str


def load_cap_levels(season: str = DEFAULT_SEASON, path: Path = DEFAULT_CAP_LEVELS) -> CapLevels:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    row = next((r for r in rows if r["season"] == season), None)
    if row is None:
        raise ValueError(f"No cap levels configured for {season}")
    return CapLevels(
        season=season,
        salary_cap=int(row["salary_cap"]),
        minimum_team_salary=int(row["minimum_team_salary"]),
        tax_level=int(row["tax_level"]),
        first_apron=int(row["first_apron"]),
        second_apron=int(row["second_apron"]),
        non_taxpayer_mle=int(row["non_taxpayer_mle"]),
        taxpayer_mle=int(row["taxpayer_mle"]),
        room_mle=int(row["room_mle"]),
        source_url=row["source_url"],
    )


def load_trade_rules(path: Path = DEFAULT_TRADE_RULES) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def scaled_expanded_additive(cap: CapLevels, rules: dict[str, Any]) -> int:
    rule = rules["traded_player_exceptions"]["expanded"]
    return round(rule["base_scaled_additive_2023_24"] * cap.salary_cap / rule["scale_base_salary_cap"])


def annual_cash_limit(cap: CapLevels, rules: dict[str, Any]) -> int:
    pct = rules["cash"]["annual_send_or_receive_limit_pct_of_salary_cap"] / 100
    return round(cap.salary_cap * pct)


def expanded_tpe_limit(outgoing_salary: int, cap: CapLevels, rules: dict[str, Any]) -> int:
    scaled_additive = scaled_expanded_additive(cap, rules)
    branch_y = min(2 * outgoing_salary + 250_000, outgoing_salary + scaled_additive)
    branch_z = round(1.25 * outgoing_salary) + 250_000
    return max(branch_y, branch_z)


def _apron_value(name: str | None, cap: CapLevels) -> int | None:
    if name == "first_apron":
        return cap.first_apron
    if name == "second_apron":
        return cap.second_apron
    return None


def _stricter_cap(a: str | None, b: str | None) -> str | None:
    order = {None: 0, "second_apron": 1, "first_apron": 2}
    return a if order[a] >= order[b] else b


def _hard_cap_allows(state: TeamTradeState, applicable_apron: str | None, post_apron_salary: int, cap: CapLevels) -> bool:
    requested = _apron_value(applicable_apron, cap)
    existing = _apron_value(state.hard_cap, cap)
    limit_candidates = [value for value in (requested, existing) if value is not None]
    return not limit_candidates or post_apron_salary <= min(limit_candidates)


def _path(
    mechanism: str,
    limit: int,
    incoming: int,
    outgoing: int,
    state: TeamTradeState,
    post_apron: int,
    cap: CapLevels,
    applicable_apron: str | None,
    row: str | None,
    reason: str,
) -> MatchingPath:
    return MatchingPath(
        mechanism=mechanism,
        salary_limit=max(limit, 0),
        incoming_matching_salary=incoming,
        outgoing_matching_salary=outgoing,
        salary_match_passes=incoming <= max(limit, 0),
        applicable_apron=applicable_apron,
        hard_cap_trigger_row=row,
        hard_cap_passes=_hard_cap_allows(state, applicable_apron, post_apron, cap),
        reason=reason,
    )


def _matching_paths(
    state: TeamTradeState,
    leg: TeamTradeLeg,
    cap: CapLevels,
    rules: dict[str, Any],
    post_apron: int,
) -> list[MatchingPath]:
    outgoing = sum(p.outgoing_match_salary for p in leg.outgoing)
    incoming = sum(p.incoming_match_salary for p in leg.incoming)
    paths: list[MatchingPath] = []

    if len(leg.outgoing) == 1:
        applicable = "first_apron" if leg.using_prior_standard_tpe_after_regular_season else None
        row = "F" if applicable else None
        paths.append(_path(
            "standard_tpe", outgoing + 250_000, incoming, outgoing, state, post_apron, cap,
            applicable, row,
            "Article VII 6(j)(1)(i): one outgoing player may bring back up to 100% of pre-trade salary plus $250,000.",
        ))

    if len(leg.outgoing) >= 2:
        paths.append(_path(
            "aggregated_standard_tpe", outgoing + 250_000, incoming, outgoing, state, post_apron, cap,
            "second_apron", "H",
            "Article VII 6(j)(1)(ii): aggregated outgoing salaries may bring back up to 100% plus $250,000; row H imposes the Second Apron.",
        ))

    if leg.outgoing:
        paths.append(_path(
            "expanded_tpe", expanded_tpe_limit(outgoing, cap, rules), incoming, outgoing, state, post_apron, cap,
            "first_apron", "E",
            "Article VII 6(j)(1)(iv): expanded matching uses the greater of the CBA's 200%/scaled-additive branch and 125% branch; row E imposes the First Apron.",
        ))

    if state.team_salary is not None:
        room_before = max(cap.salary_cap - state.team_salary, 0)
        if room_before > 0:
            paths.append(_path(
                "room_plus_250k", outgoing + room_before + 250_000, incoming, outgoing, state, post_apron, cap,
                None, None,
                "Article VII 6(j)(1)(v): available Room can be combined with outgoing salary and the $250,000 allowance.",
            ))

    return paths


def evaluate_team_trade(
    state: TeamTradeState,
    leg: TeamTradeLeg,
    cap: CapLevels,
    rules: dict[str, Any],
) -> TeamTradeEvaluation:
    failures: list[dict[str, str]] = []
    warnings: list[str] = []
    refs = [
        rules["references"]["apron_team_salary"],
        rules["references"]["transaction_restrictions"],
        rules["references"]["traded_player_exception"],
    ]

    for player in leg.outgoing:
        if not player.trade_eligible:
            failures.append({"rule": "player_trade_eligibility", "detail": f"{player.player_name} is not currently trade-eligible: {player.restriction_reason or 'unspecified restriction'}"})
        if player.consent_required and not player.consent_given:
            failures.append({"rule": "player_consent", "detail": f"{player.player_name} requires consent for this trade and consent was not supplied."})

    outgoing_salary = sum(p.salary for p in leg.outgoing)
    incoming_salary = sum(p.salary + max(p.trade_bonus, 0) for p in leg.incoming)
    outgoing_matching = sum(p.outgoing_match_salary for p in leg.outgoing)
    incoming_matching = sum(p.incoming_match_salary for p in leg.incoming)
    post_apron = state.apron_team_salary - outgoing_salary + incoming_salary

    paths = _matching_paths(state, leg, cap, rules, post_apron)

    if leg.receiving_sign_and_trade_player:
        sign_trade_ok = _hard_cap_allows(state, "first_apron", post_apron, cap)
        if not sign_trade_ok:
            failures.append({"rule": "sign_and_trade_first_apron", "detail": f"Receiving a sign-and-trade player is a row C transaction and cannot leave {state.team_name} above the First Apron."})
        refs.append("Article VII, Section 2(e)(4) row C; Section 8(e)(1)")

    if leg.cash_sent:
        refs.append(rules["cash"]["reference"])
        limit = annual_cash_limit(cap, rules)
        if state.cash_sent_ytd + leg.cash_sent > limit:
            failures.append({"rule": "annual_cash_sent_limit", "detail": f"Cash sent would be ${state.cash_sent_ytd + leg.cash_sent:,}, above the 2026-27 CBA limit of ${limit:,}."})
        if not _hard_cap_allows(state, "second_apron", post_apron, cap):
            failures.append({"rule": "cash_second_apron", "detail": "Paying cash in a trade is row I and cannot leave the team above the Second Apron."})

    if leg.cash_received:
        limit = annual_cash_limit(cap, rules)
        if state.cash_received_ytd + leg.cash_received > limit:
            failures.append({"rule": "annual_cash_received_limit", "detail": f"Cash received would be ${state.cash_received_ytd + leg.cash_received:,}, above the 2026-27 CBA limit of ${limit:,}."})

    valid_paths = [p for p in paths if p.salary_match_passes and p.hard_cap_passes]
    if not valid_paths:
        failures.append({"rule": "salary_matching", "detail": f"Incoming matching salary ${incoming_matching:,} does not fit any available matching path while satisfying applicable apron restrictions."})

    selected = None
    if valid_paths:
        preference = {"room_plus_250k": 0, "standard_tpe": 1, "aggregated_standard_tpe": 2, "expanded_tpe": 3}
        selected = sorted(valid_paths, key=lambda p: (preference.get(p.mechanism, 99), p.salary_limit))[0]

    resulting_hard_cap = state.hard_cap
    if selected and selected.applicable_apron:
        resulting_hard_cap = _stricter_cap(resulting_hard_cap, selected.applicable_apron)
    if leg.receiving_sign_and_trade_player:
        resulting_hard_cap = _stricter_cap(resulting_hard_cap, "first_apron")
    if leg.cash_sent:
        resulting_hard_cap = _stricter_cap(resulting_hard_cap, "second_apron")

    if state.apron_salary_is_estimate:
        warnings.append("Apron Team Salary is estimated from available contract evidence, not an official team salary summary; apron legality is therefore qualified.")
    if any(p.outgoing_salary_for_matching is not None or p.incoming_salary_for_matching is not None for p in leg.outgoing + leg.incoming):
        warnings.append("One or more player matching salaries use an explicit override for special CBA salary treatment.")
    if any(p.trade_bonus for p in leg.incoming):
        warnings.append("Incoming salary includes a supplied trade bonus; confirm the contract's maximum-salary trade-bonus adjustment if applicable.")

    legal = not failures
    qualified = state.apron_salary_is_estimate or bool(warnings)
    return TeamTradeEvaluation(
        team_id=state.team_id,
        team_name=state.team_name,
        legal=legal,
        qualified=qualified,
        pre_trade_apron_salary=state.apron_team_salary,
        post_trade_apron_salary=post_apron,
        outgoing_salary=outgoing_salary,
        incoming_salary=incoming_salary,
        outgoing_matching_salary=outgoing_matching,
        incoming_matching_salary=incoming_matching,
        selected_mechanism=selected.mechanism if selected else None,
        hard_cap_after_trade=resulting_hard_cap,
        matching_paths=paths,
        failures=failures,
        warnings=warnings,
        cba_references=list(dict.fromkeys(refs)),
    )


def evaluate_trade(
    states: list[TeamTradeState],
    legs: list[TeamTradeLeg],
    season: str = DEFAULT_SEASON,
    cap_path: Path = DEFAULT_CAP_LEVELS,
    rules_path: Path = DEFAULT_TRADE_RULES,
) -> TradeEvaluation:
    if len(states) < 2:
        raise ValueError("A trade requires at least two teams")
    state_by_id = {state.team_id: state for state in states}
    leg_by_id = {leg.team_id: leg for leg in legs}
    if set(state_by_id) != set(leg_by_id):
        raise ValueError("Every participating team must have exactly one TeamTradeState and one TeamTradeLeg")

    outgoing_ids: set[str] = set()
    incoming_ids: set[str] = set()
    for leg in legs:
        for player in leg.outgoing:
            if player.player_id in outgoing_ids:
                raise ValueError(f"Player appears as outgoing more than once: {player.player_id}")
            outgoing_ids.add(player.player_id)
        for player in leg.incoming:
            if player.player_id in incoming_ids:
                raise ValueError(f"Player appears as incoming more than once: {player.player_id}")
            incoming_ids.add(player.player_id)
    if outgoing_ids != incoming_ids:
        missing_in = sorted(outgoing_ids - incoming_ids)
        missing_out = sorted(incoming_ids - outgoing_ids)
        raise ValueError(f"Trade player flow is unbalanced; missing incoming={missing_in}, missing outgoing={missing_out}")

    cap = load_cap_levels(season, cap_path)
    rules = load_trade_rules(rules_path)
    evaluations = [evaluate_team_trade(state_by_id[team_id], leg_by_id[team_id], cap, rules) for team_id in state_by_id]
    return TradeEvaluation(
        season=season,
        legal=all(team.legal for team in evaluations),
        qualified=any(team.qualified for team in evaluations),
        cap_levels=cap,
        teams=evaluations,
        cba_source=rules["document"]["source"],
        cap_source=cap.source_url,
    )


def trade_evaluation_to_dict(result: TradeEvaluation) -> dict[str, Any]:
    return asdict(result)
