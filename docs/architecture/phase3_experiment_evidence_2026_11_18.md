# Arcside Phase 3 — pilot implementation and evidence ledger

**Status (2026-11-18): Implementation staged on separate experimental branch; end-to-end decision gates NOT MET.**
This ledger is deliberately not a GO decision. Review alongside the exact [Phase 3 protocol](phase3_frontend_proof_protocol.md), [Phase 2 scorecard](phase2_frontend_scorecard_2026_11_18.json) and [Phase 1 audit](phase1_arcside_architecture_audit_2026_11_18.md).

## Pinned source and branch dependencies

- POC base: Phase 2 PR #88, branch `evaluation/arcside-frontend-alternatives-phase2-2026-11`, SHA `8152b043dd2fe78badf3c38b254dacafc0baaa4f`.
- Phase 1: PR #87, SHA `493f0290acbeced582703cae3003e0fb0e50b1cf`; underlying Labs PR #86, SHA `3d8b0deb40cfbeb2b86b7fff62bd7112e59c433b`.
- Separate player profiles PR #81: SHA `7f1be850813a3fc3b7a9937bf301e066ca775e49`, not part of POC branch, not merged. Confirm profile parity before full migration.
- Existing reference logic: `lib/services/nba_stats_workstation_engine.dart`, `lib/services/nba_stats_metric_catalog.dart`, `lib/services/trade_machine_engine.dart`, `test/nba_stats_workstation_engine_test.dart`, `test/trade_machine_cba_edge_rules_test.dart`.
- Static data: same-origin `web/data/nba_static/manifest.json`, schema 5, `seasons.json`, season shards and `players/index.json`. Local corpus is not checked into Git. **Manifest fingerprint, actual season counts and baseline screenshots are NOT AVAILABLE in the GitHub connector environment.** No invented baseline or substitute NBA samples were used for product data.
- Unresolved known issue on reference: native IDE browser integration had three failing cases in Phase 1 review. New POC results must not misclassify those pre-existing failures.

## Scope delivered for local evaluation

- Separate React/TypeScript/Vite project under `experimental/arcside-react/` with original source-based NBA adapter.
- Virtualized Stats/Advanced slice, filters, regular/playoffs toggle, 50/4 qualification, rate bases, recorded team stints, null-aware formatting and stable sort. Added actual-v5-corpus inspection command and fixed fallback FTA-vs-FTM ambiguity and published `positions` alias. These fixes remain subject to real release/parity inspection. Exact visual/semantic parity against full Flutter catalog is **not yet proven**.
- One ECharts Canvas chart with source-backed fields, team colors, tooltips, selection/settings persistence, optional linear fit and explicit wheel zoom versus drag-pan controls. Preserves the active zoom on selection, regression and interaction-mode updates, and resets it when source data/axes change or the user explicitly resets.
- Two original browser-native Labs embedded through same-origin iframes, standalone routes, light/dark shell and typed season context handshake. No Lab engine rewriting.
- Selected `NbaStatsWorkstationEngine` outputs checked against synthetic fixtures from the actual Dart tests. The historical null-vs-zero discrepancy was diagnosed and the Dart reference normalizer was updated on the **experimental branch only** to preserve missing counts, while keeping actual recorded zeroes. Percentile ties now use midranks in Dart and React. These intentional improvements change the reference engine's previous historical behavior and must be independently validated with the owner's complete local corpus before any production merge.
- Original-Dart CBA scenario JSON exporter, suitable for approved goldens. Full CBA golden comparison against a new-stack rules engine is **not performed** because no new-stack trade engine was ported for this minimal visual pilot.
- Automated React-only UI tests using explicitly synthetic request-intercepted fixtures; they are not NBA-source parity tests.

## Mandatory protocol gates and truthful status

| Gate | Status | Evidence / outstanding action |
| --- | --- | --- |
| React implementation and isolated branch | **CI passed** | Pinned `npm ci`, TypeScript build, unit suite, three-browser synthetic regression suite. Flutter `main` unchanged |
| Original v5 manifest & source-backed shards | **Owner-probed, remote comparison pending** | `node experimental/arcside-react/scripts/inspect_corpus.mjs --out experimental/arcside-react/evidence/local-corpus-audit.json` checks exact available real assets and writes machine-readable evidence; requires owner's untracked release |
| Reference Flutter renderers, screenshot exports | Not run | Capture real Chromium, WebKit/Safari and Firefox on owner's Mac/OS |
| Identical Stats/Advanced metrics & 50/4 | **Strict synthetic Dart ↔ React parity passed; actual release not compared yet** | Need every displayed advanced field, null/error, 2P/rim/mid tiers, playoff split, 2TM/3TM, source provenance and exact golden review |
| 1k/10k/50k table and 300/5k/25k chart | Automated synthetic smoke submitted; matched comparison NOT measured | CI executes 1 fresh-context and 2 reused-context samples per size as a smoke, and uploads raw JSON/CSV when successful. Owner must run protocol's 5 cold / 10 warm repeats on same hardware for both implementations |
| Deep links and browser navigation | **Synthetic Chromium/Firefox/WebKit pass** | Run Playwright with real browser |
| Zoom vs pan and persisted chart state | **Synthetic browser QA pass; actual operator QA pending** | Verify tooltip, hit-testing and exact saved settings |
| Python/Sheets functionality and bridge | **Synthetic frame/bridge journeys pass; native services and data integrity unverified** | Test Monaco focus, Cmd/Ctrl+K ownership, import/export, IndexedDB, role/credential isolation, narrow layout |
| Trade salary/rules exactness | Exporter present; no cross-stack parity | Run original Dart exporter; independently generate candidate and human-review severity/messages/figures |
| Accessibility WCAG 2.2 AA | Not certified | Audit axe + keyboard + real Safari/VoiceOver + NVDA/Chrome, semantic grids and chart equivalents |
| Cross-browser, screenshots, persistence | **12/12 Playwright tests passed on Linux browser engines; not certified** | CI exercises browser engines with synthetic fixtures. WebKit-on-Linux is NOT native macOS Safari; manual Safari/VoiceOver and Firefox/Gecko real-data paths remain required |
| Decision and migration authorization | **NOT APPROVED** | Owner signs GO React / GO Flutter-hybrid / GO keep Flutter / NO GO after all gates |

## Engineering trade-offs already visible

The existing v5 JSON compiler, Python historical warehouse, original standalone Labs and local-only Python/Sheets services remain reusable. The Dart stats engine had to be translated for a narrow slice; porting complete metric/taxonomy rules and the current custom drawing system is substantially more work. A browser-first UI does make deep-linking, native DOM controls and using the existing iframe Labs straightforward, but that observation alone does not prove UX or performance gains.

The sample fixture assertions validate a limited set of well-defined calculations, **not** a statistically representative NBA corpus. The POC's chart uses only available source-backed metrics and never fabricates tracking stats. Plot colors represent team tokens, not a verified historical franchise color mapping.

## Decision

**PENDING (no go/no-go claim).** Retain Flutter as reference and Flutter-plus-web Labs as fallback. Do not merge this stacked experiment into `main` or deprecate Flutter until parity, task, browser, accessibility and matched benchmarks satisfy the pre-registered mandatory gates and owner signs off.

## Dependency-security hardening (November 18, 2026)

Upgraded the isolated experiment's direct npm dependencies to `echarts@6.1.0`, `vite@7.3.8`, and `vitest@4.1.12`. In CI the lockfile must be generated from the exact declared versions, reviewed, committed, then installs must switch to `npm ci`. The npm audit gate fails on any *moderate or higher* advisory, including transitive packages. ECharts v6 compatibility must pass the existing interactive chart browser tests. **Do not report zero advisories until the actual CI audit passes.** This change does not modify the Flutter application or Labs runtimes.

### Screenshot-based UX observations (not Phase 3 acceptance evidence)

Owner-provided browser screenshots demonstrate five reachable pages: Stats, Advanced Stats, one ECharts scatter explorer, and embedded original Python Lab and Excel Workspace. The visuals show coherent shell styling, but the Stats/Advanced metric surfaces remain narrower than Flutter's full platform, the Visualization Studio is an intentionally reduced exploratory scatter page, and the Labs retain distinct toolbars/interactions inside iframes. Preserve these as explicit feature-parity and design-integration gaps; screenshot review does not establish quantitative usability or rendering performance.


## Executed Phase 3 engineering evidence (2026-11-18, GitHub experiment)

**Reproducible dependency install:** The exact audited `experimental/arcside-react/package-lock.json` from a passing GitHub Actions run was committed (SHA-256 content available in Git history) and the React CI installer changed to `npm ci`. npm 11 install and `npm audit --audit-level=moderate` previously returned **zero advisories**. The single-use write-permitted GitHub workflow used to import the lockfile was removed immediately afterward.

**Original Dart versus React goldens:** The CI parity workflow runs the **original** `lib/services/nba_stats_workstation_engine.dart` via `flutter test`, exports it as JSON, and independently compares against TypeScript. On the explicit 3-player **synthetic** fixture (including a two-team traded player), across 6 rate bases, it compared **2,526 scalar, format, percentile, identity and stint assertions** with **zero mismatches** after correcting React's age formatting (the Dart reference displays `25.0`, not `25`). This does NOT imply historical NBA corpus or the whole Flutter stats catalog is parity-tested. Exact source-backed null/missing behavior remains under review; Dart currently defaults missing counting totals to zero while React represents them as null.

**Owner's genuine local corpus inspection:** The owner ran the read-only v5 inspector locally and reported manifest SHA-256 `b284d14cc6e39bb3dff89d7ffeef0cb8a714110d307fc73a8943867e8b39f33e`, **80** seasons, and six shard samples without structural issues. The release covered 2025–26 regular **582** and playoffs **230** players; 1986–87 regular **340** and playoffs **184**; 1946–47 regular **161** and playoffs **0**. These are **owner terminal outputs**, not an independent full-corpus comparison executed by GitHub. Missing fields in older data and 2025–26 playoffs remain real-source coverage constraints.

**React-only CI synthetic UI measurements:** The original successful 1-cold/2-warm smoke reported these *warm medians* on Linux Chromium 141 / AMD EPYC 9V74:

| Synthetic workload | Median first-visible (ms) | Median interaction (ms) | Comparison to Flutter |
| --- | ---: | ---: | --- |
| 1,000-row table | 321 | 410 | Not measured |
| 10,000-row table | 644 | 407 | Not measured |
| 50,000-row table | 2,738 | 447 | Not measured |
| 300-point chart | 324 | 203 | Not measured |
| 5,000-point chart | 537 | 248 | Not measured |
| 25,000-point chart | 1,330 | 351 | Not measured |

**These figures must not be used for the 10% acceptance rule.** Two warm measurements do not establish reliable p95, rendering throughput across platforms, or a matched Flutter baseline. The benchmark includes scripted waits in interaction timings.

**New runnable real-data gates:** `npm run test:real` checks byte-for-byte canonical manifest identity on Flutter/React local servers before probing React's historical Stats/Advanced/chart flows and embedded Lab handshakes. `ARCSIDE_GUIDED_COLD_RUNS=5 ARCSIDE_GUIDED_WARM_RUNS=10 npm run compare:guided` collects alternating, operator-verified matched critical-task timings, including actual failures, without assuming Flutter widget UI is DOM-addressable. `flutter test test/phase3_stats_parity_export_test.dart --dart-define=ARCSIDE_PARITY_CORPUS=web/data/nba_static`, followed by `ARCSIDE_PARITY_REPORT_ONLY=1 npm run test:parity`, generates every observed real historical-stat mismatch. **These local real-data tests have been implemented but not executed from the remote GitHub environment.**

**Decision after expanded checks:** The codebase and tests are substantially more ready for a genuine architecture decision; the evidence still does **not** satisfy the mandatory full-data golden checks, matched UI p95 threshold, native Safari/accessibility, full Labs roundtrip, or the full application feature-scope gates. Decision remains **PENDING**, no Flutter retirement or migration merge.

## November 18–19: real-corpus discrepancy remediation in draft PR #89

Owner-supplied local run on the pre-remediation SHA reported **1,069,254 comparisons, 253,909 mismatches across 36 season/segment/rate-basis cases**, zero missing player IDs. Frequent disagreements: tied percentile ranks (age, games, attempts), missing plus/minus, sparse box-score counts, derivations and traded stints. The output's first 150 examples all came from the initial 2025–26 regular per-game case; it was NOT a representative multi-season sample.

**Confirmed causes and changes in the isolated experiment:**

- Original Dart percentile computation gave successive positions to tied values, with Dart vs JavaScript sorting ties differently. Dart and TypeScript now both assign **midrank** percentiles for identical source values. This is a documented change to legacy Flutter reference behavior, not a cosmetic comparator adjustment.
- Original Dart `_total` silently converted missing historical box-score counts to zero, cascading into calculated shooting metrics, possession estimates, combined defensive/production indexes and rank denominators. The experimental Dart normalizer now uses **nullable source counts** and computes secondary statistics only where their required inputs exist, consistent with existing React source-backed behavior. Published zeroes remain zero; published percentages remain sourced. The static historical JSON is unchanged.
- The parity fixture now includes two-team recorded stints, sparse historical percentages, legitimate zeros and per-game-only records, across all six rate bases. The dedicated original-Dart ↔ React CI action **passed 4,302 comparisons with 0 mismatches** plus original Flutter regression tests. This is still an intentionally SYNTHETIC input; it is not the owner's original multi-season proof.
- The upgraded evidence report now records `byCase` with complete comparison and mismatch counts per season/segment/basis, `byCategory`, `byDifference` (including null-vs-value), and bounded representative examples for **every case and metric**. The first-150 examples are retained for backwards compatibility. No mismatches are automatically suppressed in strict mode.
- The real-browser and guided matched-task scripts now support `ARCSIDE_BROWSER_CHANNEL=chrome`, allowing the owner's installed Google Chrome to be used when Playwright's bundled Chromium download is incomplete. That browser version must be recorded; this is not identical to the pinned CI Chromium or native Safari.

**Pending factual test:** Owner must re-export the original updated Dart reference from local canonical shards and rerun the React comparison **without reusing the old JSON reference**. Do not report improvement percentages or a parity pass before inspecting that new actual-corpus report. If differences persist, classify by case and source completeness, fix exact semantic causes, and rerun. Source mismatch is a blocker for architecture authorization. PR #89 stays draft and Flutter production/`main` unchanged.
