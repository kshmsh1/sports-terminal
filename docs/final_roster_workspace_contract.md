# Final Roster Workspace Contract

The manual roster seed now represents the final NBA rosters at the end of the 2025-2026 season.

## Asset identity

The manual seed writes player identity and roster rows with:

```text
seasonId: 2025-26
snapshotLabel: 2025-26 final roster snapshot
sourceId: manual-roster-screenshots-2026-06-06
asOf: 2026-06-06
rosterStatus: Final roster
```

## Roster screen behavior

The Rosters screen is no longer just a generic source-pending registry table. It now acts as a usable final-roster workspace:

- player names open incomplete player profile pages;
- team names open incomplete team profile pages;
- team filtering is supported;
- player, team, jersey, position, age, height, weight, From, and salary sorting is supported;
- height is displayed in feet/inches and meters;
- weight is displayed in pounds and kilograms;
- From uses the school, college, club, country, or source-provided origin field available in the manual screenshots;
- the coverage tool fails unless all 30 canonical NBA teams are present, unless `ALLOW_PARTIAL_ROSTER_SEED=1` is set.

## Validation gates

The manual roster runner now performs three separate checks before the app should be treated as clean:

```bash
dart run tools/audit_manual_roster_sources.dart
dart run tools/summarize_manual_roster_seed.dart
dart run tools/validate_rosters.dart
```

The audit checks raw source files before generated assets are written. The summary confirms imported team coverage after generation. The roster validator enforces joins, source metadata, season identity, final-roster status, snapshot label, plausible age, parseable height, plausible weight, and 30-team coverage whenever roster rows are populated.

## Current limitation

Position values reflect the source screenshots. Later, a position normalization layer should split simple values like `G` / `F` into richer basketball roles such as `PG`, `SG`, `SF`, `PF`, and `C` only when a reliable source supports that split.
