# Sports Terminal Product Launch Plan

Sports Terminal is now being shaped as an NBA-first consumer product with an internal operator layer, rather than a long list of raw data tabs. The product should feel like a modern sports app on the surface, while retaining deep terminal-grade analytics behind the scenes.

## Completed foundation

| Area | Status | Notes |
| --- | --- | --- |
| NBA data warehouse | Strong MVP | 2024-25 Basketball Reference warehouse, normalized tables, seed JSON export, validation, and Flutter asset sync are working. |
| Generated NBA asset layer | Strong MVP | Flutter can load teams, players, games, player season totals, team game logs, leaderboards, highs, search index, validation, and source metadata. |
| Internal analytics lab | Strong prototype | NBA 2025 analytical surfaces validate workflows: leaders, screeners, splits, trends, matchups, details, QA, source maps, and front-office boards. |
| Consumer shell | Stronger first version | Main navigation is product-oriented: Home, NBA, Strategy, Front Office, Fantasy, Community, Articles, Workspace, Messages, Profile, Admin. Backend and Internal Lab remain optional operator/drawer destinations. |
| Visual identity | Improving | The shell uses a navy/orange/blue sports identity, floating nav, gradient backdrops, glass pills, and less generic card layout. |
| Competitive strategy | New product input | `docs/competitive_landscape.md` and `docs/competitive_feature_backlog.md` turn StatMuse/NBA.com/Cleaning the Glass/PBP/cap/trade/fantasy/community competitors into build targets. |
| Strategy surface | First visible version | The new Strategy tab turns the competitor map into an in-product market map, product pillars, moat, and immediate build sequence. |
| Front Office surface | First visible version | The new Front Office tab creates a local scenario lab using generated team/player data, transparent basketball-value proxy, local scenario persistence, and future salary/cap/CBA slots. |
| Local persistence | Expanded first version | The product has shared local persistence for theme, workbook cells, selected sheet, NBA mode, selected NBA entities, favorite teams, player watchlist, fantasy query, community board, liked posts, profile settings, backend sync metadata, and front-office scenario state. |
| NBA hub | Persisted first version | NBA hub supports player, team, and game page modes powered by generated data, with locally persisted favorites, watchlists, last-opened pages, and selected mode. |
| Fantasy | Persisted first version | Fantasy War Room includes target board, simple fantasy scoring proxy, local search persistence, and shared player watchlist persistence. |
| Community | Persisted first version | Community Arena includes boards, demo threads, persisted local likes, selected board persistence, replies roadmap, and moderation checklist. |
| Articles | First real version | Articles Arena frames editorial, user blogs, article queues, CMS needs, and entity-attached writing. |
| Messaging | First real version | Messages Arena frames DMs, group rooms, support/data issue chats, safety, and notification needs. |
| Profile | Persisted first version | Profile Clubhouse is routed in the main shell and persists public profile, email digest, fantasy alerts, and favorite-team chips locally. |
| Admin | First real version | Admin Ops Center introduces pipeline metrics, operator lanes, CMS/moderation/billing/data ops roadmap. |
| Backend Sync Center | Optional operator bridge | The Backend tab can connect to the FastAPI API, check health/readiness, create or reuse a backend user, sync local state, and exercise major API domains, but normal app testing no longer requires running the backend separately. |
| Workspace | Stronger first version | Excel-inspired workbook UI has a title bar, ribbon, formula bar, editable grid cells, active cell, basic formulas, local autosave, templates, sheet tabs, and status bar. |
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
| NBA | League intelligence hub | Player, team, and game pages in one surface with search, persisted favorite teams, persisted player watchlist, persisted selected mode, and last-opened entity state. |
| Strategy | Product/market map | Competitor-informed market map, product pillars, moat, and build sequence for beating fragmented NBA tools. |
| Front Office | Trade/cap/scenario workspace | Local scenario lab with team selectors, player packages, value-balance proxy, local save, and future salary/CBA slots. |
| Fantasy | Fantasy workflow center | Fantasy War Room with player target board, persisted search, shared persisted watchlist, scoring proxy, and launch checklist. |
| Community | Social layer | Community Arena with boards, threads, persisted local likes, selected board persistence, replies roadmap, and moderation checklist. |
| Articles | Editorial/blog layer | Articles Arena with featured story template, editorial queue, and CMS launch needs. |
| Workspace | Excel-like analysis workspace | Editable local workbook-style UI with ribbon, formula bar, templates, sheet tabs, local autosave, and basic formulas like SUM/AVG/MIN/MAX. |
| Messages | Private/group communication | Messaging Arena with inbox prototype, room view, chat bubbles, and safety/persistence roadmap. |
| Profile | User identity and settings | Persisted Profile Clubhouse with session identity, local settings switches, and favorite-team chips. |
| Admin | Operator console | Admin Ops Center with data health metrics, kanban-style operator lanes, and launch checklist. |
| Backend | Optional API/sync control plane | Backend Sync Center can push local Flutter state into the FastAPI + SQLite backend and verify major API domains, but it is not required for normal Flutter testing. |
| Internal Lab | Analyst/operator tooling | Consolidated destination for the raw NBA 2025 analytics surfaces. |

## Launch-critical gaps

| Area | What remains |
| --- | --- |
| Backend | SQLite persistence exists locally, but launch still needs hosted Postgres or equivalent, migrations, repository/service layering, environment separation, logging, rate limits, and deployment. |
| Auth | Real sign-up, login, provider/password handling, sessions/JWTs, email verification, account recovery, deletion/export, and role management. |
| Flutter/backend wiring | Backend Sync Center exists, but individual product screens still need direct API sync while keeping local offline fallback. |
| NBA routes | Proper URLs and routing for player pages, team pages, game pages, standings, schedules, and leaders. |
| Player pages | Bio/headshots, full game logs, trends, role/archetype, impact, shot profile, on/off, fantasy, contract, articles, comments, cross-device watchlist persistence, comparison modules. |
| Team pages | Names/logos/colors, roster page, schedule/results, standings context, splits, lineups, salary/cap table, trade needs, team articles, fan discussion. |
| Game pages | Full box score, advanced box, recap, source links, play-by-play, lineup stints, momentum, player logs, team stats, comments/discussion. |
| Workspace engine | Better formula coverage, copy/paste, keyboard navigation refinement, resizing, saved multi-sheet workbooks, import/export, sharing, and direct backend sync. |
| Front-office simulator | Real salary/cap feeds, CBA legality, exceptions, apron/tax logic, pick inventory, trade machine validation, free-agent tracker, draft board, and scenario sharing. |
| Community backend | SQLite-backed posts/comments/reactions/reports and backend sync exercise exist, but production UI wiring, moderation queues, bans, mutes, blocks, follows, saves, reputation, and audit events remain. |
| Messaging backend | SQLite-backed conversations/messages and backend sync exercise exist, but production UI wiring, unread counts, blocking, reporting, and notification delivery remain. |
| Fantasy features | Backend-synced league imports, roster management, scoring settings, dynasty value context, waiver boards, matchup tools, and alerts. |
| CMS | Article endpoints and sync exercise exist, but admin editor UI, revisions, publish workflow, featured cards, tags, author pages, moderation, and audit history remain. |
| Billing | Plans/subscription placeholders exist, but paid tiers, trials, Stripe or equivalent, invoices, cancellation, entitlements, and usage limits need implementation. |
| Live data | Current-season refreshes, live scores, injury feeds, scheduled jobs, and eventually official/commercial data agreements. |
| Twitter/X feed | API access, allowed accounts, caching, compliance, and admin configuration. |
| Production readiness | Hosting, analytics, error tracking, monitoring, backups, security review, privacy review, legal review, and launch process. |

## Near-term build sequence

1. Validate Flutter after the Strategy/Front Office shell pass.
2. Upgrade NBA player/team/game detail panels into command centers with source/method panels, role cards, impact slots, workspace exports, and entity discussion modules.
3. Make Front Office more real: package builder, pick inventory placeholders, contract/cap cards, scenario compare, and workspace export.
4. Wire individual screens directly to `ProductApiClient` only when backend testing is needed; normal UI development should remain backend-optional.
5. Add auth/session scaffolding once backend identity needs to stop being a local demo identity.
6. Add actual URLs/routing for player/team/game pages.
7. Improve the workspace engine: copy/paste, drag fill, column resizing, more formulas, import/export, and backend sync.
8. Build community primitives with moderation hooks and API persistence.
9. Build messaging after block/report/mute controls and moderation audit events are real.
10. Add billing/subscription scaffolding once account persistence exists.

## Design direction

| Principle | Direction |
| --- | --- |
| Sports-first, not generic SaaS | Use stronger sports-product language, bolder hero areas, data chips, live/status treatments, distinct layout rhythm, and fewer identical card grids. |
| Navy identity | Keep navy as the light-mode brand anchor, supported by orange and electric blue accents. |
| Consumer first | Normal users should see Home, NBA, Strategy, Front Office, Fantasy, Community, Articles, Workspace, Messages, Profile. Internal tooling belongs in Admin/Backend/Internal Lab. |
| Data underneath, not in the user's face | Raw tables and QA screens should feed friendly player/team/game/fantasy pages rather than dominate navigation. |
| Competitor-informed build | Every new feature should map back to a competitor job and improve it through integration, persistence, source transparency, workspace export, or community. |
| Backend optional during UI build | The local backend is useful and working, but normal Flutter iteration should not require running it separately. |
