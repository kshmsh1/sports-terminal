# Arcside Phase 3 — comparative UI/UX and performance evaluation (November 20, 2026)

**Decision: controlled pilot is NOT yet eligible for a frontend migration approval.** This evidence ledger distinguishes verified measurements from tooling and unexecuted local or human validations. The unpublished canonical NBA shards and the original interactive Flutter runtime reside on the owner's Mac, not in GitHub Actions.

## Verified evidence

**Verified on the owner's real Mac dataset after Advanced Stats repair (November 20):** New independent original-Dart/React Advanced Stats acceptance made **1,119,992 comparisons, 0 mismatches** across numeric, null, formatting, catalog, filter and sorting outputs. The post-repair 30-trial manual Advanced Stats study had **15 Flutter and 15 React completions, zero task failures**, with warm medians Flutter **6,472 ms** / React **7,137 ms** and warm p95 Flutter **13,850 ms** / React **9,049 ms** (React/Flutter p95 **0.6534**, inside the pre-registered 1.10 threshold). These measurements are task-completion times, not frame times. The original cross-engine statistics acceptance (1,016,826 comparisons) remains an independent and preserved earlier suite.


- Original Dart versus React on actual canonical 2025–26, 1986–87 and 1946–47 NBA season shards, regular and playoff segments, six rate bases: **1,016,826 matched field comparisons, zero mismatches**. All 1946–47 playoff cases contain zero rows; no historical playoff parity is asserted there.
- Existing React-only synthetic browser benchmarks cover 1k/10k/50k-row tables and 300/5k/25k-point charts. Earlier 1 cold and 2 warm smoke runs have no matched Flutter baseline, so they establish neither speedup nor reliable p95.
- The Phase 3 shell includes native browser route URLs, qualified and virtualized Stats/Advanced slices, one ECharts scatter explorer, recorded team-stint expansion, and integration of the unchanged original browser-native Python and Sheets Labs. It does NOT yet port all original Flutter screens, advanced metric taxonomy, detailed player profiles, saved views, full Visualization Studio, Trade Machine/CBA UI, or financial and comparison tools.

## Evaluation dimension results

| Dimension | Evidence | Status |
| --- | --- | --- |
| Mapped statistical semantics in sampled actual seasons | 1,016,826 numerical/format/percentile/stint comparisons; 0 mismatches | PASS for sampled scope |
| 50/4 qualification, rate and season switching | React synthetic plus original source-backed browser journeys; updated Flutter startup proof pending fresh source-backed rerun | Real-source checks passed previously; exact new startup gate unverified until rerun |
| Searching, virtual scroll, sorting, 2TM/3TM | Synthetic browser tests plus full source-backed script and 20-step scroll rAF probe | Partial POC |
| Chart axis/zoom/pan/regression/retained settings | Browser tests and real-source scenario with screenshots | Partial POC, one chart type |
| Keyboard/deep links, narrow and wide screens, dark and light | Semantics and synthetic Playwright coverage; real screenshots captured by runnable script | Native Safari and operator review outstanding |
| Python and Sheets | Original iframe Labs acknowledge strictly typed context; no credentials, code, or workbooks sent | Workbook roundtrip and native service checks not certified |
| Paired Flutter vs React performance | Original season task and corrected Advanced Stats manual comparisons; new isolated chart protocol | Season and Advanced Stats recorded; chart equivalence and timing pending |
| Frame and memory | Browser rAF gaps and resource transfer proxies instrumented, but not GPU frame drops or peak memory | Incomplete |
| Cross-browser and screen readers | Playwright Linux Chromium/Firefox/WebKit synthetic tests | Native macOS Safari, VoiceOver and Windows NVDA still required |
| Full product completeness and CBA correctness | React implements intentionally narrow pilot | BLOCKER to full migration |

## Exact matched source and release-build protocol

From the local repo root, with original NBA canonical v5 shards and pinned React dependencies installed, run:

~~~bash
git pull --ff-only
bash scripts/phase3_release_compare.sh --automated
~~~

The launcher builds BOTH Flutter web release and React/Vite production bundles. It hosts the Flutter release at 127.0.0.1:8768 and React release at 127.0.0.1:4173, avoiding the user's existing Flutter debug (8765) and React dev (5173) servers. It refuses port collisions and missing static files, runs against the actual local 80-season publication without rebuilding the historical warehouse, and tears down its own comparison servers when finished.

The automated stage checks exact bytes of the selected 2025–26, 1986–87 and 1946–47 regular/playoff shards on BOTH local servers, not merely the static manifest. It checks 50-game/4-playoff-game qualification against actual source records, basis switching, PTS reverse-sort, source-backed search, available team stints, Stats-to-Advanced and browser-back navigation, chart zoom/pan/axes/reset/regression with persisted settings, keyboard focus and 390px/1440px dark/light screenshots. Source files and tokens are not uploaded. The Flutter bootstrap and original screenshot are kept separate from the React task timings: a Flutter canvas root selector is not evidence that Flutter displayed a particular stats row.

The retired original interactive stage was designed to run 5 cold and 10 warm same-machine samples PER APP PER TASK for three crucial UX workflows: (1) Regular to Playoffs and back, (2) per-game to per-36 to per-100 and reverse sort, and (3) chart zoom/pan/reset/re-axis. There were **90 planned human task attempts**, alternating app order, but the original study was stopped after the newly observed React Advanced Stats mismatch; its historical partial raw results are preserved and cannot be reused for repaired Advanced Stats. The operator explicitly marks each trial Start, Finish or Fail, and partial results are checkpointed after each trial. The browser samples rAF gaps during user tasks; rAF gaps are only an approximation, NOT true GPU dropped-frame counts. Warm runs reuse browser context but open a fresh tab.

The pre-registered benchmark gate demands zero failed tasks and no React p95 task time greater than 110% of Flutter's p95, with at least 5 cold and 10 warm trials for each app/task. Missing or incomplete measurements cannot be treated as a pass.

## Evidence files and decision policy

The scripts write ignored local JSON and screenshots under:
- experimental/arcside-react/evidence/real/real-source-journeys.json
- experimental/arcside-react/evidence/guided/guided-checkpoint.json
- experimental/arcside-react/evidence/guided/guided-matched-task-timings.json
- experimental/arcside-react/evidence/decision/phase3-decision.json and phase3-decision.md

The decision script can be executed separately:

~~~bash
cd experimental/arcside-react
node scripts/phase3_decision.mjs
~~~

It records PASS, FAIL or NOT_RUN separately for real mathematical parity, source identity, real browser workflows and matched operator p95; it rejects synthetic-only and incomplete evidence. Full-feature CBA/profile parity, native Safari/VoiceOver/NVDA, workbook roundtrips, memory/GPU acceptance and explicit owner sign-off remain mandatory independent gates. An operator's photographs or browser screenshots must be visually reviewed; their existence does not prove a UX improvement.


## Advanced Stats parity repair after real same-machine operator review

The owner's **2025–26 regular season** Flutter/React season-switching workflow completed **15 trials per app**, with no marked failures. Warm manually timed medians were **3,075 ms Flutter / 2,729 ms React**, p95 **6,891 ms Flutter / 4,059 ms React**. These are human task-completion measurements and do not isolate rendering or establish a general React speedup.

The owner then discovered a **real Advanced Stats functional mismatch** while performing the shared basis/sort workflow: Flutter exposes Overview PPG → PTS/100 and many metric categories, whereas the initial React proof of concept had only a short fixed advanced metric list. Two React basis trials were correctly marked failed, and the 34 recorded trials were preserved. The local checkpoint and generated feature-parity blocker remain a historical record; don't mutate past observations or claim a passing measurement.

**Remediation implemented on the experimental React branch:**
- Port the **18 Flutter Advanced Stats stat groups** and 233 catalog metric definitions into the pilot. Add Flutter Physical Profile's source-native text fields (College / Country), group-specific child-column expansion overrides, and a source-derived unavailable field marker rather than fabricated metrics.
- Use the same named rate-sensitive Overview/Rate Adjusted scoring columns: **PPG (per game)**, **PTS/36**, **PTS/100**, and season totals. Reverse-sort the actual displayed PTS/100 column; visible headers announce ascending/descending.
- Implement selectable metric-group chips, group dropdown, GP and MPG minimums, player/team/position filters, reset, page sizes (10/20/50/100), prior/next pagination, source-recorded team stint expansion, and CSV copying. Dense horizontal table scrolling preserves player identity.
- Resolve catalog-native raw source aliases before engine-backed fields, normalize field-key casing/punctuation, and implement explicit source-grounded catalog fallbacks for PPS, net rating, and contested/uncontested rebounds. Missing source fields remain unavailable. No synthetic fixtures are substituted in runtime code.
- Add catalog/rate and rendering/browser tests plus actual-corpus React browser steps in `real_corpus_journeys.mjs`. These verify the previously missing PTS/100 header and sort within the original source-data environment.

**Remaining limits:** The catalog is now exposed, but complete provider-native column population in every season and every group has NOT yet been audited against Flutter's snapshot path. Exact visual equivalence, 100% source metric coverage, full product feature parity, and same-machine matched Advanced Stats timing must remain unapproved until separately measured. The previous feature-parity blocker is historical evidence, not automatically cleared by writing a new React implementation. Original Flutter remains untouched and authoritative.

Local verification after pulling (React source changed, so **rebuild the React bundle**):

~~~bash
cd ~/sports_terminal
git pull --ff-only
(cd experimental/arcside-react && npm run build && npm run test)
# Flutter's previous release build may be reused; React dist was just rebuilt.
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --automated
~~~

For the synthetic cross-browser tests, run `(cd experimental/arcside-react && npm run test:browser)` with browser dependencies installed. Do not restart the 90-trial guided comparison or use `--all` until a new equivalence check and test protocol are approved.

## Targeted Advanced Stats acceptance, post-repair

**New protocol only. Never reuse the 34 original operator trials for post-repair Advanced Stats measurements.** Source parity and human verification are distinct. The original issue remains in `evidence/guided/advanced-stats-parity-blocker.json` as immutable evidence.

The controlled acceptance is implemented in `test/phase3_advanced_acceptance_export_test.dart`, `scripts/advanced_acceptance_compare.mjs`, and `scripts/guided_advanced_acceptance.mjs` (under the React experiment). The Dart exporter **executes the original** `NbaStatsWorkstationEngine` and `NbaTerminalMetricResolver` over exact canonical season shards for 2025–26, 1986–87, and 1946–47, regular and postseason, across all six rate bases. React independently computes its values from those same local shards, checks the Dart-exported metric catalog and group definitions, samples players across each full season, and records per-column numerical/null agreement, default filters, ascending/descending PPG ordering, and source availability. Unpopulated provider metrics are reported explicitly; empty 1946–47 playoff samples are never counted as affirmative evidence.

First, run the **automated** reference-and-browser acceptance (do not restart old 90-trial study):

~~~bash
cd ~/sports_terminal
git pull --ff-only
(cd experimental/arcside-react && npm run build && npm test)
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --advanced-acceptance
~~~

This creates `evidence/advanced/dart-reference.json` and `evidence/advanced/advanced-source-parity.json`. The automated stage fails on mismatched original NBA data, catalog semantics, metric values, filter/sort behavior, or browser runtime errors. The source report includes a capped sample of precise mismatches to debug, not an unconditional PASS. Review `evidence/decision/phase3-decision.md` after the run. If source parity fails, fix the actual difference and rerun; **never** skip the check or reuse old goldens.

Only after source parity passes, run the **new isolated matched UI/task performance protocol**:

~~~bash
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --advanced-guided
~~~

The operator first visually checks the *actual Flutter Advanced Stats and React Advanced Stats* side-by-side. Flutter cannot be certified via React DOM selectors. The preflight requires explicitly typing `MATCHED`; otherwise it records a blocker and does not time anything. On acceptance, the guided task is identical in each app: 2025–26 Regular / Overview / Per Game / PTS descending; start stopwatch, select Per 36 then Per 100, reverse-sort PTS/100, verify the values and sort, finish or fail. Runs are 5 cold + 10 warm per app, alternating app order (30 total). Recordings include machine and browser version, original manifest hash, cold/warm counts, raw measurements, and 50th/95th percentile. The existing 10% p95 regression gate applies; 30 correct completions and a verified preflight are required. **Any failed functional attempt stops the trial set.**

Trials are checkpointed to `evidence/advanced/guided-checkpoint-v2.json` and reported at `evidence/advanced/advanced-guided-timings-v2.json`. If interrupted after a successful preflight, resume the corrected protocol with:

~~~bash
ARCSIDE_ADVANCED_RESUME=1 ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --advanced-guided
~~~

The decision report has independent `advanced_stats_source_semantic_parity`, `advanced_stats_ui_feature_parity`, and `advanced_stats_matched_task_p95` gates. It may supersede the *historical UI blocker* only after the new real-source evidence plus operator-attested full matched trials; it never deletes old failed trials. Even an Advanced Stats PASS **does not approve a full framework migration**.

### Remaining Phase 3 work by scope

For the **narrow React technical proof**, real-data cross-engine engine parity and the production-build/browser shell exist; the new Advanced Stats evaluation, visualization equivalence/performance, and final evidence review remain. For an actual **whole-platform replacement decision**, additional gates are independent: complete Flutter feature and CBA/trade/profile parity, native macOS Safari and VoiceOver/Windows NVDA accessibility, original Labs workbook round-trip and native-service security, matched peak-memory and render/GPU measurements, and explicit user review/signoff. The React POC deliberately omits large product screens, so those are substantive implementation projects, not merely tests that can be marked complete. Avoid quoting a percentage of full migration readiness from the narrow numeric parity results.

## Recommended architecture decision as of November 20

**Retain Flutter as the authoritative product, keep the React pilot isolated and continue the controlled evidence collection.** React browser-native routes, semantics and seamless JS Labs integration are promising, and the sampled 100% statistical match materially reduces porting risk. But neither React speed superiority nor complete product parity has been measured or established. The proposed 10% p95 performance threshold is a decision criterion, not an observed advantage. A failed critical task, a significant React slowdown, or a lost feature rejects full replacement even if the mathematical comparison is perfect.

PR #89 remains draft and must not be merged, and production Flutter must not be retired, without the complete runtime/feature/accessibility/security record and the owner's explicit approval.


## Post-repair remaining technical pilot protocols (November 20, 2026)

The real-corpus Advanced Stats acceptance and 30 manual trials have **already passed on the owner's Mac** and must not be rerun merely to fill the legacy 90-trial study. The prior 90-trial plan included non-equivalent UI after React's original Advanced Stats omission; its basis and chart observations are excluded from all post-repair performance gates. The season-switching block recorded 30 completed trials with no failures and remains separately eligible as historic season-only evidence.

### 1. Honest Flutter bootstrap and React real-source browser evidence

`scripts/real_corpus_journeys.mjs` now records concrete Flutter surface bounds and visible status, bootstrap latency and screenshot SHA-256, preserving the screenshot for human visual inspection. It verifies identical original manifest **and source-shard bytes** on both release servers; React routes exercise season/segment qualification, Stats, Advanced taxonomy/basis/sorting, chart controls and Labs acknowledgement. The decision report includes a per-browser diagnostic breakdown for missing exact season/segment journeys, shard coverage, Flutter renderer bootstrap, JS errors and console errors.

This gate **does not** assert Flutter row-level UI matching or automated Flutter chart controls. It is a release bootstrap and original-source React journey gate only, and cannot pass without a fresh local browser run that supplies the new bootstrap evidence. Because GitHub Actions does not contain the owner's private canonical source shards, CI can check syntax and synthetic scenarios, not fabricate live original-source runtime evidence.

~~~bash
cd ~/sports_terminal
git pull --ff-only
# Build both release apps if source code changed; omit REUSE_BUILDS on the first run.
bash scripts/phase3_release_compare.sh --automated
~~~

If the printed decision still reports the bootstrap gate blocked, inspect `experimental/arcside-react/evidence/decision/phase3-decision.json` at `gates[].detail.browsers`, including `missingRoutes`, `consoleErrorExamples`, `flutterBootstrap` and `completeShards`. Never auto-clear errors merely because a browser opened.

### 2. Repaired matched tasks and new Visualization protocol

The combined `matched_flutter_react_operator_tasks_p95` gate now requires **three independent real-source, user-verified protocols**. It reuses only the original 30 successfully completed *season* trials (5 cold + 10 warm per app), incorporates the accepted *corrected Advanced Stats* 30 trials, and separately requires **30 fresh Visualization trials**. Each group must have 0 failed interactions and React warm p95 <= 110% of Flutter warm p95. All three groups must use the same original-source manifest. This replaces, rather than retrospectively edits, the old 90-trial schema.

To run the last new 30-trial group:

~~~bash
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --visualization-guided
~~~

On the initial headed-browser preflight, the operator must confirm both live chart experiences really support **wheel zoom, drag pan, reset, X=REB and Y=AST**, with actual point/tooltips agreement. This is deliberately a narrow common chart task, not a claim of parity for the entire Flutter Visualization Studio. If the React chart differs too much from Flutter, type `FAIL`; the protocol records a blocker without claiming a benchmark. Do not time an approximate or swapped task.

The new chart evidence is stored at `experimental/arcside-react/evidence/visualization/visualization-guided-timings-v1.json`, and checkpoints at `visualization-guided-checkpoint-v1.json`. Recover interrupted sessions via:

**Current chart-runner resume environment variable** (shared implementation with the corrected Advanced protocol):


~~~bash
ARCSIDE_ADVANCED_RESUME=1 ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --visualization-guided
~~~

Do not use `--all`: it now refuses to rerun the obsolete original 90-trial protocol.

### 3. Reliable measurement controls

`scripts/guided_overlay.mjs` installs the stopwatch with Playwright `addInitScript` so it survives page reloads; a DOM mutation observer replaces the panel after an SPA remount. The shared panel records operator Start/Finish/Fail and optional browser rAF gaps as **scheduling proxies only**, not GPU frames. If a reload occurs after Start, the benchmark terminates that trial as failed rather than treating a navigation-spanning stopwatch as clean evidence. Partial trial checkpoints remain preserved. Cross-browser regression checks exercise actual reload and injected panel removal.

### 4. Non-pilot release blockers

Even if the narrow chart task passes and both technical gates clear, React still lacks much of the Flutter application. Full parity for the Trade Machine/CBA, player profiles, Visualizations, other modules and Labs; real assistive-technology acceptance; secure native-service/workbook round-trips; matched real frame/GPU/memory evidence; and owner visual/migration signoff are separate outstanding gates. Passing the three technical human-task suites never authorizes migration or a PR merge.
