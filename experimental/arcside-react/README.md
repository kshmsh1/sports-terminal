# Arcside Phase 3 — React/Vite controlled prototype

**React is the preferred local development frontend in the migration branch, while original Flutter remains fully available as a reversible reference. This is not a production certification or deployment switch.**
The branch is stacked on Phase 2 (PR #88), Phase 1 (PR #87) and Labs PR #86. PR #81's player-profile parity changes remain a separate dependency.

## React-first local beta (reversible)

From the repository root, `bash scripts/open_terminal.sh` compiles or verifies the original published data and starts React. For quick boot from an existing source-backed v5 corpus with installed dependencies, use `bash scripts/launch_arcside.sh --platform --fast`.

To revert to the original Flutter UI at any time, use `bash scripts/open_terminal.sh --flutter` or `bash scripts/launch_arcside.sh --flutter --fast`. Do not delete Flutter, the original local warehouse, or any generated data. The React implementation is still incomplete on multiple original modules, including exhaustive Trade Machine/CBA and player dossier parity.

Full architecture notes, known performance failures, remaining certification and rollback: `docs/architecture/react_first_beta_migration_2026_11_23.md`.

## Launch without rebuilding on every preview

The canonical historical data MUST already exist in the local checkout. From repository root, run the existing static compiler/launcher as needed, using your authentic historical warehouse. Check:
- `data/warehouse/nba_history.sqlite` is your real local canonical warehouse (not checked in).
- `web/data/nba_static/manifest.json` exists with `contract=sports-terminal-static-nba-website-v5`, `static_schema_version=5` and its original `database_fingerprint`.
- `web/data/nba_static/seasons.json` and `seasons/<season>/{regular,playoffs}.json` exist. Some seasons can legitimately have no playoff rows.

Then:

```bash
cd experimental/arcside-react
npm ci  # exact checked-in package-lock.json; use npm 11
npm run dev
# http://127.0.0.1:5173/stats
```

**Do not run a static rebuild just to preview.** The Vite development server serves the existing `web/data/nba_static` files and original `web/labs` under the SAME origin. The React SPA does not fetch basketball data from third parties or start any Python services. To use opt-in local Python or Sheets collaboration, start the pre-existing Labs services separately using the existing scripts; the React shell never handles their tokens.

Run `node scripts/inspect_corpus.mjs --out evidence/local-corpus-audit.json` to validate the **actual local release** without a rebuild. It prints the manifest SHA-256/fingerprint, checked season/segment row counts, missing-value coverage and recorded team stints for selected early/middle/latest seasons. This tool will fail visibly when the real release is absent or inconsistent; it never substitutes mock records. Use `--seasons 1995-96,2025-26` to inspect additional exact cohorts.

`npm run build` bundles only the React shell. Production static hosting must explicitly mount the same `/data/nba_static` and `/labs` paths, and must never publish local secrets or the warehouse. `npm run preview` uses the same development resource mounts for local comparison.

## Pilot surfaces

- `/stats` and `/advanced`: real v5 season shards, typed adapter, qualification (50+ regular / 4+ playoffs), sorts, rate bases, a virtualized fixed-height row window, source-recorded multi-team stints, nulls distinct from zeros.
- `/visualizations`: one ECharts scatter (same source rows), axis metrics, selected-player persistence, wheel zoom versus drag pan, reset and optional linear fit.
- `/workspaces/python` and `/workspaces/sheets`: embed ORIGINAL Labs HTML/JS via iframe; standalone links use the same original applications. Their only modification is importing `arcside_context_bridge.mjs`, an origin-checked typed message handler for benign season/segment context. The original Python runtime, Monaco, formulas, IndexedDB and collaboration functions are otherwise unchanged.
- `/player/:id`: read-only original dossier lookup **only** when canonical player-index IDs match. This is not an implementation of PR #81 or a full player page.

The POC deliberately does NOT replace Trade Machine, full player profiles, authenticated sessions, live NBA data, production deployment, or the Excel/Python runtime.

## Testing

```bash
npm test                         # ported stat semantics vs original committed Dart test vectors
npx playwright install chromium
npm run test:browser             # synthetic UI route tests; NOT evidence of real NBA accuracy
dart run tools/export_trade_golden.dart > /tmp/arcside-original-dart.json
# When an independently implemented rules service/TS port is ready:
node scripts/compare_trade_goldens.mjs /tmp/arcside-original-dart.json candidate.json
ARCSIDE_COLD_RUNS=5 ARCSIDE_WARM_RUNS=10 npm run benchmark
```

The CBA golden exporter calls the original Dart engine and does not pretend to validate an absent React/CBA implementation. Save and human-review its output before treating it as a baseline. Benchmark command runs synthetic UI loads of 1k/10k/50k stats rows and 300/5k/25k chart points, writes raw samples/summary to ignored local `evidence/benchmarks`, and **cannot** establish Flutter-vs-React superiority by itself.

For a real Phase 3 evaluation, follow the [pre-registered protocol](../../docs/architecture/phase3_frontend_proof_protocol.md) and the [implementation and evidence ledger](../../docs/architecture/phase3_experiment_evidence_2026_11_18.md). Record Flutter build/renderer/browser versions, identical live manifest fingerprint, source-backed real-data task outcomes, all three browsers and manual Safari/NVDA/VoiceOver findings. Do NOT make a migration recommendation until those gates pass.


## Phase 3 evidence on the owner's real data (no invented baselines)

**Reproducibility is complete:** the npm 11-generated lockfile from passing audited CI is checked in. Run `npm ci` to reproduce it, not `npm audit fix --force`.

**Recommended one-command actual-corpus retest after any code update:** From the repository root, run `bash scripts/phase3_parity_rerun.sh`. This regenerates the Dart reference (never uses stale goldens), runs React in report-only mode, and prints the full per-case mismatch summary. It does not report a pass unless the mismatch count is zero. The script doesn't install or download any browsers.

**Original Dart ⇄ React statistical comparison:**
From the REPOSITORY ROOT, run:

```bash
flutter pub get
flutter test test/phase3_stats_parity_export_test.dart --reporter expanded \
  --dart-define=ARCSIDE_PARITY_CORPUS=web/data/nba_static \
  --dart-define=ARCSIDE_PARITY_SEASONS=2025-26,1986-87,1946-47
cd experimental/arcside-react
ARCSIDE_PARITY_REPORT_ONLY=1 npm run test:parity
```

The original Flutter implementation writes `evidence/parity/dart-reference.json`; the independent TypeScript comparison writes `evidence/parity/parity-comparison.json`. The command compares all source-exposed metric values, display formatting, age/position, 6 rate bases, recorded team stints and percentiles. It **reports all mismatches**, including Dart's historical missing-field zero fallback versus React's explicit null behavior. `REPORT_ONLY=1` is not a passing strict gate; omit it to demand zero mismatches. Keep outputs local and review any intentional changes in source semantics rather than simply declaring them equal.

**Real-source browser interactions:**
Start both apps on separate local addresses. From repository root, launch Flutter in one terminal:

```bash
flutter run -d web-server --web-port 8765 --web-hostname 127.0.0.1
```

From another terminal launch the React pilot:

```bash
cd experimental/arcside-react
npm ci
npm run dev
```

From a third terminal in `experimental/arcside-react`:

```bash
# Google Chrome on macOS works without downloading Playwright Chromium:
ARCSIDE_BROWSER_CHANNEL=chrome ARCSIDE_REAL_BROWSERS=chromium npm run test:real
# Only when bundled browser engines are actually installed:
# npx playwright install chromium firefox webkit
# ARCSIDE_REAL_BROWSERS=chromium,firefox,webkit npm run test:real
```

The checker **fails** if either server serves an absent or byte-different `manifest.json` than the owner's actual local source. It traverses historical regular and playoff Stats/Advanced/Visualization and Labs context handshakes, producing `evidence/real/real-source-journeys.json` plus comparison screenshots. It captures a Flutter reference screenshot but does **not** compare Flutter widget interactions automatically; Flutter widget trees are not equivalent to React DOM selectors.

**Matched same-machine Flutter/React workflow measurements** (interactive and operator-verified):

```bash
ARCSIDE_BROWSER_CHANNEL=chrome ARCSIDE_GUIDED_COLD_RUNS=5 ARCSIDE_GUIDED_WARM_RUNS=10 npm run compare:guided
```

Use both apps with the same static data and Chromium version. Follow the prompts for three pre-registered critical tasks: regular/playoffs switching; rate basis + sorting; and visualization zoom/pan/axes. Each application gets **5 cold and 10 warm trials**, alternating order. The same small stopwatch controller appears in both windows. Click **Start** immediately before the task and **Finish** only after verifying the correct result; use **Fail** for incorrect or broken tasks. The report at `evidence/guided/guided-matched-task-timings.json` contains raw timings, p50/p95, hardware, source fingerprint and whether the proposed 10% p95 regression rule was satisfied. Trials depend on careful manual setup of Flutter's equivalent screen; timing is human-controlled and not an automated dropped-frame benchmark.

**Still required for a migration decision:** real Safari on macOS and screen-reader keyboard journeys, repeatable dropped-frame and memory measurements, workbook import/export integrity, complete metric/display/sort parity, signed-off trade rules golden cases, and feature equivalence beyond the deliberately narrow Stats/Visualization pilot. No milestone may be marked as passed solely because a test tool exists.

## Phase 3 — real-data UI/UX and matched release comparison

The owner's genuine local 2025-26, 1986-87 and 1946-47 corpus passed **1,016,826 mapped Dart/React comparisons with zero mismatches**. Six 1946-47 playoff cases were empty and do not count as positive playoff evidence. This does not make the React POC a complete replacement for Flutter.

For the meaningful frontend comparison, do **not** time a Flutter debug server against Vite dev. From the repository root, run:

~~~bash
git pull --ff-only
bash scripts/phase3_release_compare.sh --automated
# Preferred Phase 3 continuation: source-backed objective browser observations
bash scripts/phase3_release_compare.sh --objective
~~~

The launcher compiles Flutter web **release** and React **production**, serves both on new loopback ports (Flutter 8768; React 4173), hashes the exact original manifest and selected season shards on both servers, runs real-data browser journeys with installed Chrome, and emits a PASS / FAIL / NOT_RUN decision report. The legacy --all human stopwatch protocol has been retired because it mixed unresolved feature mismatches and operator time with frontend latency. --objective instead collects browser-observable load, animation frame scheduling, React chart zoom/pan DOM events, source-based module coverage, disposable-Lab roundtrip checks and an accessibility smoke. Flutter chart rendering/GPU latency, native Safari/VoiceOver/NVDA and local privilege security remain unmeasured and BLOCKED. See PHASE3_OBJECTIVE_README.md.

Outputs are kept in ignored local evidence directories: evidence/real, evidence/guided and evidence/decision. Review the artifacts and the design tradeoffs in docs/architecture/phase3_ui_ux_comparative_evaluation_2026_11_20.md. Run node scripts/phase3_decision.mjs in this directory to re-evaluate without rebuilding. Missing evidence is NOT_RUN; a synthetic React-only benchmark never proves Flutter-vs-React speedup. Any 10% p95 claim requires complete operator-verified same-hardware samples. Full product migration and owner sign-off remain separate mandatory gates.

## Lab security

Python companion and Sheets collaboration are local-only, separately authenticated services. The pilot does not alter or forward credentials. The bridge accepts an object with exactly `{type:'arcside:context',version:1,season,segment}` from the same-origin parent window and sends only a same-origin acknowledgement; it accepts no code, workbook, token, URL or arbitrary object fields. Never host this as an internet-facing Python executor.
