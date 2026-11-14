# Arcside Studio — independent desktop foundations

These are local desktop applications, separate from Arcside's Flutter website and NBA data. They do not use OpenAI APIs, paid providers, remote Python execution or telemetry. **They do not run inside GitHub Pages**. Desktop users run their own code on their own device.

## Install (macOS / Windows / Linux)

Python 3.11+ is recommended.

```bash
cd ~/sports_terminal
python3 -m venv .venv-studio
source .venv-studio/bin/activate            # Windows: .venv-studio\\Scripts\\activate
python -m pip install -r desktop/arcside_studio/requirements-desktop.txt
python -m desktop.arcside_studio.python_lab
# or in a second process:
python -m desktop.arcside_studio.spreadsheet
```

Dependencies are downloaded when you install them but there is **no per-query or per-run billing**. If you need fully air-gapped setup, predownload packages once and install from a local wheel cache. Local code is executed with the desktop user's normal filesystem/network permissions; do not run untrusted scripts. Network-isolated sandboxing of untrusted code is not included.

## Python Lab — first functional native IDE

- Resizable project file tree, tabbed source editor, line numbers, breakpoints, Python syntax highlighting, basic keyword completion, find/replace, keyboard shortcuts and file saving.
- Interpreter selection detects local `.venv`, `venv`, `.conda` and an active `VIRTUAL_ENV` alongside the system Python; Python libraries such as pandas, NumPy, scikit-learn, SciPy and Matplotlib use that interpreter.
- Run scripts with true streamed output, stderr/tracebacks and an input-capable console. Stop long-running processes. Run `pytest` across the local project.
- PDB debugging with breakpoints and Step / Next / Continue actions. Enter `p variable`, `where`, `up`, `down` etc. in the debugger console. Local `matplotlib` figures are displayed through the installed Qt GUI backend.
- AST syntax checks with source error locations. This is an actual Python interpreter, **not** the Dart-only preview previously in the web app.

Still to build for VS Code/PyCharm-class parity: persistent kernel/notebooks, full LSP diagnostics/completion/rename, DAP variable trees/call-stack UI, remote containers, integrated git diff, environment/package managers, extensions, debugger watches and breakpoints in a source map, notebooks, profilers and production-grade accessibility.

## Excel Workspace — first functional native spreadsheet

- Virtualized 3,000 × 200 editable grid (underlying sparse workbook supports up to Excel coordinate limits), formula bar, worksheet tabs, column resizing, selection, clipboard copy/paste and undo/redo.
- Safe tokenizer/parser: arithmetic, comparison, exponentiation, references, cross-sheet references, ranges, and functions `SUM`, `AVERAGE`, `MIN`, `MAX`, `COUNT`, `COUNTA`, `IF`, `IFERROR`, `ROUND`, `ABS`, `SQRT`, `POWER`, `STDEV`, `MEDIAN`, `PRODUCT`, `CONCAT`, `AND`, `OR`, `NOT`. Formula evaluation does **not** use Python `eval`.
- Dependency graph invalidates downstream formulas whenever referenced cells change. Cycles return `#CYCLE!`; missing references return `#REF!`.
- Native Arcside JSON files, CSV import/export, XLSX read/write via installed `openpyxl`. Bar, line and scatter charts with installed Matplotlib. Local formatting stores bold, colors and number-format metadata; advanced styling parity is future work.

Still to build for Excel/Sheets-class parity: pivot tables, hundreds more functions and exact Excel error semantics, multi-cell formula fill and relative address rewrites, chart editing, conditional formatting, financial/time-series functions, multiselect editing, named ranges, large-range streaming optimizations, macros, collaborative editing, comprehensive XLSX style preservation and merged cells.

## Development checks

```bash
python3 -m compileall -q desktop/arcside_studio
python3 -m unittest discover -s desktop/arcside_studio -p 'test_*.py' -v
```

Both tools intentionally remain unlinked from other Arcside features until their interfaces and security boundaries are ready.
