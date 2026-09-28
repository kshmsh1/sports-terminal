#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET_REPO_URL="${SPORTS_TERMINAL_PAGES_REPO:-https://github.com/kshmsh1/kshmsh1.github.io.git}"
TARGET_BRANCH="${SPORTS_TERMINAL_PAGES_BRANCH:-main}"
PUBLIC_SUBDIR="${SPORTS_TERMINAL_PAGES_SUBDIR:-sports-terminal}"
BASE_HREF="/${PUBLIC_SUBDIR#/}/"
BASE_HREF="/${BASE_HREF%/}/"
FORCE_STATIC=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --force-static) FORCE_STATIC=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *)
      echo "Unknown option: $arg" >&2
      echo "Usage: bash scripts/deploy_github_pages.sh [--force-static] [--dry-run]" >&2
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

Set SPORTS_TERMINAL_NBA_HISTORY_DB or keep nba_history.sqlite at one of the
same locations supported by scripts/open_terminal.sh.

Nothing is uploaded from the raw warehouse. The deployment publishes only the
compiled browser application and the static files required by that application.
EOF
    exit 1
  fi
fi

PYTHON_BIN="${SPORTS_TERMINAL_PYTHON:-python3}"
if [[ -x "$ROOT/.historical-venv/bin/python" ]]; then
  PYTHON_BIN="$ROOT/.historical-venv/bin/python"
elif ! "$PYTHON_BIN" -c 'import fastapi' >/dev/null 2>&1; then
  echo "Preparing local Python environment for the static compiler..."
  python3 -m venv "$ROOT/.historical-venv"
  "$ROOT/.historical-venv/bin/python" -m pip install --upgrade pip >/dev/null
  "$ROOT/.historical-venv/bin/python" -m pip install -r "$ROOT/backend/requirements.txt"
  PYTHON_BIN="$ROOT/.historical-venv/bin/python"
fi

echo "Building/fingerprint-checking browser-safe NBA static data..."
STATIC_ARGS=(
  --database "$NBA_HISTORY_DB"
  --output "$ROOT/web/data/nba_static"
)
if [[ "$FORCE_STATIC" -eq 1 ]]; then
  STATIC_ARGS+=(--force)
fi

"$PYTHON_BIN" "$ROOT/tools/build_static_nba_website_data_v2_core.py" "${STATIC_ARGS[@]}"
"$PYTHON_BIN" "$ROOT/tools/normalize_static_nba_three_point_fields.py"   --output "$ROOT/web/data/nba_static"
"$PYTHON_BIN" "$ROOT/tools/nba_com_static_enrichment.py"   --output "$ROOT/web/data/nba_static"
"$PYTHON_BIN" "$ROOT/tools/rebuild_static_nba_dashboards.py"   --output "$ROOT/web/data/nba_static"
"$PYTHON_BIN" "$ROOT/tools/enrich_static_nba_pdf_early_totals.py"   --output "$ROOT/web/data/nba_static"
"$PYTHON_BIN" "$ROOT/tools/build_static_front_office_snapshot.py"   --output "$ROOT/web/data/nba_static/front_office"

GAME_DETAIL_ARGS=(
  --database "$NBA_HISTORY_DB"
  --output "$ROOT/web/data/nba_static"
)
if [[ "$FORCE_STATIC" -eq 1 ]]; then
  GAME_DETAIL_ARGS+=(--force)
fi
"$PYTHON_BIN" "$ROOT/tools/materialize_static_nba_game_details.py" "${GAME_DETAIL_ARGS[@]}"

for required in   "$ROOT/web/data/nba_static/manifest.json"   "$ROOT/web/data/nba_static/seasons.json"   "$ROOT/web/data/nba_static/players/index.json"   "$ROOT/web/data/nba_static/teams/index.json"; do
  if [[ ! -s "$required" ]]; then
    echo "Static NBA corpus is incomplete: $required" >&2
    exit 1
  fi
done

echo "Building Flutter web release for GitHub Pages at $BASE_HREF ..."
flutter pub get
flutter build web --release --base-href "$BASE_HREF"

BUILD_DIR="$ROOT/build/web"
if [[ ! -s "$BUILD_DIR/index.html" ]]; then
  echo "Flutter web build did not produce build/web/index.html" >&2
  exit 1
fi

# GitHub rejects individual files above 100 MiB. Keep a small safety margin so
# a deployment fails locally instead of halfway through a push.
oversized="$(find "$BUILD_DIR" -type f -size +95M -print -quit)"
if [[ -n "$oversized" ]]; then
  echo "Deployment contains a file larger than 95 MiB: $oversized" >&2
  echo "Shard/compress that browser artifact before publishing to GitHub Pages." >&2
  exit 1
fi

# GitHub Pages is intended for sites around or below 1 GiB. Fail before
# touching the destination repository if the generated site is already close
# to that boundary.
site_kib="$(du -sk "$BUILD_DIR" | awk '{print $1}')"
if (( site_kib > 950000 )); then
  echo "Generated site is too large for a safe GitHub Pages deployment: ${site_kib} KiB" >&2
  echo "Use object storage/CDN hosting for the static corpus instead." >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run complete."
  echo "Built site size: ${site_kib} KiB"
  echo "Would publish only to /$PUBLIC_SUBDIR/ in $TARGET_REPO_URL"
  echo "Your existing kshmsh1.github.io root files would remain untouched."
  exit 0
fi

PUBLISH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sports-terminal-pages.XXXXXX")"
trap 'rm -rf "$PUBLISH_ROOT"' EXIT

echo "Cloning Pages repository..."
git clone --depth 1 --branch "$TARGET_BRANCH" "$TARGET_REPO_URL" "$PUBLISH_ROOT/site" >/dev/null

PUBLISH_DIR="$PUBLISH_ROOT/site/$PUBLIC_SUBDIR"
mkdir -p "$PUBLISH_DIR"

# Synchronize only the Sports Terminal subdirectory. Nothing at the Pages
# repository root is deleted, renamed, or replaced.
rsync -a --delete "$BUILD_DIR/" "$PUBLISH_DIR/"

# Make the public ownership boundary available next to the deployed artifact.
cp "$ROOT/LICENSE" "$PUBLISH_DIR/LICENSE.txt"

SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
cat > "$PUBLISH_DIR/deployment.json" <<EOF
{
  "source_repository": "kshmsh1/sports-terminal",
  "source_commit": "$SOURCE_COMMIT",
  "base_href": "$BASE_HREF"
}
EOF

git -C "$PUBLISH_ROOT/site" add "$PUBLIC_SUBDIR"

if git -C "$PUBLISH_ROOT/site" diff --cached --quiet; then
  echo "GitHub Pages already matches the current build; nothing to publish."
  echo "https://kshmsh1.github.io/$PUBLIC_SUBDIR/"
  exit 0
fi

git -C "$PUBLISH_ROOT/site" commit -m "Deploy Sports Terminal $SOURCE_COMMIT"
git -C "$PUBLISH_ROOT/site" push origin "$TARGET_BRANCH"

echo
echo "Sports Terminal deployment pushed successfully."
echo "Public URL: https://kshmsh1.github.io/$PUBLIC_SUBDIR/"
echo "Local development is unchanged; continue using:"
echo "  bash scripts/open_terminal.sh"
