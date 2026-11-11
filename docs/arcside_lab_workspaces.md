# Arcside · Standalone Python Lab and Excel Workspace

These are independent **browser-first development environments** in the existing Flutter repository. They intentionally do not have navigation links or connections to Arcside's sports-data endpoints yet.

## Opening the applications

From the repository root:

```bash
python3 -m http.server 8765 --directory web
```

Open **http://localhost:8765/labs/python/** or **http://localhost:8765/labs/excel/**. They can also be served by a static site host (e.g., Pages) when the `web/labs` directory is deployed. No FastAPI Python code-execution service, user account, subscription, API key, GPU server or commercial inference provider is required.

### Python Lab

The standalone Python Lab is a real in-browser Python workbench, not a simulated console. A Monaco editor handles Python syntax, tabs and a minimap; a plain-text editor is the fallback. The file explorer supports `.py`, CSV, text and JSON, with browser-local project persistence and project import/export. Code is executed by **Pyodide in a disposable Web Worker**; Stop forcibly terminates the worker and resets Python state. Syntax validation, stdout/stderr, Matplotlib figure output and a variable inspector are supported. Scientific packages including NumPy, pandas, SciPy, Matplotlib and scikit-learn may be loaded from the compatible Pyodide distribution. Python `import` remains governed by the package set available in that browser environment.

**Debugging:** Trace mode records Python line/variable snapshots after a run, optionally limited to specified breakpoints. It is *not* yet interactive pausing, stepping, watch expressions, a DAP debugger or a full LSP integration. No native terminal shell, arbitrary system subprocesses, CUDA acceleration, TensorFlow/PyTorch GPU training or unrestricted pip installation is provided. The editor/kernels initially download public open-source assets from CDNs; this is zero *paid API* cost but it is not first-load offline. External CDNs can be blocked or become unavailable. Browser localStorage is not durable storage: **export your project frequently**.

**Security:** A Web Worker and browser WebAssembly do **not** constitute a hardened security boundary for arbitrary hostile Python code. Do not execute untrusted uploaded scripts or expose secret API keys in the browser. Arbitrary remote code execution on Arcside's server is intentionally *not* offered. A native local companion for fully fledged Python/venv/uv/LSP/DAP would require opt-in installation and strict separation from the public site.

### Excel Workspace

The Excel Workspace is a **sparse virtualized spreadsheet** with up to 100,000 addressable rows and 512 addressable columns per sheet (capacity is **not** a guarantee that all such cells can be populated without browser limits). It provides multiple sheets, cell and range selection, formula entry, in-place editing, keyboard movement, browser clipboard TSV, styling, basic number formats, undo/redo, sort, elementary filtering, row/column insertion and bar/line/pie/scatter charts.

The local formula engine tokenizes expressions into an AST, builds a cell dependency graph, invalidates descendants on edits, detects circular references and does **not** use JavaScript `eval`. Implemented functions include SUM, AVERAGE, MIN, MAX, COUNT, COUNTA, COUNTIF, SUMIF, MEDIAN, IF, IFERROR, AND, OR, NOT, ABS, ROUND, SQRT, POWER, VLOOKUP, INDEX, text helpers and related arithmetic/comparisons. It is **not** a complete Excel calculation engine; complex dynamic-array formulas, pivots, Power Query, VBA, collaboration, conditional formatting, robust chart editing, complex lookup semantics and all file-format edge cases are not available.

CSV and project JSON are imported/exported locally. XLSX import/export uses the free SheetJS Community Edition loaded from a CDN; advanced formatting, unsupported formulas and some Excel-specific metadata may not survive round-tripping. Internal Arcside workbook JSON is the more faithful serialization for the current implementation.

**Important limitation:** Inserting rows/columns or sorting formulas does not yet rewrite relative/absolute formula references as Excel does. These actions announce that limitation. Both labs are significant functional foundations, **not VS Code/PyCharm/Excel feature parity**.

## Player-profile parity

`scripts/open_terminal.sh` completes the static NBA season build/enrichment, then invokes `tools/sync_player_profile_stats.py`. That script copies the exact final, source-backed `player_season_totals` rows from every static regular-season and playoff file into the corresponding `players/*.json` player dossier under `stat_seasons`. This is done for **every player in the local published corpus**.

The individual profile page uses the same compact sticky table, standard metric definitions, rate basis and percentage highlighting as the main Stats / Advanced Stats pages. Newly synchronized records preserve available advanced data, biological/physical stats and any source-backed metadata. Fields that are absent in the historical source stay null/unavailable; no imaginary values are generated.

When updating locally:

```bash
cd ~/sports_terminal
git switch main
git pull origin main
bash scripts/open_terminal.sh --rebuild-static
```

The local NBA warehouse and any authorized NBA.com historical captures must already exist. GitHub itself does not contain the complete large warehouse or every generated player shard; **the code update alone cannot fill in missing local source data or regenerate the website files without rebuilding**.

## Architecture direction

The website-first Monaco+Pyodide lab and sparse-grid formula engine should remain loosely coupled to Flutter. For native desktop parity in future iterations: optionally install a local kernel service with Python interpreter/virtualenv discovery, debugpy DAP and Pyright LSP; add package management, test discovery and explicit user permission for filesystem/network access. Build the spreadsheet with dedicated formula conformance tests, more complete Excel function compatibility, shared formula-reference rewrite AST, virtualized multi-cell selections, scalable file parsing and workbook-internal chart representations. Mobile can offer narrower feature subsets without constraining the desktop app.

Keep each feature behind its own tested backend-independent API; do not silently invoke any paid services.
