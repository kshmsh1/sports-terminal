# Sports Terminal Product Launch Plan

Sports Terminal is now being shaped as an NBA-first consumer product with an internal operator layer, rather than a long list of raw data tabs. The product should feel like a modern sports app on the surface, while retaining deep terminal-grade analytics behind the scenes.

## Completed foundation

| Area | Status | Notes |
| --- | --- | --- |
| NBA data warehouse | Strong MVP | 2024-25 Basketball Reference warehouse, normalized tables, seed JSON export, validation, and Flutter asset sync are working. |
| Generated NBA asset layer | Strong MVP | Flutter can load teams, players, games, player season totals, team game logs, leaderboards, highs, search index, validation, and source metadata. |
| Internal analytics lab | Strong prototype | Many NBA 2025 analytical surfaces were created to validate workflows: leaders, screeners, splits, trends, matchups, details, QA, source maps, and front-office boards. |
| Consumer shell | First real version | Main navigation is now product-oriented: Home, NBA, Fantasy, Community, Articles, Workspace, Messages, Profile, Admin, Internal Lab. |
| NBA hub | First real version | NBA hub supports player, team, and game page modes powered by generated data. |
| Workspace | First real version | Excel-inspired workbook UI has a title bar, ribbon, formula bar, grid, active cell, templates, sheet tabs, and status bar. |
| Theme system | First version | Light/dark toggle exists in the shell. Light mode uses the navy Sports Terminal identity. |
| Legal footer | First version | About, Contact, Privacy Policy, and Terms & Conditions are footer-linked pages. |

## Current product architecture

| Surface | User purpose | Current implementation |
| --- | --- | --- |
| Home | Personalized sports dashboard | Arena-style landing page with data health, leaders, recent games, big nights, and launch path. |
| NBA | League intelligence hub | Player, team, and game pages in one surface with search, favorites/watchlist state, stat cards, and tables. |
| Fantasy | Fantasy workflow center | Fantasy war-room prototype with player target board, watchlist, scoring proxy, and launch checklist. |
| Community | Social layer | Community arena prototype with boards, threads, likes, replies roadmap, and moderation checklist. |
| Articles | Editorial/blog layer | Content shell for platform posts, user blogs, CMS, articles, and analysis. |
| Workspace | Excel-like analysis workspace | Editable local workbook-style UI with formula bar and templates. |
| Messages | Private/group communication | Roadmap shell for DMs, group rooms, notifications, mentions, and safety tools. |
| Profile | User identity and settings | Session profile shell with settings, favorites, billing, privacy, and notifications roadmap. |
| Admin | Operator console | Admin shell for data ops, CMS, moderation, users, billing, legal, and feature flags. |
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

1. Make NBA player/team/game pages feel like real routed pages, even before full routing is added.
2. Add local persistence for theme, favorites, watchlists, and workspace sheets.
3. Improve the workspace engine: direct cell editing, keyboard navigation, formulas, and import/export.
4. Create initial backend schema for users, profiles, favorites, posts, comments, workspaces, messages, and admin roles.
5. Build community primitives with moderation hooks.
6. Build admin data-ops/CMS/moderation views that can eventually control the platform.
7. Add billing/subscription scaffolding once account persistence exists.
8. Add live/current-season data only after the product shell and persistence model are stable.
