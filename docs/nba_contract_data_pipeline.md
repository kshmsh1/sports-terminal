# NBA salary and contract data pipeline

This pipeline replaces the proposed HoopsHype-only scraper with a source-agnostic model. The goal is to preserve every useful reported term without pretending that salary, guaranteed cash, and salary-cap treatment are the same thing.

## Source hierarchy

1. **NBA / NBPA / CBA** — authoritative for transaction classifications, system levels, and rules. The checked-in `nba_cap_levels.csv` is sourced from NBA releases. The CBA rule file is transcribed from the user-provided final 2023 CBA.
2. **Basketball-Reference contracts** — secondary reported source for current player salary schedules, contract guarantees, option markers, and (where exposed) signing mechanism/cap hit.
3. **Basketball-Reference transactions** — secondary historical event log extending much farther back than current NBA.com transaction pages.
4. **Authorized supplemental sources** — future adapters may add team press releases, licensed data, or manually supplied CSVs. They should feed the same canonical fields and retain provenance.

No adapter should silently overwrite a conflicting value. Conflicts should remain inspectable as separate evidence until a reconciliation rule explicitly selects a canonical value.

## Canonical concepts

`reported_salary` is the source-reported salary for a player-season. `reported_cap_hit` is only populated when a source separately reports a cap hit. `reported_contract_guaranteed_total` is a source-reported aggregate guarantee and is not treated as a season-level guarantee. `option_type` is one of `player_option`, `team_option`, or `early_termination_option` when the source exposes it. Transaction events separately identify two-way, 10-day, rest-of-season, Exhibit 10, rookie-scale, and extension events.

The CBA model deliberately distinguishes Compensation, Salary, and Team Salary. Future cap calculations should therefore live in derived fields such as `derived_team_salary_amount` with a CBA rule reference rather than replacing reported cash salary.

## CBA-backed rule checks

The checked-in rule file covers the contract taxonomy, compensation-protection categories, player/team options and ETOs, maximum-salary service tiers, bonus limits, two-way rules, 10-day/rest-of-season rules, the baseline rookie scale, and the baseline minimum salary scale. The current validator is intentionally conservative: it flags obvious anomalies but does not claim to make legal determinations.

## Run

```bash
pip install -r backend/requirements.txt
python backend/scripts/nba_contracts_pipeline.py
python backend/scripts/test_nba_contracts_pipeline.py
```

Default output is written under `raw/nba_contracts/`:

- `contracts_long.csv`
- `transactions.csv`
- `cba_validation_issues.csv`
- `manifest.json`

Automated fetching checks each host's `robots.txt` before requesting source pages and fails closed when permission cannot be established. There is intentionally no bypass flag.

## Next adapters

The highest-value next additions are team press-release parsing for guaranteed/option detail, an NBA.com offseason-deal/official-trade adapter, a player/team identity reconciler, and a season-by-season Team Salary calculator that applies Article VII rather than treating payroll totals as cap totals.
