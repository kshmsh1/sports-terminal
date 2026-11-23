# Phase 3 — five engineering gates: verification and remaining work

**Reference:** Flutter/Dart `main`. **Candidate:** draft React PR #89. **Data:** original local NBA static v5. Never merge or retire Flutter based on existence of a route, nominal parity or an automated smoke test.

## What the engineering branch now provides

The experimental React Trade Machine can consume source-fingerprinted 2026–27 salary, financial, 30-team cap-ledger, separate 30-team **salary-position** ledger, first/second-round draft interests and traded-player exceptions extracted at build time from the **original** Dart source. Payroll defaults to the exact original Flutter salary-position metric (not the distinct cap ledger total) when the operator explicitly applies original ledgers. TPEs are acquisition mechanisms assigned to the receiving team, **not transferrable trade assets**; their modeled review still cannot authorize an NBA transaction. Missing sources cause errors; hard caps and payroll have an explicit opt-in, and frozen/untradeable picks cannot be selected in the published picker. The independent TypeScript CBA engine is not the authoritative 2023 NBA CBA interpreter; 27 original-Dart goldens previously matched but do not prove legal completeness. Original React player dossiers and front-office modules remain partial compared with Flutter.

The companion denies cross-origin and tokenless mutation requests, nested internal-directory writes and in-workspace reserved symlinks. The original Labs have browser-based import/export roundtrips and collaboration tests that cover owner/editor/viewer roles on an isolated live service. These constitute security test coverage, **not** a full external penetration test, native OS sandbox or general-purpose untrusted-code execution guarantee.

## Gate: functional and trade/profile parity

Full migration requires original Flutter-to-React per-module source and UI comparison of Stats, Advanced Stats, Visualizations, Trade Machine, Player Profiles, Player/Team Compare, Financials, Games, Box Scores, Team Detail, With/Without, Python Lab and Sheets. Verify exact source rows/metrics and complete user controls, all 2023 CBA edge cases, original roster and draft-asset overlays, profile contract/award/advanced subsections, keyboard navigation and source missing-data fallbacks. Source-backed routing and limited fixtures **cannot** close this gate alone.

After updating the branch on the Mac and rebuilding **React** (Flutter unchanged):

```bash
cd ~/sports_terminal
git pull --ff-only
(cd experimental/arcside-react && npm run build && npm test && node scripts/phase3_bundle_gate.mjs)
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --objective
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --advanced-acceptance
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --visualization-acceptance
```

## Gate: matched operator performance

`--objective` measures React chart readiness against Flutter root mounting; the two milestone times are **not** the same task and cannot certify a performance win. After original-source parity preflight, run physical-operator matched tasks:

```bash
cd ~/sports_terminal
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --advanced-guided
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --visualization-guided
```

The registered decision engine requires same-source full functional verification and original valid historical season samples, 30 advanced trials and 24 visualization trials, with a React/Flutter p95 ratio <=1.10; do not reuse prior failed or non-equivalent task timings.

## Gate: real accessibility

On a physical **Mac**, use real **Safari + VoiceOver**, then on a physical **Windows** machine use **Chrome + NVDA**. Use the same source-backed release shells on the respective machine. Start the shell servers in one terminal, and run the log in another **while both servers are running**:

```bash
cd ~/sports_terminal
bash scripts/phase3_serve_release_pair.sh
```

With both servers active (in a second terminal), run the native accessibility audit:

```bash
cd ~/sports_terminal/experimental/arcside-react
node scripts/phase3_native_a11y_session.mjs
```

The latter checks the host OS, requires exact v5 source matching, and prompts for actual speech/focus/role behavior on 16 workspaces with detailed evidence. It produces an untracked local native report and **cannot** sign off without physical operator tests. Screen-reader observations are necessary but not an independent WCAG 2.2 AA certification. Fix defects and retest both platforms.

## Gate: Labs native security

Run the original companion and live collaboration tests. The GitHub workflows `.github/workflows/labs_power_quality.yml` and collaboration quality checks exercise native process execution, Python notebook export, workbook sync, token/Origin and viewer/editor authorization in test environments. Full local trust-boundary review must still validate privileged shell/package/debugger consequences, filesystem race windows, role isolation on the deployed service and all origin/CORS/CSRF/token lifecycle behavior. Never enable untrusted code execution or expose the loopback companion on a public interface.

## Gate: rendering/frame/GPU/memory

The `--frame-memory-guided` mode runs same-source Chrome tabs with manual chart task-equivalence preflight and samples rAF gaps, JS heap, DOM counters, CDP task/layout durations and screenshot hashes. For a stronger study:

```bash
cd ~/sports_terminal
ARCSIDE_FRAME_SAMPLES=10 ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --frame-memory-guided
```

This is not true GPU frame-present-time measurement, nor does Chrome JS heap capture Flutter renderer/GPU/native process RAM. Use physical device Chrome DevTools Performance traces, OS process monitors and Mac Instruments/Windows Performance Recorder or GPUView for verified native memory, compositor and GPU timelines; attach the traces before assessing p95 thresholds and catastrophic jank.

## Final GO/NO GO decision

Review `experimental/arcside-react/evidence/decision/phase3-decision.md` after original-source, human-native, security and performance evidence. Only once all gates are verified should the owner compare actual side-by-side visual output and choose staged React migration, hybrid or retain Flutter. Until then the decision remains **NOT AUTHORIZED** and PR #89 is **DRAFT**.


## November 23: benchmark forensic audit and final operator review

The previously reported Visualization Studio p95 *does not* mix cold with warm trials. It is nearest-rank p95 of **10 warm** trials per app, so the largest WARM observation is the registered p95. The original November 23 operator run failed on React warm trial 12 (879.91 ms; browser rAF p95 9.2 ms, no gaps >50 ms); do not discard that data, relabel it as a GPU freeze, or silently reinterpret the registered sample.

With the locally built original-sourced React/Flutter releases reused, run this focused diagnostic (it does not ask for another 24 human timed trials):

\`\`\`bash
cd ~/sports_terminal
git pull --ff-only
ARCSIDE_DIAGNOSTIC_TRIALS=10 ARCSIDE_VIS_TRACE=1 ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --diagnose-chart
\`\`\`

This first audits the *immutable* original V2 24-trial data. The second step performs ten **React-only** automated zoom, pan, reset, X/Y axis and underlying-player-selection probes against the same local NBA v5 manifest. The diagnostic saves individual operation latencies and a React performance trace in \`experimental/arcside-react/evidence/visualization/\`. **REACT_OPERATIONS_OBSERVED is not the Flutter-versus-React p95 gate PASS**; an original-corpus repeat may be required after an actual chart fix. Do not weaken the established 1.10 threshold.

For the operator's **final visual + functional review**, start both local release servers in terminal A:

\`\`\`bash
cd ~/sports_terminal
bash scripts/phase3_serve_release_pair.sh
\`\`\`

In terminal B, run:

\`\`\`bash
cd ~/sports_terminal
node experimental/arcside-react/scripts/phase3_final_visual_review.mjs
\`\`\`

The runner opens both app tabs with the exact same NBA v5 manifest. For **15 original Flutter modules**, manually inspect the corresponding React route, real player/team/game selections, functional controls, data equivalence, errors, keyboard behavior, dark/light readability and dimensions. It captures both actual screenshots and explicit operator notes. Enter FAIL/BLOCKED for an unimplemented original function or missing historical source; there are no skip/waive controls. The result is in \`experimental/arcside-react/evidence/final-review/final-visual-review.md\` with untracked screenshots.

**Important:** \`OPERATOR_VISUAL_SAMPLE_PASS_ONLY\` does **not** certify full functional parity or authorize migration. React still has known incomplete original Trade Machine/CBA transaction work and some player-profile/front-office modules. The original Flutter app is untouched. Real Mac Safari+VoiceOver and physical Windows Chrome+NVDA must be reviewed separately. Labs native privilege boundaries and total process/GPU rendering still require independent evidence. A visually excellent candidate could still receive an architecture NO-GO or a hybrid migration recommendation.

The decision program retains all original evidence and reports unavailable/failed gates explicitly. Do not mark PR #89 ready or merge it until a separate owner decision explicitly authorizes the selected rollout scope.
