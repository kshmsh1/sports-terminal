# Sports Terminal Backend Architecture Plan

Sports Terminal can continue as a Flutter/static-asset prototype for NBA historical data, but the launch product needs a backend before community, messaging, saved workspaces, profiles, fantasy, billing, and admin operations can become real.

## Backend goals

| Goal | Why it matters |
| --- | --- |
| Persist user identity | Profiles, settings, favorites, watchlists, billing, posts, comments, messages, and workspaces must survive refresh/login. |
| Separate consumer and operator permissions | Normal users, moderators, admins, organizations, and internal operators need different capabilities. |
| Keep NBA data read-optimized | Historical/generated NBA data can stay asset-backed first, then move behind APIs when current-season/live refreshes need it. |
| Moderate social surfaces from day one | Forums, messages, comments, and public profiles need report queues, blocks, mutes, bans, and audit trails. |
| Support subscriptions later | Billing should gate premium fantasy tools, saved workspaces, advanced analytics, and organization features. |

## Suggested first schema

| Domain | Core tables / collections | Notes |
| --- | --- | --- |
| Accounts | users, user_profiles, user_settings, user_sessions | Profile, privacy, theme, notification preferences, account status. |
| Favorites | favorite_teams, favorite_players, player_watchlists | Powers Home, NBA Hub, Fantasy, alerts, and personalized feeds. |
| Workspaces | workbooks, worksheets, worksheet_cells, workspace_templates, workspace_shares | Replaces local Excel-like state with saved sports sheets. |
| Community | boards, posts, comments, reactions, saved_posts, follows | Powers forums, team rooms, fantasy boards, product feedback. |
| Moderation | reports, moderation_actions, user_blocks, user_mutes, audit_events | Required before public community/messaging launch. |
| Messaging | conversations, conversation_members, messages, message_reads | DMs, group rooms, support/data issue threads. |
| Articles / CMS | articles, article_revisions, tags, article_tags, featured_slots | Admin-controlled editorial and user blog pipeline. |
| Billing | plans, subscriptions, invoices, entitlements | Paid tiers, trials, org subscriptions, usage limits. |
| Admin | admin_tasks, feature_flags, data_pipeline_runs, data_quality_checks | Operator console and product control plane. |

## API surfaces to build first

| API area | Example capabilities |
| --- | --- |
| Auth/profile | Sign up, sign in, edit profile, update settings, export/delete account. |
| Favorites/watchlists | Add/remove teams and players, fetch personalized home state. |
| Workspace | Save workbook, update cells, create template, duplicate workbook, share/export. |
| Community | Create post, reply, like, save, follow board/team/player, report content. |
| Messaging | Create conversation, send message, mark read, mute/block/report. |
| Admin | Review reports, publish article, toggle feature flag, inspect pipeline run. |

## First implementation sequence

1. Pick backend stack and hosting strategy.
2. Implement auth, users, profiles, user_settings, and favorite teams/players.
3. Persist theme, favorites, watchlists, profile settings, and workbook cells.
4. Build community posts/comments/reactions with moderation reports.
5. Build admin moderation queue and audit events.
6. Build messaging after block/report/mute safety controls exist.
7. Add CMS/admin publishing.
8. Add billing and entitlements once account state is stable.
9. Add current-season/live data jobs and API caching.

## Product rule

Do not ship public community or messaging without moderation, report queues, block/mute controls, and operator audit logs. The social layer is valuable, but it creates the most product risk if it launches before safety infrastructure.
