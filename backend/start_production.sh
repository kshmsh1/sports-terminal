#!/bin/sh
set -eu

if [ "${SPORTS_TERMINAL_ENV:-}" != "production" ]; then
  echo "SPORTS_TERMINAL_ENV must be production" >&2
  exit 2
fi

PYTHONPATH=. python - <<'PY'
from app.runtime_config import load_runtime_config
config = load_runtime_config()
config.assert_production_safe()
print("production configuration: safe")
PY

if [ "${SPORTS_TERMINAL_RUN_MIGRATIONS_ON_START:-false}" = "true" ]; then
  echo "Running explicit production migrations before serving"
  PYTHONPATH=. python scripts/migrate.py
else
  echo "Automatic production migrations disabled; launch bootstrap will verify schema version"
fi

set -- uvicorn app.main_launch:app \
  --host 0.0.0.0 \
  --port "${PORT:-8000}" \
  --workers "${WEB_CONCURRENCY:-2}"

if [ "${SPORTS_TERMINAL_TRUST_PROXY_HEADERS:-false}" = "true" ]; then
  set -- "$@" --proxy-headers
else
  set -- "$@" --no-proxy-headers
fi

exec "$@"
