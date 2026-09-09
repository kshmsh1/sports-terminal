#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from app.cap_accounting import (  # noqa: E402
    CapPlayer,
    FreeAgentHold,
    RookiePickHold,
    TeamCapInput,
    WaivedSalary,
    evaluate_team_cap,
    free_agent_amount,
    minimum_salary,
    rookie_scale_amount,
    rookie_scale_cap_hold,
    stretched_salary_schedule,
)

# Exhibit B/C values roll forward in proportion to the Salary Cap. The baseline
# applies to the 2022-23 cap, so cumulative annual adjustments telescope to the
# 2026-27 cap divided by the 2022-23 cap.
assert minimum_salary(0) == 1_357_763
assert minimum_salary(10) == 3_876_528
assert rookie_scale_amount(1) == 12_289_998
assert rookie_scale_cap_hold(1) == 14_747_998

# Article VII 4(d) free-agent holds.
bird_high = FreeAgentHold("p1", "Bird High", 20_000_000, "bird", True)
assert free_agent_amount(bird_high)[0] == 30_000_000
bird_low = FreeAgentHold("p2", "Bird Low", 10_000_000, "bird", False)
assert free_agent_amount(bird_low)[0] == 19_000_000
rookie_bird_low = FreeAgentHold("p3", "Rookie Bird", 8_000_000, "bird", False, rookie_scale_second_option_year=True)
assert free_agent_amount(rookie_bird_low)[0] == 24_000_000
early_bird = FreeAgentHold("p4", "Early Bird", 8_000_000, "early_bird")
assert free_agent_amount(early_bird)[0] == 10_400_000
non_bird = FreeAgentHold("p5", "Non Bird", 8_000_000, "non_bird")
assert free_agent_amount(non_bird)[0] == 9_600_000
assert free_agent_amount(FreeAgentHold("p6", "2W", 0, "two_way_completed"))[0] == minimum_salary(0)

# Minimum-contract FA holds require the league-fund non-reimbursed amount rather
# than fabricating one from gross minimum salary.
try:
    free_agent_amount(FreeAgentHold("p7", "Minimum Vet", 2_000_000, "non_bird", prior_salary_at_or_below_minimum=True))
    raise AssertionError("Expected minimum reimbursement input validation")
except ValueError:
    pass

# Article VII 7(d)(6) stretch mechanics.
assert stretched_salary_schedule(WaivedSalary("Sep Waive", 4_000_000, [4_300_000, 4_700_000, 5_000_000], True, "sep_jun")) == [4_000_000] + [2_000_000] * 7
assert stretched_salary_schedule(WaivedSalary("July Waive", 4_000_000, [4_300_000, 4_700_000, 5_000_000], True, "jul_aug")) == [2_000_000] * 9

# Team Salary includes likely bonuses and cap holds; Apron Team Salary reverses
# specified holds and adds excluded performance bonuses.
team = TeamCapInput(
    team_id="TST",
    team_name="Test Team",
    players=[
        CapPlayer("a", "Player A", 20_000_000, likely_bonus=1_000_000, unlikely_bonus=2_000_000),
        CapPlayer("b", "Player B", 10_000_000),
    ],
    free_agent_holds=[FreeAgentHold("fa", "FA", 8_000_000, "early_bird")],
    rookie_pick_holds=[RookiePickHold(1, "Pick One")],
)
result = evaluate_team_cap(team)
assert result.team_salary > 0
assert any(charge.category == "free_agent_hold" for charge in result.charges)
assert any(charge.category == "rookie_pick_hold" for charge in result.charges)
assert any(charge.category == "incomplete_roster" for charge in result.charges)
assert result.apron_team_salary < result.team_salary + 2_000_000
assert not result.authoritative_team_salary
assert not result.authoritative_apron_salary
assert result.warnings

# Official overrides are preserved rather than replaced by derived accounting.
override = evaluate_team_cap(TeamCapInput(
    team_id="OFF",
    team_name="Official",
    official_team_salary_override=180_000_000,
    official_apron_team_salary_override=185_000_000,
))
assert override.team_salary == 180_000_000
assert override.apron_team_salary == 185_000_000
assert override.authoritative_team_salary and override.authoritative_apron_salary

print("2026-27 CBA cap accounting contract test passed")
