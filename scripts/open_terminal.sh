#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

USE_POSTGRES=false
NO_BROWSER=false
FORCE_STATIC=false
MATERIALIZE_PBP=false
for arg in "$@"; do
  case "$arg" in
    --postgres) USE_POSTGRES=true ;;
    --no-browser) NO_BROWSER=true ;;
    --rebuild-static) FORCE_STATIC=true ;;
    --materialize-pbp) MATERIALIZE_PBP=true ;;
    --skip-pbp) MATERIALIZE_PBP=false ;;
    -h|--help)
      cat <<'EOF'
Usage: bash scripts/open_terminal.sh [--postgres] [--no-browser] [--rebuild-static] [--materialize-pbp]

Starts Sports Terminal locally.

Historical NBA website data is compiled from the canonical warehouse into
versioned, sharded static JSON under web/data/nba_static before Flutter starts.
Authorized NBA.com historical response files are also materialized into that
same static corpus during launch. The browser never calls NBA.com for
historical statistics at runtime.

Home, Stats, Advanced Stats, player pages, team pages, awards, drafts,
contracts/cap snapshots and historical game details read those files directly
in the browser. FastAPI/SQLite are not in the historical page-rendering path.
Historical play-by-play is also static when materialized, but its full export is
optional because the source-backed event corpus can be very large.

  --postgres         Use the loopback-only Postgres 17 app database.
  --no-browser       Do not automatically open http://127.0.0.1:8080.
  --rebuild-static   Force rebuilding static NBA files even when fingerprints match.
  --materialize-pbp  Also build all available source-backed historical PBP shards. This can take significant time.
  --skip-pbp         Explicit compatibility alias for the default behavior: defer PBP materialization.

Static compilation is fingerprint-aware. Historical warehouse changes and
local NBA.com normalized capture changes have independent fingerprints. Once a
historical NBA.com response has been imported locally and materialized, no
runtime NBA.com network access is required to display it.

Dynamic services are optional for local browsing. If the local API cannot start,
the website still launches with immutable historical NBA pages available while
accounts, saved work, community, mutable front-office edits and other dynamic
features remain offline.
EOF
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "python3 is required." >&2; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "Flutter is required." >&2; exit 1; }

VENV="$ROOT/.venv"
if [[ ! -x "$VENV/bin/python" ]]; then
  echo "==> Creating .venv"
  python3 -m venv "$VENV"
fi
PYTHON="$VENV/bin/python"

if [[ "${SPORTS_TERMINAL_SKIP_DEP_INSTALL:-false}" != "true" ]]; then
  echo "==> Resolving backend dependencies"
  "$PYTHON" -m pip install --disable-pip-version-check -q -r backend/requirements.txt
fi

CURRENT_HISTORY_DB="$ROOT/data/warehouse/nba_history.sqlite"
PARENT_HISTORY_DB="$PARENT_ROOT/data/warehouse/nba_history.sqlite"
if [[ -s "$CURRENT_HISTORY_DB" ]]; then
  HISTORY_DB="$CURRENT_HISTORY_DB"
elif [[ -s "$PARENT_HISTORY_DB" ]]; then
  HISTORY_DB="$PARENT_HISTORY_DB"
  echo "==> Rediscovered NBA history warehouse: $HISTORY_DB"
else
  HISTORY_DB="$CURRENT_HISTORY_DB"
fi

CURRENT_SOURCE_ROOT="$ROOT/raw/historical"
PARENT_SOURCE_ROOT="$PARENT_ROOT/raw/historical"
if [[ -d "$CURRENT_SOURCE_ROOT" ]]; then
  HISTORICAL_SOURCE_ROOT="$CURRENT_SOURCE_ROOT"
elif [[ -d "$PARENT_SOURCE_ROOT" ]]; then
  HISTORICAL_SOURCE_ROOT="$PARENT_SOURCE_ROOT"
else
  HISTORICAL_SOURCE_ROOT="$CURRENT_SOURCE_ROOT"
fi

export SPORTS_TERMINAL_NBA_HISTORY_DB="$HISTORY_DB"

history_db_has_canonical_tables() {
  [[ -s "$HISTORY_DB" ]] || return 1
  "$PYTHON" - "$HISTORY_DB" <<'PY' >/dev/null 2>&1
import sqlite3, sys
with sqlite3.connect(sys.argv[1]) as db:
    names = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type IN ('table','view')")}
required = {
    "canon_dim_player",
    "canon_dim_team",
    "canon_dim_season",
    "canon_dim_game",
    "canon_fact_player_season",
    "canon_fact_team_season",
}
raise SystemExit(0 if required.issubset(names) else 1)
PY
}

history_db_has_import_inventory() {
  [[ -s "$HISTORY_DB" ]] || return 1
  "$PYTHON" - "$HISTORY_DB" <<'PY' >/dev/null 2>&1
import sqlite3, sys
with sqlite3.connect(sys.argv[1]) as db:
    row = db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='historical_table_inventory'").fetchone()
raise SystemExit(0 if row else 1)
PY
}

local_historical_sources_exist() {
  [[ -d "$HISTORICAL_SOURCE_ROOT" ]] || return 1
  find "$HISTORICAL_SOURCE_ROOT" -type f \
    \( -name '*.sqlite' -o -name '*.sqlite3' -o -name '*.db' -o -name '*.csv' \) \
    -print -quit 2>/dev/null | grep -q .
}

prepare_nba_history() {
  mkdir -p "$(dirname "$HISTORY_DB")"
  if history_db_has_canonical_tables; then
    echo "==> Canonical NBA history warehouse ready: $HISTORY_DB"
    return 0
  fi
  if history_db_has_import_inventory; then
    echo "==> Canonicalizing existing historical NBA warehouse"
    "$PYTHON" tools/build_historical_nba_canonical.py --database "$HISTORY_DB" || true
    history_db_has_canonical_tables && return 0
  fi
  if local_historical_sources_exist; then
    echo "==> Importing already-downloaded historical NBA sources"
    "$PYTHON" tools/run_historical_nba_import.py \
      --source-root "$HISTORICAL_SOURCE_ROOT" \
      --output "$HISTORY_DB" \
      --report "$(dirname "$HISTORY_DB")/nba_history_import_report.json"
    "$PYTHON" tools/build_historical_nba_canonical.py --database "$HISTORY_DB"
    history_db_has_canonical_tables && return 0
  fi
  echo "Canonical NBA history warehouse is unavailable." >&2
  echo "Checked: $CURRENT_HISTORY_DB" >&2
  echo "Checked: $PARENT_HISTORY_DB" >&2
  return 1
}

STATIC_NBA_DIR="$ROOT/web/data/nba_static"

validate_static_nba_corpus() {
  "$PYTHON" - "$STATIC_NBA_DIR" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
manifest_path = root / "manifest.json"
if not manifest_path.is_file():
    raise SystemExit("Static NBA manifest is missing")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
latest = str(manifest.get("latest_season") or "")
required = [
    root / "seasons.json",
    root / "players/index.json",
    root / "teams/index.json",
    root / "games/index.json",
    root / "history/awards.json",
    root / "history/all_star.json",
    root / "history/draft.json",
]
if latest:
    required.extend([
        root / f"seasons/{latest}/regular.json",
        root / f"dashboard/{latest}.json",
    ])
missing = [str(path.relative_to(root)) for path in required if not path.is_file()]
if missing:
    raise SystemExit("Static NBA corpus is incomplete: " + ", ".join(missing))
runtime = manifest.get("runtime") or {}
if runtime.get("historical_http_api_required") is not False:
    raise SystemExit("Static NBA manifest does not declare API-independent historical runtime")
print(f"Static NBA corpus validated: {manifest.get('season_count', 0)} seasons; latest={latest or 'unknown'}")
enrichment = manifest.get("nba_com_enrichment") or {}
fingerprint = enrichment.get("fingerprint") or {}
normalized_files = int(fingerprint.get("normalized_file_count") or 0)
enriched_rows = int(enrichment.get("enriched_player_rows") or 0)
matched_rows = int(enrichment.get("matched_source_rows") or 0)
unmatched_rows = int(enrichment.get("unmatched_source_rows") or 0)
if enrichment:
    print(
        "Static NBA.com materialization: "
        f"{normalized_files} normalized captures; "
        f"{enriched_rows} player-season rows; "
        f"{matched_rows} matched source rows; "
        f"{unmatched_rows} unmatched source rows"
    )
else:
    print("Static NBA.com materialization: none (no normalized local NBA.com captures materialized)")
PY
}

prepare_nba_history

STATIC_ARGS=(--database "$HISTORY_DB" --output "$STATIC_NBA_DIR")
GAME_ARGS=(--database "$HISTORY_DB" --output "$STATIC_NBA_DIR")
if $FORCE_STATIC; then
  STATIC_ARGS+=(--force)
  GAME_ARGS+=(--force)
fi
if $MATERIALIZE_PBP; then GAME_ARGS+=(--include-pbp); fi

echo "==> Preparing immutable static NBA website data"
"$PYTHON" tools/build_static_nba_website_data_v2.py "${STATIC_ARGS[@]}"

# Explicitly run the local NBA.com materialization layer even when the historical
# compiler reports that its SQLite-derived corpus is already current. This step
# performs no network requests and is independently fingerprint-aware.
echo "==> Materializing imported NBA.com historical statistics"
NBA_COM_ARGS=(--output "$STATIC_NBA_DIR")
if $FORCE_STATIC; then NBA_COM_ARGS+=(--force); fi
"$PYTHON" tools/nba_com_static_enrichment.py "${NBA_COM_ARGS[@]}"

if $MATERIALIZE_PBP; then
  echo "==> Preparing static historical game detail and source-backed PBP"
else
  echo "==> Preparing static historical game detail (PBP deferred)"
fi
"$PYTHON" tools/build_static_nba_game_data.py "${GAME_ARGS[@]}"

validate_static_nba_corpus

echo "==> Resolving Flutter dependencies"
flutter pub get >/dev/null

mkdir -p "$ROOT/.data/logs" "$ROOT/.data/objects" "$ROOT/backend/.data"
export PYTHONPATH="$ROOT/backend"
export SPORTS_TERMINAL_ENV=development
export SPORTS_TERMINAL_AUTO_MIGRATE=true
export SPORTS_TERMINAL_ENFORCE_AUTH=false
export SPORTS_TERMINAL_REQUIRE_EMAIL_VERIFICATION=false
export SPORTS_TERMINAL_BILLING_MODE=disabled
export SPORTS_TERMINAL_RATE_LIMITS=false
export SPORTS_TERMINAL_EMAIL_PROVIDER=console
export SPORTS_TERMINAL_OBJECT_STORE=filesystem
export SPORTS_TERMINAL_OBJECT_STORE_ROOT="$ROOT/.data/objects"
export SPORTS_TERMINAL_PUBLIC_API_ORIGIN="http://127.0.0.1:8000"
export SPORTS_TERMINAL_SESSION_PEPPER="local-session-pepper-0123456789abcdef0123456789abcdef"
export SPORTS_TERMINAL_MFA_ENCRYPTION_KEY="local-mfa-encryption-key-0123456789abcdef0123456789abcdef"
export SPORTS_TERMINAL_SSO_ENCRYPTION_KEY="local-sso-encryption-key-0123456789abcdef0123456789abcdef"
export SPORTS_TERMINAL_RELEASE_SIGNING_SECRET="local-release-signing-secret-0123456789abcdef0123456789abcdef"
export SPORTS_TERMINAL_BACKUP_SIGNING_SECRET="local-backup-signing-secret-0123456789abcdef0123456789abcdef"

STARTED_POSTGRES=false
BACKEND_PID=""
FLUTTER_PID=""
cleanup() {
  echo
  echo "==> Stopping Sports Terminal local session"
  [[ -n "$FLUTTER_PID" ]] && kill "$FLUTTER_PID" >/dev/null 2>&1 || true
  [[ -n "$BACKEND_PID" ]] && kill "$BACKEND_PID" >/dev/null 2>&1 || true
  if $STARTED_POSTGRES; then
    docker compose -f backend/docker-compose.postgres.yml --profile local-postgres down >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

wait_for_port() {
  local port="$1" label="$2"
  for _ in $(seq 1 60); do
    if "$PYTHON" - "$port" <<'PY' >/dev/null 2>&1
import socket, sys
with socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=0.5):
    pass
PY
    then return 0; fi
    sleep 1
  done
  echo "$label did not start on port $port." >&2
  return 1
}

launch_api_ready() {
  "$PYTHON" - <<'PY' >/dev/null 2>&1
import json, urllib.request
try:
    with urllib.request.urlopen("http://127.0.0.1:8000/v2/launch/readiness", timeout=1.0) as response:
        if response.status != 200:
            raise SystemExit(1)
        payload = json.load(response)
        if "status" not in payload or "launch_profile" not in payload:
            raise SystemExit(1)
except Exception:
    raise SystemExit(1)
PY
}

if $USE_POSTGRES; then
  command -v docker >/dev/null 2>&1 || { echo "Docker is required for --postgres." >&2; exit 1; }
  echo "==> Starting loopback-only Postgres 17"
  docker compose -f backend/docker-compose.postgres.yml --profile local-postgres up -d postgres
  STARTED_POSTGRES=true
  export SPORTS_TERMINAL_DATABASE_URL="postgresql://sports_terminal:local-development-only@127.0.0.1:54329/sports_terminal"
  wait_for_port 54329 "Postgres"
  "$PYTHON" backend/scripts/local_postgres_smoke.py
else
  unset SPORTS_TERMINAL_DATABASE_URL || true
  export SPORTS_TERMINAL_DB_PATH="$ROOT/backend/.data/sports_terminal.db"
fi

DYNAMIC_API_AVAILABLE=false

echo "==> Initializing application database"
if "$PYTHON" backend/scripts/migrate.py >/dev/null 2>"$ROOT/.data/logs/migrate.log"; then
  if ! $USE_POSTGRES; then
    echo "==> Publishing static front-office snapshot"
    if ! "$PYTHON" tools/build_static_front_office_snapshot.py \
      --database "$SPORTS_TERMINAL_DB_PATH" \
      --output "$STATIC_NBA_DIR/front_office" >/dev/null 2>"$ROOT/.data/logs/front_office_snapshot.log"; then
      echo "WARNING: static front-office snapshot could not be refreshed; historical NBA browsing remains available." >&2
    fi
  else
    echo "==> Postgres mode: keeping any previously published static front-office snapshot"
  fi

  echo "==> Starting dynamic Sports Terminal services at http://127.0.0.1:8000"
  "$PYTHON" -m uvicorn app.main_launch:app --host 127.0.0.1 --port 8000 \
    >"$ROOT/.data/logs/backend.log" 2>&1 &
  BACKEND_PID=$!

  for _ in $(seq 1 20); do
    if ! kill -0 "$BACKEND_PID" >/dev/null 2>&1; then
      break
    fi
    if launch_api_ready; then
      DYNAMIC_API_AVAILABLE=true
      break
    fi
    sleep 1
  done

  if ! $DYNAMIC_API_AVAILABLE; then
    echo "WARNING: dynamic Sports Terminal API is unavailable. Historical NBA pages will still launch." >&2
    echo "         See .data/logs/backend.log for the backend failure." >&2
    [[ -n "$BACKEND_PID" ]] && kill "$BACKEND_PID" >/dev/null 2>&1 || true
    BACKEND_PID=""
  fi
else
  echo "WARNING: application database migration failed. Historical NBA pages will still launch." >&2
  echo "         See .data/logs/migrate.log for the migration failure." >&2
fi

echo "==> Starting Sports Terminal website at http://127.0.0.1:8080"
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 \
  >"$ROOT/.data/logs/flutter.log" 2>&1 &
FLUTTER_PID=$!
wait_for_port 8080 "Flutter web server"

if ! kill -0 "$FLUTTER_PID" >/dev/null 2>&1; then
  echo "Flutter exited during startup. See .data/logs/flutter.log" >&2
  exit 1
fi

if ! $NO_BROWSER; then
  if command -v open >/dev/null 2>&1; then
    open "http://127.0.0.1:8080" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://127.0.0.1:8080" >/dev/null 2>&1 || true
  fi
fi

if $DYNAMIC_API_AVAILABLE; then
  API_STATUS="online"
else
  API_STATUS="offline (historical NBA remains available)"
fi

cat <<EOF

Sports Terminal is running locally.
  Website:         http://127.0.0.1:8080
  Dynamic API:     $API_STATUS
  NBA warehouse:   $HISTORY_DB
  Static NBA:      $STATIC_NBA_DIR
  Front office:    $STATIC_NBA_DIR/front_office
  Backend log:     .data/logs/backend.log
  Migration log:   .data/logs/migrate.log
  Flutter log:     .data/logs/flutter.log

Historical NBA pages are served from static files, not the API.
Press Ctrl-C to stop it.
EOF

wait "$FLUTTER_PID"
