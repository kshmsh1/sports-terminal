#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKEND_BASE="${SPORTS_TERMINAL_BACKEND_BASE_URL:-http://127.0.0.1:8000}"

# Prefer the composed launch API when it is already running; otherwise compute the
# same readiness contract locally so this report is useful before startup as well.
if curl -fsS "$BACKEND_BASE/v2/completion/pre-capital" >/tmp/sports_terminal_pre_capital.json 2>/dev/null; then
  python3 -m json.tool /tmp/sports_terminal_pre_capital.json
  exit 0
fi

if [[ -x "$ROOT/.venv/bin/python" ]]; then
  PYTHON="$ROOT/.venv/bin/python"
elif [[ -x "$ROOT/backend/.venv/bin/python" ]]; then
  PYTHON="$ROOT/backend/.venv/bin/python"
else
  PYTHON="python3"
fi

PYTHONPATH="$ROOT" "$PYTHON" - <<'PY'
import json
from backend.app.pre_capital_readiness_api import pre_capital_readiness
print(json.dumps(pre_capital_readiness(), indent=2, sort_keys=True))
PY