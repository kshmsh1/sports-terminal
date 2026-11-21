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
| Player profiles | React minimal dossier only | Source-backed full Stats/Advanced tables and complete profile interactions matching Flutter |
| Trade Machine + 2023 CBA | Original Dart validation exporter only; no independent React engine/UI | Same approved rules, salary/matching restrictions, severity, multi-team trade scenarios, picks and transaction feedback |
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

Run `(cd experimental/arcside-react && npm test && npm run test:browser)` as the normal TypeScript/browser regression suite if not already covered by CI. Review JSON evidence under `evidence/objective`, `evidence/readiness`, `evidence/labs` and `evidence/accessibility` and the updated decision ledger. Production Flutter remains unchanged and PR #89 remains draft.
