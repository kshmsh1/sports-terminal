# Arcside React-first beta migration — November 23, 2026

## Decision: develop in React first; do not mislabel unverified gates

The owner has accepted proceeding with React as the **primary development UI** while fixing remaining defects and incomplete modules in subsequent changes. This decision is an explicit change in *rollout tolerance*, **not** evidence that the original comprehensive Phase 3 parity or nonfunctional acceptance gates have passed.

Source-backed tests already performed on the owner's actual local NBA v5 corpus: 1,119,992 Advanced Stats parity comparisons with zero mismatches; 38,086 Visualization Studio comparisons with zero mismatches. Operator Advanced Stats matched-task performance passed its 10% acceptance tolerance. Visualization Studio matched-task performance did **not**: one React warm trial took 879.91 ms, and the recorded warm p95 ratio was 2.779. Preserve that failure; continue instrumenting actual chart operation latency.

The standalone original Labs have test coverage, but native Python code execution and workbook collaboration still require careful access controls. The 27 independent Dart/TS CBA goldens do not verify the full NBA agreement or authoritative legal trade validity. Real Safari+VoiceOver and Windows+NVDA, comprehensive original Flutter feature parity, GPU/native memory behavior, and visual review across all modules remain outstanding.

## Reversible developer rollout

The ordinary full-data launcher now defaults to React but preserves the original Flutter reference and historical warehouse:

```bash
cd ~/sports_terminal
git pull --ff-only
(cd experimental/arcside-react && npm ci && npm run build && npm test)
bash scripts/open_terminal.sh
```

For rapid subsequent daily launches without rebuilding the original static warehouse:

```bash
bash scripts/launch_arcside.sh --platform --fast
```

For a complete rollback to the original Flutter UI:

```bash
bash scripts/open_terminal.sh --flutter
```

The alternate integrated launcher also supports `bash scripts/launch_arcside.sh --flutter --fast`, provided existing Flutter dependencies are installed and the NBA v5 snapshot exists. To force the legacy frontend on the canonical launcher, set `ARCSIDE_FRONTEND=flutter`. The original Flutter code, asset generation, and source history remain intact.

The React/Vite development server is bound to `127.0.0.1`; it is not a hosted production build or public deployment. Do not expose Python companion tokens, local histories, hidden workspace files, or authentic private datasets to public hosting.

## Two different completion states

1. **React-first local beta enabled**: frontend defaults to React, Flutter can be launched immediately as fallback, verified original data is read-only, and known gaps are documented. This is an acceptable developer rollout even while unresolved acceptance findings remain.
2. **Full Flutter retirement / production migration approved**: only after original feature and CBA/profile parity, supported user workflows, native accessibility, Labs security, matching graphics/process-memory testing and explicit owner GO decision are actually evidenced. A beta label must never be substituted for these gates.

The owner review script `bash scripts/phase3_release_compare.sh --final-review` records actual screenshots/notes. It now resumes verified checkpoints, accepts annotations before/after status, and prompts again instead of aborting on mistyped answers. Operator review is useful, but optional for the developer beta and mandatory before any claim of complete parity.

## Prioritized follow-up engineering

**P0.** No data loss or invented source values. Preserve immutable original NBA history, process and browser sandbox boundaries, original Labs and Flutter fallback. Stabilize default launcher and actual Mac/Windows browser paths; audit cross-origin exposure.

**P1.** Full CBA Trade Machine rules and UI, real salary ledger and protected-pick handling; complete original player dossier career/advanced-stat tables, awards, contracts and canonical deep links. Also fill original NBA Home, header search and navigation gaps so React reproduces core Flutter use cases.

**P1.** Investigate and remediate matched Visualization Studio warm-tail outlier, confirm repeatable direct chart operation measurements, and rerun pre-registered matched user tasks with unchanged 10% tolerance. Preserve original failed evidence in local ignored evidence directory.

**P2.** Finish all remaining original UI module interactions, dark/light responsive UX, keyboard/screen reader assistive tech, source-backed game/box-score/financials consistency, full Excel/Python standalone workflows, security review and true frame presentation/total memory measurements.

Maintain a code-level regression suite plus authentic local-v5 acceptance report for each completed parity area. Maintain one GitHub issue per outstanding workstream. Do not turn any NOT_RUN or FAIL gate into PASS because the development frontend preference changed.

## Integration boundaries

The experiment branch is stacked on unmerged Labs/architecture history. Promotion to `main` must bring required predecessors coherently, not squash the app into a missing-Labs base. A direct integration pull request should remain individually reviewable and should report the entire diff and deployment impact. Original Flutter remains a supported fallback after any merge.
