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
- Selected `NbaStatsWorkstationEngine` outputs checked against synthetic fixtures from the actual Dart tests. The intentional null-vs-0 improvement differs from Dart's `_total` missing-field fallback; this must be reconciled and documented before mandatory golden equality.
- Original-Dart CBA scenario JSON exporter, suitable for approved goldens. Full CBA golden comparison against a new-stack rules engine is **not performed** because no new-stack trade engine was ported for this minimal visual pilot.
- Automated React-only UI tests using explicitly synthetic request-intercepted fixtures; they are not NBA-source parity tests.

## Mandatory protocol gates and truthful status

| Gate | Status | Evidence / outstanding action |
| --- | --- | --- |
| React implementation and isolated branch | Implemented, compile pending | POC source, dedicated Vite config, new branch; Flutter `main` not touched |
| Original v5 manifest & source-backed shards | Unverified locally | `node experimental/arcside-react/scripts/inspect_corpus.mjs --out experimental/arcside-react/evidence/local-corpus-audit.json` checks exact available real assets and writes machine-readable evidence; requires owner's untracked release |
| Reference Flutter renderers, screenshot exports | Not run | Capture real Chromium, WebKit/Safari and Firefox on owner's Mac/OS |
| Identical Stats/Advanced metrics & 50/4 | Partial unit coverage | Need every displayed advanced field, null/error, 2P/rim/mid tiers, playoff split, 2TM/3TM, source provenance and exact golden review |
| 1k/10k/50k table and 300/5k/25k chart | Instrumentation present; not measured | Run `npm run benchmark`, preserve raw JSON/CSV and browser metadata; Flutter same-hardware baseline required |
| Deep links and browser navigation | Browser tests authored; not run in connector | Run Playwright with real browser |
| Zoom vs pan and persisted chart state | Implemented, real-browser QA pending | Verify tooltip, hit-testing and exact saved settings |
| Python/Sheets functionality and bridge | Bridge added; integration QA pending | Test Monaco focus, Cmd/Ctrl+K ownership, import/export, IndexedDB, role/credential isolation, narrow layout |
| Trade salary/rules exactness | Exporter present; no cross-stack parity | Run original Dart exporter; independently generate candidate and human-review severity/messages/figures |
| Accessibility WCAG 2.2 AA | Not certified | Audit axe + keyboard + real Safari/VoiceOver + NVDA/Chrome, semantic grids and chart equivalents |
| Cross-browser, screenshots, persistence | Not certified | Run Chrome, Firefox, Safari; capture light/dark and narrow/wide |
| Decision and migration authorization | **NOT APPROVED** | Owner signs GO React / GO Flutter-hybrid / GO keep Flutter / NO GO after all gates |

## Engineering trade-offs already visible

The existing v5 JSON compiler, Python historical warehouse, original standalone Labs and local-only Python/Sheets services remain reusable. The Dart stats engine had to be translated for a narrow slice; porting complete metric/taxonomy rules and the current custom drawing system is substantially more work. A browser-first UI does make deep-linking, native DOM controls and using the existing iframe Labs straightforward, but that observation alone does not prove UX or performance gains.

The sample fixture assertions validate a limited set of well-defined calculations, **not** a statistically representative NBA corpus. The POC's chart uses only available source-backed metrics and never fabricates tracking stats. Plot colors represent team tokens, not a verified historical franchise color mapping.

## Decision

**PENDING (no go/no-go claim).** Retain Flutter as reference and Flutter-plus-web Labs as fallback. Do not merge this stacked experiment into `main` or deprecate Flutter until parity, task, browser, accessibility and matched benchmarks satisfy the pre-registered mandatory gates and owner signs off.
