from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.trade_machine_api import trade_machine_teams

teams = trade_machine_teams('2026-27')
assert len(teams) == 30, len(teams)
assert len({team['team_id'] for team in teams}) == 30
assert {'BKN', 'CHA', 'PHX'}.issubset({team['team_id'] for team in teams})

houston = next(team for team in teams if team['team_id'] == 'HOU')
assert houston['reported_payroll_total'] == 205_487_343
assert houston['apron_team_salary'] == 205_487_343
assert houston['apron_salary_is_estimate'] is True
assert houston['source_status'] == 'uploaded'

warriors = next(team for team in teams if team['team_id'] == 'GSW')
curry = next(player for player in warriors['players'] if player['player_name'] == 'Stephen Curry')
assert curry['salary'] == 62_587_158
assert curry['remaining_guaranteed_total'] == 62_587_158
assert curry['trade_eligible'] is True

portland = next(team for team in teams if team['team_id'] == 'POR')
lillard = next(player for player in portland['players'] if player['player_name'] == 'Damian Lillard')
assert lillard['multi_team_obligation'] is True
assert lillard['trade_eligible'] is True
assert lillard['restriction_reason'] is None

milwaukee = next(team for team in teams if team['team_id'] == 'MIL')
lillard_retained = next(player for player in milwaukee['players'] if player['player_name'] == 'Damian Lillard')
assert lillard_retained['multi_team_obligation'] is True
assert lillard_retained['trade_eligible'] is False
assert 'current NBA team is POR' in lillard_retained['restriction_reason']

miami = next(team for team in teams if team['team_id'] == 'MIA')
klay = next(player for player in miami['players'] if player['player_name'] == 'Klay Thompson')
assert klay['trade_eligible'] is True

dallas = next(team for team in teams if team['team_id'] == 'DAL')
klay_retained = next(player for player in dallas['players'] if player['player_name'] == 'Klay Thompson')
assert klay_retained['trade_eligible'] is False

orlando = next(team for team in teams if team['team_id'] == 'ORL')
assert sum(1 for player in orlando['players'] if player['player_name'] == 'Jonathan Isaac') == 1

print('Snapshot-backed trade machine teams API contract passed')
