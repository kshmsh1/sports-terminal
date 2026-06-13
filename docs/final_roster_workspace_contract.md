# Final Roster Workspace Contract

The manual roster seed represents the final NBA rosters at the end of the 2025-2026 season.

## Authoritative source

The committed authoritative manual source set is:

```text
docs/manual_roster_sources/
```

The older `assets/data/nba/manual_sources/rosters/` directory is retained only as legacy staging material and is no longer scanned by the audit or importer. This prevents mirrored files from being counted as duplicate source rows while preserving the original staging history.

Generated player and roster JSON assets remain reproducible outputs of the committed PSV source set rather than a second hand-maintained source of truth.

## Asset identity

The manual seed writes player identity and roster rows with:

```text
seasonId: 2025-26
snapshotLabel: 2025-26 final roster snapshot
sourceId: manual-roster-screenshots-2026-06-06
asOf: 2026-06-06
rosterStatus: Final roster
```

## Core product surfaces

The same joined player-team-season objects now drive three core surfaces.

### Players

The Players page is a source-backed league directory. It supports team, position, and completeness filters plus sorting by player, team, jersey number, position, age, height, weight, From, and salary. Player names open shared player profile pages. Team names open shared team profile pages.

### Teams

The Teams page now exposes roster count, average age, average height, average weight, known payroll, identity completion, and stat-row coverage. Team names open shared team profile pages with their final roster and future team-stat attachment points.

### Rosters

The Rosters tab now opens a dedicated final-roster control center rather than the older generic context-asset preview. It includes:

- all 537 connected final-roster rows;
- all 30 canonical NBA teams;
- linked player and team profile routes;
- height in feet/inches and meters;
- weight in pounds and kilograms;
- sortable player, team, jersey, position, age, height, weight, From, and salary columns;
- a metadata completion queue;
- team-by-team identity and salary completion;
- known payroll totals that exclude missing salaries instead of estimating them.

## Profile routes

Player and team profile routes are shared application screens rather than one-off roster-table stubs.

Player profiles show identity, final roster context, physicals, From, jersey, position, salary, source metadata, roster history, future season-stat rows, and attachment readiness for awards, draft, and transactions.

Team profiles show team identity, final roster players, known payroll, roster completeness, sortable physical and salary columns, clickable player names, and future attachments for team stats, standings, games, awards, draft, and transactions.

## Validation and reporting gates

The manual roster runner now performs raw-source auditing, compilation preflight, transactional asset generation, validation, completeness reporting, and the post-import candidate gate:

```bash
dart run tools/audit_manual_roster_sources.dart
flutter test test/roster_measurement_formatter_test.dart \
  test/roster_directory_service_test.dart \
  test/roster_completeness_service_test.dart \
  test/roster_entry_validator_test.dart
dart run tools/apply_manual_roster_seed.dart
dart run tools/summarize_manual_roster_seed.dart
dart run tools/validate_rosters.dart
dart run tools/write_roster_completeness_report.dart
```

The full product-surface release gate is:

```bash
bash tools/check_roster_product_release.sh
```

The completeness report is written to:

```text
raw/roster_completeness_report.json
```

Missing From, jersey, or salary values are visible completion tasks, not hidden failures. Broken player/team joins, invalid physical measurements, invalid snapshot identity, and incomplete 30-team coverage remain blocking failures.

## Current limitations

Position values still reflect the source screenshots. A later position-normalization layer should split simple values such as `G` and `F` into richer basketball roles such as `PG`, `SG`, `SF`, `PF`, and `C` only when a reliable source supports that split.

Missing From values should later be completed using verified college, prior club, development program, or country information. They should not be guessed merely to make the completion rate reach 100 percent.
