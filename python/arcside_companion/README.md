# Arcside Python Companion (trusted local process)

The browser-only Pyodide lab works without this companion. For actual OS
Python, a PTY terminal, Python environments, a live debugger, a language server
and Jupyter kernels, install the **opt-in local companion** in the project
folder on your own Mac or Linux computer:

\`\`\`bash
cd python/arcside_companion
python3 -m venv .venv
. .venv/bin/activate
pip install -e '.[all]'
python -m arcside_companion --workspace ~/my-python-project \
  --allow-origin http://127.0.0.1:8765
\`\`\`

For an Arcside site hosted at a different address, explicitly pass that
exact origin using another \`--allow-origin\` argument. Open **Python Lab**,
select **Local runtime**, and paste the generated 256-bit connection token
into the local-only connection form. The token is kept only in this tab's
\`sessionStorage\`, not in a source file, repository or URL.

The runtime listens **only on 127.0.0.1:8766**, and all code-execution
routes require the token and trusted Origin. Directories accessed through
file-management routes are confined to the workspace, including symlink
checks. Every runtime process has your user account's privileges; this is
**not an isolation sandbox** and must only be used with trusted projects,
packages and browser origins. Never forward this port, publish the token,
run it as root or enable a wildcard Origin.

What is real and supported:
- Native CPython execution, syntax errors, subprocess output, pytest/unittest.
- Workspace-scoped file sync and real filesystem paths, with optimistic SHA-256
  revision checks to prevent overwriting pre-existing or externally edited files.
- Python venv, optional uv/conda, pip installation, environment selection.
- Unix PTY shell with live input; no PTY claim for Windows.
- Optional python-lsp-server over LSP WebSocket bridge.
- Optional debugpy DAP bridge, supporting launch/true pause/step and stack scopes.
- Optional Jupyter client kernel using the selected interpreter, if ipykernel is installed.
- Ruff format/lint, cProfile profiling, test coverage, and Git status/diff/staging/commit.

Important limitations: binding is loopback only; local network and public
deployment are intentionally unsupported. The web UI requires an explicit
local token; runtime dependencies and native wheels are installed on the
user's machine. Jupyter and debugpy need their respective optional packages,
including installation in the selected virtual environment. The debugger
does not allow arbitrary process attach. Browser/OS security settings may
block the HTTP loopback bridge from certain HTTPS origins.

Run the companion tests:
\`\`\`bash
python -m pip install -e '.[test,ide,notebook]'
python -m pytest -q
\`\`\`
