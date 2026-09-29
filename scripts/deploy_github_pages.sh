#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET_REPO_URL="${SPORTS_TERMINAL_PAGES_REPO:-https://github.com/kshmsh1/kshmsh1.github.io.git}"
TARGET_BRANCH="${SPORTS_TERMINAL_PAGES_BRANCH:-main}"
PUBLIC_SUBDIR="${SPORTS_TERMINAL_PAGES_SUBDIR:-sports-terminal}"
PUBLIC_SUBDIR="${PUBLIC_SUBDIR#/}"
PUBLIC_SUBDIR="${PUBLIC_SUBDIR%/}"
STATIC_PUBLIC_BASE="${SPORTS_TERMINAL_STATIC_PUBLIC_BASE:-}"
STATIC_S3_URI="${SPORTS_TERMINAL_STATIC_S3_URI:-}"
STATIC_S3_ENDPOINT="${SPORTS_TERMINAL_STATIC_S3_ENDPOINT:-}"
FORCE_STATIC=0
DRY_RUN=0

if [[ -z "$PUBLIC_SUBDIR" ]]; then
  echo "SPORTS_TERMINAL_PAGES_SUBDIR must not be empty." >&2
  exit 2
fi
BASE_HREF="/$PUBLIC_SUBDIR/"

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

if [[ -z "$STATIC_PUBLIC_BASE" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    STATIC_PUBLIC_BASE="https://static.example.invalid/nba_static"
    echo "No SPORTS_TERMINAL_STATIC_PUBLIC_BASE set; using a non-routable placeholder for dry-run."
  else
    echo "SPORTS_TERMINAL_STATIC_PUBLIC_BASE is required for public deployment." >&2
    echo "Example: https://data.example.com/nba_static" >&2
    exit 2
  fi
fi
STATIC_PUBLIC_BASE="${STATIC_PUBLIC_BASE%/}"

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

The raw warehouse is never uploaded. Only the browser-safe generated static
corpus is synchronized to the configured object-storage bucket.
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

STATIC_DIR="$ROOT/web/data/nba_static"
echo "Building/fingerprint-checking browser-safe NBA static data..."
STATIC_ARGS=(--database "$NBA_HISTORY_DB" --output "$STATIC_DIR")
if [[ "$FORCE_STATIC" -eq 1 ]]; then STATIC_ARGS+=(--force); fi

"$PYTHON_BIN" "$ROOT/tools/build_static_nba_website_data_v2_core.py" "${STATIC_ARGS[@]}"
"$PYTHON_BIN" "$ROOT/tools/normalize_static_nba_three_point_fields.py" --output "$STATIC_DIR"
"$PYTHON_BIN" "$ROOT/tools/nba_com_static_enrichment.py" --output "$STATIC_DIR"
"$PYTHON_BIN" "$ROOT/tools/rebuild_static_nba_dashboards.py" --output "$STATIC_DIR"
"$PYTHON_BIN" "$ROOT/tools/enrich_static_nba_pdf_early_totals.py" --output "$STATIC_DIR"
"$PYTHON_BIN" "$ROOT/tools/build_static_front_office_snapshot.py" --output "$STATIC_DIR/front_office"

GAME_DETAIL_ARGS=(--database "$NBA_HISTORY_DB" --output "$STATIC_DIR")
if [[ "$FORCE_STATIC" -eq 1 ]]; then GAME_DETAIL_ARGS+=(--force); fi
"$PYTHON_BIN" "$ROOT/tools/materialize_static_nba_game_details.py" "${GAME_DETAIL_ARGS[@]}"

for required in   "$STATIC_DIR/manifest.json"   "$STATIC_DIR/seasons.json"   "$STATIC_DIR/players/index.json"   "$STATIC_DIR/teams/index.json"; do
  if [[ ! -s "$required" ]]; then
    echo "Static NBA corpus is incomplete: $required" >&2
    exit 1
  fi
done

corpus_kib="$(du -sk "$STATIC_DIR" | awk '{print $1}')"
echo "Static corpus size: ${corpus_kib} KiB"

if [[ "$DRY_RUN" -eq 0 ]]; then
  if [[ -z "$STATIC_S3_URI" ]]; then
    echo "SPORTS_TERMINAL_STATIC_S3_URI is required for public deployment." >&2
    echo "Example: s3://sports-terminal-static/nba_static" >&2
    exit 2
  fi
  if ! command -v aws >/dev/null 2>&1; then
    echo "AWS CLI is required to synchronize the static corpus to S3-compatible object storage." >&2
    echo "On macOS with Homebrew: brew install awscli" >&2
    exit 2
  fi

  AWS_SYNC=(aws s3 sync "$STATIC_DIR/" "${STATIC_S3_URI%/}/" --delete --only-show-errors)
  if [[ -n "$STATIC_S3_ENDPOINT" ]]; then
    AWS_SYNC+=(--endpoint-url "$STATIC_S3_ENDPOINT")
  fi
  echo "Synchronizing browser-safe NBA corpus to object storage..."
  "${AWS_SYNC[@]}"
fi

echo "Building lightweight Flutter shell for GitHub Pages at $BASE_HREF ..."
flutter pub get
flutter build web --release   --base-href "$BASE_HREF"   --dart-define="SPORTS_TERMINAL_NBA_STATIC_BASE=$STATIC_PUBLIC_BASE"

BUILD_DIR="$ROOT/build/web"
if [[ ! -s "$BUILD_DIR/index.html" ]]; then
  echo "Flutter web build did not produce build/web/index.html" >&2
  exit 1
fi

# Flutter copies web/ verbatim. The generated NBA corpus belongs in object
# storage, so explicitly remove that copy from the Pages artifact.
rm -rf "$BUILD_DIR/data/nba_static"

oversized="$(find "$BUILD_DIR" -type f -size +95M -print -quit)"
if [[ -n "$oversized" ]]; then
  echo "Pages shell contains a file larger than 95 MiB: $oversized" >&2
  exit 1
fi

site_kib="$(du -sk "$BUILD_DIR" | awk '{print $1}')"
if (( site_kib > 950000 )); then
  echo "Pages shell is unexpectedly large: ${site_kib} KiB" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo
  echo "Dry run complete."
  echo "Static corpus: ${corpus_kib} KiB (object storage; not uploaded in dry-run)"
  echo "GitHub Pages shell: ${site_kib} KiB"
  echo "Production static base: $STATIC_PUBLIC_BASE"
  echo "Would publish only to /$PUBLIC_SUBDIR/ in $TARGET_REPO_URL"
  echo "Local localhost behavior remains unchanged."
  exit 0
fi

# Verify that the public origin is reachable before publishing a frontend that
# depends on it. The bucket/CDN must also allow browser GET requests from the
# GitHub Pages origin through its CORS policy.
echo "Verifying public static corpus..."
if ! curl --fail --silent --show-error --location   "$STATIC_PUBLIC_BASE/manifest.json" >/dev/null; then
  echo "Static corpus is not publicly reachable at $STATIC_PUBLIC_BASE/manifest.json" >&2
  echo "Enable public access/custom domain and CORS on the object-storage bucket, then retry." >&2
  exit 1
fi

PUBLISH_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sports-terminal-pages.XXXXXX")"
trap 'rm -rf "$PUBLISH_ROOT"' EXIT

echo "Cloning Pages repository..."
git clone --depth 1 --branch "$TARGET_BRANCH" "$TARGET_REPO_URL" "$PUBLISH_ROOT/site" >/dev/null
PUBLISH_DIR="$PUBLISH_ROOT/site/$PUBLIC_SUBDIR"
mkdir -p "$PUBLISH_DIR"

# Synchronize only Sports Terminal's project-site directory. The personal-site
# root remains untouched.
rsync -a --delete "$BUILD_DIR/" "$PUBLISH_DIR/"
cp "$ROOT/LICENSE" "$PUBLISH_DIR/LICENSE.txt"

SOURCE_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
cat > "$PUBLISH_DIR/deployment.json" <<EOF
{
  "source_repository": "kshmsh1/sports-terminal",
  "source_commit": "$SOURCE_COMMIT",
  "base_href": "$BASE_HREF",
  "static_data_base": "$STATIC_PUBLIC_BASE"
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
echo "Static data: $STATIC_PUBLIC_BASE/"
echo "Local development is unchanged; continue using:"
echo "  bash scripts/open_terminal.sh"
