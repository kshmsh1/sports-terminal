# Sports Terminal Product Launch Plan

Sports Terminal is now being shaped as an NBA-first consumer product with an internal operator layer, rather than a long list of raw data tabs. The product should feel like a modern sports app on the surface, while retaining deep terminal-grade analytics behind the scenes.

## Completed foundation

| Area | Status | Notes |
| --- | --- | --- |
| NBA data warehouse | Strong MVP | 2024-25 Basketball Reference warehouse, normalized tables, seed JSON export, validation, and Flutter asset sync are working. |
| Generated NBA asset layer | Strong MVP | Flutter can load teams, players, games, player season totals, team game logs, leaderboards, highs, search index, validation, and source metadata. |
| Internal analytics lab | Strong prototype | NBA 2025 analytical surfaces validate workflows: leaders, screeners, splits, trends, matchups, details, QA, source maps, and front-office boards. |
| Consumer shell | Stronger first version | Main navigation is product-oriented: Home, NBA, Fantasy, Community, Articles, Workspace, Messages, Profile, Admin, Internal Lab. |
| Visual identity | Improving | The shell now uses a more distinctive navy/orange/blue sports identity, floating nav, gradient backdrops, glass pills, and less generic card layout. |
| NBA hub | First real version | NBA hub supports player, team, and game page modes powered by generated data. |
| Fantasy | First interactive version | Fantasy War Room includes target board, simple fantasy scoring proxy, and local watchlist interactions. |
| Community | First interactive version | Community Arena includes boards, demo threads, likes, replies roadmap, and moderation checklist. |
| Articles | First real version | Articles Arena frames editorial, user blogs, article queues, CMS needs, and entity-attached writing. |
| Messaging | First real version | Messages Arena frames DMs, group rooms, support/data issue chats, safety, and notification needs. |
| Profile | First real version | Profile Clubhouse introduces local settings switches and favorite-team chips. |
| Admin | First real version | Admin Ops Center introduces pipeline metrics, operator lanes, CMS/moderation/billing/data ops roadmap. |
| Workspace | First real version | Excel-inspired workbook UI has a title bar, ribbon, formula bar, grid, active cell, templates, sheet tabs, and status bar. |
| Theme system | First version | Light/dark toggle exists in the shell. Light mode uses the navy Sports Terminal identity. |
| Legal footer | First version | About, Contact, Privacy Policy, and Terms & Conditions are footer-linked pages. |

## Current product architecture

| Surface | User purpose | Current implementation |
| --- | --- | --- |
| Home | Personalized sports dashboard | Arena-style landing page with data health, leaders, recent games, big nights, quick actions, and launch path. |
| NBA | League intelligence hub | Player, team, and game pages in one surface with search, favorites/watchlist state, stat cards, and tables. |
| Fantasy | Fantasy workflow center | Fantasy War Room with player target board, watchlist, scoring proxy, and launch checklist. |
| Community | Social layer | Community Arena with boards, threads, like interactions, replies roadmap, and moderation checklist. |
| Articles | Editorial/blog layer | Articles Arena with featured story template, editorial queue, and CMS launch needs. |
| Workspace | Excel-like analysis workspace | Editable local workbook-style UI with ribbon, formula bar, templates, sheet tabs, and status bar. |
| Messages | Private/group communication | Messaging Arena with inbox prototype, room view, chat bubbles, and safety/persistence roadmap. |
| Profile | User identity and settings | Profile Clubhouse with session identity, local settings switches, and favorite-team chips. |
| Admin | Operator console | Admin Ops Center with data health metrics, kanban-style operator lanes, and launch checklist. |
| Internal Lab | Analyst/operator tooling | Consolidated destination for the raw NBA 2025 analytics surfaces. |

## Launch-critical gaps

| Area | What remains |
| --- | --- |
| Backend | Persistent users, profiles, favorites, watchlists, workspaces, posts, comments, messages, notifications, billing, admin actions, and moderation. |
| Auth | Real sign-up, login, provider/password handling, email verification, account recovery, deletion/export, and role management. |
| NBA routes | Proper URLs and routing for player pages, team pages, game pages, standings, schedules, and leaders. |
| Workspace engine | Better cell editing, formulas, copy/paste, keyboard navigation, resizing, saved sheets, templates, import/export, and sharing. |
| Community backend | Create posts, comments, likes, saves, follows, reports, moderation queue, bans, and content safety. |
| Messaging backend | DMs, group rooms, unread counts, blocking, reporting, and notification delivery. |
| Fantasy features | Persistent watchlists, league imports, roster management, scoring settings, waiver boards, matchup tools, and alerts. |
| CMS | Admin article editor, drafts, publish/unpublish, featured cards, tags, author pages, and moderation. |
| Billing | Plans, trials, Stripe or equivalent, invoices, cancellation, entitlements, and usage limits. |
| Live data | Current-season refreshes, live scores, injury feeds, scheduled jobs, and eventually official/commercial data agreements. |
| Twitter/X feed | API access, allowed accounts, caching, compliance, and admin configuration. |
| Production readiness | Hosting, analytics, error tracking, monitoring, backups, security review, privacy review, and legal review. |

## Near-term build sequence

1. Add local persistence for theme, favorites, player watchlists, profile settings, community likes, and workspace sheets.
2. Make NBA player/team/game pages feel like real routed pages, then add actual URLs/routing.
3. Improve the workspace engine: direct cell editing, keyboard navigation, formulas, copy/paste, and import/export.
4. Create initial backend schema for users, profiles, favorites, posts, comments, workspaces, messages, and admin roles.
5. Build community primitives with moderation hooks.
6. Build admin data-ops/CMS/moderation views that can eventually control the platform.
7. Add billing/subscription scaffolding once account persistence exists.
8. Add live/current-season data only after the product shell and persistence model are stable.

## Design direction

| Principle | Direction |
| --- | --- |
| Sports-first, not generic SaaS | Use stronger sports-product language, bolder hero areas, data chips, live/status treatments, and less templated card grids. |
| Navy identity | Keep navy as the light-mode brand anchor, supported by orange and electric blue accents. |
| Consumer first | Normal users should see Home, NBA, Fantasy, Community, Articles, Workspace, Messages, Profile. Internal tooling belongs in Admin/Internal Lab. |
| Data underneath, not in the user's face | Raw tables and QA screens should feed friendly player/team/game/fantasy pages rather than dominate navigation. |
| Launchable surface, expandable core | Prototype with local state now, then replace local state with backend persistence once schema/auth are ready. |
