# Arcside Labs — integrated local preview and live collaboration

## One-command startup

These changes live in the stacked development branch
`feature/arcside-labs-collaboration-launch` (draft PR #85, based on PR #84,
which is based on PR #82). They have **not been merged into main**.

In a local checkout of `sports-terminal`:

```bash
git fetch origin feature/arcside-labs-collaboration-launch
git switch feature/arcside-labs-collaboration-launch || \
  git switch --track origin/feature/arcside-labs-collaboration-launch

# Preview Python Lab + Sheets without NBA data or Flutter:
bash scripts/launch_arcside.sh --labs

# If your canonical nba_history.sqlite warehouse and Flutter SDK are ready,
# launch the entire Arcside Flutter platform with both embedded workspaces:
bash scripts/launch_arcside.sh --platform
```

The launcher creates an isolated `.arcside-labs-venv` (Python 3.11+), installs
the trusted Python companion and independent collaboration service, starts
both on loopback, and prints the two separate connection credentials
in the local terminal. It serves the Labs at port 8765 or hands off to Flutter
on the same port. Ctrl+C shuts the services down.

To install optional local scientific packages (NumPy, pandas, SciPy,
scikit-learn, Matplotlib, Polars and Plotly):

```bash
bash scripts/launch_arcside.sh --labs --science
```

Subsequent launches can skip Python dependency installation:

```bash
bash scripts/launch_arcside.sh --labs --skip-install
```

For a trusted Python project outside the repository:

```bash
ARCSIDE_PYTHON_WORKSPACE="$HOME/my-data-science-project" \
  bash scripts/launch_arcside.sh --labs
```

### URLs

- Arcside Python Lab — `http://127.0.0.1:8765/labs/python/index.html`
- Arcside Sheets — `http://127.0.0.1:8765/labs/sheets/index.html`
- Python companion — `http://127.0.0.1:8766`, authenticated
- Live workbook collaboration — `http://127.0.0.1:8767`, authenticated
- When `--platform` is used, Flutter opens at `http://127.0.0.1:8765`.
  Its Python Lab and Excel Workspace navigation loads these same workspaces.

For a full sports-site launch, the existing static NBA historical warehouse
is still required. The launcher never fabricates or downloads NBA data.

## Working with Sheets

The spreadsheet offers multi-sheet formulas, an Excel-style formula bar,
cell formatting, chart studio, pivot studio, conditional formatting, filters,
formula-aware fill/copy/paste, undo/redo, CSV/TSV/JSON/XLSX import-export,
and IndexedDB autosave.

**My workbooks** saves separate named workbooks in this browser's IndexedDB.
Opening or deleting a named workbook never modifies other named workbooks.
The current workbook also has an automatic local recovery copy. Local browser
storage can be cleared by users/browsers; export important files regularly.

**Share workbook** uses the separate, opt-in collaboration service:
1. Start the launcher. Copy the **Sheets room creation key** printed in your terminal.
2. Open Sheets, choose **Share workbook**, paste the room creation key, and
   click **Create shared room**.
3. Copy the room ID and one of the generated **owner**, **editor**, or **viewer**
   keys. These are only displayed once. Send those room-specific access
   credentials privately to collaborators (never the room-creation key).
4. In a second browser tab, choose **Share workbook**, paste the room ID and
   room access key, and click **Join room**. Joining replaces the current local
   workbook; export local edits first if needed.
5. Edits propagate in real time; peers and nearby selections are shown.
   Edits to different cells merge; stale writes to the **same** cell are
   rejected, and the client downloads a backup before restoring the
   current server copy.
6. Choose **Version history** to inspect revisions. Owners can restore a prior
   version; each restore creates a new revision for the room.

Rooms, version history and role-key hashes persist in the SQLite database
under `.arcside-labs-runtime/collaboration.sqlite`. The last 200 revisions
per room are retained. A new global **room-creation key** is generated every
launcher restart. Existing room-specific keys remain valid after restart.

This is working local collaboration, not a fully hosted SaaS multi-tenant
collaboration product. Browsers must be able to reach the same service.
The default launcher deliberately binds to 127.0.0.1: devices on other
machines cannot reach it. Do not open or forward the local service ports.
Deploying to a network requires a separate HTTPS reverse proxy,
user authentication, rate limiting, backups and a security review.

## Working with Python Lab

Choose **Browser / Pyodide** to execute within the browser without
installing a local runtime.

Choose **Trusted local CPython**, then **Connect local** to use the native
CPython environment, OS shell, python-lsp-server semantic tooling, live
debugpy breakpoints/step controls, project files, Jupyter kernels,
environment/package management, Ruff lint/format, Git, pytest, code
coverage and cProfile.

The terminal prints a **different** Python connection token. This key
grants access to executing code as your OS user and must **never be shared
with workbook collaborators**. Python execution is not a sandbox for
untrusted third-party code.

## Current compatibility constraints

Arcside Sheets is **not a drop-in clone of Microsoft Excel or Google Sheets**:
not all Excel formulas, named ranges, structured references, arrays,
macros/VBA, conditional formatting, comments, native pivot objects, chart
objects, imports, collaboration controls or enterprise workbook formats
are round-tripped. The internal grid is limited to 256 columns, 100,000
rows and a capped number of occupied cells. Native XLSX import/export via
ExcelJS is best-effort and may drop unsupported features. Always keep
the original Excel workbook.

Arcside Python Lab is **not a fully equivalent replacement for VS Code or
PyCharm**. Native execution and selected LSP/DAP/Jupyter capabilities are
real, but marketplace plugins, cloud compute, remote containers, broad
multi-language language servers, a complete Jupyter document editor,
and all editor refactorings are incomplete. Local trusted Python is
supported on macOS/Linux; Windows terminals require further work.

For the development team, full commercial feature parity and public
multi-user production readiness remain separate release criteria,
including cross-browser/OS QA, accessibility review, large-scale performance,
auth/account integration, resilience testing, privacy and data controls,
and a comprehensive Excel compatibility corpus.

## Tests

```bash
# API, roles, conflict/persistence/revision history
python -m pip install -e 'python/arcside_collab[test]'
python -m pytest -q python/arcside_collab/tests

# Browser formula/analytics/collaboration semantics
node --test web/labs/tests/*.test.mjs

# Actual end-to-end browser integrations: use CI, which starts isolated
# local services and uses disposable test room keys.
```

CI includes `labs_quality.yml`, `labs_power_quality.yml`,
and `labs_collaboration_quality.yml` (API, two-browser synchronization,
version restoration and one-command launcher smoke tests).

All new work remains draft until quality and security review.
