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
| **Editorial Instrument** | Swiss-style alignment, warm neutral canvas, restrained chartreuse actions, asymmetric overview, persistent research nav | Balance: fast scan, distinctive craft, high density where appropriate | Requires more than palette changes: consistent page hierarchies | **Chosen** |

The interface should feel serious enough for an analyst and approachable enough for a sports fan. It should be built as an original system, not resemble Blitz's chat-first black/red page or an imitation Bloomberg terminal.

## 3. Structural navigation model

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

Desktop 1280+ gets a 252px persistent sidebar; medium desktops from 980 use a 76px icon rail to protect data density. Smaller widths use a navigation drawer, not a horizontal menu that scrolls into oblivion. Cmd/Ctrl+K opens a searchable workspace dialog; player/team search is a **separate** source-backed entity lookup. The selected route is always represented by a visible icon+label or by an explicit compact topbar context.

## 4. Visual system

### Product chrome

| Token | Dark | Light | Role |
|---|---|---|---|
| Canvas | #0D1215 | #F4F5F0 | Primary working background |
| Sidebar | #11181A | #EAEEE7 | Navigation plane |
| Surface | #182023 | #FFFFFF | Data cards and sheets |
| Border | #303A3C | #D6DCD4 | Divisions without heavy shadows |
| Text | #F2F3EC | #17241E | High-contrast main copy |
| Subtext | #ABB9B5 | #52645B | Secondary contextual copy |
| Action | #C7EF77 | #3F6322 | Active navigation / primary call to action |

Use the lime only for **interaction state and action**, never to encode a player, team, winner, statistical increase, profitability, injury, or validity. Sports/team colors remain semantic inside charts, comparisons, and standings. Alert/error/success colors must use separate accessible tokens.

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
- New token foundation in `sports_workspace_design.dart`.
- Responsive sidebar, collapsible rail, mobile drawer, command palette, context topbar in `sports_workspace_chrome.dart`.
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
