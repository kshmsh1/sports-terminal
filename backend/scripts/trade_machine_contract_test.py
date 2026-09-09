#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from app.trade_machine import (  # noqa: E402
    TeamTradeLeg,
    TeamTradeState,
    TradePlayer,
    annual_cash_limit,
    evaluate_trade,
    expanded_tpe_limit,
    load_cap_levels,
    load_trade_rules,
    scaled_expanded_additive,
)


def player(pid: str, name: str, salary: int, **kwargs) -> TradePlayer:
    return TradePlayer(pid, name, salary, **kwargs)


def two_team_trade(a_state, b_state, a_out, b_out, **leg_kwargs):
    return evaluate_trade(
        [a_state, b_state],
        [
            TeamTradeLeg(a_state.team_id, outgoing=a_out, incoming=b_out, **leg_kwargs.get("a", {})),
            TeamTradeLeg(b_state.team_id, outgoing=b_out, incoming=a_out, **leg_kwargs.get("b", {})),
        ],
    )


cap = load_cap_levels("2026-27")
rules = load_trade_rules()
assert cap.salary_cap == 164_961_000
assert cap.first_apron == 209_015_000
assert cap.second_apron == 221_686_000
assert cap.tax_level == 200_428_000
assert cap.non_taxpayer_mle == 15_044_000
assert cap.taxpayer_mle == 6_064_000
assert cap.room_mle == 9_366_000
assert scaled_expanded_additive(cap, rules) == 9_095_709
assert annual_cash_limit(cap, rules) == 8_495_492

# Standard TPE: one outgoing salary can bring back 100% + $250k when the post-trade
# Apron Team Salary does not exceed the First Apron.
a = TeamTradeState("A", "Team A", apron_team_salary=180_000_000, team_salary=180_000_000)
b = TeamTradeState("B", "Team B", apron_team_salary=180_000_000, team_salary=180_000_000)
trade = two_team_trade(a, b, [player("p1", "A Player", 10_000_000)], [player("p2", "B Player", 10_200_000)])
assert trade.legal
team_a = next(t for t in trade.teams if t.team_id == "A")
assert team_a.selected_mechanism == "standard_tpe"
assert team_a.post_trade_apron_salary == 180_200_000

# Article VII 6(j)(1)(v) is Room + $250k, not outgoing salary + Room + $250k.
room_trade = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=150_000_000, team_salary=150_000_000),
    TeamTradeState("B", "Team B", apron_team_salary=180_000_000, team_salary=180_000_000),
    [player("r1", "A Small", 1_000_000)],
    [player("r2", "B Room", 15_000_000)],
)
assert room_trade.legal
room_a = next(t for t in room_trade.teams if t.team_id == "A")
assert room_a.selected_mechanism == "room_plus_250k"
room_path = next(p for p in room_a.matching_paths if p.mechanism == "room_plus_250k")
assert room_path.salary_limit == (cap.salary_cap - 150_000_000) + 250_000

# Article VII 6(j)(3) removes the $250k allowance if post-assignment Apron Team
# Salary would exceed the First Apron.
allowance_fail = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=209_000_000),
    TeamTradeState("B", "Team B", apron_team_salary=170_000_000),
    [player("al1", "A Allowance", 10_000_000)],
    [player("al2", "B Allowance", 10_200_000)],
)
assert not allowance_fail.legal
allowance_a = next(t for t in allowance_fail.teams if t.team_id == "A")
standard_path = next(p for p in allowance_a.matching_paths if p.mechanism == "standard_tpe")
assert standard_path.salary_limit == 10_000_000
assert not standard_path.salary_match_passes

# Expanded TPE should use the CBA's scaled 7.5m branch for a $20m outgoing salary.
assert expanded_tpe_limit(20_000_000, cap, rules) == 29_095_709
expanded = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=190_000_000),
    TeamTradeState("B", "Team B", apron_team_salary=175_000_000),
    [player("p3", "A 20m", 20_000_000)],
    [player("p4", "B 28m", 28_000_000)],
)
assert expanded.legal
expanded_a = next(t for t in expanded.teams if t.team_id == "A")
assert expanded_a.selected_mechanism == "expanded_tpe"
assert expanded_a.hard_cap_after_trade == "first_apron"

# The exact same matching path fails if it leaves the acquiring team above the first apron.
first_apron_fail = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=205_000_000),
    TeamTradeState("B", "Team B", apron_team_salary=170_000_000),
    [player("p5", "A 20m", 20_000_000)],
    [player("p6", "B 28m", 28_000_000)],
)
assert not first_apron_fail.legal
assert any(f["rule"] == "salary_matching" for f in next(t for t in first_apron_fail.teams if t.team_id == "A").failures)

# Aggregating two outgoing players is a row H transaction and cannot leave the team above the second apron.
aggregate_fail = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=221_700_000),
    TeamTradeState("B", "Team B", apron_team_salary=150_000_000),
    [player("p7", "A One", 8_000_000), player("p8", "A Two", 7_000_000)],
    [player("p9", "B One", 15_000_000)],
)
assert not aggregate_fail.legal
aggregate_a = next(t for t in aggregate_fail.teams if t.team_id == "A")
assert any(p.mechanism == "aggregated_standard_tpe" and p.salary_match_passes and not p.hard_cap_passes for p in aggregate_a.matching_paths)

# Cash has both a season-wide 5.15% limit and a second-apron restriction for the paying team.
cash_fail = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=222_000_000, cash_sent_ytd=8_000_000),
    TeamTradeState("B", "Team B", apron_team_salary=160_000_000),
    [player("p10", "A Cash", 10_000_000)],
    [player("p11", "B Cash", 10_000_000)],
    a={"cash_sent": 600_000},
    b={"cash_received": 600_000},
)
assert not cash_fail.legal
cash_a = next(t for t in cash_fail.teams if t.team_id == "A")
assert {f["rule"] for f in cash_a.failures} >= {"annual_cash_sent_limit", "cash_second_apron"}

# A receiving sign-and-trade team is constrained by the first apron.
snt_fail = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=208_000_000),
    TeamTradeState("B", "Team B", apron_team_salary=170_000_000),
    [player("p12", "A SNT", 10_000_000)],
    [player("p13", "B SNT", 12_000_000)],
    a={"receiving_sign_and_trade_player": True},
)
assert not snt_fail.legal
assert any(f["rule"] == "sign_and_trade_first_apron" for f in next(t for t in snt_fail.teams if t.team_id == "A").failures)

# Engine fails closed on trade eligibility and player-consent requirements.
consent_fail = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=170_000_000),
    TeamTradeState("B", "Team B", apron_team_salary=170_000_000),
    [player("p14", "Consent Player", 5_000_000, consent_required=True, consent_given=False)],
    [player("p15", "Other Player", 5_000_000)],
)
assert not consent_fail.legal
assert any(f["rule"] == "player_consent" for f in next(t for t in consent_fail.teams if t.team_id == "A").failures)

# Explicit matching-salary overrides support special CBA treatment without corrupting reported salary.
override_trade = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=180_000_000),
    TeamTradeState("B", "Team B", apron_team_salary=180_000_000),
    [player("p16", "Override Out", 12_000_000, outgoing_salary_for_matching=15_000_000)],
    [player("p17", "Override In", 15_200_000)],
)
assert override_trade.legal
assert next(t for t in override_trade.teams if t.team_id == "A").outgoing_salary == 12_000_000
assert next(t for t in override_trade.teams if t.team_id == "A").outgoing_matching_salary == 15_000_000

# Estimated Apron Team Salary produces a qualified result rather than pretending to be authoritative.
qualified = two_team_trade(
    TeamTradeState("A", "Team A", apron_team_salary=180_000_000, apron_salary_is_estimate=True),
    TeamTradeState("B", "Team B", apron_team_salary=180_000_000),
    [player("p18", "Estimate A", 8_000_000)],
    [player("p19", "Estimate B", 8_000_000)],
)
assert qualified.legal and qualified.qualified
assert next(t for t in qualified.teams if t.team_id == "A").warnings

print("2026-27 CBA trade machine contract test passed")
