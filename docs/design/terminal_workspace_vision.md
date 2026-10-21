# Sports Terminal — Product UX Reset (2026)

Status: **Design hypothesis and working implementation branch**, not a claim of completed design migration across every individual screen.

References:
- https://www.uistyleguide.com/
- https://www.uistyleguide.com/style/data-dense-dashboard
- https://www.uistyleguide.com/style/bento-box-grid
- https://github.com/nextlevelbuilder/ui-ux-pro-max-skill

The linked style explorer is a *palette of possible approaches*, not a design to copy. The open-source UI UX Pro Max repository's priorities—accessible targets, responsive breakpoints, semantic tokens, consistent navigation, understandable status/error feedback, and Flutter composition—inform this proposal. This is not a bundled install or dependency on third-party code.

## 1. Problem statement

Sports Terminal currently reads as independent feature pages wrapped in a common navbar:
- Initial state is a wall of equal-priority sport selectors even though only NBA datasets are supported.
- A long horizontal bar and nested dropdowns make navigation difficult and bury frequently used research functions.
- Trade/CBA, games, research, visualizations, stats, and social tools have inconsistent page anatomy.
- A fixed one-size content container constrains dense workspaces while adding empty space in simpler pages.
- Too many controls use the same muted rounded-rectangle treatment; there is too little visual hierarchy.
- Tool state and data availability are not visible enough when moving between workspaces.

Merely adding more cards, gradients, purple highlights, rounded pills, or AI chat does not solve the product model.

## 2. Three competing visual concepts

| Concept | Visual | Strength | Weakness | Verdict |
|---|---|---|---|---|
| Broadcast | Big typography, immersive imagery, editorial story cards, vivid league palette | Great for scores and casual fans | Distracts from dense research; cannot make unsourced live visuals credible | Use on selected NBA/game landing sections |
| Quant Terminal | Graphite grid, dense tables, tiny metadata and status ribbon, information everywhere | Very efficient for power analysts | Visually exhausting for new users; poor mobile ergonomics; can become a Bloomberg imitation | Use inside advanced workbenches only |
| **Editorial Instrument** | Swiss-style alignment, midnight-blue canvas, indigo action blue, asymmetric overview, contextual top navigation | Balance: fast scan, distinctive craft, high density where appropriate | Requires more than palette changes: consistent page hierarchies | **Chosen** |

The interface should feel serious enough for an analyst and approachable enough for a sports fan. It should be built as an original system, not resemble Blitz's chat-first black/red page or an imitation Bloomberg terminal.

## 3. Structural navigation model

**Revision after product review:** Keep task-based groups, but return them to the top navigation. Desktop displays Overview, NBA, Analyze, Trade Machine and More; medium widths show a compressed version; mobile uses a grouped popover. The command palette remains on Cmd/Ctrl+K. No permanent sidebar or rail is used.

```text
SPORTS TERMINAL
├─ Start
│  └─ Overview
├─ Basketball
│  ├─ NBA Home
│  ├─ Schedule
│  ├─ Box Scores
│  └─ Media Sources
├─ Research & analysis
│  ├─ Research
│  ├─ Stats / Advanced Stats
│  ├─ Visualization Studio
│  ├─ Player Compare / Team Compare
│  ├─ With / Without
│  └─ Rankings
├─ Front office
│  ├─ Trade Machine
│  ├─ Financials
│  └─ Front Office
├─ Community
│  ├─ Community
│  └─ Profile
└─ More
   ├─ Python Lab / Excel Workspace (disabled until implemented)
   └─ About / Contact / Policy / Accessibility / Methodology
```

Desktop uses a top group menu, transitioning to a compact top group menu and then a mobile overflow menu. Cmd/Ctrl+K opens a searchable workspace dialog; player/team search is a **separate** source-backed entity lookup. The blue accent indicates selection and is independent of team/stat colors.

## 4. Visual system

### Product chrome

| Token | Dark | Light | Role |
|---|---|---|---|
| Canvas | #0B111A | #F7F8FC | Primary working background |
| Sidebar | #101823 | #F0F2F9 | Navigation plane |
| Surface | #141D29 | #FFFFFF | Data cards and sheets |
| Border | #2B3849 | #D8DFEA | Divisions without heavy shadows |
| Text | #E9EDF7 | #17223B | High-contrast main copy |
| Subtext | #B7C2D5 | #4D5A73 | Secondary contextual copy |
| Action | #AAB8FF | #5363B5 | Active navigation / primary call to action |

Use blue only for **interaction state and action**, never to encode a player, team, winner, statistical increase, profitability, injury, or validity. Sports/team colors remain semantic inside charts, comparisons, and standings. Alert/error/success colors must use separate accessible tokens.

- Typography: geometric sans using native material font stack; compact uppercase kicker for route/section identity; tabular figures for table metrics.
- Rhythm: 4/8/12/16/24/32/48px, with different density modes per screen.
- Radius: 8–11px for controls; 14–18px for working surfaces.
- Borders: hairline; no gratuitous shadows or glass blur.
- Motion: brief and functional (150–200ms), reduced-motion respectful. No animated wallpaper, HUD scanlines, blinking numbers, or fake live-state indicators.
- Layout: constrained editorial overview, width-expanding stats and visualization workspaces.

### Page anatomy

**Overview:** product identity and direct actions → archive availability from actual local static index → six meaningful workflow launches → league coverage disclosure. Never fabricate a "recent activity", scores, or game alert tile.

**Research:** question/composer or query builder → query receipt and coverage → result data (sortable table/chart) → related investigations and reusable export. Treat uncertainty, absent tracking and stale data as separate states.

**Stats and Advanced:** compact top context with selected season/segment/rate → sticky filters → performance table → drilldown affordance. Preserve row labels on wide tables and use accessible horizontal overflow on mobile.

**Visualizations:** gallery for visual discovery but no huge hero; configuration drawer/rail, chart canvas, hover/selection details, source notes and export grouped logically. Verify page-scroll vs chart-pan interactions.

**Player/Team Compare:** entity lineup/season chooser anchored to chart; compare table/relative distribution, synchronized filters and source notes. Team color semantics are independent of action-green chrome.

**Trade Machine:** full-width canvas, persistent scenario summary and restriction status; enforce the CBA logic. Workflow: build proposal → analyze exceptions/aprons → review legality and rationale → save. Never assert legal until all source-backed checks have passed.

**Financials:** thresholds and season at top, team table and drilldown with proper sort, no truncated exception strings.

**Games & Box Scores:** matchups and game metadata, honest final / pregame states, accessible tabs for away/home player rows, source availability and no false times.

**Community / Account:** light structural alignment to product navigation and accessible forms. Leave legal routes legible rather than packed into dense terminal tables.

## 5. Accessibility & interaction bar

- The navigation menu and command palette must work with keyboard, touch, screen readers and constrained screen widths.
- All icon actions need labels/tooltips, visible focus cues, semantics and reasonable targets.
- Reflow at 390, 768, 1024, 1280, 1600 and 1920 CSS pixels; test text scaling.
- No color-only interpretation of finance/cap legality or table wins.
- No silent selection updates that leave stale stats; asynchronous data handles cancellation/version guards.
- Missing source data stays missing; never render fictional game scores, AI-computed lineup splits, or live status.
- Verify light/dark contrast on actual rendered pages.
- Preserve navigation and player identity when users move among research workspaces.

## 6. Implementation status and constraints

### Implemented in this PR
- Revised blue/indigo token foundation in `sports_workspace_design.dart`.
- Responsive top navigation, grouped menus, command palette and mobile overflow navigation in `sports_workspace_chrome.dart`.
- New overview page in `sports_workspace_overview.dart`, with working tools and local archive season count.
- Centralized route inventory still owned by `CanonicalProductShell`; original NBA page builders unchanged.
- Existing player/team search remains operational and independent from workspace navigation.
- New widget and contract tests; old tests updated to reflect intentionally changed UX.

### Not yet implemented
- Per-screen component migration, true client-side deep links/route history, multi-tab workspace state retention, keyboard-first chart accessibility, route-specific skeletons, live sports feeds.
- Full cross-branch integration with existing open PR #63 (financials) / PR #64 (global shell foundation) / PR #65 (research). These are separate unmerged branches; review and reconcile before merging.

## 7. Validation and go/no-go

1. Flutter analysis, tests and production web build pass on every changed commit.
2. Browser review in both themes for 390/768/1024/1280/1600/1920px.
3. Route smoke tests: start, compare, stats, visualization, trade, financials, game pages, research, user area, disabled placeholders.
4. State-transition verification: season, rate basis, regular/playoffs, navigation, modal close, drawer close, search results and error states.
5. No regression to stat values or CBA calculation / trade restrictions.
6. User signs off on visual direction before migrating every page into new layout components.

### Next round
Design high-fidelity, code-backed compositions for the 4 most structurally different workspaces (Research, Stats, Visualization, Trade Machine), test the design system there, then migrate the remainder. Do not call the redesign complete after merely changing the shell.

## 8. Box Scores / game center revision

The archive is now a dedicated game-discovery workspace: indexed game count, genuinely materialized player-box-score count, latest indexed game date, query/season/segment filters and a detailed-only switch. Date-grouped game cards display legible scores, winner emphasis and explicit player-data availability. The game-detail modal provides an immediate loading state, a match scoreboard, team-specific player tables, numeric sort selectors, and an expandable group for rows without recorded minutes.

No live games or missing player values are synthesized. Local static files remain the single runtime source; missing is distinct from zero. The current revision uses the original Sports Terminal indigo/blue accents, restores accessible text colors and makes no changes to font families. This is a design review branch, not an automatic merge of PR #63, which contains overlapping game-screen modifications.
