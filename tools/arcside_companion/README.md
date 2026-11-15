# Arcside Local Python Companion

The Arcside Python Lab works through browser **Pyodide** without a native
service. The optional companion adds a native Python interpreter, real OS
terminal, environments, language intelligence, pytest, interactive debugging
and persistent Jupyter notebooks. It runs only with explicit user consent,
on loopback. It is **not** a sandbox for untrusted code.

## Installation (macOS and Linux)

From the Arcside repository root:

~~~bash
python3 -m venv .arcside-companion-venv
.arcside-companion-venv/bin/python -m pip install -e "./tools/arcside_companion[ide]"
mkdir -p "$HOME/arcside-lab-project"

.arcside-companion-venv/bin/arcside-companion \
  --workspace "$HOME/arcside-lab-project" \
  --allow-origin http://127.0.0.1:8765
~~~

The command starts an HTTP/WebSocket API on **127.0.0.1:8766** and prints a
newly generated session token. Keep the terminal open while using the IDE;
Ctrl+C stops the companion. The token is **never saved** with the browser
project. Paste a new one after restarting the companion.

For local web testing, serve the Arcside static app from the repository root:

~~~bash
python3 -m http.server 8765 --bind 127.0.0.1 --directory web
~~~

Open http://127.0.0.1:8765/labs/python/, choose **Local IDE**, enter
http://127.0.0.1:8766 and paste the temporary token, then press **Connect**.
The browser-only Pyodide mode remains available without the companion.

If Arcside is served from another origin, supply its **exact** scheme,
hostname and port via --allow-origin. The default origins are
http://127.0.0.1:8765 and http://localhost:8765. Remote HTTPS origins
may be blocked by browser Private Network Access, CORS or mixed-content
policies. Use a trusted local setup unless a desktop bridge is engineered.

## Native IDE features

**Python and pytest.** Run the current script with the selected .venv/.conda
or system interpreter. Native pytest discovers tests in the project.
Run Selection starts a **separate** Python process: state does not persist
between snippets. Persistent state is provided by Notebook.

**Environments.** Create .venv using Python venv or installed uv, or create
.conda using installed conda. The companion prefers .venv if both exist.
Package input is limited to names/specifiers; arbitrary pip CLI flags, local
paths and URLs are deliberately rejected. Special installs are possible in
the manually controlled local PTY shell, which runs trusted commands with
full local OS privileges.

**Real PTY terminal.** Interactive macOS/Linux shell with streaming output
and resizing through xterm.js. Windows ConPTY has not been implemented.

**Language server.** If installed, pyright-langserver or pylsp provides
Monaco completions, hover information and diagnostics. Basic Monaco language
features work independently of the companion.

**Debugging.** Real debugpy sessions support pausing on entry, continue,
step over, step in, step out, stack frames, variables, watch expressions
and breakpoint markers. Browser-only Pyodide debugging still uses trace
replay rather than true pause/resume.

**Notebook.** Persistent Jupyter/ipykernel with editable code cells, run
cell/all, interrupt/restart, text and Matplotlib PNG outputs, and .ipynb
import/export. Arbitrary HTML output is intentionally not rendered.
Code-cell source is saved locally in the browser; outputs are session-only
and are excluded from exported notebooks.

**Additional tools.** Native Ruff format/check and read-only Git status.

## Data safety

- The companion **never starts automatically** when Arcside loads.
- Each privileged HTTP request uses X-Arcside-Token, and all privileged
  WebSockets use an authenticated initial handshake. Browser origins are
  allowlisted. The session token is stored in runtime memory only.
- The first browser-to-disk project sync requires explicit confirmation.
  It **overwrites matching filenames** within the chosen local workspace.
  Choose a dedicated folder and back up valuable files first.
- The file API prevents parent-path traversal, symlink escapes and writes
  to protected directories such as .git and .venv. **This is NOT process
  isolation:** a Python script or shell executes with your user's OS
  permissions and can access other files and network connections.
- Native run/test commands are bounded by timeouts, explicit Stop
  cancellation and streamed output memory caps. PTY shell sessions are
  separate; interrupt them in the terminal or stop the companion.
- Never expose this service with a reverse proxy, public port or tunnel.
  Do not use it to execute other people's code or as a multi-tenant API.
- Restart the companion to invalidate an old session token. The local
  browser still downloads pinned versions of Monaco, Pyodide, xterm and
  ExcelJS from CDNs; deployment with a strict CSP or offline use requires
  vendored assets and integrity controls.

## Tests

~~~bash
python3 -m pip install -e "./tools/arcside_companion[test]"
python3 -m pytest -q tools/arcside_companion/tests
cd web/labs
npm install
npx playwright install chromium
npm run test:browser
~~~

The full browser-to-native test suite starts its own **temporary test-only**
loopback companion with an isolated workspace, available when
ARCSIDE_NATIVE_TEST=1. Never use CI's fixed throwaway token for real use.
GitHub Actions runs Python 3.11/3.12/3.13 tests, JavaScript syntax/formula
tests and real Chromium integration tests.

## Scope and limitations

This is a functional advanced IDE foundation, **not full VS Code or PyCharm
parity**. Native capabilities still need Windows ConPTY, comprehensive
semantic refactoring, notebook widgets, deep profiling/coverage UIs,
containerized isolation, robust multi-user access policies, and a supported
desktop app distribution model. Likewise, the spreadsheet workspace is
not yet feature-compatible with all of Microsoft Excel or Google Sheets.
