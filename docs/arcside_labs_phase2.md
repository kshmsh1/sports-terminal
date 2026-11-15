# Arcside Labs Phase II — native Python companion and spreadsheet analysis

## What ships in this phase

This phase is stacked on draft PR #82 and leaves the Flutter Arcside sports
features unchanged. It does **not** introduce any NBA data integration.
Two paths are supported:

1. **Browser**: Monaco editor + Pyodide, no local runtime required; browser
   spreadsheet with IndexedDB persistence. Phase I remains the default.
2. **Trusted local**: owner starts `arcside-companion` on their own
   Mac/Linux computer, supplies an explicit permitted Origin, and enters the
   generated connection token into Python Lab. The browser can then run
   native CPython, control the owner's terminal, and use IDE services.

The trusted companion is **not a sandbox**, does not run untrusted code safely,
and should never be exposed to public internet access. It executes with
the same privileges as the user running it.

## Python IDE: newly implemented and tested

| Capability | Implementation | Caveat |
| --- | --- | --- |
| Native Python execution | CPython subprocess through authenticated loopback FastAPI | Must launch local companion; outputs capped |
| File/project sync | Explicit local file import, SHA-256 optimistic writes | 8MB total sync cap; conflicts block overwrites |
| Real terminal | POSIX PTY, live input/output, resize, Ctrl+C, optional xterm.js | Mac/Linux only; not Windows PTY |
| Virtual environments | venv + optional uv/conda, selected Python interpreter, pip installs | Requires appropriate tools and package compatibility |
| Language server | python-lsp-server over JSON-RPC WebSocket | Monaco completions, hover, definition, diagnostics, semantic rename |
| Debugger | debugpy adapter DAP over WebSocket | Launch, real breakpoints, pause/continue/step, stack/scopes/watch; arbitrary attach blocked |
| Notebook execution | Jupyter async kernel, editable cells with stdout/MIME image output | ipykernel in the selected environment; .ipynb export has no captured execution output |
| Testing | pytest where installed, unittest fallback | Installed in selected Python environment |
| Formatting | Ruff format and check, active file | Refresh local revision after formatting |
| Git | status, diff, log, branch, init, stage, commit | Native git required |
| Profiling | cProfile cumulative stats, isolated module startup | Sampling flame graphs are not yet implemented |
| Test coverage | coverage run and textual report | coverage installed in the chosen environment |

The browser-only Pyodide editor and virtual trace-replay remain available
without installing anything. The real debugpy adapter only applies to the
trusted local runtime.

### Getting started

1. Open an existing project folder or create a dedicated one on your machine.
   Review its contents and do not run arbitrary downloaded code.
2. From the repository root:

   ```bash
   cd python/arcside_companion
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -e '.[all]'
   python -m arcside_companion --workspace ~/my-project \
     --allow-origin http://127.0.0.1:8765
   ```

3. Serve Arcside from the exact permitted Origin. For a different hosted
   browser origin, restart the companion with an explicit alternate
   `--allow-origin` value, never a wildcard. In Python Lab choose
   **Trusted local CPython**, then **Connect local**.
4. Paste the token from the companion process into the **Dev tools** panel,
   then use **Open workspace files** before editing existing local source.
   The editor will not silently replace pre-existing differently-versioned
   local files. Use **Start local PTY**, **Notebook**, **Dev tools**, or
   **Debug** to access native capabilities.

Connection tokens are kept in tab memory, not copied into project exports
or URL parameters. The server is bound to `127.0.0.1:8766`, checks strict
Host and allowed-Origin values and first-message WebSocket authentication,
and declines requests without the bearer token.

Never run the companion as root, port-forward it, share its token, or permit
a browser Origin you do not fully control. A bearer token does not confer
process isolation. The project workspace boundary protects file-management
endpoints, not code the user chooses to execute.

Note: some browser deployment environments may restrict HTTPS-to-loopback
requests. Use the same local development origin for supported workflows.

### Python feature gaps

The local companion does not match every VS Code or PyCharm capability.
There is no complete plugin marketplace, remote-cloud workspace, multi-user
authenticated container service, profiler flame-graph UI, comprehensive
test explorer, fully-featured package/environment manager, or debugger
record/replay. Running code is trusted-local only, not remotely isolated.
The language server is pylsp; optional Pyright/Pylance integration may
be added later.

## Spreadsheet: newly implemented and tested

### Pivot Studio

Source selection respects current range (or populated sheet extent).
Pivot Studio supports up to four row grouping fields and a column pivot,
multi-measure SUM/COUNT/AVERAGE/MIN/MAX/MEDIAN/STDEV/DISTINCT COUNT,
simple filter conditions, sort direction, grand totals, and a preview.
The final result is written into a new sheet, with source spec persisted
so **Refresh pivots** can recompute from the updated source.

The UI currently exposes two row fields and one measure per designer
interaction; the underlying analysis engine supports more for future
advanced designs.

### Chart Studio

Multi-series bar, line, area, scatter and pie SVG charts, with titles,
category choice, and series selection. Charts can be saved with their
source sheet/range configuration and opened for editing from the gallery.
They are not Excel-native chart objects or a full chart-design canvas.
Chart definitions persist in Arcside JSON/IndexedDB, **not** as fully
equivalent Excel chart objects on XLSX export.

### Conditional formatting

Editable rules for greater/less/equal, text contains, range between,
nonblank, numeric data bars and color scales. Rules are stored with the
workbook and applied to visible cells, persisting across reload.

### Filtering and calculation

Filter Studio can produce an independent filtered result sheet without
mutating the original. Pivot and filter computations run in a module Web
Worker. The core cell-formula dependency engine still calculates on the
main thread and supports only a subset of Excel's formulas. Avoid assuming
Excel formula and XLSX behavior is entirely equivalent.

### Spreadsheet feature gaps

No production-grade multi-user collaboration/operational transforms,
structured tables, named ranges, spill arrays, macro/VBA support, full
Excel XLSX import/export fidelity, exhaustive Excel formula catalog,
advanced PowerQuery, workbook-level remote data connections, chart
interactivity, full pivot drag-and-drop layout, pane freezing or fully
isolated worker formula recalculation.

## Automated validation

```bash
# Browser JS, spreadsheet unit/regression, and UI end-to-end
node --test web/labs/tests/*.test.mjs
cd web/labs
npm install --no-package-lock --ignore-scripts
npx playwright install chromium
npx playwright test -c playwright.config.mjs

# Local companion API/security/integration tests
cd ../../python/arcside_companion
pip install -e '.[all]'
python -m pytest -q tests
```

CI workflows:
- `.github/workflows/labs_quality.yml` checks JS syntax, embedded Python
  bootstrap, pure spreadsheet formulas and Chromium UI interactions.
- `.github/workflows/labs_power_quality.yml` checks companion security
  and actual CPython/PTY/Notebook/DAP/LSP Chromium-to-native integration.
  The native CI companion starts on localhost with a CI-only test token.

If browser dependencies or OS optional packages are unavailable, existing
browser-only functionality remains operational. Cross-browser Safari and
Firefox behavior still needs full validation, especially WebSocket/local
loopback security and browser-private-network restrictions.

This milestone is implemented as a **draft stacked PR**; keep PR #82
independent until the phase-I workspaces are reviewed.
