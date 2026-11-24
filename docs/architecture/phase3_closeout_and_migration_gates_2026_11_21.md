# Arcside Phase 3 — engineering closeout and migration acceptance ledger

**Updated:** November 21, 2026. **Reference:** Flutter; **candidate:** React 19 + TypeScript + Vite. **Scope:** evaluation and experimental implementation only. **Release recommendation:** continue React as a staged browser-first candidate; **do not retire Flutter and do not merge draft PR #89 into `main`.**

## What has been established

The original Mac evaluation previously reported 1,016,826 original Dart vs independent TypeScript mapped-stat comparisons with zero mismatches, plus 1,119,992 Advanced Stats source comparisons with zero mismatches. The original visualization comparison reported 38,086 comparisons with zero mismatches over sampled historical source-backed cases. These statements are scoped to their original sampled inputs; an empty season shard is not affirmative proof of data parity.

On the owner's November 21 objective run, the prior React implementation had 44/44 Vitest checks passing; the 15 original-Dart/TypeScript CBA scenarios matched; eight source-backed route smoke tests, three player dossiers and three isolated browser Labs roundtrips passed. The *warm browser-visible probe* medians were 308.2 ms Flutter and 190.2 ms React on ten warm observations each. The metric is neither identical chart completion nor GPU responsiveness. At that time the readiness ledger still reported seven blockers to a full migration. Preserve that prior evidence without treating it as acceptance for newer commits.

The next experimental commits add deferred route loading, a CI bundle-size regression gate, an expanded two-to-five-team *hypothetical* CBA editor and 27 Dart/React golden scenarios, and native CI diagnostic repairs. Their actual CI and local original-corpus outcomes must be checked separately; a successful code commit alone is not test evidence.

## Surface-by-surface implementation status

| Surface | Candidate now | What full equivalence still requires |
| --- | --- | --- |
| Stats / Advanced Stats | Source-backed tables, original advanced catalog, filters, rate basis and saved context | Exhaustive original column population, exact table interactions and accessible keyboard behavior in real devices |
| Visualization Studio | ECharts source-backed charting, zoom/pan, regression, presets | Same historical population, full chart controls, owner appearance approval and matched gesture/frame measurements |
| Player Profiles | Original dossier career and advanced tables, honors, dated contract join, context | Every original Flutter section, contract overlay semantics, navigation and visual equivalence |
| Trade Machine | Independent TS engine, original Dart scenario goldens, hypothetical 2–5 team editor | Entire 2023 CBA behavior, live authoritative salary/cap/draft assets, original complete transaction UX and exhaustive edge-case validation |
| Player / Team Compare | Source-backed comparisons and browser-local saved presets | Every Flutter metric/control, authenticated persistence and complete cross-team/player behavior |
| Box Scores / Games | Historical original index and available box/play-by-play detail | Exhaustive original game coverage, original filters and interactions, unavailable-source handling |
| Financials / Team Detail | Dated original team financials, team dossiers and salary joins | Live contracts, overlays, complete roster and source-level interactions |
| With / Without | Published player-pair splits where materialized | Full Flutter source and filter coverage; no fabricated split rows |
| Franchise History | Original team identity index and original Flutter planning-stage screen | Historical relocation mapping is **not currently an implemented source-backed feature in Flutter** |
| Python Lab / Excel Workspace | Embed unchanged original browser-native Labs, basic roundtrip evidence | Native-companion permission review, authorization and collaboration security, persistence and screen-reader checks |

A route existing in React is *not* full feature parity. The original Python Lab and spreadsheet engines must not be duplicated merely to satisfy a frontend framework decision.

## Seven mandatory full-migration gates

| Gate | Current status | Evidence needed to close |
| --- | --- | --- |
| 1. Matched operator tasks / p95 | **Open** | Real Flutter and React equivalent inputs, preflight functional equivalence and a same-machine p95 study at the registered <=110% React/Flutter threshold; avoid reusing historical pre-repair failures |
| 2. Full application feature parity | **Open** | Signed per-module controls, data, route and visual comparison against the authoritative Flutter version, not just a source-availability smoke |
| 3. Full CBA rules and player profile parity | **Open** | Exhaustive approved rules/asset tests, independently verified Dart and TS outputs and all player profile sections |
| 4. Native accessibility | **Open** | Physical macOS Safari+VoiceOver and Windows Chrome+NVDA testing, keyboard-only routes and a WCAG 2.2 AA remediation record |
| 5. Labs integrity and service security | **Open** | Confirmed native Python CI; local non-loopback denial, CSRF/origin/token tests, workbook preservation, collaboration role isolation and explicit operator trust boundaries |
| 6. Matched frame/GPU/memory | **Open** | Same chart/table workload on both release shells and hardware; frame-time distributions, GPU/heap/memory comparison and trace review |
| 7. Owner visual / migration approval | **Open** | Owner reviews real side-by-side screens, records GO/NO GO and approves the migration or hybrid roadmap explicitly |

The decision engine must continue to emit `NOT AUTHORIZED` while any required evidence is missing, stale, non-equivalent or failed. CI/Playwright is neither a human approval nor native Safari or Windows testing. The Dart 2023 CBA engine remains authoritative.

## Repeatable local acceptance (requires original Mac corpus)

Run from the experimental branch. If the original Flutter source and its previous release build are unchanged, the cached Flutter release is reusable after React rebuild:

```bash
cd ~/sports_terminal
git pull --ff-only
(cd experimental/arcside-react && npm run build && npm test && node scripts/phase3_bundle_gate.mjs)
ARCSIDE_COMPARE_REUSE_BUILDS=1 bash scripts/phase3_release_compare.sh --objective
```

If Flutter sources or `build/web` differ, omit `ARCSIDE_COMPARE_REUSE_BUILDS=1` so both release shells rebuild. Do not commit untracked historical warehouse/corpus, local workbook exports, access tokens, test traces with private data or machine-specific artifacts.

Only after source/feature equivalence and the relevant security/accessibility review pass should owner-run matched chart tasks be attempted. The objective run alone cannot close seven full migration gates. The final architecture choice should be `REACT_STAGED`, `FLUTTER_HYBRID`, or `RETAIN_FLUTTER` **only after** the owner explicitly signs the evaluation; none is authorized here.

## Immediate interpretation

**Phase 3 has a substantive working React proof of concept, but not a proven full-platform replacement.** The engineering evidence supports continuing a controlled React migration experiment. It does **not** support declaring the remainder of Phase 3's required native/human/full-scope migration acceptance complete.
