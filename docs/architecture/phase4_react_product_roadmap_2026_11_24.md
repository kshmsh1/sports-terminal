# Arcside Phase 3 closeout and Phase 4 implementation roadmap — 2026-11-24

## Architecture decision

**GO — staged React-first development migration.** The owner explicitly accepted migrating to React and fixing remaining gaps afterward. PR #94 merged the reversible React-first local development baseline at main commit `955448a0ec76c54b58e7872389b2a4079bf81d69` after all eight integration workflows passed. Original Flutter remains available as an executable reference and rollback option. The original decision protocol is retained as a historical record; this is not an all-gates-PASS declaration, public deployment, or authorization to retire Flutter.

The architecture-selection experiment can be closed on this staged GO, while its unmet verification obligations transfer to Phase 4. The full-migration decision ledger remains unchanged and may continue to report NOT AUTHORIZED. Do not backfill, waive, overwrite or recategorize failed results.

## Evidence baseline

| Area | Observed result | Boundary |
|---|---|---|
| Advanced Stats | 1,119,992 actual local v5 comparisons, 0 mismatches | Tested sample; not every original feature |
| Visualization | 38,086 actual local v5 comparisons, 0 mismatches | Tested source semantics |
| Advanced matched performance | warm p95 ratio 0.9295, PASS | Owner Mac registered study |
| Visualization matched performance | warm p95 ratio 2.7789, FAIL | React warm trial 12 = 879.91 ms; preserve |
| Trade rules | 27 original Dart/TypeScript golden cases | Limited deterministic rule coverage, not full CBA correctness |
| Integration CI | 8/8 successful at the #94 tested integration revision | CI tests, not device certification |
| Local owner visual review | Stats recorded PASS, Advanced interrupted | Six later screenshots show prototype pages, not complete workflow evidence |
| Browser / native / rendering | Automated coverage exists; physical native and GPU/process-memory requirements outstanding | Do not label full WCAG, security or GPU pass |

The owner's six Nov 24 screenshots showed Trade Machine, Player Compare, Team Compare, Box Scores, Financials and With/Without. Observed problems: technical example trade appears by default, comparison selectors are basic, box-score entries concatenate date/score/status, financial currency and lineup metric cells truncate, independent pages show irrelevant common season controls, and the sidebar still describes an isolated experiment. The screenshots alone do not prove end-to-end functionality.

## Closeout fixes

- React-first beta wording replaces stale Phase 3 experiment wording; incomplete transaction validation remains clearly labeled. Hide irrelevant common season/rate controls on dated finance and trade and the independent historical box-score archive.
- Financial, comparison, lineup and modeled trade tables use workspace-specific intrinsic widths, full visible cell values, local horizontal overflow, and content-height containers. Financials restores the original league thresholds from Dart, standard plus two-way roster count, hard-cap status, inspector cap allocation, and closing/filtering details. Stats/Advanced virtual row semantics are unchanged.
- Trade Machine opens a clean scenario with source team suggestions, dated cap import, explicitly optional illustrative example, no default fake transaction, and duplicate source-selection/stale team-selection safeguards.
- Player/Team Compare adds searchable source-backed candidate lists; restores saved segment/rate settings; team comparisons do not advertise an unsupported global player rate basis. Field-level completeness prevents partial game-log sums from becoming season totals.
- Box Scores separates date, matchup and publication state; pages through the whole index; explicitly shows indexed date range. No inferred later-season game data.
- With/Without clears stale season/segment data and shows readable labels. The original Flutter screen also requires genuine lineup data. The current screenshot's missing pair-split source is a data availability issue, not proof of a React-only regression.

Run the following optional one-time **read-only** coverage inventory against the original local v5 dataset; it does not start browsers, rebuild the warehouse, or require repeated timed trials:

```bash
cd ~/sports_terminal
node experimental/arcside-react/scripts/phase4_source_coverage.mjs
```

The output is ignored local evidence under `experimental/arcside-react/evidence/coverage/`. It records actual indexed historical game date range by season/segment and lineup-file coverage; a file reference alone is not proof of complete per-game data.

## Phase 4 — React product implementation and parity

Work in incremental PRs from main. Original Flutter and local source data remain the comparison reference, not a second product to independently extend. Prioritize:

1. **P0 correctness and source contracts:** finish Trade Machine and full source-backed 2023 CBA rule/UI coverage (#90). Replace generic transaction editor with actual team/roster/asset workspaces, ensure date-specific cap and draft restrictions, and test rule boundaries. No unsupported legality claims.
2. **P1 complete core user experience:** NBA Home/global search, player and team profile fidelity, canonical routes and cross-navigation (#91). Complete original comparison control scope and accurate advanced stats; compare original fields, not screenshots alone.
3. **P1 data coverage:** compare box-score index and player details with original warehouse, identify true absent seasons; build lineup splits only from genuine lineup stint/play-by-play data; full financial and contract ledger views with provenance. Preserve missingness and source dates.
4. **P1 performance:** diagnose retained Visualization warm-tail failure (#92), profile operations and fix measured bottlenecks; rerun matched tasks with unchanged registered criteria only where needed.
5. **P2 complete product UX and verification:** consistent layouts, responsive and accessible interactions, saved-state and data portability, native Safari/VoiceOver and Windows/NVDA, Labs isolation/security, real compositor and total-memory checks (#93). Full production signoff requires independently verified gates.

Each workstream closes only with an implementation, regression tests, actual corpus/device evidence where applicable, and a recorded acceptance result. For local beta work, the previously required 15-module interactive comparison is optional and resumable; not a prerequisite for starting Phase 4. For full migration certification the requirements remain mandatory.

## Rollback and day-to-day development

```bash
bash scripts/launch_arcside.sh --platform --fast
```

Original Flutter fallback: `bash scripts/open_terminal.sh --flutter`. No database deletion, source rebuild, new data ingestion, public deployment, or retirement of Flutter is authorized by this document.

## Phase 4 implementation checkpoint — PR #97

The React product branch now includes the source-backed Trade Machine, NBA Home, global search, canonical profile statistics and legacy Flutter saved-trade import, route-scoped fetching, chart resize and zoom optimization, and local Labs trust-boundary improvements. The cross-engine dated-source trade suite ran 1,112 cases with zero semantic mismatches on commit 480466d7; the 27 original synthetic goldens remain separate. This proves base-engine agreement for the tested cases, not complete CBA coverage, correctness of the original engine, or UI-level legality certification.

Local acceptance still requires original warehouse and native-device evidence. Run from the repository root:

```bash
python3 tools/phase4_warehouse_audit.py --verify-details
node experimental/arcside-react/scripts/phase4_source_coverage.mjs
```

The first command opens SQLite read-only, compares canonical game identities and existing captured NBA.com game IDs to the published index, and verifies referenced game detail payloads. It honors SPORTS_TERMINAL_NBA_HISTORY_DB or accepts --database. No source ingestion or fabrication takes place. The second inventories published coverage. Preserve the reports in evidence/coverage (gitignored). For chart acceptance, run `bash scripts/phase3_release_compare.sh --diagnose-chart` after rebuilding, and retain the prior failed p95 comparison until a matched rerun passes unchanged thresholds.

Native companion and collaborative workspaces are loopback-only, credential-gated, trusted-project tools, not an OS sandbox. Service credentials are isolated from one another and from normal child process environments. Native execution remains as the user's account; external dependencies and imported content still require trust. Native Safari/VoiceOver, Windows/NVDA, GPU/compositor and total-memory acceptance remain open. Do not retire the Flutter fallback or mark full production migration certified on the strength of CI alone.
