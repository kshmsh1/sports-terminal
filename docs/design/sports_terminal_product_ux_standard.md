# Sports Terminal: platform-wide product UX standard

**Status:** Foundation implemented on `terminal-platform-ux-foundation`; screen-by-screen work tracked separately.  
**Scope:** All customer-facing destinations reachable from `CanonicalProductShell`. The internal build-lab `TerminalShell` is not the user-facing product.

## Design review: three disciplines, one product

**Chief UX Designer — first proposal:** The app has outgrown its linear navigation. Research users need to locate a workflow by intent, not remember which menu contains it. The tool should retain context while transitioning, expose unavailable data, and avoid making users scroll to the top after changing a page. A searchable route navigator and controlled input primitives should come before decorative work.

**Creative Design Director — critique:** Searchable navigation is important but not sufficient. The current screenshots and source show inconsistent content widths, button styles and filter density. Even highly functional analysis surfaces look disconnected when a dense trading workspace and a historical game page use unrelated visual treatment. The shared surface language must be neutral, precise and legible, with actual team/player colors reserved for sports data.

**Head of UI & Frontend — critique:** A broad rewrite would break the NBA trade rule engine, static snapshot integrations, and cross-era comparisons. Unify the Material theme and shell first, reuse source-preserving empty states, and migrate tables and filters incrementally. Never recolor semantic data or treat missing stats as zero just to fill a chart.

**UX response:** A shared theme alone cannot make an old three-level dropdown usable. Put searchable navigation directly in the common shell, include compact-screen discoverability, reset route scroll position on navigation, and introduce real widget tests for selection changes.

**Creative response:** Agreed, provided workspace labels reflect a coherent information architecture; selected destinations must be apparent and the active background subtle enough for analytics to remain the focus. The experience must work in both dark and light modes.

**Frontend response:** Agreed. The initial PR will contain shared tokens, grouped accessible navigation, responsive gutters, feedback states and regression tests; separate page PRs will handle the high-risk charting and transaction screens. Avoid nested controls with two sources of truth and guard every missing-data state.

**Consensus:** A platform foundation first, followed by evidence-driven surface migration and breakpoint testing. All changes are independent of the historical data pipeline and never invent missing research data.

## Product rules

1. **Clear context.** Every route has a short, descriptive name, an obvious active state, a stable content gutter and usable back/navigation behavior. Search for workspaces is separate from search for NBA entities.
2. **Data fidelity.** Display unavailable values as unavailable. Label season baselines, estimated data, historical snapshots and actual observed split statistics distinctly. Never silently replace absence with zero.
3. **Controlled interactions.** A season, period, category or rate selector must be a single state source of truth. Selected values must remain valid members of the current option set. Dedupe identifiers, guard asynchronous replies and test rapid switching.
4. **Legible data density.** Prefer concise rows with tabular digits. Keep labels visible when scrolling datasets and provide horizontal-scroll affordances on narrow screens. Do not shrink numeric type until data becomes unreadable.
5. **Responsive behavior.** Build for narrow phones (~390 px), tablets (~768 px), desktops (~1280 px) and wide analysis screens (~1920 px). Controls must wrap or change layout; never silently disappear.
6. **Keyboard/accessibility.** Important controls need tooltips, meaningful labels and consistent focus cues. All routes must remain discoverable without hover. Cmd/Ctrl+K opens workspace navigation.
7. **Consistent visual identity.** Product chrome uses common Material tokens; purple/blue/green/red team, player and outcome colors can still appear where they convey actual data semantics.
8. **Progressive disclosure.** Summary first; team-specific, game-specific and player-specific details open deliberately. Large statistical comparison experiences may use the full permitted workspace width.
9. **Useful empty states.** Source missing, no matches, insufficient games, loading, invalid selection and genuine errors are different conditions with different copy and recovery paths.
10. **Safe implementation.** Feature logic, NBA CBA calculations, static warehouse interfaces and source contracts should not change in styling-only work.

## Current customer-facing route audit

The observations below are **repository/code-level evidence**, not a claim of completed visual/interaction QA in browsers. The shared theme/navigation changes apply to every listed route. Individual page redesign remains subject to the follow-up work described.

| Destination | Code-level finding or opportunity | Priority | Next migration |
|---|---|---|---|
| Sports | Cross-sport home; maintain explicit unavailable-league labels | Medium | Use consistent product page header/cards |
| NBA Home | Multiple responsive panels and dashboard controls | High | Align filters, featured modules and loading skeletons |
| Stats | Extensive filtering and sticky statistical grid | High | Standardize controls, scroll affordance and missing rows |
| Advanced Stats | Dense rate/period filter combinations | High | Shared controlled-selector test matrix |
| Player Compare | Recently redesigned; complex comparison state | High | Breakpoint and keyboard audits; preserve team identity |
| Team Compare | Recently redesigned; complex comparison state | High | Breakpoint and keyboard audits; preserve team identity |
| Trade Machine | CBA-heavy rule logic and custom visual styling | Critical | Design migration behind verified CBA regression tests |
| Financials | Existing follow-up PR #63 improves financial workspace | High | Review/merge PR #63 before page-specific polish |
| Schedule | Responsive game/event information | Medium | Unified date, segment and no-games states |
| Box Scores | Existing follow-up PR #63 improves archive and detail | High | Review/merge PR #63 before page-specific polish |
| Media Sources | Small static source-directory page | Low | Consistent source metadata and navigation |
| Visualization Studio | Highly custom 4k-line chart experience | Critical | Protect pan/zoom, legends, density and metric selection |
| With / Without | Existing follow-up PR #63 fixes source and dropdowns | High | Only show real lineup split values once materialized |
| Rankings | Drag/drop and persistence interactions | High | Accessible reorder fallbacks and responsive tier view |
| Front Office | Deep multi-form data and source lineage | Critical | Reuse layout primitives; preserve transaction provenance |
| Research | Lightweight static research index | Medium | Unify search, cards, source labels and state messages |
| Community | Distinct user-generated/social patterns | Medium | Harmonize feedback, navigation, loading and prompts |
| Profile | Account state and settings | Medium | Consistent form hierarchy, confirmation and error states |
| Python Lab | Explicit navigation placeholder | Low | Keep disabled until real implementation exists |
| Excel Workspace | Explicit navigation placeholder | Low | Keep disabled until real implementation exists |
| About / Contact | Information and support routes | Low | Shared readable typography and spacing |
| Privacy / Terms | Legal routes | Low | Accessible width and long-form reading |
| Sitemap / Accessibility / Data & Methodology | Informational routes | Medium | Keep available and maintain content quality |

## Implementation tracks

**Foundation — in this PR**
- Central dark/light theme, semantic surface/border/text colors, Material table and input styling.
- Grouped, searchable workspace navigator and keyboard shortcut.
- Responsive content gutters and active-route context.
- Route-change scroll reset, shared empty state, reusable page heading.
- Theme-aware terminal primitives and parent-controlled dropdown selection.
- UI regression tests for route-category coverage and interactive filter selection.

**Analysis workspaces — subsequent PRs**
- Stats and Advanced Stats: consistent, controlled filter bars, row virtualization where needed and responsive table semantics.
- Visualization Studio: harmonize surrounding UI without disturbing chart interactions; validate zoom vs document scroll.
- Player/Team Compare: keyboard focus, rate and segment switching, multi-selection density.
- Rankings: accessible drag/drop alternatives, responsive boards and saved view confirmations.

**Front office and game research — subsequent PRs**
- Trade Machine: component migration only with strict trade legality/cap regression fixtures.
- Financials, Box Scores, With/Without: finish and verify PR #63, then use shared tokens.
- Front Office, Schedule, Research, Media: filter panels, source attribution and empty states.

**Community/account and release quality — subsequent PRs**
- Sports entry, NBA Home, Community, Profile, informational pages and global search polish.
- Screenshot comparisons at 390/768/1280/1920 pixels in both themes; keyboard-only interaction checks.
- Smoke-check every route, every disabled control and every critical search/selection state.
- Record defects by route, severity and reproduction; no claim of complete UX parity until browser QA passes.

## Definition of done for the *entire* redesign

Each enabled route has been exercised in both themes and across supported viewport widths. Navigation is discoverable and keyboard-accessible. No controls overflow or appear to change value while leaving data stale. Missing data is accurately disclosed, and important operations have loading, empty and error states. No NBA trade logic, historical facts or source-availability constraints regress. CI and representative browser screenshots are reviewed **before** merge.
