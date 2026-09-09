from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.user_salary_snapshot import (
    contract_seed_records,
    load_player_rows,
    load_team_rows,
    snapshot_diagnostics,
    team_position_seed_records,
)

players = load_player_rows()
teams = load_team_rows()
diagnostics = snapshot_diagnostics()
contracts = contract_seed_records()
positions = team_position_seed_records()

assert len(players) == 478, len(players)
assert [row['rank'] for row in players] == list(range(1, 479))
assert len(teams) == 30, len(teams)
assert len({row['team_id'] for row in teams}) == 30
assert diagnostics['player_rows'] == 478
assert diagnostics['team_rows'] == 30
assert diagnostics['exact_duplicate_rows'] == 2, diagnostics['exact_duplicate_rows']
assert len(contracts) == 476, len(contracts)
assert len(positions) == 30, len(positions)

canonical_team_ids = {row['team_id'] for row in teams}
assert {'BKN', 'CHA', 'PHX'}.issubset(canonical_team_ids)
assert not {'BRK', 'CHO', 'PHO'}.intersection(canonical_team_ids)
assert diagnostics['team_aliases'] == {'BRK': 'BKN', 'CHO': 'CHA', 'PHO': 'PHX'}
assert next(row for row in players if row['player'] == 'Michael Porter Jr.')['team'] == 'BKN'
assert next(row for row in players if row['player'] == 'Naz Reid')['team'] == 'CHA'
assert next(row for row in players if row['player'] == 'Devin Booker')['team'] == 'PHX'

expected_multi_team = {
    'Damian Lillard',
    'Bradley Beal',
    'Klay Thompson',
    'Jonathan Kuminga',
    'Kentavious Caldwell-Pope',
    'Olivier-Maxence Prosper',
}
assert expected_multi_team.issubset(set(diagnostics['multi_team_player_names']))

curry = next(row for row in players if row['player'] == 'Stephen Curry')
assert curry['2026-27'] == 62_587_158
assert curry['guaranteed'] == 62_587_158

tatum = next(row for row in players if row['player'] == 'Jayson Tatum')
assert tatum['2029-30'] == 71_446_914
assert tatum['guaranteed'] == 188_360_046

houston = next(row for row in teams if row['team_id'] == 'HOU')
assert houston['2026-27'] == 205_487_343
assert houston['2031-32'] == 47_337_931

for name in expected_multi_team:
    matches = [item for item in contracts if item['record']['player_name'] == name]
    assert len(matches) >= 2
    assert all(item['record']['metadata']['multi_team_obligation'] for item in matches)
    assert all(item['record']['metadata']['tradeable'] is False for item in matches)
    assert all(item['record']['metadata']['trade_restricted'] is True for item in matches)

assert sum(1 for item in contracts if item['record']['player_name'] == 'Jonathan Isaac') == 1
assert sum(1 for item in contracts if item['record']['player_name'] == 'Haywood Highsmith') == 1

for position in positions:
    record = position['record']
    assert record['source_status'] == 'uploaded'
    assert record['metadata']['payroll_total_not_cba_team_salary'] is True
    assert record['salary_cap'] == 164_961_000
    assert record['first_apron'] == 209_015_000
    assert record['second_apron'] == 221_686_000

print('User-supplied 2026-27 salary snapshot contract passed')
