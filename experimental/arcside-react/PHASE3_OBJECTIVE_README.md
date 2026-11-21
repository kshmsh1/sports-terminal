# Phase 3 objective evidence (experiment only)

This suite replaces the 24 user-timed Visualization Studio benchmark as the **default next investigation**, but it does **not** magically supply a comparable Flutter chart-render timestamp. Human stopwatch trials are archived; previous observed failures are not silently rewritten. Flutter and the historical source remain authoritative.

## Run on the original Mac

Use the committed Phase 3 branch with the user's genuine untracked `web/data/nba_static` v5 corpus. The default command builds BOTH release shells, starts ephemeral loopback-only servers and collects baseline journeys, scope, browser, Labs and accessibility probes:

```bash
cd ~/sports_terminal
git pull --ff-only
bash scripts/phase3_release_compare.sh --objective
```

The browser must have Google Chrome installed for the default `ARCSIDE_BROWSER_CHANNEL=chrome`. Set `ARCSIDE_BROWSER_CHANNEL=` for Playwright's Chromium engine if installed.

The benchmark collects 5 fresh-context and 10 reused-context observations for each shell, alternates variant order, records browser navigation timing, initial paint markers, visible DOM milestones, Chromium JS heap where available, request/console failures and settled requestAnimationFrame intervals. It does NOT exercise identical chart interactions in Flutter and React, does not claim actual GPU presents, and does not compare Flutter bootstrap to React chart readiness as equal tasks.

`ARCSIDE_OBJECTIVE_COLD=2 ARCSIDE_OBJECTIVE_WARM=3 bash scripts/phase3_release_compare.sh --objective` is a **diagnostic smoke only**; default is 5+10. Set `ARCSIDE_OBJECTIVE_BROWSER=firefox` or `webkit` for separate browser probes if Playwright's binaries are installed. Native macOS Safari/VoiceOver and Windows NVDA still require their actual platforms.

The readiness audit inspects tracked Flutter screen implementations and the React pilot's routes. Missing Trade Machine, comparison and box-score modules are recorded as real blockers. The pilot now includes source-backed original-dossier career and Advanced Stats family tables; complete Flutter profile parity (contracts, honors, full interaction semantics) is still not verified. The original Dart and independent TypeScript CBA validators now run 15 deterministic golden comparison scenarios. The React pilot also contains a read-only editable scenario editor. This is **limited rule parity only**: it is not the production Trade Machine UI, verified live cap/asset ingestion, or every CBA edge case.

The Labs integrity probe imports a **throwaway** Python file, downloads it and the original project archive, exports and reimports a throwaway Sheets workbook JSON, and checks a same-origin typed context message. It uses a fresh Playwright browser context and does not connect Python's native companion or authenticated collaboration. This is deliberately not a security certification.

The accessibility probe checks landmarks, skip-link focus, image alternatives and embedded Lab titles. It is not axe/WCAG certification, actual VoiceOver/Safari or NVDA.

## Evidence paths

- `experimental/arcside-react/evidence/objective/objective-browser-performance.json`
- `experimental/arcside-react/evidence/readiness/phase3-readiness-audit.json`
- `experimental/arcside-react/evidence/accessibility/accessibility-smoke.json`
- `experimental/arcside-react/evidence/labs/lab-integrity.json`
- `experimental/arcside-react/evidence/profiles/profile-corpus-smoke.json`
- `experimental/arcside-react/evidence/trade/dart-trade-reference.json`
- `experimental/arcside-react/evidence/decision/phase3-decision.md`

All outputs are excluded from Git, preserving user-local private data and hardware details. Tests are **not yet executed against the owner's Mac** until the owner runs the command and shares the resulting summary.

## Architecture decision remains pending

The React pilot is a good experimental reference for Stats, Advanced Stats, Visualization Studio, and the unchanged embedded Labs, but full application migration is **not approved**. Any comprehensive framework switch requires verified full player-profile behavior, full CBA engine and transaction-UI parity with real input data, comparisons, financials, box scores, the remaining Arcside workflows, native accessibility, Lab authorization security, genuinely matched critical-interaction/GPU measurements and explicit owner signoff. The decision ledger records the missing work rather than stamping it PASS.

Recommended next implementation path after reviewing local evidence: measure identical chart input-to-render behavior using explicit, equivalent app-level instrumentation in Dart/Flutter and React; test both on the same physical hardware; then complete full player profile parity (contracts and honors) and independent trade rule/service parity before reconsidering wholesale migration.

## November 20 isolated Trade Machine and contract-source continuation

The independent TypeScript validator at `src/tradeEngine.ts` mirrors every identified finding-code family in the existing authoritative `lib/services/trade_machine_engine.dart`; the original Dart and separate TypeScript fixture engines are checked against **15** golden scenarios in GitHub CI and the local `--objective` suite. This is a partial sample and not a blanket proof of correctness for all possible salary/apron/pick states.

The React `/trade` path is an isolated two-team **hypothetical** scenario editor. It does not read from or mutate source contracts, approve trades, or replace Flutter's full Trade Machine. The source-coverage audit keeps full production trade parity as FAIL.

Player profiles now reuse the original published dossier, original-Dart honor naming/ending-year semantics, and a dated read-only salary seed derived at Vite build time from `lib/services/nba_trade_contract_seed.dart`. The source is labeled `2026-09-11` and is not claimed as live. The page can also join original published static `/data/nba_static/front_office/contracts.json` rows, when available, but doesn't read Flutter's browser-local mutable registry overlay.

After pulling these changes, the React Vite build must be refreshed because its code and dated salary asset changed. The original Flutter application source was not modified, so **you may safely reuse your existing Flutter release build only after rebuilding React**:

```bash
cd ~/sports_terminal
git pull --ff-only
(cd experimental/arcside-react && npm run build)
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --objective
```

If `build/web` is missing or you have separately changed Flutter application source since that build, omit `ARCSIDE_COMPARE_REUSE_BUILDS=1` and run `bash scripts/phase3_release_compare.sh --objective` to rebuild both release shells.

The read-only salary artifact is emitted under `experimental/arcside-react/dist/data/phase3/2026-27-contracts.json`. Never commit generated historical corpus files, a local workbook, or service credentials.

## Five-route source-backed expansion (2026-11-20 continuation)

The experiment now has initial `/player-compare`, `/team-compare`, `/box-scores`, `/financials`, and `/with-without` routes. These are not placeholders or invented source rows:

- **Player Compare:** 2–5 slots, independent historical seasons, source-backed standard rate bases, head-to-head leader and tie rules. Reuses the existing React engine already covered by original-Dart metrics parity. Flutter saved-view and full advanced metric customization parity remain outstanding.
- **Team Compare:** 2–5 slots and historical seasons; canonical team-season records, standings, and complete actual team game logs are read with missing values left unavailable. No player-to-team inferred zeros.
- **Box Scores:** original historical v5 `games/index.json` and published per-game detail files; date/season/type filtering, team toggles, player game inspection. Per-game records not materialized in the corpus are explicitly unavailable.
- **Financials:** same original Flutter team financial snapshot from `lib/services/nba_team_financial_reference_2026.dart`, emitted into the isolated React build; immutable 30-team financial reference dated 2026-10-05, not live contract updates.
- **With/Without:** same optional original `lineups/<season>/<segment>/with_without.json` pair split files as Flutter; lack of a lineup source never produces fabricated on/off values.

Added Vitest checks of the team-record completeness and comparison winning/tie behavior, Playwright UI tests with **explicitly synthetic** intercepted reference shards, and a separate authentic-corpus route smoke script `scripts/phase3_module_corpus_probe.mjs`, now called by the objective shell script. The readiness audit marks each route `SOURCE_BACKED_PILOT_ROUTE_NOT_FULL_PARITY`, not complete Flutter equivalence.

### Fast local release verification

Because these changes only affect the isolated React app and the original Dart financial-reference parser is part of the **React Vite build**, and provided `build/web` still reflects unchanged Flutter sources:

```bash
cd ~/sports_terminal
git pull --ff-only
(cd experimental/arcside-react && npm run build && npm test)
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --objective
```

If Flutter source or `build/web` has changed, omit `ARCSIDE_COMPARE_REUSE_BUILDS=1`. The original Flutter parity engine remains authoritative, and the draft branch must not be merged until complete semantic, UX, assistive technology, Labs security and matched visual performance gates have passed.

## Three final source-backed route pilots and deeper parity work (2026-11-21)

New routes: `/teams` (canonical indexed team directory), `/team/:key` (original Flutter team dossier, historical season tabs, dated 2026–27 salary-seed roster, optional injury/transaction/recent games, 2025–26 baseline player join), `/games` and `/game/:key` (historical game catalog, indexed player/team details and optional published play-by-play), and `/franchise-history` (exact original Flutter six-item build plan plus searchable historical team identity index). The original Flutter Franchise History screen is **a roadmap**, not an implemented continuity database. These routes must not infer missing schedule, arena, injury, relocation or game details.

Additional implementation slices: browser-local player/team comparison presets preserving slot-specific seasons/metrics; additional source-only player identity and context sections; and the ability to add 2026–27 original dated salary records to the **isolated hypothetical** React CBA validator. Do **not** use these salaries to assert current asset eligibility, team cap amounts or transaction legality.

CI now includes synthetic fixture browser journeys, unit tests for team identity, season history, dated player salary join, games filtering, and the original franchise planning status. The existing objective local suite extends the genuine-corpus smoke to all **8** new module routes and a published team dossier. This is route/source availability evidence, not comprehensive Flutter visual/feature equivalence.

The React pilot still does not match the original complete NBA Trade Machine, native Safari VoiceOver/NVDA interactions, secured Labs runtime, every user-specific saved-view control, or full GPU/frame/memory comparison. Even if all routes pass, the decision gate remains **NOT AUTHORIZED** until a complete feature-by-feature operator signoff and original-source evidence are accepted.

Run after pulling:

```bash
cd ~/sports_terminal
git pull --ff-only
(cd experimental/arcside-react && npm run build && npm test)
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --objective
```

Only reuse the Flutter binary if its original sources and build/web have not changed. The original Flutter app remains authoritative and draft PR #89 must not be merged automatically.
