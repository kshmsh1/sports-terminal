# Arcside Labs — Phase IV interaction audit and design review

This document records an adversarial **simulated** discussion of three specialist
design perspectives, the consensus decisions implemented in the code, and the
real browser/companion evidence. The roles are design-review perspectives, not
three separately employed or independently consulted humans.

## Problem observed in the November 2026 screenshots

The two products have a credible dark workbench aesthetic, but both interfaces
present too many operations with the same visual weight. Python's single toolbar
competes for the editor's attention, the fixed right inspector can sit mostly
empty, and its output panel cannot be resized. The spreadsheet has ungrouped
command labels and initially shows long decimal margin ratios rather than
percentages. Its A1 name box and 100% zoom indicator look like controls but
were not interactive. Embedding the workspaces inside Flutter also makes
horizontal space more scarce.

## Three-expert design debate

**Chief UX Designer / Engineer:** "These are tools for sustained work. A user
must immediately understand where to start, what's editable, which run mode is
active, whether work was saved, and where results appear. We should surface
Run/Debug and basic workbook editing, while ensuring every less-frequent
operation is discoverable. Fewer visual choices, not fewer capabilities."

**Creative Design Director:** "A merely condensed set of text buttons will
still look like a developer demo. Preserve the restrained navy palette, but
introduce task group headings, consistent sizing and distinct surface depths.
The code canvas and sheet grid should dominate visually. Keep color for the
primary action, selection and meaningful status—not decorative gradients."

**Head of UI & Frontend:** "A completely new custom ribbon or dock layout
could break existing automated controls and keyboard integrations. The same
standalone pages also run inside Flutter iframes. I propose reusing IDs,
handlers and rendering engines, and adding a small shared command-search layer.
We must test narrow viewports and both embedding modes."

**UX lead (challenge):** "A command palette alone hides essential capabilities
behind something new users may not discover. Keep a visible, labeled
'Commands' button; include the keyboard shortcut on it. Group spreadsheet
actions by task instead of demanding a search for everything."

**Creative director (challenge):** "A two-row Python header risks using
valuable vertical space. Move file import/export and test tooling into a slim
secondary actionbar, not a giant ribbon. Keep execution and runtime state on
the first row, with the editor remaining dominant."

**Frontend lead (challenge):** "Resizable panes need pointer capture, keyboard
arrow handling, remembered sizes, sensible minimum widths, and no second
Monaco instance. For Sheets, make zoom update real row/column geometry—not
fake percentage text or a CSS transform that desynchronizes hit testing."

**UX lead:** "Make the spreadsheet name box genuinely navigate to A1/M150
and selected ranges. Ensure modal dialogs close with Escape. If a user enters
an invalid address, give useful, localized feedback. Preserve editable data
when changing only the layout."

**Creative director:** "Use quiet headings such as WORKBOOK, EDIT, ANALYZE
and VISUALIZE, consistent spacing and muted dividers. Visually distinguish
persistent collaboration from per-browser storage without louder colors."

**Frontend lead:** "Agreed if we preserve every existing command and introduce
automated command inventories. Browser QA should verify actual state changes,
not just the click target. The Python native companion remains opt-in and
cannot be exposed with workbook collaboration credentials."

### Unanimous decision / implemented

- Keep underlying Python worker/CPython, Monaco, debugging, Jupyter, workbook
  engine, SQLite collaboration and import/export logic.
- Add a unified command palette: visible trigger and Ctrl/Cmd+K,
  searchable groups, Arrow/Enter/Escape support, focus management.
- Reprioritize Python's top bar: Run/Debug and runtime are primary; project
  imports, exports and tests sit in a quieter second row.
- Allow Python explorer, inspector and output panel to be collapsed/resized;
  persist individual layout preferences locally; provide keyboard-operated
  splitters.
- Reorganize Sheets toolbar into WORKBOOK, EDIT, ANALYZE, VISUALIZE and HELP.
- Turn the spreadsheet name box and zoom percentage into functional controls.
- Improve the demo workbook by showing margin values as percentages (the
  existing workbook values and formulas remain untouched).
- Improve modal Escape behavior, active-state clarity, sizing and responsive
  layout, without sacrificing the already-tested engines.

## Automated browser user simulator

The deterministic Playwright user simulator lives in
`web/labs/tests/ux-audit.browser.spec.mjs`. It:
- Inventories every top-level sheet command and every named Python control,
  failing if a newly added command is not accounted for.
- Performs real multi-step interactions on sample workbooks and Python
  projects, including edits, undo/redo, formatting, file import/export, sheet
  creation, analysis modals, virtual terminal and file management.
- Exercises keyboard navigation and the action palette, name box, zoom,
  collapsible/resizable panels, persistence and responsive layouts.
- Runs both workspaces inside genuine HTML iframes as an embedding smoke test.
- Captures actual Chromium screenshots. CI publishes Playwright result and
  report artifacts for subsequent visual inspection.
- Checks for uncaught JavaScript errors in key interaction flows.

The native Python journey extension lives in
`web/labs/tests/local_ux_audit.browser.spec.mjs`, called by
`.github/workflows/labs_power_quality.yml` with an authenticated, isolated
local companion. It exercises real Ruff lint/format, pytest, coverage,
cProfile, Git workflow controls and Jupyter notebook export. Existing tests
cover live debugpy DAP, python-lsp-server, PTY and persistent Jupyter
execution. The independent collaboration CI tests exercise different
permission levels and live workbook edits between two browser contexts.

### How to run locally

```bash
bash scripts/launch_arcside.sh --labs

# Separate terminal:
npm install --prefix web/labs --no-package-lock --ignore-scripts
cd web/labs
npx playwright install chromium
npx playwright test tests/ux-audit.browser.spec.mjs -c playwright.config.mjs
```

The native companion integration suite requires an isolated local test server
and token, as configured in the GitHub Actions workflow. Never paste
production/user Python companion tokens into CI configuration.

## Limits

This is **scripted human-journey simulation**, not an autonomous AI vision
agent independently deciding what to click. Buttons and supported journeys
are inventoried and exercised, but the state space of every workbook formula,
third-party Excel input, library dependency, operating system, browser and
external collaboration arrangement is effectively unbounded. A passing
suite is evidence for the tested behaviors, not proof of perfect
compatibility, universal accessibility, zero bugs or exhaustive product
parity. Further work is needed for formal accessibility audits, larger user
studies, browser matrix coverage, SSO/hosted collaboration and complete
Excel/PyCharm/VS Code compatibility.
