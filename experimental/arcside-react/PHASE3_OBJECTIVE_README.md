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

The readiness audit inspects tracked Flutter screen implementations and the React pilot's routes. Missing Trade Machine, comparison and box-score modules are recorded as real blockers. The pilot's player profile is a minimal dossier, not full profile tables; a Dart CBA exporter does not equal a React CBA engine.

The Labs integrity probe imports a **throwaway** Python file, downloads it and the original project archive, exports and reimports a throwaway Sheets workbook JSON, and checks a same-origin typed context message. It uses a fresh Playwright browser context and does not connect Python's native companion or authenticated collaboration. This is deliberately not a security certification.

The accessibility probe checks landmarks, skip-link focus, image alternatives and embedded Lab titles. It is not axe/WCAG certification, actual VoiceOver/Safari or NVDA.

## Evidence paths

- `experimental/arcside-react/evidence/objective/objective-browser-performance.json`
- `experimental/arcside-react/evidence/readiness/phase3-readiness-audit.json`
- `experimental/arcside-react/evidence/accessibility/accessibility-smoke.json`
- `experimental/arcside-react/evidence/labs/lab-integrity.json`
- `experimental/arcside-react/evidence/decision/phase3-decision.md`

All outputs are excluded from Git, preserving user-local private data and hardware details. Tests are **not yet executed against the owner's Mac** until the owner runs the command and shares the resulting summary.

## Architecture decision remains pending

The React pilot is a good experimental reference for Stats, Advanced Stats, Visualization Studio, and the unchanged embedded Labs, but full application migration is **not approved**. Any comprehensive framework switch requires full player-profile tables, CBA rules, comparisons, financials, box scores, the remaining Arcside workflows, native accessibility, Lab authorization security, genuinely matched critical-interaction/GPU measurements and explicit owner signoff. The decision ledger records the missing work rather than stamping it PASS.

Recommended next implementation path after reviewing local evidence: measure identical chart input-to-render behavior using explicit, equivalent app-level instrumentation in Dart/Flutter and React; test both on the same physical hardware; then prioritize missing player profile and trade rule parity before reconsidering wholesale migration.
