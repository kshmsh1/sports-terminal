# Arcside Phase 3 — architecture recommendation and remaining acceptance gates

**Assessment:** 2026-11-20. **Status:** engineering recommendation; NOT owner-signed migration approval. **Current recommendation:** RETAIN FLUTTER as authoritative application; continue the isolated React/TypeScript/Vite pilot and selectively validate routes. **No merge into `main`.**

## 1. What Phase 3 established

The owner's Mac release checks reported 38,086 independent original Dart versus React Visualization Studio comparisons, with zero mismatches across 144 historical source-backed cases (86 nonempty), and six qualified React real-source browser journeys with zero errors. This is strong *narrow* numerical/functional evidence, not a full-scope UI match.

React production compilation and 23 TypeScript unit tests passed on the owner's machine after the ECharts simultaneous wheel zoom/drag pan change. The former human-operated 24-trial timer is not a valid pure performance metric because it combines application responsiveness with mouse movement speed. Historical failed timing remains retained; no synthetic “PASS” is substituted.

The candidate currently ships only Stats, Advanced Stats, Visualization Studio, Python Lab and Excel Workspace routes, plus a minimal player dossier. The Dart original remains authoritative for NBA metrics, full trade validation and broader Arcside capabilities. The Labs are embedded original HTML/JS applications, not ported to React.

## 2. New reproducible evidence collection

The isolated `--objective` runner starts both release builds against the **same original local v5 NBA manifest**, alternates variant order, records 5 fresh-context and 10 reused-context browser samples each, browser navigation/first paint and memory where exposed, JS-frame scheduling gaps, and **React-only** scripted wheel/drag/axis interaction events. Flutter's initial root mount is recorded separately from React chart readiness and MUST NOT be used as a comparable chart latency. No actual GPU presentations or frame drops are claimed.

The `phase3_readiness_audit.mjs` report flags missing React routes, incomplete player dossier tables and no React-native CBA validation implementation. It checks tracked Flutter screen paths, not every runtime-activated route; absence in candidate remains a blocker.

The browser accessibility probe verifies the existence of semantic landmarks, skip link focus, and accessible chart text alternatives. The isolated Labs probe uses disposable browser storage to import/export original Python files and Sheets workbooks, then checks a typed same-origin context acknowledgment. Neither is a certified WCAG audit, native Safari/VoiceOver test, Windows NVDA test, authenticated role security review or companion service penetration test.

The live evidence is user-local under ignored `experimental/arcside-react/evidence/` and must be read from the original Mac run. A committed script is **not** a recorded measurement or a completed certification.

## 3. Full-application migration blockers

| Workstream | Current status | Acceptance required |
| --- | --- | --- |
| Stats + Advanced Stats | Narrow source parity and real browser journeys implemented | All displayed metric families, UX controls and player-profile replication, regular/playoff and multi-team behavior |
| Visualization Studio | 38,086 historical comparisons / zero mismatches reported; zoom/pan implementation updated | Real drag viewport regression test, matched chart performance and owner visual signoff |
| Player profiles | React source-backed original dossier career and Advanced family tables implemented; original corpus/browser proof pending | Complete approved profile column parity, contracts, honors, player inspection, deep links and Flutter profile interaction equivalence |
| Trade Machine + 2023 CBA | Original Dart five-case rule golden exporter implemented and CI-tested; no independent React engine/UI | Same approved rules, salary/matching restrictions, severity, multi-team trade scenarios, picks and transaction feedback |
| Player/Team Compare, With/Without, Financials, Box Scores | Not implemented in React pilot | Each production route, data semantics, interactions and visual behavior |
| Native Safari / VoiceOver / NVDA | Not executed | Real macOS Safari + VoiceOver, Windows Chrome + NVDA, keyboard-only and WCAG 2.2 AA review |
| Python + Sheets | Original modules embedded; basic typed-context bridge | Authoritative file import/export checks, persistent workbooks, Monaco and keyboard ownership, local companion / collaboration credentials |
| Performance | Cross-browser observational suite staged; Flutter chart actions not instrumented | Same task/input-to-completion markers in BOTH shells and actual frames/memory/GPU on same hardware; review p95 and variance |
| Decision | Current migration not authorized | Explicit owner signoff following passed correctness, workflow, security, accessibility and performance gates |

## 4. Recommendation among architectures

- **Full React migration now — NO-GO.** Current evidence does not support retiring Flutter: too many production modules and domain contracts have no replacement, and there are hard unmeasured accessibility/security/performance gates.
- **Stay on Flutter without experimentation — acceptable fallback**, but it would forgo the opportunity to learn whether React improves interactivity and browser-native controls on the highest-value analytic views.
- **Flutter authoritative + contained React pilot — preferred now.** Keep the existing warehouse, static compiler, Dart trade/CBA logic and Lab services, develop the React proof independently, and make route-by-route migration decisions only after genuine dual-renderer testing.

This is an engineering recommendation, not the user's signed GO/NO GO. No untracked corpus files or generated evidence should be committed.

## 5. Owner-run verification

```bash
cd ~/sports_terminal
git pull --ff-only
bash scripts/phase3_release_compare.sh --objective
```

Run `(cd experimental/arcside-react && npm test && npm run test:browser)` as the normal TypeScript/browser regression suite if not already covered by CI. Review JSON evidence under `evidence/objective`, `evidence/readiness`, `evidence/labs`, `evidence/profiles`, `evidence/trade` and `evidence/accessibility` and the updated decision ledger. Production Flutter remains unchanged and PR #89 remains draft.

## November 20 continuation — additional shipped narrow evidence

- Updated React's `/player/:key` route to render the original published regular/playoff career tables and Advanced Stats metric-family tables with expandable columns and explicit null behavior. Uses the original player dossier `regular_seasons` / `playoff_seasons` contract. Added deterministic synthetic browser/unit tests for source format, category selection, season toggling, and reload; added a genuine original-v5 player index/dossier browser probe for three source-backed player records. **No local corpus execution has been observed yet**, and complete player-profile contracts/awards and column-level exact Flutter equality remain unverified.
- Original `TradeMachineEngine` now exports five 2026–27 deterministic scenario reports directly from Dart (salary exchange, BYC/poison pill, missing required matching values, dated restriction, sign-and-trade apron). GitHub parity workflow successfully ran the original Dart reference exporter. The comparator refuses a copied Dart reference as a candidate unless an independently declared candidate engine is provided. **No React CBA engine exists, and this does not establish trade-rule parity**.
- React chart test verifies actual numeric viewport changes for wheel/drag/reset in Chromium, Firefox and WebKit CI. A previous synthetic benchmark still used a deleted `Drag pan` button and was repaired.
- The original Labs continue unchanged. Their authenticated native companion browser integration still requires separate verification; passing the isolated export/import tests cannot certify local-service token security.
- PR #89 remains draft. Do not merge; no full architecture migration approval is inferred from the new evidence.

## Controlled Phase 3 continuation after the first objective run

**New candidate implementation:** An isolated React Trade Machine scenario editor and independent TypeScript port of the full existing Dart `TradeMachineEngine.validate` finding families, with 15 independently generated Dart-versus-TypeScript golden cases passing on CI. This does not mean full original Flutter Trade Machine UI parity, complete authoritative team/player/cap/pick ingestion, or every CBA scenario is proven. The production feature gate remains FAIL.

**Player-profile extension:** Historical career/advanced tables remain source-backed. The React pilot now ports the original confirmed-honors algorithm (season-ending years, elections vs winner ballots) and emits an as-of-2026-09-11 salary snapshot derived from the unchanged original Flutter seed at React build time. It optionally reads the original immutable front-office contract registry. It does not yet mirror Flutter's local browser overlay, all deep links, complete profile controls or exact field-by-field screenshot parity.

**Independent evidence:** 15 CBA goldens, source-labeled salary browser tests and the actual-original-corpus profile smoke belong to the isolated Phase 3 branch. The owner-local objective runner compares the engines before browser acceptance; it never upgrades a 15-case PASS into unrestricted CBA authority.

**Architecture decision remains unchanged:** Flutter is authoritative; **no merge into main or full framework migration** before broad route parity, matched input/GPU metrics on hardware, native screen-reader testing, Labs security validation and explicit owner signoff.

## Five original-corpus React route pilots — implementation follow-through

An additional *source-backed but not yet feature-equivalent* slice now exists for Player Compare, Team Compare, Box Scores, Financials and With/Without. These five modules reuse published original NBA v5 data files and the original Dart 2026–27 team financial reference; no production React route falls back to synthetic data. The original Flutter implementations were consulted for reference contracts and their more extensive interface behavior remains authoritative.

- Player Compare reuses the independently validated numerical player-season transform, supports 2–5 slots, different historical season choices, metric groups, head-to-head tied leaders and profile navigation.
- Team Compare derives values only from canonical team records, standings, or adequately complete actual team game logs. W/L, percentages, and other values are left unavailable if insufficient underlying data exists.
- Box Scores uses the original game index and per-game detail, filters history and inspects source-backed team and player lines. Explicit empty state for unmaterialized games; corrected initial home-team player selection and Firefox hit targets.
- Financials consumes the unchanged Dart team-financial reference exported as an immutable and date-labeled 30-team 2026–27 JSON asset; it is **not** live payroll or contract validation.
- With/Without reads optional canonical lineup-pair files by season and segment; unknown pair splits display unavailable rather than invented impact.

Unit tests for team-metric completeness/tie semantics, intercepted-fixture three-engine browser tests, a separate authentic-corpus five-route smoke, and the readiness audit provide incremental evidence. `scripts/phase3_release_compare.sh --objective` runs the real source smoke when the owner's untracked NBA v5 corpus is available.

**No whole-migration authorization is inferred.** The five routes omit parts of Flutter's controls, saved views, detailed analytics and integrations; remaining Team Detail, Games, Franchise History, complete original player profiles, full Trade Machine UX/CBA coverage, Labs authentication, native screen readers, truly matched GPU/response timings, and owner visual signoff remain unresolved. PR #89 stays DRAFT.

## Follow-through: Team Detail, Games, and Franchise History, plus profile and operator improvements

The React pilot now implements the three previously missing module categories using the original NBA static-v5 contracts: `/teams` directory and `/team/:key` dossier; `/games` and `/game/:key` historical archive and optional source play-by-play; and `/franchise-history`, reflecting the original Flutter *planning-stage* six-topic roadmap and authentic indexed team identities. Dated salary roster joins use the original Flutter 2026–27 seed and its 2025–26 regular-season performance baseline, not an assumed live roster. Lineup and scheduled-event gaps remain explicit.

The original Flutter Franchise History screen was itself a six-row future build plan, so implementing a full verified franchise lineage remains a distinct *future data-provenance project*. No unverified relocation edges, previous-team identities, or schedule events are manufactured in this pilot.

Comparison now supports browser-local saved presets; published player profiles expose more source-known context; and the hypothetical CBA scenario editor can choose from the original dated player salary seed. These incremental additions do not verify authenticated preset interoperability, complete original profile widgets or the Trade Machine's full asset and cap sources.

Unit and browser checks, a source-code audit and an 8-route authentic corpus smoke (including an indexed team dossier) were added. They cannot establish matched native assistive technology, full CBA legality, user approval, Labs native security, GPU equivalence, or all interaction-level feature parity. **Keep the full migration decision at NOT AUTHORIZED and PR #89 in draft.** The original Flutter shell remains authoritative.
