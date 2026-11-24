# Arcside — Phase 2: frontend alternatives and architecture decision study

**Assessment date:** 2026-11-18  
**Related source audit:** [Phase 1 architecture audit](phase1_arcside_architecture_audit_2026_11_18.md) (draft [PR #87](https://github.com/kshmsh1/sports-terminal/pull/87))  
**Code snapshot evaluated:** `main` at `f7abf0c883f9552e41d72ab8fbbe6223f047a2d8`; most complete unmerged Labs branch `feature/arcside-labs-ux-qa-hardening` at `3d8b0deb40cfbeb2b86b7fff62bd7112e59c433b`  
**Decision status:** **PROVISIONAL — choose what to test, not what to migrate.**  
**Scope of this PR:** comparison, source verification, scoring/sensitivity, target architectures, migration risks and measurable decision criteria. **No frontend framework installed; no app implementation, business rules, branch merge, or build configuration changed.**

> **Executive recommendation:** Prototype a **React + TypeScript + Vite static-hosted SPA** as the leading **long-term browser-first Arcside candidate**, retain the **Flutter + browser-native module hybrid** as the cost-efficient alternative, and treat **Next.js** as the React variant if public SEO/SSR requirements turn out to be first-class. **Do not authorize a rewrite** based on this study alone: the subjective baseline score difference is small; Phase 3 must measure real interaction/performance and exact data/algorithm parity.

## 1. Product requirements — Arcside, not a generic website

The relevant product is a broad, data-intensive sports analysis application with a sophisticated terminal aesthetic. Core use cases include:
- **Stats and Advanced Stats:** substantial tabular data, custom metric catalog, multiple rate bases (totals/per-game/per-36/per-100), regular/playoff splits, column persistence, sticky headers/columns, multi-team player rows, sorting/filtering, keyboard actions, deep entity links, exact null/percentage semantics and qualification thresholds (historically requested 50 games regular season / 4 playoffs; existing actual page contracts must be verified before changing these).
- **Visualization Studio:** interactive scatter/bubble, distributions, comparisons and other plots, zoom/pan separation, hover performance, regression/stat summaries, preset persistence, export, high-DPI displays, accessible chart alternatives, coherent team/metric colors.
- **Trade Machine:** nested draggable/selectable teams and assets, detailed CBA constraints, dynamic totals/validation, complex state transitions and source-backed 2026-27 cap/contract context. Underlying `trade_machine_engine.dart` is not a mere UI helper.
- **Python Lab:** Monaco, in-browser Pyodide Web Worker, optional trusted local CPython with LSP/DAP/Jupyter, native tools and terminal. Needs predictable keyboard/focus ownership, sandbox/privilege separation, and substantial client-side execution not SSR.
- **Excel Workspace:** custom grid and formula DAG, large virtual viewport, keyboard and clipboard, XLSX adapters, pivot/charts, IndexedDB persistence and opt-in SQLite/WebSocket collaboration.
- **Platform shell:** unified theme, navigation, session, entity/season/league context, responsive workspaces, browser history/deep links, shareable saved views, discoverable metrics and user support.
- **Non-negotiable:** preserve immutable NBA static datasets, source provenance, player/team keys, advanced statistical definitions, historical season coverage and CBA decision behavior; do not accidentally simulate missing data or replace current production/local trust boundaries.

For this evaluation assume **web browser is the primary Arcside platform**. If a first-class, single-codebase Android/iOS product becomes a firm requirement, rerun the scoring: that assumption materially changes the result. A high-SEO public player directory is also *not* yet an established requirement and is modeled as an alternative scenario.

## 2. Options deliberately assessed

### A. Keep Flutter and refactor

Preserve `CanonicalProductShell` and Dart engines. Modularize the two 4,000+ line visualization and Trade Machine screens; improve routing, screen semantics, separate math from paint logic, move expensive transforms off rendering hot paths, use Flutter Wasm/Skwasm where compatible, and keep HTML iframe Labs where warranted.

**Upside:** maximal preservation of code/tests, native mobile path intact, one primary widget idiom. Flutter already supports complex charts with `CustomPainter` and accessibility Semantics-to-DOM mappings. Modern Flutter supports Wasm builds and JavaScript/CanvasKit fallback (check engine/browser compatibility before benchmarking).  
**Downside:** direct browser DOM/widget library usage remains indirect; independent Labs create isolated focus/themes; some existing code mixes UI and domain logic. Neither React nor Flutter automatically fixes poor screen composition or missed UX requirements.

**Do not assume** that canvas rendering implies inaccessible or slow: Flutter publishes accessibility APIs and Wasm/browser renderer options. All concrete claims require current app measurements.

### B. Flutter shell + browser-native analytic modules

Retain Flutter for navigation and existing Dart business-logic screens, but migrate new and selectively redesigned heavy workspaces to independently built, DOM-native modules, initially using iframes and then a versioned event/data bridge. Keep original Labs as they stand.

**Upside:** preserves the trade engine/most screens; fastest path to richer browser interaction where the existing JS is already mature; progressive, reversible.  
**Downside:** **two rendering/UI frameworks**, duplicated focus and theme logic, CSS isolation, copy/paste and keyboard shortcut collisions, routing and saved-state synchronization. Existing Flutter iframe integration proves embedding is feasible, not that seamless cross-app interoperability is done. Flutter officially supports iframe and hostElement/multi-view embeddings; these have different memory/communication properties ([Flutter embedding guide](https://docs.flutter.dev/platform-integration/web/embedding-flutter-web)).

**Use as near-term control/fallback**, not necessarily the desired long-term end state.

### C. React + TypeScript + Vite SPA

Build a browser-native shell with React, TypeScript and Vite, a URL router and typed data adapters. Preserve `web/labs` workspaces initially as independent pages/embedded modules. Consume exactly the same static JSON/data bundle contracts; port domain calculations only after establishing golden fixtures. Make interactive charts using a measured combination of Apache ECharts or Plotly for common plots, and D3/SVG/Canvas where Arcside-specific interactions demand them; use a table/grid tool for stats **not** automatically for the bespoke spreadsheet formula engine.

**Upside:** direct DOM interaction, browser routing, accessible semantic HTML, CSS layout and JavaScript/Web Worker ecosystem; least wrapping around Monaco, Pyodide, ExcelJS and the existing JS workspaces. Strong match for a primarily authenticated, client-heavy analytics surface. Vite ships standalone static assets; React officially documents Vite as a scratch-build option, while warning that a custom stack needs intentional routing/data patterns ([React guidance](https://react.dev/learn/build-a-react-app-from-scratch), [Vite build guide](https://vite.dev/guide/build), [React Router SPA](https://reactrouter.com/how-to/spa)).

**Downside:** substantial UI rewrite; Dart stats/trading/reference logic must be translated or served through a shared API; route state and saved data require migrations. A client-rendered SPA does not magically provide high-quality crawler HTML for every player/team page. Browser-native UI is not automatically fast or accessible.

**Leading hypothesis for long-term browser-first Arcside**, contingent on Phase 3.

### D. React + TypeScript + Next.js App Router

Same general React ecosystem; the additional value is route-by-route prerendered/server HTML, an integrated full-stack convention and future server-rendered public player pages. Client-only IDE/spreadsheet code must still load on the browser side.

**Upside:** potential SEO/content discoverability and server-friendly routes while retaining React components. Next.js **does support static export** via `output: 'export'` and client components, so it is inaccurate to label Next "server required" ([Next static export](https://nextjs.org/docs/app/guides/static-exports)).  
**Downside:** static export does not support features dependent on an active server; dynamic request-time server functionality needs runtime hosting. SSR/RSC and hydration boundaries complicate Monaco/Pyodide/IndexedDB and code-split workspaces if mishandled. For Arcside's currently static, signed-out or demo-centric **analytical** app, Next adds architecture surface area without proven need.

**Choose if** genuine SEO for player/team pages, marketing/research content, or server-mediated product use cases dominate; do not adopt Next by default solely because it is popular.

### E. Vue 3 + Nuxt

Vue offers highly productive DOM components and Vite compatibility; Nuxt supports client, server, static and hybrid rendering. Libraries like TanStack Table are framework agnostic, and existing Labs remain vanilla JS. The functionality required is technically feasible ([Vue introduction](https://vuejs.org/guide/introduction.html), [Nuxt rendering](https://learn.nuxt.com/en/concepts/rendering-modes), [TanStack Table](https://tanstack.com/table/latest/docs/overview)).

**Tradeoff:** no clear Arcside-specific advantage over React sufficient to offset rewriting the same Dart UI/domain modules. Do **not** assert that Vue is inherently slow, lacks grids, or cannot host Monaco.

### F. Svelte + SvelteKit

SvelteKit supports static deployments through `adapter-static` and browser-native components; Svelte Flow and other libraries provide relevant interaction tooling ([SvelteKit adapters](https://svelte.dev/docs/kit/adapters)). This is a viable alternative, especially for smaller UI bundles and state ergonomics.

**Tradeoff:** Arcside has no pre-existing Svelte application to preserve, and vendor wrappers/existing React reference implementations for some target complex controls can reduce integration risk. This is a relative project-maintainability judgment, **not** a benchmarked speed inferiority.

**Out of scope as full-shell candidates:** Angular (credible but unneeded complexity for this particular application); pure vanilla JS (already used successfully for Labs, less desirable for a large shared shell); rewriting Labs in a new licensed commercial component (premature); native-only desktop Electron/Tauri (deployment wrapper, not a substitute for selecting a web UI framework); and replacing the NBA warehouse (not a frontend decision). None is deemed impossible.

## 3. Evaluation matrix (explicit judgment, not a measured benchmark)

Scoring is **1–5, higher is preferable**. The weights sum to **100**. Values are architecture judgments informed by Arcside's code inventory and official feature documentation; they are **not measurements of FPS, memory, developer velocity or accessibility compliance**. Full scores and exact assumptions are machine-readable in [`phase2_frontend_scorecard_2026_11_18.json`](phase2_frontend_scorecard_2026_11_18.json).

| Criterion | Weight | Why weighted this way |
| --- | ---: | --- |
| Large data tables, keyboard and virtual rows | 14% | Stats/Advanced are core, not incidental |
| High-interaction charting and plotting | 14% | Visualization Studio must outperform its current UX |
| Direct reuse of Python/Sheets web workspaces | 14% | Labs are a critical differentiator and JS already exists |
| Domain reuse, migration risk and shipping effort | 16% | Trade CBA and statistical semantics must survive |
| Browser routing, accessibility and general integration | 10% | Current shell lacks route-deep linking and unified focus |
| Static-first hosting simplicity | 9% | Historical datasets already ship without a live query API |
| Performance *tuning potential*, not speed | 7% | Actual performance remains unmeasured |
| Public SEO/server-rendering options | 4% | Useful, but no verified need to dominate the app |
| Native mobile code reuse | 4% | Potential future scope, not current browser-first objective |
| Ecosystem, maintenance and recruitability | 8% | Long-term tooling availability matters |

| Option | Weighted judgment / 5 | Primary advantage | Main caveat |
| --- | ---: | --- | --- |
| **React + Vite SPA** | **4.130** | Native integration with Labs/DOM and static-first app | Cost and risk of Dart business-rule/UI port |
| React + Next.js | 4.063 | React tools plus public-page SSR/SEO | Extra server/static-export and client/hydration considerations |
| Flutter + web hybrid | 3.985 | Preserve code while improving selective web workspaces | Split shell/runtime and focus ownership |
| Vue + Nuxt | 3.888 | Good SPA and hybrid rendering | Same port cost without an Arcside-specific edge |
| SvelteKit | 3.828 | Lean browser-native app path | Same port cost and less directly demonstrated target tooling |
| Flutter refactor | 3.665 | Minimize rewrite; preserves native Dart investment | More integration work for fully browser-native IDE and grid workflows |

**Interpret cautiously:** the leading React+Vite and Flutter-hybrid scores differ by **0.145 on a 5-point scale**. That is smaller than reasonable subjective uncertainty; it is **not** statistically significant or a claim that React will feel better to users. Nor is the 0.067 difference between React+Vite and Next evidence that Next is technically inferior.

### Sensitivity: the winner changes with product strategy

| Scenario (weights explicitly changed in scorecard) | Winner | Score | Decision implication |
| --- | --- | ---: | --- |
| Browser-first Arcside analysis app (base case) | **React + Vite** | 4.130 | Experiment with browser-native React shell |
| Public player SEO/editorial acquisition is important | **React + Next.js** | 4.211 | Reconsider server/prerendered pages |
| One native iOS/Android codebase is a central priority | **Flutter refactor** | 4.045 | Preserve Flutter; may use browser Labs hybrid |
| Near-term delivery and minimal rewriting dominate | **Flutter + web hybrid** | 4.120 | Improve incrementally; avoid front-end rewrite |

A scorecard based on a single invented user priority mix could mislead. The scenario flip is the most important numerical outcome. **The true decision must come from requirements and Phase 3 matched evidence.**

## 4. Component-selection study: what Arcside would actually need

| Arcside surface | React/Vite candidate | Flutter/hybrid equivalent | Adoption decision |
| --- | --- | --- | --- |
| Stats/Advanced dense data | TanStack Table + TanStack Virtual for custom headless UI, **or** AG Grid Community where native grid features are preferable | Existing sticky stats table widgets and `NbaStatsWorkstationEngine` | Test both React table paths for columns, sticky behavior, keyboard accessibility, multi-team expandable rows and huge data. Do not select before POC |
| Spreadsheet grid | **Keep current vanilla JS grid and formula DAG** first; selectively wrap with typed adapters | Existing `web/labs/sheets` iframe | No wholesale replacement. TanStack Table is *not* an Excel engine |
| Charting | ECharts for standard statistical charts; D3/SVG/Canvas for custom zoom/bubble/regression; Plotly if scientific functionality justifies cost | Dart `CustomPainter` and existing chart state | Compare behavior/axes/performance under identical data. Avoid two chart engines owning the same viewport |
| Python IDE | **Keep Monaco + Pyodide, native companion, LSP/DAP/Jupyter clients**; embed as client-only JS app initially | Existing iframe from Flutter | Maintain keyboard and token trust boundaries; optional code reuse into React wrapper later |
| Drag/drop trade construction | Browser drag-and-drop primitives, optional DnD Kit/React Flow *only if matched UX requirements* | Existing Flutter gesture controls | Build a narrow trade flow POC after CBA result fixtures exist |
| Reusable UI toolkit | TypeScript tokens, semantic DOM, tested headless accessible primitives | Material themes / semantic widgets | Theme and WCAG quality requires implementation and testing |
| Cross-workspace communication | Versioned, typed event contracts and shared route state; iframe `postMessage` initially | `postMessage` bridge into Flutter | Enforce target origin/source validation and never broadcast privileged Python tokens |
| State persistence | Browser-compatible versioned localStorage/IndexedDB adapters, future authorized server storage | `SharedPreferences` + existing IndexedDB | Audit origin, namespace, schema version; preserve user saves |

**Licensing:** TanStack Table/Virtual are MIT and framework agnostic ([docs](https://tanstack.com/table/latest/docs/overview)); AG Grid Community is MIT, while Enterprise features are commercially licensed ([AG Grid](https://www.ag-grid.com/react-data-grid/community-vs-enterprise/), [license](https://www.ag-grid.com/eula/community/)). Handsontable is **not** a default free-for-commercial-use dependency; commercial licensing applies to commercial use, and HyperFormula may require a separate license ([Handsontable license/pricing](https://handsontable.com/pricing/)). Apache ECharts is Apache-2.0 and offers SVG/Canvas renderers ([features](https://echarts.apache.org/en/feature.html)), while Plotly.js is MIT ([project](https://github.com/plotly/plotly.js)). Monaco has its own worker/bundling constraints ([project](https://github.com/microsoft/monaco-editor)). Verify actual package versions/licenses when installing; these are **not** blanket legal approvals.

**Accessibility:** Native DOM provides useful browser semantics and test tooling but React tables/charts still need deliberate ARIA keyboard implementation. Flutter can translate a Semantics tree into an accessible DOM layer; custom widgets need explicit semantic roles. Its web accessibility activation should be verified in the actual running build ([Flutter accessibility](https://docs.flutter.dev/ui/accessibility/web-accessibility)). Do not mark either option WCAG-compliant by default.

## 5. Three deployable target blueprints

### Blueprint R — preferred *candidate* if Phase 3 validates React

~~~text
arcside.com or /app
    |
    +-- React/TypeScript/Vite (static-built client shell)
    |      +-- URL router (/nba/stats, /nba/players/:key, /trade, /studio)
    |      +-- Arcside design tokens, navigation, keyboard/focus manager
    |      +-- typed contracts -> existing /data/nba_static/manifest.json
    |      |                    -> season/player/team/game JSON or gzip bundles
    |      +-- domain adapters -> stats/research/Trade rules (ported or versioned service)
    |      +-- ECharts/D3 and typed grid components
    |      +-- Web Workspaces / Labs (same-origin independent apps first)
    |                            +-- Monaco/Pyodide -> worker
    |                            +-- Sheets/IndexedDB -> local assets
    |                            +-- opt-in local companion :8766
    |                            +-- opt-in local collaboration :8767
    |
    +-- independently published immutable NBA JSON & metadata (CDN-friendly)
    +-- separate future authenticated mutable API (existing FastAPI carefully activated)
~~~

*Storage, URLs and identity:* Preserve old browser-local data keys where safely possible; migrate via versioned idempotent adapters and backups. Contract all entity links as real navigable URLs, not private mutable UI index values. The JS Labs must be dynamically imported in client-only contexts or remain iframe pages; do not import DOM-only globals during SSR/prerendering.

*Deployment:* Vite output can deploy to static hosting with a **documented history-route fallback** or a suitable router mode. The canonical SQLite warehouse remains in the local publishing pipeline, not in the browser or Vite build itself.

### Blueprint H — best *near-term* fallback

~~~text
Flutter CanonicalProductShell + existing Dart rules
     +-- Flutter Stats / Trade / existing custom visualization routes
     +-- selected DOM-native workspaces in same-origin iframes
     +-- shared lightweight event/route/theme bridge
     +-- same static NBA data and Python/Sheets local services
~~~

*Focus:* create a genuine keyboard shortcut owner and fix iframe focus, context/cross-route selection, and theme token parity. Retain Flutter if a matched React experiment does not materially outperform current experience or if rewriting materially damages domain fidelity.

### Blueprint N — conditional public SEO product

~~~text
Next.js App Router / React
     +-- prerendered or server-rendered discoverable player/team/editorial pages
     +-- client-only authenticated analytical workbench routes
     +-- existing static NBA corpus and opt-in local Labs services
~~~

*Activation rule:* only pursue if product requirements and a crawler/SEO experiment show material need for SSR/SSG. Static export alone is not a real server-side authenticated backend. The mutable customer API remains a separate system concern.

## 6. Portability and migration risk: actual source-level choices

**Reuse unchanged or with adapters:**
- `data/warehouse/nba_history.sqlite` as canonical local build input; all `tools/*` ingest/enrichment/compilers; `web/data/nba_static/*` manifest/shards and gzip output.
- JS code under `web/labs/python` and `web/labs/sheets`, their formula engines/workers and assets, subject to embedding tests.
- Python companion FastAPI service and Sheets collaboration FastAPI/SQLite service, for the same **trusted-local** use case only.
- Browser-side persisted workbook assets if the origin and schema remain compatible.
- Backend FastAPI routers as *potential* future mutable data services, not as a live dependency magically enabled by React.

**Requires contracts and deliberate code port/service extraction:**
- `NbaStatsWorkstationEngine`: metrics, normalized aliases, totals/rate basis, traded-player stint rows, nulls and qualification/filter/sort semantics.
- `NbaStatsQueryEngine`, `ArcsideResearchQueryEngine`: deterministic query language and output provenance.
- `TradeMachineEngine` and CBA reference/source metadata: exact salary matching, restrictions, trade exceptions, future picks, multi-team and deadline boundaries; reference tables must be source-versioned.
- App session, settings, watchlist, saved trade, saved visualization and compare-state keys in `ProductLocalStore`, `SharedPreferences` and individual screens.
- UI theme and layout conventions, accessible keyboard interactions and top-level route/navigation.

**Browser-specific rewrite cost:**
- `website_nba_visualizations_v2_screen.dart` (4,213 lines) and `product_trade_machine_video_screen.dart` (4,312 lines) are large, strongly coupled screens; simply copying their state objects to a React hook is insufficient. Break into domain/view-model/renderer/interaction layers first.
- Player/Team Compare tables, Front Office form dialogs, Community, entity pages and responsive navigation need route-by-route reimplementation and parity checks.
- Existing duplicate older screens may be unreachable; do not count or delete them without a reference graph.

**Separate P0 production issue:** `LaunchBackendTransport` and remote auth requests are disabled in the current static-only Flutter customer frontend, while the standalone local services and backend code are independent. A React rewrite **must not** silently re-enable them or mistake demo sign-in for hosted authentication. Decide the authenticated customer architecture separately. The native CPython companion runs with local OS privileges: do **not** turn it into a public HTTP execution endpoint.

### Planning effort / budget comparability

No reliable person-hour estimate is available from this code-only source audit. The bands below are **relative engineering effort**, not calendars or quotes. They assume a familiar engineer, representative historical data locally available, existing tests working, and existing features *only*; production auth, cloud compute, new data connectors and Excel/VS Code parity are explicitly excluded:

| Work area | React full-shell migration | Flutter + hybrid |
| --- | --- | --- |
| New design system/navigation/responsive shell | Medium–high | Low–medium |
| Stats, Advanced Stats and profile table parity | High | Low–medium |
| Bespoke Visualization Studio parity | **Very high** | Medium if web-native selectively, lower if keeping Flutter |
| Trade Machine and CBA exactness | **Very high** | Low if keeping original rules/screen |
| Two Labs and native service integration | Low–medium | Medium for shared key/theme/selection bridge |
| Deep link/shareable state and storage migration | Medium–high | Medium |
| Mobile native code reuse | Limited from React web; additional strategy needed | Preserved Flutter option |
| QA/regression and long-tail maintenance | High during transition | Medium |

A full rewrite is **not** automatically cheaper to maintain than an incremental cleanup. A mixed hybrid can also become expensive if allowed to accumulate duplicate nav, data adapters and styling indefinitely. In either case prioritize clear ownership and remove bridge layers only when parity passes.

## 7. Reversible evaluation: exact Phase 3 tests and pass/fail gates

Phase 2 cannot honestly report winner-level rendering performance because the canonical `nba_history.sqlite` and generated static corpus are uncommitted, actual deployed browser telemetry is absent, and no matched React/Flutter implementation has yet been built. The appropriate output is a **pre-registered test contract**, not fabricated numbers. The companion document [`phase3_frontend_proof_protocol.md`](phase3_frontend_proof_protocol.md) specifies implementation slices, fixtures and measurements.

**Candidate comparison in Phase 3:**
1. **Stats vertical slice:** identical season/player dataset, typed static data adapter, sortable/virtualized/frozen-columns table, rate-basis changes, playoffs and traded player rows, selection, accessibility and browser history.
2. **Visualization vertical slice:** representative scatter/bubble with zoom/pan, exact percentile and metric selection, per-team colors, multi-team hover, regression summary, large-data rendering and saved-view serialization.
3. **Integration slice:** real same-origin Python/Sheets UI embedding, keyboard command ownership, theme switch, deep links, persistent workbook/project data. **Do not** publicly expose or proxy the privileged local execution token.
4. **Domain contract slice:** golden Dart-vs-new-stack stats, percentiles and representative CBA decision outcomes. Not a full Trade Machine UI port in this early proof.

Use the same desktop hardware/browser version, exact data, network throttling and CPU profile for both apps. Benchmark Chrome, Safari and Firefox; warm and cold with cache/worker status documented. Record p50/p95 route load and input latency, RAF frame timings during pan/zoom and scrolling, JS/WasM transfer, memory and accessibility/navigation outcomes. Compare light/dark and narrow screen widths. Include source-backed nulls and missing-coverage cases.

**Non-negotiable promotion gates:** parity on every committed golden fixture; no invented missing stats; CBA rule test agreement including error/severity outputs; working keyboard semantics, visible focus and screen reader navigation; no token trust-boundary regression; working import/export/browser persistence; no severe recurring browser errors; no statistically unmeasured performance claims.

**Decision gate (proposed policy, not evidence):** 
- React pilot advances only if all correctness/security gates pass, its core task completion and interaction quality is demonstrably better in matched usability testing, its p95 interaction regressions do not exceed 10% of the measured Flutter baseline on critical routes, and the team accepts a funded, tested business-rule port plan. "Within 10%" is an evaluation threshold, **not** a claim that React currently hits it.
- If parity passes but users prefer existing Flutter or React costs dominate, choose Flutter/hybrid and invest in Dart UI modularization and web bridge, rather than force a rewrite.
- If public SEO emerges as a verified requirement, extend comparison to Next/Nuxt static/dynamic routes and an indexed player-page test.
- If native mobile dominates, rerun scoring and consider Flutter-first architecture.
- If all alternatives miss critical gates, **no frontend switch**.

## 8. Risk pre-mortem and mitigations

| Failure mode | Risk trigger | Prevention / evidence |
| --- | --- | --- |
| Beautiful new React charts but incorrect historical stats | Rate-basis, 2TM/3TM, pct, min-games and null semantics differ | Golden snapshots of matching data + metric contract tests |
| Trade Machine rebuild weakens CBA correctness | Rules copied from widget behavior rather than domain tests | Keep original rules authoritative until validated port/service |
| Labs break on SSR or change origin | `document`/`window` globals, workers, storage/clipboard/ports | Client-only loading; same origin; Playwright nested and standalone tests |
| Browser-native charts stutter on NBA-size data | Unvirtualized DOM, chart data copies, rerenders | Measure p95 event/render throughput and memory on equal fixtures |
| Porting clobbers saved user work | Different `SharedPreferences`/localStorage/IndexedDB keys or origin | Export before migration; versioned key map; rollback tests |
| Production demo accounts mistaken for real auth | Static-only auth transport disabled | Separate auth track, fail closed, do not publish privileged services |
| Hosted Python execution becomes a security hole | Loopback companion exposed or tokens forwarded | Retain local-only semantics; isolated authenticated compute for future SaaS |
| Static deployment loses direct URL access | Missing SPA fallback / prerender path | Test hard refresh, deep link, relative static assets and 404 |
| SEO decision inferred from popularity | No user acquisition/indexing need verified | Require public-page SEO experiment before Next |
| Licensing surprise | AG Grid Enterprise / Handsontable/HyperFormula | Pin inventory and approve licenses prior to adopting enterprise features |
| Legacy work duplicated | Competing #78–#86/PR #81 states | Reconcile exact baseline before experiments; do not auto-merge |
| Tool scorecards masquerade as science | Subjective ordinal ratings presented as performance fact | Machine-readable assumptions/sensitivity; measured evidence in next phase |

## 9. Phase 2 decision record — ADR-002 (proposed)

- **Context:** Existing production-like Flutter app is browser-first and static-data-centric; JS-native Labs are substantial and iframe-isolated; very large Flutter screens contain both state and bespoke UI logic; high-value Dart domain calculations are not language-neutral.
- **Decision:** **Authorize a controlled Phase 3 React/Vite prototype and a Flutter/hybrid comparator**, not a full rewrite. Keep Flutter `main` as reference and the original Dart logic/data as authoritative.
- **Non-decision:** No Next.js, Vue, Svelte, grid/chart vendor, CSS framework, production authentication strategy, or cloud-hosted execution service is approved for implementation yet.
- **Rationale:** Baseline qualitative 4.130 vs 3.985 scores give React/Vite a weak initial advantage under *browser-first* priorities, while alternate priorities reverse that. React/Vite can use existing JS Labs with fewer embedding/runtime layers, but the cost of porting 4,000-line visualizations/Trade Machine is substantial and unmeasured. No honest architecture study can settle actual UI responsiveness without a prototype.
- **Consequences:** Build thin, reversible UI slices; preserve static read model and historical keys; write golden algorithm fixtures before porting; evaluate Safari/Firefox alongside Chromium; preserve user data and privilege separation.
- **Decision expiry:** Review immediately after Phase 3 measured gates; reconsider earlier if the user prioritizes public player SEO or mobile native apps.

## 10. Evidence and source notes (verified documentation vs subjective inferences)

**Code and first-party evidence:** [Phase 1 audit](phase1_arcside_architecture_audit_2026_11_18.md), `lib/widgets/canonical_product_shell.dart`, `lib/screens/website_nba_visualizations_v2_screen.dart`, `lib/screens/product_trade_machine_video_screen.dart`, `lib/services/nba_stats_workstation_engine.dart`, `lib/services/trade_machine_engine.dart`, `lib/services/launch_backend_transport.dart`, `web/labs/python`, `web/labs/sheets`, `python/arcside_companion`, `python/arcside_collab` and CI runs linked in Phase 1.

**Official docs read during the evaluation (links are primary sources, checked 2026-11-18):**
- [React: build from scratch and tradeoffs](https://react.dev/learn/build-a-react-app-from-scratch); [Vite production building](https://vite.dev/guide/build); [React Router SPA mode](https://reactrouter.com/how-to/spa); [React Router prerendering](https://reactrouter.com/how-to/pre-rendering).
- [Next.js static export, capabilities and limitations](https://nextjs.org/docs/app/guides/static-exports); [Next.js SPA guidance](https://nextjs.org/docs/app/guides/single-page-applications).
- [Flutter web Wasm and browser fallback](https://docs.flutter.dev/platform-integration/web/wasm); [Flutter web deployment](https://docs.flutter.dev/deployment/web); [Flutter embedding](https://docs.flutter.dev/platform-integration/web/embedding-flutter-web); [Flutter accessibility](https://docs.flutter.dev/ui/accessibility/web-accessibility).
- [Vue introduction](https://vuejs.org/guide/introduction.html); [Nuxt rendering modes](https://learn.nuxt.com/en/concepts/rendering-modes); [SvelteKit adapters](https://svelte.dev/docs/kit/adapters).
- [TanStack Table](https://tanstack.com/table/latest/docs/overview); [TanStack Virtual](https://tanstack.com/virtual/latest); [AG Grid Community v Enterprise](https://www.ag-grid.com/react-data-grid/community-vs-enterprise/); [AG Grid Community license](https://www.ag-grid.com/eula/community/); [Handsontable pricing and licensing](https://handsontable.com/pricing/).
- [Apache ECharts chart and renderer capabilities](https://echarts.apache.org/en/feature.html); [Plotly.js](https://github.com/plotly/plotly.js); [D3 zoom](https://github.com/d3/d3/blob/main/docs/d3-zoom.md); [Monaco Editor](https://github.com/microsoft/monaco-editor); [MDN postMessage origin security](https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage).

**Evidence classification:** library capabilities and licensing are verified from vendor/project docs; Dart code/reuse costs are derived from the GitHub source audit; rankings and architecture/effort expectations are **expert estimates only**; future speed and accessibility benchmarks are unmeasured. Paid feature pricing/licensing may change; review procurement before dependency adoption.

**Phase 2 outcome:** Completed architecture alternative assessment and pre-registered experiment plan. **React/Vite is the preferred candidate to test, not the approved new Arcside frontend.** Flutter/hybrid remains a credible option; changing requirements can change the preferred choice. No software migration has begun.
