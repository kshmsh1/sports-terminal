# Arcside local development workspaces (first functional release)

These are **standalone desktop applications** in the repository. Neither is yet connected to the Arcside Flutter Research route or to historical NBA datasets. They execute locally; there is no user account, cloud bill, generative AI, telemetry, or remote compute.

## Install once (free/open-source tooling)

```bash
cd ~/sports_terminal
python3 -m venv .arcside-tools
source .arcside-tools/bin/activate
python -m pip install PySide6 openpyxl matplotlib pytest numpy pandas scipy scikit-learn
```

Optional data science tools: `python -m pip install jupyter ipykernel seaborn statsmodels torch` (large downloads and compatible Python versions may vary).

## Python Lab

```bash
python tools/arcside_python_lab/app.py
```

Features now: local project file tree, persistent saved Python files, multiple editor tabs, Python syntax highlighting, automatic indentation, inline syntax validation, find and go-to-line, selectable system/project virtualenv interpreters, real subprocess execution with streaming stdout/stderr, stdin console, stop process, interactive `pdb` debugging commands, pytest, local interactive shell, save/open and keyboard shortcuts. The currently selected project environment controls access to installed packages; NumPy, pandas, scikit-learn, and matplotlib work when installed there. Matplotlib charts created by executed programs open as separate local figures.

**Safety:** running arbitrary code means the code has your local user's file and network permissions; execute only scripts you trust. This is a local IDE, not a multi-tenant sandbox. No LSP, notebook kernel, remote service, variable inspector, profiler or graphical debugger has been implemented yet. The interactive terminal uses the machine's shell with those same permissions.

## Spreadsheet

```bash
python tools/arcside_spreadsheet/app.py
```

Features now: virtualized worksheet grid (Excel-compatible logical coordinates), cell editing, formula bar, named selection jump, multiple worksheets, workbook save/open in native `.arcside.json`, Excel `.xlsx` import/export via openpyxl, CSV import/export, local formula calculation, DAG dependency invalidation, reference/range evaluation, circular-reference errors, undo/redo, bold formatting, numeric-selection charts (bar/line/scatter via matplotlib), standard keyboard shortcuts.

Supported formulas include arithmetic `+ - * / ^`, references and rectangular ranges, comparisons, `SUM`, `AVERAGE`, `AVG`, `MIN`, `MAX`, `COUNT`, `COUNTA`, `ROUND`, `ABS`, `SQRT`, `POWER`, `IF`, `IFERROR`, `AND`, `OR`, `NOT`, and `CONCAT`. Expressions run through a purpose-built recursive-descent parser—**no eval/exec**. Formula recalc propagates through dependents and reports `#CIRC!` for cycles.

Important limitations: current formula syntax supports references **within one sheet**; cross-sheet formulas, complex Excel function parity, pivot tables, charts embedded in files, macros/VBA, concurrent collaboration, workbook sharing, conditional formatting, merged cells, full-scale copy/paste with relative-reference rebasing, and production-caliber optimization are not complete. Excel import/export preserves formulas as text but Excel-specific functionality outside the supported subset will not calculate in Arcside. This is a working spreadsheet foundation, **not yet an Excel replacement**.

## Verification

```bash
python backend/scripts/arcside_workspaces_contract_test.py
python -m compileall -q tools/arcside_python_lab tools/arcside_spreadsheet tools/player_dossier_stat_parity.py
```

## Player profile parity

The static NBA compiler now overlays each player's dossier with the same **published season snapshot** used by Stats and Advanced Stats. This works for regular season and playoffs independently. The overlay never invents numbers, overwrites canonical box-score totals or propagates an aggregated traded-player statistic onto an individual team-stint record. Rebuild the static corpus for an existing local dataset to take effect; committing code alone cannot retroactively update already-built JSON. Historical availability still depends on captures actually present in the warehouse.
