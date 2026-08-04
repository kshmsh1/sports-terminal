# Role Research Command Center

This phase makes the professional NBA research product visible and operational in both launch roles instead of leaving the Stats Workstation and Analytics Suite buried as ordinary sidebar destinations.

## Role integration

Analyst and organization-admin sessions now enter through `RoleResearchAugmentedShell`. The existing role terminal remains intact, while an always-visible NBA Research launcher and a direct-module menu provide access to the full research product from every destination.

The role home screen also promotes NBA Research above the broader launch and arena surfaces. It includes direct actions for:

- Research Home
- Stats Workstation
- Analytics Suite
- Research Workspaces

Platform administrators continue to use the internal `TerminalShell` and are not redirected into the customer role product.

## Research Command Center

The command center unifies five professional surfaces:

1. Research Home
2. Stats Workstation
3. Analytics Suite
4. Research Workspaces
5. Coverage & Methods

Keyboard shortcuts `1` through `5` switch among these surfaces.

### Research Home

The home page reports actual loaded counts for players, player summaries, games, player game logs, teams and normalized play-by-play events. It exposes whether the application is using the certified candidate release or the validated development fallback.

It also promotes the complete Stats and Analytics capabilities, shows active saved workspaces and reiterates the professional source boundary.

### Stats Workstation

The existing PR #16 workstation is available without leaving the analyst or organization experience. It retains table views, basis conversion, search, filters, custom views, favorites, comparisons, percentiles, chart studio, glossary, density controls, pagination and TSV export.

### Analytics Suite

The complete data-backed analytics suite is available from the same role-level command center. It includes player and team dashboards, comparisons, rankings, recent form, shot profile, lineup construction, tiering, the modeled offensive-rating sandbox and data coverage.

### Research Workspaces

Research boards persist separately for each analyst user or organization ID. Starter boards include a player-evaluation board and a data-coverage audit.

Available templates cover:

- player evaluation;
- team scouting;
- opponent preparation;
- transaction review;
- rotation planning;
- data audit.

Users can create, duplicate, open, annotate, move to review, reactivate, archive, restore and delete boards. Each board preserves its workflow type, metric set, scope, notes and status.

Organization-scoped boards are currently persisted on the device under an organization-specific namespace. The product explicitly states that true shared collaboration remains unavailable until a research backend endpoint is deployed.

### Coverage & Methods

The coverage console reports:

- supported season;
- dataset status;
- validation status;
- active asset path;
- warehouse generation timestamp;
- resolved asset count;
- normalized play-by-play count;
- fallback state.

It also separates capabilities into ready, partial, modeled and source-gated states. The product does not fabricate lineup stints, matchup assignments, RAPM, shot quality or draft outputs.

## Persistence model

`NbaResearchWorkspaceStore` stores JSON through `ProductLocalStore` under one of two keys:

- `sports_terminal.nba.research_workspaces.v1.analyst.<userId>`
- `sports_terminal.nba.research_workspaces.v1.organization.<organizationId>`

The model includes explicit serialization, status, workflow kind, player and team selections, metric keys, tags, notes, owner, organization scope and timestamps.

## Validation coverage

The dedicated workspace tests verify:

- complete JSON round trips;
- separation of analyst and organization keys;
- organization template scoping;
- seeded evaluation and coverage workspaces.
