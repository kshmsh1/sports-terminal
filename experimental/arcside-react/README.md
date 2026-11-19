# Arcside Phase 3 — React/Vite controlled prototype

**This is an experimental UI alongside Flutter, not a migration or production replacement.**
The branch is stacked on Phase 2 (PR #88), Phase 1 (PR #87) and Labs PR #86. PR #81's player-profile parity changes remain a separate dependency.

## Launch without rebuilding on every preview

The canonical historical data MUST already exist in the local checkout. From repository root, run the existing static compiler/launcher as needed, using your authentic historical warehouse. Check:
- `data/warehouse/nba_history.sqlite` is your real local canonical warehouse (not checked in).
- `web/data/nba_static/manifest.json` exists with `contract=sports-terminal-static-nba-website-v5`, `static_schema_version=5` and its original `database_fingerprint`.
- `web/data/nba_static/seasons.json` and `seasons/<season>/{regular,playoffs}.json` exist. Some seasons can legitimately have no playoff rows.

Then:

```bash
cd experimental/arcside-react
npm install
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

## Lab security

Python companion and Sheets collaboration are local-only, separately authenticated services. The pilot does not alter or forward credentials. The bridge accepts an object with exactly `{type:'arcside:context',version:1,season,segment}` from the same-origin parent window and sends only a same-origin acknowledgement; it accepts no code, workbook, token, URL or arbitrary object fields. Never host this as an internet-facing Python executor.
