# NBA salary and contract data pipeline

This pipeline replaces the proposed HoopsHype-only scraper with a source-agnostic model. The goal is to preserve every useful reported term without pretending that cash salary, guaranteed/protected compensation, and salary-cap treatment are the same thing.

## Source hierarchy and coverage

1. **NBA / NBPA / CBA** — authoritative for transaction records, system levels, and rules. The pipeline reads the NBA's structured player-movement JSON, which supplies dates, descriptions, transaction types, NBA team IDs/slugs, NBA player IDs/slugs, and grouping IDs. The feed currently reaches back to July 2015. The checked-in `nba_cap_levels.csv` uses official NBA releases, and the CBA rule file is transcribed from the user-provided final 2023 CBA.
2. **Basketball-Reference current league contracts** — secondary reported source for current player salary schedules, aggregate guarantees, option markers, and any signing/cap-hit fields exposed by the table.
3. **Basketball-Reference current team payrolls** — a second current-contract evidence source. Team pages expose future salary schedules, aggregate guarantees, player/team options, and an italic marker for amounts that are not fully guaranteed.
4. **Basketball-Reference historical team-season salary tables** — historical player salary evidence. The pipeline discovers the teams that actually played each season rather than hard-coding today's franchises, so historical franchise abbreviations are retained. Default coverage begins with 1984-85.
5. **Basketball-Reference historical transactions** — secondary historical event log, used as the long-history backfill around and before the NBA structured movement feed.
6. **Authorized supplemental sources** — future adapters can add team press releases, licensed data, or user-supplied data. They must feed the same evidence model and retain provenance.

No adapter silently overwrites a conflicting value. All source rows are written to `contract_evidence.csv`; a conservative reconciler then creates one canonical player/team/season row in `contracts_long.csv`. Source URLs and the selected source for salary, guarantee, and option fields remain visible.

## Important historical-data caveat

Basketball-Reference describes historical NBA salary collection as unofficial and inexact. Its salary methodology notes that minimum salaries were assigned where salary data was missing in 1988-89 and 1990-91 through 2004-05, and that in other seasons missing salaries may be extrapolated when a player's salary is known before and after the missing season. Historical salary evidence therefore carries an explicit `source_quality_note` instead of being presented as audited contract data.

## Canonical concepts

`reported_salary` is a source-reported player-season salary. `reported_cap_hit` is populated only when a source separately reports a cap hit. `reported_contract_guaranteed_total` is an aggregate source-reported guarantee and is not allocated across seasons by inference. `reported_salary_fully_guaranteed` records the team-payroll page's guarantee presentation when available. `option_type` is one of `player_option`, `team_option`, or `early_termination_option` when source markup supports it.

Transactions separately classify standard contracts, two-way contracts, 10-day contracts, rest-of-season contracts, Exhibit 10 contracts, rookie-scale contracts, rookie-scale extensions, veteran extensions, waivers, conversions, and trades. Official NBA IDs/slugs are retained when supplied by the NBA movement feed.

The CBA model deliberately distinguishes Compensation, Salary, and Team Salary. CBA calculations should therefore live in future derived fields such as `derived_team_salary_amount`, with the exact CBA rule/reference and calculation inputs, rather than replacing source-reported salary.

## CBA-backed rule model

`backend/data/cba_2023_contract_rules.json` currently encodes:

- standard, rookie-scale, two-way, 10-day, rest-of-season, and Exhibit 10 contract structures;
- compensation-protection categories and conditional protection;
- team options, player options, and ETO concepts;
- maximum-salary service tiers and the 105% prior-salary alternative;
- signing/incentive bonus limits;
- the full 30-pick baseline rookie salary scale from Exhibit B; and
- the baseline minimum annual salary scale by Years of Service from Exhibit C.

The current validator is intentionally conservative. It flags obvious source/rule anomalies and does not claim to make legal determinations where the required contract facts are unavailable.

## Run

```bash
pip install -r backend/requirements.txt
python backend/scripts/test_nba_contracts_pipeline.py
python backend/scripts/nba_contracts_pipeline.py
```

The default run is broad: historical salaries begin with 1984-85, historical transactions begin with 1983-84, current team payrolls are included, and current official NBA movement data is included. Use the `--skip-*` flags for targeted runs.

Fetched HTML/JSON is cached under `raw/nba_contracts/cache/`, making large historical runs resumable and reducing repeat traffic. Use `--refresh` only when a fresh source snapshot is required.

Default outputs under `raw/nba_contracts/`:

- `contract_evidence.csv` — every parsed salary/contract evidence row with provenance;
- `contracts_long.csv` — conservative reconciled player/team/season view;
- `transactions.csv` — official + historical transaction events and contract subtypes;
- `cba_validation_issues.csv` — CBA-informed anomaly diagnostics; and
- `manifest.json` — per-source/page success/failure and row counts.

Automated fetching checks each host's `robots.txt` before network retrieval and fails closed when permission cannot be established. There is intentionally no bypass flag.

## Next high-value enrichment

The next layer should focus on team/player identity reconciliation between NBA IDs and Basketball-Reference IDs, team press releases for signing dates and guarantee language, and CBA Article VII calculations for Team Salary/cap charges. Those should be built on top of the evidence layer rather than inferred into source fields.
