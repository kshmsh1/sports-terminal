#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AUDITOR_PATH = ROOT / 'tools' / 'audit_nba_api_metric_coverage.py'
CATALOG_PATH = ROOT / 'lib' / 'services' / 'nba_stats_metric_catalog.dart'

spec = importlib.util.spec_from_file_location('nba_api_metric_coverage', AUDITOR_PATH)
if spec is None or spec.loader is None:
    raise SystemExit('Unable to load NBA API coverage auditor')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

metrics = module.parse_metric_catalog(CATALOG_PATH)
by_key = {metric['key']: metric for metric in metrics}

assert len(metrics) >= 180, len(metrics)
for required in [
    'ppg',
    'deflections_pg',
    'potential_apg',
    'contested_rpg',
    'ts_pct',
    'net_rating',
    'epm',
    'darko',
    'usage',
    'clutch_ppg',
    'rim_frequency',
    'isolation_ppp',
    'offensive_gravity',
    'dunks_pg',
    'height',
    'technical_fouls',
    'availability_pct',
]:
    assert required in by_key, required

assert 'PTS' in module.ENGINE_COLUMN_ALIASES['pts']
assert 'LeagueDashPlayerStats' in module.PRIORITY_ENDPOINT_HINTS['Basic']
assert 'GravityLeaders' in module.PRIORITY_ENDPOINT_HINTS['Creation']
assert 'SynergyPlayTypes' in module.PRIORITY_ENDPOINT_HINTS['Play Type']

print(
    'nba_api metric coverage contract ok:',
    len(metrics),
    'Sports Terminal metrics parsed',
)
