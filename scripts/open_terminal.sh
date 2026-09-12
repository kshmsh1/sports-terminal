#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FORCE_STATIC=0
for arg in "$@"; do
  case "$arg" in
    --rebuild-static) FORCE_STATIC=1 ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: bash scripts/open_terminal.sh [--rebuild-static]" >&2
      exit 2
      ;;
  esac
done

find_history_db() {
  local candidates=(
    "$ROOT/data/warehouse/nba_history.sqlite"
    "$ROOT/nba_history.sqlite"
    "$(dirname "$ROOT")/data/warehouse/nba_history.sqlite"
    "$(dirname "$ROOT")/nba_history.sqlite"
  )
  local path
  for path in "${candidates[@]}"; do
    if [[ -f "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  done
  return 1
}

NBA_HISTORY_DB="${SPORTS_TERMINAL_NBA_HISTORY_DB:-}"
if [[ -z "$NBA_HISTORY_DB" || ! -f "$NBA_HISTORY_DB" ]]; then
  if ! NBA_HISTORY_DB="$(find_history_db)"; then
    cat >&2 <<'EOF'
Sports Terminal could not find the local canonical NBA historical warehouse.
Expected one of:
  data/warehouse/nba_history.sqlite
  nba_history.sqlite
  the same paths in the immediately previous repository directory

This launcher deliberately does not scrape or download sports data at runtime.
Point SPORTS_TERMINAL_NBA_HISTORY_DB at your existing nba_history.sqlite and run again.
EOF
    exit 1
  fi
fi
export SPORTS_TERMINAL_NBA_HISTORY_DB="$NBA_HISTORY_DB"

echo "NBA historical warehouse: $NBA_HISTORY_DB"

echo "Building/fingerprint-checking immutable NBA website data..."
STATIC_ARGS=(
  --database "$NBA_HISTORY_DB"
  --output "$ROOT/web/data/nba_static"
)
if [[ "$FORCE_STATIC" -eq 1 ]]; then
  STATIC_ARGS+=(--force)
fi
python3 "$ROOT/tools/build_static_nba_website_data_v2_core.py" "${STATIC_ARGS[@]}"

# Optional source-backed NBA.com fields such as deflections are read only from
# already-normalized local captures. This script performs no network requests.
python3 "$ROOT/tools/nba_com_static_enrichment.py" \
  --output "$ROOT/web/data/nba_static"
python3 "$ROOT/tools/rebuild_static_nba_dashboards.py" \
  --output "$ROOT/web/data/nba_static"

# Contracts/cap/draft records are also published as static read-only website
# files when the local mutable registry exists. Missing registry data produces
# explicit empty static files rather than a runtime API dependency.
python3 "$ROOT/tools/build_static_front_office_snapshot.py" \
  --output "$ROOT/web/data/nba_static/front_office"

for required in \
  "$ROOT/web/data/nba_static/manifest.json" \
  "$ROOT/web/data/nba_static/seasons.json" \
  "$ROOT/web/data/nba_static/players/index.json" \
  "$ROOT/web/data/nba_static/teams/index.json"; do
  if [[ ! -s "$required" ]]; then
    echo "Static NBA corpus is incomplete: $required" >&2
    exit 1
  fi
done

LATEST_SEASON="$(python3 - <<'PY'
import json
from pathlib import Path
manifest = json.loads(Path('web/data/nba_static/manifest.json').read_text())
print(manifest.get('latest_season') or '')
PY
)"
if [[ -n "$LATEST_SEASON" && ! -s "$ROOT/web/data/nba_static/dashboard/$LATEST_SEASON.json" ]]; then
  echo "Static NBA dashboard is missing for $LATEST_SEASON" >&2
  exit 1
fi

echo "Static NBA website corpus ready${LATEST_SEASON:+ through $LATEST_SEASON}."
echo "Resolving Flutter dependencies..."
flutter pub get

echo "Opening Sports Terminal in Chrome..."
exec flutter run -d chrome
