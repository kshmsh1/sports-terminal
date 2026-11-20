# Arcside Phase 3 — comparative UI/UX and performance evaluation (November 20, 2026)

**Decision: controlled pilot is NOT yet eligible for a frontend migration approval.** This evidence ledger distinguishes verified measurements from tooling and unexecuted local or human validations. The unpublished canonical NBA shards and the original interactive Flutter runtime reside on the owner's Mac, not in GitHub Actions.

## Verified evidence

- Original Dart versus React on actual canonical 2025–26, 1986–87 and 1946–47 NBA season shards, regular and playoff segments, six rate bases: **1,016,826 matched field comparisons, zero mismatches**. All 1946–47 playoff cases contain zero rows; no historical playoff parity is asserted there.
- Existing React-only synthetic browser benchmarks cover 1k/10k/50k-row tables and 300/5k/25k-point charts. Earlier 1 cold and 2 warm smoke runs have no matched Flutter baseline, so they establish neither speedup nor reliable p95.
- The Phase 3 shell includes native browser route URLs, qualified and virtualized Stats/Advanced slices, one ECharts scatter explorer, recorded team-stint expansion, and integration of the unchanged original browser-native Python and Sheets Labs. It does NOT yet port all original Flutter screens, advanced metric taxonomy, detailed player profiles, saved views, full Visualization Studio, Trade Machine/CBA UI, or financial and comparison tools.

## Evaluation dimension results

| Dimension | Evidence | Status |
| --- | --- | --- |
| Mapped statistical semantics in sampled actual seasons | 1,016,826 numerical/format/percentile/stint comparisons; 0 mismatches | PASS for sampled scope |
| 50/4 qualification, rate and season switching | React synthetic browser tests; expanded real-source script now verifies counts and changes | Real-source UI run pending |
| Searching, virtual scroll, sorting, 2TM/3TM | Synthetic browser tests plus full source-backed script and 20-step scroll rAF probe | Partial POC |
| Chart axis/zoom/pan/regression/retained settings | Browser tests and real-source scenario with screenshots | Partial POC, one chart type |
| Keyboard/deep links, narrow and wide screens, dark and light | Semantics and synthetic Playwright coverage; real screenshots captured by runnable script | Native Safari and operator review outstanding |
| Python and Sheets | Original iframe Labs acknowledge strictly typed context; no credentials, code, or workbooks sent | Workbook roundtrip and native service checks not certified |
| Paired Flutter vs React performance | Same-hardware release-build launcher and manually verified alternating trials now implemented | NOT MEASURED until local operator execution |
| Frame and memory | Browser rAF gaps and resource transfer proxies instrumented, but not GPU frame drops or peak memory | Incomplete |
| Cross-browser and screen readers | Playwright Linux Chromium/Firefox/WebKit synthetic tests | Native macOS Safari, VoiceOver and Windows NVDA still required |
| Full product completeness and CBA correctness | React implements intentionally narrow pilot | BLOCKER to full migration |

## Exact matched source and release-build protocol

From the local repo root, with original NBA canonical v5 shards and pinned React dependencies installed, run:

~~~bash
git pull --ff-only
bash scripts/phase3_release_compare.sh --all
~~~

The launcher builds BOTH Flutter web release and React/Vite production bundles. It hosts the Flutter release at 127.0.0.1:8768 and React release at 127.0.0.1:4173, avoiding the user's existing Flutter debug (8765) and React dev (5173) servers. It refuses port collisions and missing static files, runs against the actual local 80-season publication without rebuilding the historical warehouse, and tears down its own comparison servers when finished.

The automated stage checks exact bytes of the selected 2025–26, 1986–87 and 1946–47 regular/playoff shards on BOTH local servers, not merely the static manifest. It checks 50-game/4-playoff-game qualification against actual source records, basis switching, PTS reverse-sort, source-backed search, available team stints, Stats-to-Advanced and browser-back navigation, chart zoom/pan/axes/reset/regression with persisted settings, keyboard focus and 390px/1440px dark/light screenshots. Source files and tokens are not uploaded. The Flutter bootstrap and original screenshot are kept separate from the React task timings: a Flutter canvas root selector is not evidence that Flutter displayed a particular stats row.

The interactive stage runs 5 cold and 10 warm same-machine samples PER APP PER TASK for three crucial UX workflows: (1) Regular to Playoffs and back, (2) per-game to per-36 to per-100 and reverse sort, and (3) chart zoom/pan/reset/re-axis. There are **90 total human-verified task attempts**, alternating app order. The operator explicitly marks each trial Start, Finish or Fail, and partial results are checkpointed after each trial. The browser samples rAF gaps during user tasks; rAF gaps are only an approximation, NOT true GPU dropped-frame counts. Warm runs reuse browser context but open a fresh tab.

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

## Recommended architecture decision as of November 20

**Retain Flutter as the authoritative product, keep the React pilot isolated and continue the controlled evidence collection.** React browser-native routes, semantics and seamless JS Labs integration are promising, and the sampled 100% statistical match materially reduces porting risk. But neither React speed superiority nor complete product parity has been measured or established. The proposed 10% p95 performance threshold is a decision criterion, not an observed advantage. A failed critical task, a significant React slowdown, or a lost feature rejects full replacement even if the mathematical comparison is perfect.

PR #89 remains draft and must not be merged, and production Flutter must not be retired, without the complete runtime/feature/accessibility/security record and the owner's explicit approval.
