# Arcside — Phase 1 existing-architecture audit
**Audit date:** 2026-11-18  
**Repository:** [kshmsh1/sports-terminal](https://github.com/kshmsh1/sports-terminal)  
**Baseline reviewed:** `main` at `f7abf0c883f9552e41d72ab8fbbe6223f047a2d8`  
**Full Labs development snapshot reviewed:** `feature/arcside-labs-ux-qa-hardening` at `3d8b0deb40cfbeb2b86b7fff62bd7112e59c433b` (draft PR #86, stacked on #85, #84, #82).  
**Scope:** source and architecture review, route/ownership inventory, runtime and data flows, persistence, tests, CI, operational risks, portability and candidate migration boundaries. **No feature implementation or framework selection is authorized by this audit.**  
**Evidence limitations:** GitHub tree/source, documented contracts and GitHub Actions logs were inspected. The locally generated historical warehouse and full static output are excluded from Git, and no local, cross-browser or production load benchmark was performed by this audit. CI outcomes are observations, not proof of universal correctness.

## 1. Executive assessment

**Conclusion:** Arcside is a Flutter browser frontend over a largely reusable, static-first NBA data publishing pipeline, with a substantial set of Dart analytical/transaction rules, a separate FastAPI product service, and two independent browser-native workspaces supported by opt-in Python services. Replacing Flutter **would not** require rebuilding the historical warehouse, NBA static compilers, local Python runtime, SQLite collaboration service or most JavaScript Labs code. It **would** require rewriting the active Flutter screens and porting or extracting the domain logic currently implemented in Dart.

The strongest evidence **against** premature wholesale migration is that Flutter is demonstrably capable of the present custom graphics: Visualization Studio already implements a 4,213-line Dart module with custom chart painting, mouse interaction and chart state. The strongest evidence **for evaluating** an alternative is engineering friction and code organization: browser-native Labs are iframe applications, major modules keep large amounts of UI state and custom drawing together, and cross-workspace command/routing integration has not been designed yet. The language alone is not proven to cap visual fidelity or runtime performance.

**Separate product-readiness finding:** The current Flutter customer shell is explicitly static/local-only. Its generic HTTP-backed application services are disabled at the frontend transport boundary; registration and remote Community operations are not operating as a hosted multi-user SaaS through that path. This is a product architecture issue, not a Flutter-specific issue. The independent Sheets collaboration server and Python companion are functional local services but are not a substitute for a production platform backend.

**Recommendation for Phase 1:** preserve the existing product and data pipeline; mark frontend selection **undecided**; evaluate React/TypeScript versus Flutter/hybrid in Phase 2 using precisely documented interfaces; prototype one demanding page in Phase 3; do not merge or rewrite product code as part of this report.

## 2. Scope, repository topology and branch reality

GitHub's recursive tree inspection reported **1,206 tree entries** on the Labs branch (not truncated) compared with **1,135** on `main`. On the Labs branch the repository has **526 Dart files total**, **426 files under `lib/`**, **82 under `test/`**, **152 files under `lib/screens/`**, **108 under `lib/data/`**, **88 under `lib/services/`**, **46 under `lib/models/`**, and **28 under `lib/widgets/`**. There are **35 files under `web/labs/`**, **14 under `python/`** and six CI workflows. Counts include legacy, prototype and planning surfaces; they do not imply all files are customer-facing or actively maintained.

| Area | Main paths | Role | Runtime status |
| --- | --- | --- | --- |
| Flutter customer web | `lib/main.dart`, `lib/widgets/canonical_product_shell.dart`, `lib/screens/website_*`, `lib/screens/product_*` | App entry, login/demo, navigation, sports pages, analytics UI, custom charts | Active web frontend |
| Flutter domain/state | `lib/services/`, `lib/controllers/`, `lib/models/` | Trade rules, stats calculations, research rules, local settings, source data facades | Mix of reusable concepts and Dart-only implementation |
| Historical ingest/publish | `tools/`, `raw/`, `data/warehouse/`, `web/data/nba_static/` | Source normalization, canonical SQLite, static JSON publishing and enrichment | Local build pipeline; generated warehouse and output not committed |
| Legacy / product FastAPI | `backend/app/main.py`, `backend/app/main_launch.py`, `backend/schema_v1.sql` | Auth, profiles, orgs, community, front office, transaction cases, data APIs and other mutable workflows | Runs independently on port 8000; Flutter general transport currently disabled |
| Python Lab web UI | `web/labs/python/` | Monaco-based browser editor, Pyodide worker, native-service UI and LSP/DAP clients | Draft PR stack; loaded from iframe or separate tab |
| Excel Workspace web UI | `web/labs/sheets/` | Virtual grid, formula engine, XLSX I/O, analytics, storage and collaboration client | Draft PR stack; loaded from iframe or separate tab |
| Trusted local Python service | `python/arcside_companion/` | Opt-in CPython, filesystem, PTY, env, debugger, LSP, Jupyter, Git | Loopback-only FastAPI; not an untrusted-code sandbox |
| Sheets collaboration service | `python/arcside_collab/` | SQLite room/grant/event journal, WebSocket syncing, revision history | Loopback-only, independently authenticated |
| Automation/validation | `.github/workflows/`, `test/`, `backend/scripts/`, `web/labs/tests/` | Dart unit/widget, backend contracts, JS unit/browser and browser-native tests | Broad coverage, with a current native UI test failure detailed below |

### Branch and PR dependency map

~~~text
main (Flutter platform, no new standalone Labs)
 ├─ PR #81: player history stats parity (separate unmerged branch)
 ├─ PR #78, #79, #80: other alternate Labs/player-parity efforts (unmerged)
 └─ PR #82: independent Labs foundation (draft)
      ├─ PR #83: alternate independent Phase II branch (draft)
      └─ PR #84: local Python companion + Sheets analytics (draft)
           └─ PR #85: collaboration + launcher (draft)
                └─ PR #86: Labs UX and browser QA + --fast launcher (draft)
~~~

PR #86 is *not* based directly on `main` and does **not** contain the separately proposed `lib/widgets/website_player_history_stats_table.dart` from PR #81. This is a concrete parity/integration risk: the version a developer runs from #86 and a hypothetical future merge of #81 are not automatically additive. PR #83 overlaps with #84, while #78–80 overlap with later work. Before any transition, consolidate/disposition the competing branches, compare their features explicitly and establish a single known-good source-of-truth baseline. **Do not merge the dependent PRs in an arbitrary order.**

## 3. Actual runtime architecture

~~~text
                         OFFLINE / BUILD-TIME
Local/source captures -> canonical import/normalization -> nba_history.sqlite
                                                    |
                                                    v
                         tools/build_static_nba_website_data_v2_core.py
                         + additional enrichment and materialization scripts
                                                    |
                                                    v
                                      web/data/nba_static/*
                                                (read-only)
                                                    |
                  BROWSER / CUSTOMER PRESENTATION    |
                                                    v
Browser ---> Flutter app shell ---> WebsiteNbaApiService
              (Dart widgets)       -> WebsiteNbaStaticRepository
                     |              -> SportsTerminalStaticJsonLoader
                     |              -> same-origin static JSON (or gzip bundles)
                     |
                     +--> in-memory widget state, Dart metric/trade engines,
                     |    SharedPreferences/browser-local persistent state
                     |
                     +--> HTML iframe: /labs/python/index.html
                     |        -> Monaco + Web Worker/Pyodide
                     |        -> optional localhost:8766 trusted CPython service
                     |
                     +--> HTML iframe: /labs/sheets/index.html
                              -> custom JS grid/formula engine + IndexedDB
                              -> optional localhost:8767 SQLite collaboration

Separately launched, not automatically reconnected through Flutter transport:
  backend/app/main_launch.py -> FastAPI/SQLite (normally localhost:8000)
~~~

The default customer historical path is **static HTTP** rather than an active historical FastAPI query. The name `WebsiteNbaApiService` is a compatibility facade; its implementation delegates to `WebsiteNbaStaticRepository`. The published `manifest.json`/`seasons.json`, season shards, player/team indexes and dossiers, dashboards, historical games and Front Office snapshots constitute a practical frontend-neutral contract. The loader supports loose same-origin JSON as well as bundled gzip files for public static hosting, with a small in-memory bundle LRU. This is a substantial portability advantage.

**Do not confuse independent Python services:** `backend/app/python_runtime_api.py` is an older constrained server-side notebook runner; `python/arcside_companion` is a separate high-privilege, opt-in local IDE execution service. They must never be treated as interchangeable execution trust boundaries.

## 4. Flutter frontend and user-interface boundaries

### Entry, navigation and state

`lib/main.dart` constructs `MaterialApp` and controllers. `lib/widgets/app_entry_gate.dart` waits for a session and chooses login or `CanonicalProductShell`. The active shell in `lib/widgets/canonical_product_shell.dart` builds a fixed route registry, owns the selected destination in a private `_selected` string, applies dark/light `ThemeData`, and renders one page at a time. Its main navigation selection **is not represented by a URL route**; a refresh or copied URL cannot inherently restore the same top-level workspace. Entity detail screens can use Flutter navigation separately.

There are **20 product/utility destinations** in the current shell, plus seven legal/information destinations. The high-value map:

| Shell destination | Active implementation | Data/logic dependency | Migration treatment |
| --- | --- | --- | --- |
| Sports, NBA Home | `website_sports_home_screen.dart`, `website_nba_home_dashboard.dart` | Static season/dashboard | Recreate layout; preserve JSON contract |
| Stats | `website_nba_stats_screen.dart` forwarding to `website_nba_stats_v2_screen.dart` | `NbaStatsWorkstationEngine`, season snapshot, metric catalogue | Port UI and analytical logic separately; golden parity checks |
| Advanced Stats | `website_nba_advanced_stats_screen.dart` forwarding to `website_nba_advanced_stats_v4_screen.dart` | Same stats engine, glossary/metric taxonomy | Reuse data and metric definitions; port interactive table |
| Player / Team Compare | `website_nba_player_comparison_screen.dart`, `website_nba_team_comparison_screen.dart` | Stats engine, shared comparison widgets, local saved views | Rebuild interactive UI; translate calculations and saved-view schema |
| Trade Machine | `product_trade_machine_screen.dart` -> `product_trade_machine_video_screen.dart` | `trade_machine_engine.dart`, CBA and salary/draft repositories | Rebuild UI; preserve domain contract/test vectors; port or serve rule engine |
| Visualizations | `website_nba_visualizations_screen.dart` -> `website_nba_visualizations_v2_screen.dart` | Stats engine, custom `_NbaChartPainter`, saved presets | High-cost UI port; chart behaviors need independent contracts |
| With / Without, Rankings | `website_nba_with_without_v2_screen.dart`, `website_nba_rankings_v2_screen.dart` | Static game/stat datasets | Recreate presentation; preserve data/derivations |
| Financials, Front Office | `website_nba_financials_screen.dart`, `product_front_office_registry_screen.dart` | Published Front Office snapshot + browser overlay; backend transport disabled | Preserve immutable facts; explicitly design future authoritative writes |
| Box Scores, Schedule | `website_nba_box_scores_screen.dart`, `website_nba_live_games_screen.dart` | Static historical game detail/schedule; live network box scores disabled | Preserve static endpoints; design future active-season overlay separately |
| Research | `website_nba_research_screen.dart`, `nba_research_query_panel.dart`, `nba_research_query_engine.dart` | Rules-based, source-backed research over static corpus | Keep contract/semantics; port or move parser to backend |
| Community | `product_community_v2_screen.dart` | `CommunityNetworkService` and `TrustSafetyService`, disabled general transport | UX is porting work; interactive hosted service requires a separate backend decision |
| Python Lab, Excel Workspace | `arcside_lab_webview.dart` with `arcside_lab_platform_web.dart` | Same-origin iframe to standalone browser applications | **Highly reusable** web code; solve embedding, shared identity and data exchange |
| Profile/login | `product_profile_v3_screen.dart`, `auth_controller.dart`, `launch_auth_client.dart` | Locally cached session/demo paths, remote auth disabled | Redesign identity and persistence contract before real user rollout |

The current shell also includes About, Contact, Privacy, Terms, Sitemap, Accessibility and Data & Methodology.

### UI size and coupling evidence

| Active Flutter file | Approx. size | Why it matters |
| --- | ---: | --- |
| `website_nba_visualizations_v2_screen.dart` | 4,213 lines / 144 KB | User controls, preset serialization, viewport interactions, regression/chart semantics and a large custom canvas painter in one file |
| `product_trade_machine_video_screen.dart` | 4,312 lines / 148 KB | Layout, interactions, selection/restrictions and scenario state concentrated in one presentation file |
| `website_nba_player_comparison_screen.dart` | 1,572 lines / 54 KB | Filter/state, saved views and table UI tightly neighboring |
| `website_nba_team_comparison_screen.dart` | 1,227 lines / 45 KB | Similar UI/state coupling |
| `product_front_office_registry_screen.dart` | 1,396 lines / 50 KB | Many dialog forms and mutable state paths |
| `product_community_v2_screen.dart` | 1,307 lines / 48 KB | UI, community actions and service fallbacks |

The existing visualizations use `CustomPainter`, mouse interactions, charts and layout controls; these are not features Flutter is technically incapable of. However, replacing them with D3/ECharts/Plotly or DOM/SVG composition requires **intentional reimplementation**. React cannot consume a Flutter widget or `CustomPainter` verbatim.

The Flutter dependency surface is intentionally small: `pubspec.yaml` specifies Flutter, `http`, `shared_preferences`, `web` and `archive`, plus Flutter lint/test tooling. A migration is not blocked by a large closed-source Flutter widget dependency graph; it is driven by the amount of *custom* Dart UI and behavior.

### Older/parallel surfaces and maintainability

`lib/widgets/terminal_shell.dart` and numerous `lib/screens/product_*`, `lib/data/*_items.dart` and old screen aliases are still in the tree. The active customer shell is explicitly `CanonicalProductShell`, not all historical terminal screens. This makes a raw file-count migration estimate misleading. Inventory reachability from `AppEntryGate` and the shell registry before deciding what must be ported. Retire nothing until a reference/behavior scan and regression evidence establish it is unused.

## 5. Domain logic, typed contracts and portability

The most reusable **ideas** are not uniformly reusable **source code**.

- **High-value Dart domain rules:** `lib/services/nba_stats_workstation_engine.dart` holds row normalization, rate basis, filters, percentiles, sorting and stat formatting. `lib/services/nba_stats_metric_catalog.dart` defines extensive metric semantics. `lib/services/nba_stats_query_engine.dart` and `nba_research_query_engine.dart` parse questions over source-backed records. These should be specified by language-neutral JSON inputs, outputs and golden test cases *before* porting.
- **High-value CBA logic:** `lib/services/trade_machine_engine.dart` and `cba_transaction_rules_engine.dart`, together with contract/roster/draft and exception reference repositories, encode salary matching and transaction rules. None of this should be rebuilt from memory during a frontend rewrite. Decide between a TypeScript port with exact parity fixtures and a server-hosted rules service; test historic and edge-date rule cases.
- **Data contracts:** The website API uses `Map<String, dynamic>` extensively, with season/player keys and metrics normalized at read and presentation time. Formal, versioned JSON schemas / typed TS models are not currently the primary boundary. A React client would benefit from automated schema validation and typed adapters instead of translating every ad hoc map access.
- **Local saved data:** `ProductLocalStore`/`SharedPreferences` keys and screen-specific serialized presets are part of the user's current data. Changing framework without data-migration mapping will silently lose saved comparisons, charts, trades, watchlists or preferences. Preserve or explicitly migrate key namespaces.

**Portability verdict:** Historical datasets, source-processing Python, file/JSON API contracts and the standalone Labs can be reused essentially as designed. Flutter domain algorithms require a typed contract and code port/service extraction. Flutter layouts, widgets, theme declarations, navigation, gesture handlers and paint operations require rebuilding.

## 6. Data pipeline and data ownership

The canonical history path begins with local source captures, normalized sources and `data/warehouse/nba_history.sqlite`. `tools/build_static_nba_website_data_v2_core.py` publishes versioned JSON; its manifest declares schema version **5**, a database fingerprint, source coverage and flags indicating historical API/SQLite need not be called by the browser. The normal `scripts/open_terminal.sh` then runs a **serial chain** of field normalization, optional NBA.com enrichment, materialization, dashboard rebuild, early-era totals/leaderboards, Front Office snapshot and game detail publishing before `flutter pub get` and `flutter run`. Those steps explain slow development startup; they should not be coupled to routine UI preview.

The current fast launcher path in `scripts/launch_arcside.sh --platform --fast` reuses already-generated JSON and the existing Python environment, starts both local services and calls Flutter directly. It checks for a prebuilt manifest but does not validate the *entire* corpus on each fast start; it is a developer convenience, not a correctness certificate.

**Multiple data layers to track:** older bundled Flutter `assets/data/nba/*` and `NbaTerminalSeedRepository` coexist with the newer `web/data/nba_static/*` historical website path. Existing screens use more than one repository contract (historical stats, financial/static snapshot, CBA reference data, saved views). A migration inventory must identify per-route reads and not assume all data arrives through one API.

**Source and rights discipline:** `.gitignore` excludes the primary warehouse, raw captures and generated historical corpus. GitHub code alone cannot reproduce the user's complete historical dataset. Published JSON is a frontend-neutral asset, but source attribution, rights and completeness remain separate release gates. Optional NBA.com captures must be present and normalized; missing tracking/hustle data is not imputed. Do not infer data coverage from a passing synthetic CI test.

**Data contract proposal (not implemented):** Define a manifest/schema compatibility contract covering season and season type, entity IDs, nulls/missing metrics, aliases, traded-player aggregates, player/team dossiers, game IDs, rate bases and source metadata. A new frontend should consume identical versioned static resources in both parallel implementations.

## 7. Python Lab, Excel Workspace and collaboration

### Python Lab

`web/labs/python/app.mjs` integrates **Monaco 0.52.2** loaded from a pinned CDN, uses browser-local project storage, and executes browser Python through `kernel.worker.js` using **Pyodide 0.29.1**. The worker supports Python output, tracebacks, syntax analysis, test execution and Matplotlib rendering subject to Pyodide constraints. This mode does **not** expose native Python packages or an OS terminal.

`web/labs/python/local_runtime.mjs`, `lsp_client.mjs` and `power_panel.mjs` optionally connect the editor to `python/arcside_companion` for local CPython, file synchronization, PTY, environments, pip, pytest, Ruff, Git, python-lsp-server, Jupyter kernels and debugpy DAP. The companion only listens on loopback, requires a strong bearer token and configured browser Origin and is **not a sandbox**: execution has the user's OS permissions. Windows support differs from Mac/Linux. A hosted multi-user implementation would require isolated per-user compute and a different security model, regardless of frontend framework.

### Excel Workspace

`web/labs/sheets/core.mjs` is a custom AST-based formula parser/evaluator with dependency tracking and cycle detection; it does not use `eval`. `app.mjs` renders a virtualized grid supporting large logical row ranges; current limits documented are **100,000 rows, 256 columns and a 250,000 occupied-cell/import cap**. `formula_functions.mjs` adds an extensive but incomplete set of functions. `storage.mjs` persists workbooks in browser IndexedDB. `xlsx.mjs` dynamically loads **ExcelJS 4.4.0** from a pinned CDN on import/export; fidelity is intentionally incomplete. `analytics.mjs` and `studio.mjs` provide worker-backed pivot/filter work and custom SVG charting.

`web/labs/sheets/collaboration.mjs` connects to `python/arcside_collab`. The server persists workbook rooms, hashed role grants and a revision/event journal in SQLite, and broadcasts changes through authenticated WebSockets. Concurrent different-cell changes can merge, while stale conflicting same-cell edits are rejected. The implementation is local service collaboration, **not** a deployed Google Sheets equivalent.

**Integration boundary:** `lib/widgets/arcside_lab_platform_web.dart` registers an HTML iframe view whose source is `labs/python/index.html` or `labs/sheets/index.html`; the full-tab action opens the same page. There is currently no formal shared entity/selection bus, shared authentication context, notebook dataset bridge or trade-to-spreadsheet protocol. These gaps are *architecture work*, not a reason to discard the functioning Labs.

**Documentation drift:** `docs/arcside_labs_architecture.md` describes Phase I limitations (e.g. no live DAP or Jupyter) which were addressed conditionally by later draft PRs; `docs/arcside_labs_collaboration_launch.md` documents Phase III. Versioned capability docs should become environment/branch-specific, otherwise engineering discussions will compare the wrong product versions.

## 8. Backend, trust boundaries and production considerations

The backend contains an original SQLite-centered FastAPI prototype (`backend/app/main.py`) and a composed launch app (`backend/app/main_launch.py`), which attaches many routers for auth, organization, Front Office, historical research, community, profiles, workspaces, moderation and data governance. `backend/Dockerfile` provides a non-root container and sets production-oriented auth and rate-limiting environment flags.

**But current customer Flutter code does not generally call it:** `lib/services/launch_backend_transport.dart` returns `available: false` for GET/POST/PUT/DELETE, `lib/services/launch_auth_client.dart` returns unavailable for its remote request method, and `lib/services/product_api_client.dart` explicitly throws for network calls. The frontend login controller has demo account/session flows and can restore local cached sessions. Front Office reads published static snapshots and overlays browser-local edits. Community service methods expect remote transport but encounter the disabled boundary. Therefore code presence of FastAPI routers **does not establish** that production auth/community/shared data behavior is available in the current customer web shell.

For any eventual public SaaS offering, distinguish at least these trust zones:

1. Public, immutable NBA data: static CDN/JSON; read-only, cacheable.
2. Authenticated mutable customer records: production identity, authorization, server-side persistence and audits.
3. Multi-user spreadsheet collaboration: authenticated room permissions with persistence, conflict management and recovery.
4. User code execution: a privileged, explicitly authorized sandbox/isolated compute environment; never share the existing trusted local companion on the public internet.

The developer backend defaults and container deployment defaults differ; audit actual deployment configuration before drawing conclusions about hosted protections. Browser local-storage preferences and demo sign-in do not constitute production authentication.

## 9. Tests, CI and measured status on 2026-11-18

The `main` commit `f7abf0c…` has successful **Flutter Quality**, **Historical Research Quality** and **Pre-Data Gate** workflows (GitHub runs `42936064693`, `42936064752`, `42936064703`). The Flutter Quality workflow runs Python source/contract checks, repository audits, `flutter analyze`, `flutter test` and `flutter build web --release`.

For current draft PR #86 head `3d8b0deb…`, actual GitHub Actions outcomes are:

| Workflow / run | Observed result | Scope |
| --- | --- | --- |
| [Standalone Labs QA — 44430115069](https://github.com/kshmsh1/sports-terminal/actions/runs/44430115069) | **PASS** | JavaScript syntax/unit tests and Playwright browser workspaces |
| [Labs collaboration QA — 44430114946](https://github.com/kshmsh1/sports-terminal/actions/runs/44430114946) | **PASS** | SQLite API, local launcher, Flutter Labs integration/release build, two-browser collaboration |
| [Native Python companion QA — 44430115050](https://github.com/kshmsh1/sports-terminal/actions/runs/44430115050) | **FAIL** | Companion Python/backend job passed, but browser-to-native IDE integration job failed |

The failing native-browser job had **six passing and three failing test cases** (before retry counts). The failing additions in `web/labs/tests/local_ux_audit.browser.spec.mjs` observed: no expected stdout after an IDE Run; `Invalid environment name` on environment selection; and an absent/late `.ipynb` download event. The earlier DAP, LSP and Jupyter integration tests were among the passing cases. The logs **do not prove** whether each new failure is a product defect, UI test setup issue, or both. Preserve screenshots/traces and reproduce before classifying or fixing. Do not call the branch completely green.

What is covered: meaningful backend contract tests, Flutter/widget rules, static-data normalization, JS formula/analytics unit tests, browser keyboard/workflow journeys and authenticated local-service testing. What is **not** established by this audit: full historical production-data correctness for all seasons, Chrome/Safari/Firefox parity, WCAG audit with assistive technologies, large-data/browser memory benchmarks, production multi-user tenancy/security review, end-to-end hosted authentication, cross-product workflows, or complete Excel/VS Code parity.

## 10. Risk register, prioritized

| Priority | Risk / observation | Evidence | Required disposition before a migration decision |
| --- | --- | --- | --- |
| **P0** | **Competing PRs and incomplete shared baseline** | PRs #78–86; #81 standalone history widget not in #86 | Name canonical integration ref; disposition overlapping PRs; establish parity matrix |
| **P0** | **Undefined production boundary for auth/mutable collaboration** | Disabled Flutter backend/auth transports; demo accounts; standalone local collaboration | Decide which services are intentionally local and which are required for a hosted product |
| **P1** | **Native Python browser CI red** | Run 44430115050; three failing native UI cases | Reproduce from artifact traces and separate product defects from test assumptions before claiming readiness |
| **P1** | **Dart business semantics mixed with large UI modules** | Large visualization/trade screens; several independent Dart engines | Capture golden input/output contracts for stats, rates, CBA and interaction state |
| **P1** | **No canonical, typed cross-framework front-end data contract** | Widespread dynamic maps and aliases | Formal schemas, validation, version pinning and fixture corpus |
| **P1** | **Large historical outputs absent from source control** | `.gitignore` excludes canonical DB/static corpus | Define reproducible fixture and independently validated sample manifest for dual-frontends |
| **P1** | **Security model does not translate to hosted local execution** | Loopback companion executes with OS privileges, room-only collaboration | Preserve trusted-local semantics; design isolation/identity separately if offering cloud compute |
| **P2** | **Top-level screen state lacks shareable URL addresses** | `CanonicalProductShell._selected` | Define route IDs and serialized URL state before changing shell |
| **P2** | **Browser storage and import fidelity risk** | Flutter `SharedPreferences` keys; Sheets IndexedDB; partial XLSX | Versioned migrations, backup/export compatibility test fixtures |
| **P2** | **Startup pipeline over-coupled to preview** | `open_terminal.sh` chains many scripts before Flutter; `--fast` bypasses them | Keep fast development lane, separate data-build task and readiness checks |
| **P2** | **CDN/offline and browser support assumptions** | Monaco/Pyodide/ExcelJS pinned CDNs, local loopback bridge | Dependency vendoring/CSP plan, cross-browser evidence and offline behavior |
| **P2** | **Documentation/version drift and legacy surface sprawl** | Phase I Labs doc versus Phase III; old terminal screens | Maintain active-route/source-of-truth inventory, archive unused docs only after review |

P0 denotes a **decision blocker**, not proof of a live exploit or irrecoverable defect. P1 is serious migration/QA debt; P2 is expected engineering follow-up.

## 11. Reuse ledger

| Component | Reuse in a browser-first React alternative | Why | Migration burden |
| --- | --- | --- | --- |
| Canonical historical SQLite warehouse | **Keep** | Language-independent compiled data foundation | Low; must reproduce sources and schema |
| Python ingest/normalization/materializers | **Keep** | Already independent of Flutter | Low–medium for build/deploy orchestration |
| Static season/player/team/game JSON + manifest | **Keep** | Reads over ordinary same-origin HTTP | Low; TS schemas and adapters needed |
| Front Office static publisher | **Keep** | Independently publishes immutable read model | Low–medium; editable workflows separate |
| FastAPI routers and database model | **Conditional keep** | Backend-independent implementation exists | Medium: unify actual frontend transport and deployment/identity |
| Python Lab Monaco, Pyodide and JS client | **Keep, integrate directly** | Already browser-native | Low–medium: component shell, styling and cross-workspace event bridge |
| Native Python companion | **Keep for trusted local mode** | Separate executable service | Medium for new frontend integration; **high** if changing to hosted execution |
| Excel grid, parser, analytics, storage, XLSX adapter | **Keep, integrate directly** | Already browser-native | Low–medium for React embedding and events; feature parity still separate |
| Sheets collaboration API and SQLite journal | **Keep for local workflow** | Existing independent authenticated protocol | Medium for future production identity, persistence and tenancy |
| Stats/research/trade algorithms currently in Dart | **Keep specifications/tests; port or expose** | Valuable, tested analytical rules but Dart code is not callable from TypeScript as-is | **High** unless extracted to a shared service |
| Flutter screen widgets, charts and `CustomPainter` | **Reimplement** | UI/runtime-specific code | **High**, particularly Visualization Studio and Trade Machine |
| Flutter shell, navigation, theme, local state | **Reimplement/migrate** | Framework-specific routing/state | Medium, plus saved-state compatibility |
| Dormant/prototype screens | **Do not migrate automatically** | Not necessarily reachable in customer shell | Requires reachability proof |

## 12. Architecture decision questions left open for Phase 2

This audit intentionally **does not choose React, Next.js, Vue, or Flutter**. It establishes the questions to answer with comparative evidence:

1. Can a browser-native stack deliver better drag/drop, accessible grid interactions, interactive plots, dockable windows and multi-workspace interoperability **for Arcside's actual feature requirements**, rather than theoretical library catalogues?
2. What is the realistic time to port chart interactions and CBA/stats business rules with full behavior parity? Which should instead become a shared API or independently packaged algorithm?
3. How much performance advantage is measurable with authentic season-sized data (interaction latency, memory, bundle size, startup, responsiveness)?
4. Can React host the existing Labs with shared identity, data selection and keyboard commands without duplicating their engines or compromising security?
5. Will Arcside be browser-first indefinitely, or is a native mobile product a first-class product requirement? Flutter remains strong if unified native UI is vital.
6. Where should long-term authoritative state live: browser, hosted API, isolated workspaces, or read-only static build outputs?

### Evidence required for a fair Phase 3 proof of concept

Use a **matched** route/data snapshot; same entity IDs, season selection, regular/playoff split, rate basis, qualification minimums, missing-value behavior and hover/zoom/filter affordances. Candidate: Visualization Studio (hardest chart interaction) or Player Compare (good state/table reproducibility). Measure cold/warm startup, bundle size, main-thread blocking, memory and user interaction latency in Chrome and Safari. Run task-based UX/accessibility checks. Keep the Flutter implementation running as the reference. No framework migration is authorized until these results and the P0 dispositions are reviewed.

## 13. Immediate non-feature decisions recommended

- **Freeze product feature expansion** while preserving all existing branches and generated local data.
- Treat **PR #86 head as the most complete Labs *development* snapshot**, but treat `main` as production-like baseline; do not claim they are merged.
- Keep **PR #81's player-profile parity** as a separately tracked regression requirement.
- Record the **red native-browser CI** and avoid broad claims of IDE parity.
- Do not change CBA, stat definitions, entity keys or static archive semantics merely to facilitate a frontend rewrite.
- Prepare versioned fixture contracts and an active-route reachability inventory before experimental framework code is written.

## 14. Evidence pointers / reproducibility

Inspect these sources at the pinned `3d8b0deb…` audit snapshot unless marked as `main`:

- Entry and navigation: [`lib/main.dart`](../../lib/main.dart), [`lib/widgets/app_entry_gate.dart`](../../lib/widgets/app_entry_gate.dart), [`lib/widgets/canonical_product_shell.dart`](../../lib/widgets/canonical_product_shell.dart).
- Browser Labs: [`lib/widgets/arcside_lab_platform_web.dart`](../../lib/widgets/arcside_lab_platform_web.dart), [`web/labs/python/app.mjs`](../../web/labs/python/app.mjs), [`web/labs/sheets/core.mjs`](../../web/labs/sheets/core.mjs).
- Domain: [`lib/services/nba_stats_workstation_engine.dart`](../../lib/services/nba_stats_workstation_engine.dart), [`lib/services/trade_machine_engine.dart`](../../lib/services/trade_machine_engine.dart), [`lib/services/nba_research_query_engine.dart`](../../lib/services/nba_research_query_engine.dart).
- Data: [`lib/services/website_nba_static_repository.dart`](../../lib/services/website_nba_static_repository.dart), [`lib/services/sports_terminal_static_json_loader.dart`](../../lib/services/sports_terminal_static_json_loader.dart), [`tools/build_static_nba_website_data_v2_core.py`](../../tools/build_static_nba_website_data_v2_core.py), [`scripts/open_terminal.sh`](../../scripts/open_terminal.sh).
- Mutable services: [`lib/services/launch_backend_transport.dart`](../../lib/services/launch_backend_transport.dart), [`lib/services/launch_auth_client.dart`](../../lib/services/launch_auth_client.dart), [`backend/app/main_launch.py`](../../backend/app/main_launch.py), [`python/arcside_companion/arcside_companion/security.py`](../../python/arcside_companion/arcside_companion/security.py), [`python/arcside_collab/arcside_collab/server.py`](../../python/arcside_collab/arcside_collab/server.py).
- CI: [Flutter Quality](../../.github/workflows/flutter_quality.yml), [Labs browser](../../.github/workflows/labs_quality.yml), [Native Python](../../.github/workflows/labs_power_quality.yml), [Sheets collaboration](../../.github/workflows/labs_collaboration_quality.yml).

**Final Phase 1 disposition:** The architecture is feasible to migrate **incrementally**, with substantial reuse and measurable but significant Dart UI/domain porting cost. The audit **does not** show that Dart/Flutter prevents Arcside's desired UI. It shows that browser-native tooling integration, large single-file presentations, disconnected mutable-service contracts and baseline fragmentation are the immediate architectural constraints. Next step: evaluate alternative stacks against these concrete requirements, not against a generic framework popularity claim.
