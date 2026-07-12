# Sports Terminal Product Launch Plan

Sports Terminal is now being shaped as an NBA-first consumer product with an internal operator layer, rather than a long list of raw data tabs. The product should feel like a modern sports app on the surface, while retaining deep terminal-grade analytics behind the scenes.

## Completed foundation

| Area | Status | Notes |
| --- | --- | --- |
| NBA data warehouse | Strong MVP | 2024-25 Basketball Reference warehouse, normalized tables, seed JSON export, validation, and Flutter asset sync are working. |
| Generated NBA asset layer | Strong MVP | Flutter can load teams, players, games, player season totals, team game logs, leaderboards, highs, search index, validation, and source metadata. |
| Internal analytics lab | Strong prototype | NBA 2025 analytical surfaces validate workflows: leaders, screeners, splits, trends, matchups, details, QA, source maps, and front-office boards. |
| Consumer shell | Stronger first version | Main navigation is product-oriented: Home, Stats, NBA, Trade Machine, Advanced, Front Office, Strategy, Fantasy, Team Blogs, Community, Articles, Workspace, Python Lab, Messages, Profile, Admin. Backend and Internal Lab remain optional operator/drawer destinations. |
| Visual identity | Improving | The shell uses a navy/orange/blue sports identity, floating nav, gradient backdrops, glass pills, and less generic card layout. |
| Competitive strategy | New product input | `docs/competitive_landscape.md` and `docs/competitive_feature_backlog.md` turn StatMuse/NBA.com/Cleaning the Glass/PBP/cap/trade/fantasy/community competitors into build targets. |
| NBA Stats Center | First visible version | Official NBA.com/stats-style player table with default per-game view, query box, season/basis controls, and hidden OREB/DREB expansion. |
| Trade Machine | First visible version | Multi-team trade-machine shell with operating year, selected teams, active roster assets, draft picks, draft rights, cash, free agents, exceptions, cap/apron/tax cards, and trade result panels. |
| Advanced NBA tools | First visible version | Player Dashboard, Lineups, Comparisons, Tier Lists, and Matchups surfaces define the advanced analytics workflows that need to become real. |
| Python Lab | First visible version | Embedded notebook-style UI with starter code, console, data resources, and documentation for a future sandboxed Python execution environment. |
| Team Blogs | First visible version | Dedicated team-blog network surface for all loaded teams, with CMS/community/stat modules defined as product requirements. |
| Strategy surface | First visible version | Strategy tab turns the competitor map into an in-product market map, product pillars, moat, and immediate build sequence. |
| Front Office surface | First visible version | Front Office tab creates a local scenario lab using generated team/player data, transparent basketball-value proxy, local scenario persistence, and future salary/cap/CBA slots. |
| Local persistence | Expanded first version | Shared local persistence covers theme, workbook cells, selected sheet, NBA mode, selected NBA entities, favorite teams, player watchlist, fantasy query, community board, liked posts, profile settings, backend sync metadata, front-office scenarios, NBA Stats query, and Trade Machine state. |
| NBA hub | Persisted first version | NBA hub supports player, team, and game page modes powered by generated data, with locally persisted favorites, watchlists, last-opened pages, and selected mode. |
| Fantasy | Persisted first version | Fantasy War Room includes target board, simple fantasy scoring proxy, local search persistence, and shared player watchlist persistence. |
| Community | Persisted first version | Community Arena includes boards, demo threads, persisted local likes, selected board persistence, replies roadmap, and moderation checklist. |
| Articles | First real version | Articles Arena frames editorial, user blogs, article queues, CMS needs, and entity-attached writing. |
| Messaging | First real version | Messages Arena frames DMs, group rooms, support/data issue chats, safety, and notification needs. |
| Profile | Persisted first version | Profile Clubhouse is routed in the main shell and persists public profile, email digest, fantasy alerts, and favorite-team chips locally. |
| Admin | First real version | Admin Ops Center introduces pipeline metrics, operator lanes, CMS/moderation/billing/data ops roadmap. |
| Backend Sync Center | Optional operator bridge | Backend tab can connect to the FastAPI API, check health/readiness, create or reuse a backend user, sync local state, and exercise major API domains, but normal app testing does not require running the backend separately. |
| Workspace | Stronger first version | Excel-inspired workbook UI has a title bar, ribbon, formula bar, editable grid cells, active cell, basic formulas, local autosave, templates, sheet tabs, and status bar. |
| Workspace / Python docs | First guide | `docs/workspace_and_python_lab_guide.md` defines formula roadmap, sports-object formulas, notebook helper APIs, export flows, and sandbox requirements. |
| Theme system | First persisted version | Light/dark toggle exists and persists locally. Light mode uses the navy Sports Terminal identity. |
| Backend schema | First draft | `backend/schema_v1.sql` maps product domains into launch database tables. |
| Backend API | Durable local prototype | `backend/app/main.py` exposes FastAPI endpoints backed by local SQLite for users, profiles, settings, personalization, workspaces, community, moderation, messaging, CMS, billing, feature flags, data sources, and pipeline runs. |
| Backend dev tooling | Working | Backend scripts run on macOS/Python 3.14, build the venv, install compatible dependencies, launch Uvicorn, and run a smoke test. |
| Flutter API client | Expanded scaffold | `lib/services/product_api_client.dart` covers health/readiness, users, profile/settings, personalization, workbooks, community posts/reactions/reports, messaging, CMS/articles, billing/subscriptions, feature flags, data sources, and pipeline runs. |
| Legal footer | First version | About, Contact, Privacy Policy, and Terms & Conditions are footer-linked pages. |
| Analyzer hygiene | Improved | Legacy internal helper warnings are no longer allowed to interrupt product build loops, while runtime/compiler errors still remain blocking. |

## Current product architecture

| Surface | User purpose | Current implementation |
| --- | --- | --- |
| Home | Personalized sports dashboard | Arena-style landing page with data health, leaders, recent games, big nights, quick actions, and launch path. |
| Stats | Official-style player statistics | Per-game default player table, query field, basis/season controls, source/method panel, and expandable rebound breakdown. |
| NBA | League intelligence hub | Player, team, and game pages in one surface with search, persisted favorite teams, persisted player watchlist, selected mode, and last-opened entity state. |
| Trade Machine | Multi-team transaction builder | Operating-year selector, add/remove teams, active roster, draft picks, draft rights, cash, free agents, exceptions, cap/apron/tax cards, and result panels. |
| Advanced | Advanced NBA workflows | Player dashboard, lineup builder, head-to-head comparisons, tier lists, and matchup-analysis shells. |
| Front Office | Scenario workspace | Local scenario lab with team selectors, player packages, value-balance proxy, local save, and future salary/CBA slots. |
| Strategy | Product/market map | Competitor-informed market map, product pillars, moat, and build sequence for beating fragmented NBA tools. |
| Fantasy | Fantasy workflow center | Fantasy War Room with player target board, persisted search, shared persisted watchlist, scoring proxy, and launch checklist. |
| Team Blogs | Dedicated team publication layer | Blog-homepage surface for every team, with recaps, roster notes, trade ideas, community, and CMS modules defined. |
| Community | Social layer | Community Arena with boards, threads, persisted local likes, selected board persistence, replies roadmap, and moderation checklist. |
| Articles | Editorial/blog layer | Articles Arena with featured story template, editorial queue, and CMS launch needs. |
| Workspace | Excel-like analysis workspace | Editable local workbook-style UI with ribbon, formula bar, templates, sheet tabs, local autosave, and basic formulas like SUM/AVG/MIN/MAX. |
| Python Lab | Embedded analysis IDE | Notebook-style UI with starter code, console, data resource list, and documentation for Python/data visualization workflows. |
| Messages | Private/group communication | Messaging Arena with inbox prototype, room view, chat bubbles, and safety/persistence roadmap. |
| Profile | User identity and settings | Persisted Profile Clubhouse with session identity, local settings switches, and favorite-team chips. |
| Admin | Operator console | Admin Ops Center with data health metrics, kanban-style operator lanes, and launch checklist. |
| Backend | Optional API/sync control plane | Backend Sync Center can push local Flutter state into the FastAPI + SQLite backend and verify major API domains, but it is not required for normal Flutter testing. |
| Internal Lab | Analyst/operator tooling | Consolidated destination for raw NBA 2025 analytics surfaces. |

## Launch-critical gaps

| Area | What remains |
| --- | --- |
| Backend | SQLite persistence exists locally, but launch still needs hosted Postgres or equivalent, migrations, repository/service layering, environment separation, logging, rate limits, and deployment. |
| Auth | Real sign-up, login, provider/password handling, sessions/JWTs, email verification, account recovery, deletion/export, and role management. |
| Flutter/backend wiring | Backend Sync Center exists, but individual product screens still need direct API sync when backend testing becomes necessary. |
| NBA routes | Proper URLs and routing for player pages, team pages, game pages, standings, schedules, leaders, and search results. |
| Stats query engine | Natural-language/stat-query parser needs real query planning, more operators, age fields, playoff splits, official stat categories, sorting, pagination, and export. |
| Player pages | Bio/headshots, full game logs, trends, role/archetype, impact, shot profile, on/off, fantasy, contract, articles, comments, cross-device watchlist persistence, comparison modules. |
| Team pages | Names/logos/colors, roster page, schedule/results, standings context, splits, lineups, injuries, transactions, salary/cap table, trade needs, team articles, fan discussion. |
| Game pages | Full box score, advanced box, recap, source links, play-by-play, lineup stints, momentum, player logs, team stats, comments/discussion. |
| Workspace engine | Better formula coverage, copy/paste, keyboard navigation refinement, resizing, saved multi-sheet workbooks, import/export, sharing, and direct backend sync. |
| Python Lab | Real sandboxed execution through Pyodide or backend kernel, package controls, chart rendering, dataframe display, saved notebooks, exports, quotas, and security limits. |
| Trade Machine | Real 2026 offseason rosters, salary/cap feeds, CBA legality, exceptions, apron/tax logic, pick inventory, trade restrictions, draft rights, free-agent renunciation, cash tracking, and scenario sharing. |
| Salary/cap trackers | Team-by-season cap, apron, tax, signing exceptions, multi-year cap/cash, combined AAV, and player cap-hit trackers. |
| Advanced tools | Real lineups, on/off, WOWY, player tracking, defenders faced, players guarded, shot-profile comparisons, closest comps, regular-season/playoff splits. |
| Community backend | SQLite-backed posts/comments/reactions/reports and backend sync exercise exist, but production UI wiring, moderation queues, bans, mutes, blocks, follows, saves, reputation, and audit events remain. |
| Messaging backend | SQLite-backed conversations/messages and backend sync exercise exist, but production UI wiring, unread counts, blocking, reporting, and notification delivery remain. |
| Fantasy features | Backend-synced league imports, roster management, scoring settings, dynasty value context, waiver boards, matchup tools, and alerts. |
| CMS | Article endpoints and sync exercise exist, but admin editor UI, revisions, publish workflow, featured cards, tags, author pages, moderation, and audit history remain. |
| Billing | Plans/subscription placeholders exist, but paid tiers, trials, Stripe or equivalent, invoices, cancellation, entitlements, and usage limits need implementation. |
| Live data | Current-season refreshes, live scores, injury feeds, scheduled jobs, and eventually official/commercial data agreements. |
| Production readiness | Hosting, analytics, error tracking, monitoring, backups, security review, privacy review, legal review, and launch process. |

## Near-term build sequence

1. Validate Flutter after the Stats/Trade Machine/Advanced/Python/Team Blogs pass.
2. Upgrade NBA player/team/game detail panels into command centers with source/method panels, role cards, impact slots, workspace exports, and entity discussion modules.
3. Make Trade Machine more real: package builder, picks, cash, exception selection, cap table slots, scenario compare, and workspace export.
4. Improve NBA Stats query parsing, official-style columns, playoff toggle, sorting, pagination, and export-to-workspace.
5. Improve the workspace engine: copy/paste, drag fill, column resizing, more formulas, import/export, and backend sync.
6. Turn Python Lab from scaffold into sandboxed execution with charts and dataframe display.
7. Build team pages with statistics, schedule, roster, depth chart, injuries, and transactions.
8. Build community primitives with moderation hooks and API persistence.
9. Build messaging after block/report/mute controls and moderation audit events are real.
10. Add billing/subscription scaffolding once account persistence exists.

## Design direction

| Principle | Direction |
| --- | --- |
| Sports-first, not generic SaaS | Use stronger sports-product language, bolder hero areas, data chips, live/status treatments, distinct layout rhythm, and fewer identical card grids. |
| Navy identity | Keep navy as the light-mode brand anchor, supported by orange and electric blue accents. |
| Consumer first | Normal users should see Home, Stats, NBA, Trade Machine, Advanced, Front Office, Strategy, Fantasy, Team Blogs, Community, Articles, Workspace, Python Lab, Messages, Profile. Internal tooling belongs in Admin/Backend/Internal Lab. |
| Data underneath, not in the user's face | Raw tables and QA screens should feed friendly player/team/game/fantasy/trade/workspace pages rather than dominate navigation. |
| Launchable surface, expandable core | Prototype with local persistence, backend sync, and local backend now, then replace local/demo identity with hosted backend persistence once auth/deployment are ready. |
