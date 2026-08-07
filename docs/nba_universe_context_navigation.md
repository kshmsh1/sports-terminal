# NBA Universe and Shared Research Context

## Objective

Historical NBA data should not behave like a separate archive. Analysts should be able to discover an entity anywhere in canonical NBA/ABA/BAA history, choose the exact season they want to study, and carry that selection into the same Stats Workstation and Analytics Suite used for the current release.

`NBA Universe` is the cross-era navigation layer for that workflow.

## Product surface

The analyst and organization shells expose a persistent `NBA Universe` launcher alongside NBA Research. The surface searches canonical historical players and teams, opens a source-aware entity dossier, and exposes season-by-season history.

Player dossiers include canonical identity, active years, source count, identity confidence, NBA/Basketball Reference identifiers, career season rows and an era-relative scoring signal. Team dossiers include canonical team identity, franchise linkage, historical abbreviations/league, source count and canonical team-season rows.

No data is fabricated for eras where a field did not exist. The dossier intentionally reports the canonical fields and source confidence that actually exist.

## Shared context contract

`NbaResearchContextStore` sits above the existing `NbaTerminalSeedRepository` data-scope keys. A research context contains:

- current vs historical scope
- season
- league
- season segment
- selected player, team or game identity
- human-readable player/team label
- last activation timestamp for recent-context history

Activating a historical season writes through `NbaTerminalSeedRepository.selectHistorical`. Therefore existing seed-backed modules inherit the selected historical season without requiring a second analytics contract.

Entity selections reuse the existing `ProductLocalStore.nbaSelectedPlayerKey`, `nbaSelectedTeamKey` and `nbaSelectedGameKey` keys. Human-readable entity labels are stored alongside them.

## Direct handoff

Every season row in NBA Universe exposes three actions:

1. Set active context.
2. Set active context and open Stats.
3. Set active context and open Analytics.

The role shell closes NBA Universe and opens the requested research module only after the shared context has been persisted. This makes cross-era navigation deterministic: the destination loads against the season/entity context selected in Universe.

Switching back to `Certified Current Release` calls the same current-scope contract used elsewhere in the product.

## Recent contexts

The store keeps a bounded, deduplicated local history of recently activated research contexts. This is not a second warehouse or a browser history replacement; it is a fast research-navigation affordance. Restoring a recent context rewrites the same shared NBA scope and entity keys used by the rest of the terminal.

## Data boundaries

NBA Universe uses canonical historical APIs for entity discovery and history. Historical context is always labeled as historical/canonical; it is not relabeled as a certified current release.

The current-release seed remains a distinct validated release path. Historical parity means shared product infrastructure and analytics contracts, not pretending every modern field exists in every historical season.

## Validation

The build adds tests for:

- historical context -> shared seed-scope synchronization
- entity selection persistence
- recent-context deduplication and restoration
- desktop NBA Universe mounting
- narrow-width NBA Universe mounting without render overflow

The repository-wide Flutter Quality workflow continues to gate analyzer, the full test suite and release web build.
