# Arcside independent Python Lab and Excel Workspace

## Architecture

Two self-contained web applications are served from web/labs and embedded
within the existing Flutter Arcside navigation using a conditional
HtmlElementView iframe on web. The desktop/mobile Flutter target shows
an explicit fallback. Neither lab is connected to NBA data, trading,
community, authentication, or the legacy workbook and notebook prototypes.

## Python Lab: implemented

- Monaco editor 0.52.2: Python syntax coloring, line numbering, code folding,
  autoindent, editor tabs, minimap, local token completion, search/replace,
  multi-cursor support, and keyboard shortcuts.
- Virtual multi-file project with create/rename/delete, class/function outline,
  import individual files and export/download project files. Saved in browser.
- Pyodide 0.29.1 Python in a dedicated browser Web Worker, with compatible
  standard libraries and Pyodide/micropip packages.
- Output panel captures stdout, stderr, tracebacks and Matplotlib PNG plots.
- unittest discovery, Python console, AST syntax errors, breakpoint markers,
  and recorded line-by-line trace replay with captured locals.

**New in PR #83, opt-in local companion:** Real native Python execution,
pytest, selected-source snippets, environment creation through venv/uv/conda,
validated package installs, interactive macOS/Linux PTY through xterm.js,
Pyright/pylsp language server completions and diagnostics, debugpy DAP
breakpoints/step/stack/watch, Ruff format and lint, read-only Git status,
and persistent ipykernel/Jupyter notebook cells with .ipynb import/export.
All native features require starting a trusted localhost companion and
entering its per-session token; they are never auto-enabled for visitors.

The browser-only Pyodide execution retains trace replay, not a pause/step
debugger. Native Python uses a real debugger; browser Python cannot use
arbitrary native wheels. There is no Windows ConPTY implementation, general
remote server sandbox, comprehensive semantic refactoring, coverage/profiling
UI, or complete VS Code/PyCharm feature parity.
See tools/arcside_companion/README.md for installation and safeguards.

Safety: executing browser Python is NOT a hardened sandbox for untrusted code:
it executes within the web origin in a worker. Run only trusted code.
No generative AI, LLM SDK, assistant, or app telemetry has been added.
The browser currently downloads Pyodide and Monaco from pinned CDN versions
on first use; offline-first vendoring is future work. Package installations
may require network access.

## Excel Workspace: implemented

- Virtual viewport grid up to 100,000 rows and 256 columns, not 25.6 million
  live DOM cells; multi-sheet workbooks, editable formula bar.
- Range selection, keyboard navigation, clipboard TSV copy/paste, undo/redo,
  basic formatting, resizing column widths, find and range sorting.
- A custom AST formula parser without eval or arbitrary JS execution, a
  dependency DAG with invalidation, cross-sheet references, and circular
  reference detection.
- Arithmetic and comparisons, plus SUM, AVERAGE, AVG, MIN, MAX, COUNT,
  COUNTA, MEDIAN, STDEV, IF, IFERROR, ROUND, ROUNDUP, ROUNDDOWN, ABS,
  SQRT, POWER, MOD, AND, OR, NOT, LEN, LEFT, RIGHT, UPPER, LOWER,
  TRIM and CONCAT, plus COUNTIF/COUNTIFS, SUMIF/SUMIFS, AVERAGEIF,
  VLOOKUP/XLOOKUP exact match, INDEX/MATCH, IFNA, PRODUCT,
  MID/FIND/SEARCH/SUBSTITUTE and text type checks.
- Browser-local IndexedDB save with localStorage fallback, CSV/TSV import, calculated CSV export, Arcside JSON
  backup/restore, SVG bar/line/pie charts, bounded conditional formatting
  rules (numeric/text/blank/error-based), and **configurable pivot-table
  designer**: multiple grouping dimensions, column cross-tabs, SUM/AVERAGE,
  COUNT/DISTINCT COUNT, MIN/MAX/MEDIAN, optional filters, preview, source-backed
  refresh and separate filtered tables. Pivot/filter computation runs in a
  dedicated browser worker. An optional MIT-licensed ExcelJS 4.4.0
  adapter imports and exports XLSX workbooks (cell values, formulas, and basic
  styling) from the browser on demand; Excel will recalculate cached formulas.

Not yet available: complete XLSX feature fidelity (charts, macros, all Excel
functions/formatting), full Excel function catalogue,
array/dynamic spill formulas, named ranges, fully Excel-compatible
multi-measure/GETPIVOTDATA pivot features, chart series customization,
collaborative editing, formula-driven conditional formats and icon sets,
merged cells, industrial
calculation performance or complete XLSX fidelity.
Clipboard copy, fill and sorting now rebase relative formulas, but complex
structured references and formula rewriters remain incomplete. Storage is IndexedDB (with a localStorage fallback for smaller workbooks),
subject to browser quota and device-storage limitations.

## Validation

From repo root:
- node --check web/labs/sheets/core.mjs
- node --check web/labs/sheets/app.mjs
- node --check web/labs/sheets/xlsx.mjs
- node --check web/labs/python/app.mjs
- node --check web/labs/python/kernel.worker.js
- node --test web/labs/tests/*.test.mjs
- python3 web/labs/tests/check_kernel_bootstrap.py
- flutter analyze && flutter test && flutter run -d chrome

Manual checks:
1. Edit Analysis!B2: D2/D6 must recalculate. Test a circular reference,
   cross-sheet references, TSV paste and formula bar.
2. Select a range to insert a chart or generate a pivot summary. Export/import
   an Arcside workbook JSON file and roundtrip CSV/XLSX.
3. Python Lab: run main.py; see pandas/NumPy output; uncomment Matplotlib
   example and inspect Plots; inject a syntax error and inspect Problems.
4. Run unittest in test_math.py; set a breakpoint in the editor gutter,
   run Debug and navigate the recorded trace; export and re-import a project.
5. Check mobile web, native fallback, storage caps, CDN/CSP behavior and
   accessibility before any production release.

## Next milestones

Python Lab: the opt-in localhost companion now provides native interpreters,
venv/uv/conda, PTY, pytest, LSP, debugpy, Jupyter, Ruff and Git status.
Next: a distributable desktop app, Windows ConPTY, comprehensive semantic
refactoring, persistent notebook/output management, deeper Git/coverage/
profiling integrations, and hardened resource isolation.
For server-hosted workspaces, isolate each user's untrusted execution in
short-lived authenticated containers with CPU/memory/network limits. Never
reuse the restricted existing Python runtime as an unrestricted public API.

Excel Workspace: pivots and filters now calculate in a dedicated worker.
Next: broader calculation-worker offloading, dynamic arrays, named ranges,
more XLSX fidelity, drag-to-fill, structured tables, advanced chart design,
advanced formula-based conditional formatting, pane freezing, accessible
navigation and collaboration
only after conflict semantics are designed.

These are initial working foundations, NOT complete replacements for
VS Code, PyCharm, Microsoft Excel or Google Sheets.


## Browser CI verification

The standalone labs quality workflow includes real Chromium Playwright tests
that launch the static HTML workspaces and execute Python via Pyodide, verify
syntax highlighting/diagnostics, test unittest, recorded debug traces,
pandas DataFrame previews, Matplotlib PNG output and spreadsheet formula
editing, clipboard behavior, cross-sheet formulas, chart/pivot creation and
XLSX interchange. Tests run on Ubuntu 24.04 and store failure screenshots
and traces as GitHub Actions artifacts. Avoid assuming a passing Flutter build
alone establishes Python runtime and browser editor behavior.

## Phase-two validation — PR #83

A CI-only loopback Python companion is started with a disposable temporary
workspace and token for Chromium Playwright tests. The expanded suite
successfully exercised real native Python/pytest, terminal PTY echo,
pylsp connection, debugpy pause/step, live Jupyter/ipykernel cell state,
notebook .ipynb exports, browser Pyodide, XLSX roundtrip, pivot design and
refresh, dynamically recalculated conditional formatting, and browser
IndexedDB persistence. Native package tests run on
Python 3.11, 3.12 and 3.13. File sync requires consent and authenticated
loopback origin validation. Native execution is *trusted*, not sandboxed.

This stacked PR targets the draft PR #82, and neither is merged into main.
