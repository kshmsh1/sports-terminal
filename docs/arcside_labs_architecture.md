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

Not yet available: real local shell/PTY, conda or uv environments, native
Python wheels outside WebAssembly, IDE-wide Pyright/Pylance inference,
semantic refactoring, Python DAP step/continue debugging, Jupyter cells,
terminal subprocesses, integrated Git and desktop filesystem access.
Recorded trace replay is NOT a pause-and-resume debugger.

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
  backup/restore, SVG bar/line/pie charts and simple pivot summary sheets. An optional MIT-licensed ExcelJS 4.4.0
  adapter imports and exports XLSX workbooks (cell values, formulas, and basic
  styling) from the browser on demand; Excel will recalculate cached formulas.

Not yet available: complete XLSX feature fidelity (charts, macros, all Excel
functions/formatting), full Excel function catalogue,
array/dynamic spill formulas, named ranges, Excel-level pivot tables,
chart series customization, collaborative editing, conditional formatting,
merged cells, advanced filters, or industrial calculation performance.
Sorting moves literal/formula source without fixing relative references;
avoid sorting blocks containing formulas until addressed. Storage is IndexedDB (with a localStorage fallback for smaller workbooks),
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

Python Lab: build an opt-in trusted local desktop companion with scoped
filesystem, interpreter discovery, uv/venv/conda management, PTY terminal,
pytest runner, Pyright LSP, debugpy DAP, Jupyter kernels, debugger watch
expressions, formatting/refactoring, Git support, profiling and coverage.
For server-hosted workspaces, isolate each user's untrusted execution in
short-lived authenticated containers with CPU/memory/network limits. Never
reuse the restricted existing Python runtime as an unrestricted public API.

Excel Workspace: move expensive recalculation into a worker, add XLSX file
fidelity, richer formula typing, array formulas, relative-reference rewrites,
drag-to-fill, true pivots/filters/tables, advanced charts, pane freezing,
screen-reader/keyboard coverage, versioned IndexedDB history and optional
collaboration after conflict semantics are designed.

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
