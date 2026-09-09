# NBA salary, cap-accounting, and trade-machine data pipeline

This pipeline replaces the proposed HoopsHype-only scraper with a source-agnostic model. The goal is to preserve reported contract terms, derive CBA accounting separately, and evaluate trades without pretending cash salary, protected compensation, Team Salary, and Apron Team Salary are interchangeable.

## Source hierarchy and coverage

1. **NBA / NBPA / CBA** — authoritative for transaction records, system levels, and rules. The pipeline reads the NBA's structured player-movement JSON, which supplies dates, descriptions, transaction types, NBA team IDs/slugs, NBA player IDs/slugs, and grouping IDs. The feed currently reaches back to July 2015. `nba_cap_levels.csv` uses official NBA releases; the CBA rule files are transcribed from the user-provided final 2023 CBA.
2. **Basketball-Reference current league contracts** — secondary reported source for current player salary schedules, aggregate guarantees, option markers, and any signing/cap-hit fields exposed by the table.
3. **Basketball-Reference current team payrolls** — a second current-contract evidence source. Team pages expose future salary schedules, aggregate guarantees, player/team options, and a marker for amounts that are not fully guaranteed.
4. **Basketball-Reference historical team-season salary tables** — historical player salary evidence. The pipeline discovers the teams that actually played each season rather than hard-coding today's franchises, so historical franchise abbreviations are retained. Default coverage begins with 1984-85.
5. **Basketball-Reference historical transactions** — secondary historical event log, used as the long-history backfill around and before the NBA structured movement feed.
6. **Authorized supplemental sources** — future adapters can add team press releases, licensed data, official Team Salary Summaries, or user-supplied data. They must feed the same evidence model and retain provenance.

No adapter silently overwrites a conflicting value. All source rows are written to `contract_evidence.csv`; a conservative reconciler creates `contracts_long.csv`. Source URLs and selected salary/guarantee/option sources remain visible.

## Canonical concepts

`reported_salary` is a source-reported player-season salary. `reported_cap_hit` is populated only when a source separately reports a cap hit. `reported_contract_guaranteed_total` is an aggregate source-reported guarantee and is not allocated across seasons by inference. `reported_salary_fully_guaranteed` records the source's guarantee presentation when available. `option_type` is one of `player_option`, `team_option`, or `early_termination_option` when source markup supports it.

The CBA model separately represents Compensation, Salary, Team Salary, and Apron Team Salary. CBA-derived figures never replace source-reported values.

## 2026-27 system values

The checked-in official NBA levels are:

- Salary Cap: $164,961,000
- Minimum Team Salary: $148,465,000
- Tax Level: $200,428,000
- First Apron: $209,015,000
- Second Apron: $221,686,000
- Non-Taxpayer MLE: $15,044,000
- Taxpayer MLE: $6,064,000
- Room MLE: $9,366,000

The CBA baseline rookie and minimum salary scales are rolled forward by Salary Cap growth. Because the CBA specifies annual proportional adjustments, the cumulative 2026-27 scale equals the applicable Exhibit B/C baseline amount multiplied by the 2026-27 Salary Cap divided by the 2022-23 Salary Cap ($123.655 million). Derived scale values are labeled CBA-derived rather than official source-reported contract amounts.

## Cap accounting

`backend/app/cap_accounting.py` and `/v2/nba/cap-accounting/*` implement a source-aware 2026-27 accounting layer including:

- likely performance bonuses in player Salary and excluded/unlikely bonuses in Apron Team Salary treatment;
- Bird, Early Bird, Non-Bird, rookie-scale-related Bird, and completed two-way free-agent holds;
- first-round-pick holds at 120% of applicable Rookie Scale Amount;
- July-through-preseason incomplete-roster charges using the zero-YOS minimum;
- waived salary and optional Salary Cap stretch schedules, including the July-August vs September-June timing distinction;
- explicit other Team Salary charges and exception amounts;
- Article VII 2(e)(1) adjustments from Team Salary toward Apron Team Salary; and
- official Team Salary / Apron Team Salary overrides when an authoritative Team Salary Summary is available.

The engine fails closed when a CBA calculation requires a non-public or separately supplied input. For example, a minimum-contract free-agent hold can depend on the portion not reimbursed by the league-wide benefits fund; the engine requires that non-reimbursed amount rather than fabricating it.

`GET /v2/nba/cap-accounting/config?season=2026-27` returns the system levels plus derived rookie/minimum scales. `POST /v2/nba/cap-accounting/evaluate-team` calculates Team Salary, Apron Team Salary, cap room, tax overage, apron room, charge breakdown, authority flags, and warnings.

## 2026-27 trade machine

`backend/app/trade_machine.py` and `/v2/nba/trade-machine/*` implement multi-team player-flow validation and the principal current CBA salary-matching paths:

- **Standard TPE:** one outgoing player; incoming matching salary up to 100% of outgoing plus $250,000.
- **Aggregated Standard TPE:** two or more outgoing players; incoming up to 100% of aggregate outgoing plus $250,000; Transaction Restrictions Table row H applies the Second Apron.
- **Expanded TPE:** the greater of the CBA's 200%/scaled-additive branch and 125% + $250,000 branch; row E applies the First Apron. The $7.5 million component is scaled from 2023-24 with Salary Cap growth.
- **Room + $250,000:** available cap Room can be combined with outgoing salary and the $250,000 allowance where applicable.

The engine also checks:

- a receiving sign-and-trade team's First Apron restriction;
- cash paid in a trade against both the 5.15%-of-cap season limit and the Second Apron restriction;
- cash received against the season-wide 5.15%-of-cap limit;
- player trade eligibility and required consent inputs;
- explicit incoming/outgoing matching-salary overrides for special CBA treatment such as trade bonuses; and
- balanced player flow across all participating teams.

Results expose every attempted matching path, salary limit, apron restriction, CBA reference, resulting hard cap, failures, and qualification warnings. A trade can be mechanically legal yet marked `qualified=true` when its Apron Team Salary inputs are estimates rather than authoritative CBA accounting.

`GET /v2/nba/trade-machine/teams?season=2026-27` loads the current canonical player contract rows. Until complete CBA team-state inputs are available it labels the simple contract-salary sum as an estimate. `POST /v2/nba/trade-machine/evaluate` accepts explicit team states and trade legs for authoritative calculations.

## CBA-backed rule files

`backend/data/cba_2023_contract_rules.json` encodes contract structures, protection, options, maximum-salary tiers, bonus limits, and Exhibits B/C. `backend/data/cba_2023_trade_rules.json` encodes TPE formulas, Transaction Restrictions Table rows used by the engine, apron behavior, trade cash limits, and fail-closed guardrails.

## Run and tests

```bash
pip install -r backend/requirements.txt
python backend/scripts/test_nba_contracts_pipeline.py
python backend/scripts/cap_accounting_contract_test.py
python backend/scripts/trade_machine_contract_test.py
python backend/scripts/nba_contracts_pipeline.py --output-dir raw/nba/contracts
```

The Historical Research Quality GitHub Actions workflow runs all three contract suites. Fetched HTML/JSON is cached, and automated fetching checks each host's `robots.txt` before network retrieval. There is intentionally no bypass flag.

## Outputs

The ingestion pipeline writes:

- `contract_evidence.csv` — every parsed salary/contract evidence row with provenance;
- `contracts_long.csv` — conservative reconciled player/team/season view;
- `transactions.csv` — official + historical transaction events and contract subtypes;
- `cba_validation_issues.csv` — CBA-informed anomaly diagnostics; and
- `manifest.json` — per-source/page success/failure and row counts.

## Remaining enrichment

The highest-value remaining accuracy work is complete team/player ID reconciliation, authoritative current Team Salary Summary inputs, cap-hold and exception ledgers by team, precise minimum-contract reimbursement amounts, trade eligibility/consent dates, trade-kicker details, and draft-pick trade legality (Stepien, frozen-pick and second-apron draft consequences). The backend is designed to accept those facts without changing the trade-evaluation contract.
