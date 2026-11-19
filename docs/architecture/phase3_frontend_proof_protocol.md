# Arcside Phase 3 — pre-registered frontend proof-of-concept and decision protocol

**Status:** Evaluation protocol only; **not executed** and **no framework switch approved**.  
**Source:** [Phase 2 alternatives and provisional ADR](phase2_frontend_alternatives_2026_11_18.md) and [Phase 1 audit](phase1_arcside_architecture_audit_2026_11_18.md).  
**Candidate:** React + TypeScript + Vite SPA. **Reference/control:** existing Flutter customer web shell. **Fallback/control architecture:** Flutter + browser-native workspaces.

## 0. Before making any code changes

- Use a new experiment-only branch that does not replace or mutate existing `main`, #81, #82/#84/#85/#86, or Phase 1/2 documentation. Do not make `main` deploy a half-built frontend.
- Resolve the competing PR snapshot issue at the *contract* level first: pin exact sources for Dart stats and profile parity (PR #81), Labs (#86), domain test fixtures and static-data manifest. Document any paths excluded from pilot.
- Confirm valid local `data/warehouse/nba_history.sqlite`, generated `web/data/nba_static/manifest.json` with expected schema/fingerprint and required regular/playoff shards. All large user-supplied local historical data stay out of Git. Do not scrape at runtime or fabricate files when absent.
- Capture the existing Flutter product's launch instructions, actual browser/renderer version, feature flags and baseline screenshots/saved workflow exports. Capture the known red native-IDE Playwright test suite as a **pre-existing issue**, not a new migration regression.
- Get explicit approval before choosing license-restricted grids or changing cloud auth/security. Keep Python and collaboration services bound to loopback with separate tokens.

## 1. Minimum implementation scope (strict)

**1A — Stats/Advanced Stats slice**  
A new web-shell route and typed static-data adapter reading *existing* published NBA JSON; sortable virtualized columns, sticky controls, filters, play-off toggle, per-game/per-36/per-100/totals, expandable multi-team stints, percent formatting and player detail link. Do not recreate the whole Stats product, just enough interactions to meaningfully compare against Flutter.

**1B — Visualization Studio slice**  
One representative interactive scatter/bubble chart that uses actual normalized player season fields and has axis dropdowns, rate basis, team-based colors, hover readout, reset zoom, pan vs wheel zoom, optional regression/mean reference and visible selection persistence. Use **one** candidate rendering library initially (Apache ECharts *or* custom D3/SVG/Canvas), not both owning one canvas. Compare same points and selected labels with Flutter custom painter.

**1C — Labs embedding slice**  
Render the **existing** `web/labs/python/index.html` and `web/labs/sheets/index.html` on standalone and embedded paths, not rewritten copies. Preserve Monaco/Pyodide/IndexedDB, integrate keyboard shortcut ownership and theme, plus send one innocuous typed context message such as `season=2025-26` from shell to Lab. The Lab must ignore unknown message schemas and reject unexpected origins. **Do not send access tokens or Python code across that bridge.** Existing Labs are independent; no full NBA dataset linkage is implied.

**1D — Domain correctness slice**  
Port **only** the domain operations required for the two visual pilots, using precise baseline fixture contracts for `NbaStatsWorkstationEngine`. Separately demonstrate that representative `TradeMachineEngine` scenarios can be compared as JSON golden fixture input/output (no full trade UI port); prove severity, total salary, trade exceptions and rejection explanations match before recommending the full move.

## 2. Data fixture requirements

- Representative historic regular season and playoffs from same canonical static release, one early sparse-coverage season and one modern season with advanced tracking fields *where present*. Record manifest version, SHA/fingerprint and row counts.
- At least one player who changed teams (split-team stints, aggregate 2TM or 3TM if supported by fixture), a team with missing fields, a traded player's player dossier and games where detailed box scores are unavailable. Keep true null/missing values distinct from source-backed zero.
- Current season sample for 50-game regular/4-game playoff qualification user specification where applicable, with exact existing Flutter behavior verified and deviations filed as existing bugs rather than silently normalized.
- Synthetic benchmark workloads seeded deterministically with **1,000, 10,000 and 50,000 table rows** and **300, 5,000 and 25,000 chart points**, alongside real historic data. Synthetic datasets measure UI throughput only, **never** statistical accuracy or claimed historical player coverage.
- Exact golden outputs for offensive/defensive advanced metrics, 2P/rim/mid percentage format tiers where present, percentiles, rate basis transitions, player rank/sort tie breaks, null/error propagation, and 2026-27 trade restrictions/multi-team salary and draft picks. Preserve formula fields and season-specific source provenance. Golden snapshots generated from known-good original logic, reviewed by a human for edge-cases.

## 3. Pre-registered user tasks

| Task | Reference expectation | Both variants tested |
| --- | --- | --- |
| Open Stats via direct URL, refresh, back/forward | Same route/view restored without a dead URL | Yes |
| Change regular to playoffs and back | Right data, correct qualification, no stuck dropdown | Yes |
| Switch totals/per-36/per-100 and sort metric | Correct rate basis and stable sort | Yes |
| Expand 2TM/3TM player row then open player | Correct teams, IDs and dossier; no data loss | Yes |
| Scroll 10k-row table to last third, reverse sort | Sticky headers, predictable focus and performance | Yes |
| Navigate Stats to Advanced with copied context | Matching metric semantics and filters | Yes |
| Visualize 300 then 5k points, zoom, pan and reset | Distinct operations, accurate hit testing and hover | Yes |
| Switch axis metric and rate basis while zoomed | No stale tooltip/axis values; reset behavior defined | Yes |
| Save/apply visualization and refresh page | Exact persisted dataset, series, axes and settings | Yes |
| Use entire product solely with keyboard for core routes | Visible focus; no trapped navigation | Yes |
| Interact with Python and Sheets embedded/standalone | No Ctrl/Cmd+K leakage; clipboard and edit preserved | Yes |
| Import/export workbook in fresh browser profile | No unexpected workbook modification; file contents roundtrip within documented limits | Yes |
| Attempt invalid CBA trade and valid trade | Same report/error severity and source values | Contract tests |
| Load unsupported historical field | Explicit unavailable/unknown, not fake zero | Yes |

## 4. How to measure (do not backfill fake baselines)

**Test hardware:** record CPU, RAM, OS, GPU/driver, display pixel ratio, browser build, power mode. If Flutter Wasm and JavaScript builds are both available, test both and name the renderer. Include normal and incognito profiles. Use controlled cache state and disable unrelated extensions; account for DevTools overhead.

**Browsers:** current Chrome/Chromium, Safari/WebKit and Firefox/Gecko. Chromium Playwright alone is **not** a cross-browser claim. Safari on macOS needs a real browser test for clipboard, WebAssembly, fonts and Monaco focus behavior. Use WebKit automation as additional signal, not as replacement for Safari.

**Test variants:** Flutter baseline; Flutter+browser hybrid if representative; React+Vite pilot. Use the **same static data manifest and metrics**; do not benchmark one with synthetic and another with real data. Use same port/origin assumptions for user-storage parity only in an isolated copy—do not overwrite a real workbook/profile.

**Measurements:** record cold route-to-visible-data time, warm route switch, action-to-updated-table time, p50/p95 keyboard and filter feedback time, actual dropped frames and frame-time distribution over 20 repeat pans/zooms and scrolls, peak JS heap and GPU/renderer memory where available, compressed/uncompressed transferred bytes, total requests, browser console errors, tab/window focus behavior. Use performance marks and reproducible browser scripts and save original traces/screenshots in CI.

**Sampling:** at least 10 warm runs per app/task per browser on same hardware, 5 cold runs with cache reset; alternate variants to avoid heat/system load ordering effects. For timing claims, show median, p95 and absolute differences with samples/variability; for visual confidence compare screenshots and manual task observations.

**Accessibility:** WCAG 2.2 AA target for pilot flows; audit via axe where supported plus manual VoiceOver/Safari and NVDA/Chrome keyboard screen-reader journeys. Test grid semantic row/column announcements, tab order, skip navigation, focus restoration, modal escape, contrast/heatmap non-color alternative, tooltips usable without hover, and chart text/tabular alternatives. Flutter's semantics bridge requires its real activation mechanism; do not auto-label it inaccessible.

**Security:** demonstrate that Python connection token is only in the active page's runtime memory as currently designed, that no untrusted origin or shell telemetry receives it, that collaboration role tokens cannot call Python endpoints, and that the POC does not expose local services remotely. A hosted Python sandbox is not part of this proof.

## 5. Acceptance and rejection gates

**Mandatory correctness:** 100% equality on approved JSON golden fixtures for statistics, rate scaling, stable player identity and tested CBA rules; no regression in 50/4 qualification, season type, multi-team stints, available/missing fields, and source backing. For numerical floating points define a domain-appropriate tolerance in the fixture and compare *displayed* rounding exactly.

**Mandatory workflow:** all table, chart, browser route and Labs tasks above complete without critical failures in supported browsers. New browser-console errors, lost workbooks, trapped focus, invalid deep links or cross-workspace credentials leaks are immediate blockers.

**Performance policy, conditional:** use measured Flutter baseline as reference and require the candidate's p95 critical interactions not be worse by more than **10%** under matched conditions. The 10% limit is a proposed migration decision rule, *not* known performance. Slowdown on a single important multi-second user task is also a rejection even if the aggregate stays within tolerance. Positive performance/UX gains should be established by observed task completion, not only charts.

**UX policy:** demonstrate improved usability on at least the top three prior user-reported problems (switching playoffs/rate basis, tight sortable tables, zoom vs pan controls), confirmed in systematic tasks with screenshots/interaction traces. Declining visual polish or perceived performance is not acceptable merely for cleaner code.

**Engineering policy:** no double-maintained source-of-truth NBA metrics; a documented architecture for translating Dart rules or serving them, file map, test and release plan, and estimated ongoing two-shell bridge burden. A full framework switch is rejected until the owner sees actual costs and accepts a staged plan.

**SEO/mobile conditional:** if these become material, run a relevant indexed public-player-page POC (Next/SSR) or Flutter native reuse study and rescore using `phase2_frontend_scorecard_2026_11_18.json`.

## 6. Deliverable checklist for the *future* Phase 3 experiment

- [ ] Pinned Flutter reference build, renderer version and representative valid historical static data manifest
- [ ] Separate React/Vite proof branch with **one** table, **one** chart and **two** unchanged Labs embedded
- [ ] Reviewed domain fixture JSON, Dart-vs-new-stack parity tests and clear edge-case explanations
- [ ] Screenshots and actual task traces for both variants, narrow and wide viewport, light and dark
- [ ] Cold/warm performance dataset (raw timing CSV/JSON) plus summary with variance and browser builds
- [ ] No missing-value/aggregate mismatches and actual missing-data coverage documentation
- [ ] Keyboard and screen-reader accessibility report; real Safari and Firefox results
- [ ] Persistence/export integrity; hard-refresh/deep-link behavior; browser storage migration plan
- [ ] Local Python and collaboration privilege and token security checks
- [ ] Actual development/port effort observations and compatibility assessment
- [ ] Explicit final **GO: React migration** / **GO: Flutter+web hybrid** / **GO: keep Flutter** / **NO GO** decision signed off by project owner

**Why this exists:** Phase 2 rankings are *reasoned hypotheses*. This protocol pre-commits the comparison to conditions that could disprove our preferred React/Vite candidate. Phase 3 is not started by writing the protocol.
