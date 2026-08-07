#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR="${SPORTS_TERMINAL_HISTORY_VENV:-.historical-venv}"
SOURCE_ROOT="${SPORTS_TERMINAL_HISTORY_RAW:-raw/historical}"
REGISTRY="${SPORTS_TERMINAL_HISTORY_REGISTRY:-assets/data/nba/metadata/historical_source_registry.json}"
OUTPUT="${SPORTS_TERMINAL_HISTORY_DB:-data/warehouse/nba_history.sqlite}"
REPORT="${SPORTS_TERMINAL_HISTORY_REPORT:-data/warehouse/nba_history_import_report.json}"

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python 3 is required. Set PYTHON_BIN to a Python 3 executable." >&2
  exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
python -m pip install --upgrade pip
python -m pip install --upgrade kagglehub

mkdir -p "$SOURCE_ROOT"

python - "$REGISTRY" "$SOURCE_ROOT" <<'PY'
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import kagglehub

registry_path = Path(sys.argv[1])
source_root = Path(sys.argv[2])
registry = json.loads(registry_path.read_text(encoding="utf-8"))

for source in registry.get("sources", []):
    dataset = source.get("dataset")
    source_key = source.get("key")
    if not dataset or not source_key:
        continue
    print(f"\n==> Downloading {source_key} ({dataset})")
    try:
        cache_path = Path(kagglehub.dataset_download(dataset))
    except Exception as error:
        print(
            f"Download failed for {dataset}: {type(error).__name__}: {error}\n"
            "If Kaggle requires authentication on this machine, configure Kaggle credentials "
            "and rerun the command; already-downloaded source packages will remain usable.",
            file=sys.stderr,
        )
        continue
    destination = source_root / source_key
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(cache_path, destination)
    files = sum(1 for path in destination.rglob("*") if path.is_file())
    size = sum(path.stat().st_size for path in destination.rglob("*") if path.is_file())
    print(f"Copied {files:,} files / {size / 1_048_576:.1f} MiB to {destination}")
PY

python tools/import_historical_nba_sources.py \
  --registry "$REGISTRY" \
  --source-root "$SOURCE_ROOT" \
  --output "$OUTPUT" \
  --report "$REPORT" \
  "$@"

python - "$OUTPUT" <<'PY'
from __future__ import annotations

import sqlite3
import sys

path = sys.argv[1]
db = sqlite3.connect(path)
try:
    print("\nHistorical NBA warehouse coverage")
    print("=" * 86)
    rows = db.execute(
        """
        SELECT source_key, domain, grain, table_count, row_count, min_season, max_season
        FROM historical_source_coverage
        ORDER BY source_key, row_count DESC, domain, grain
        """
    ).fetchall()
    for source, domain, grain, tables, count, minimum, maximum in rows:
        coverage = ""
        if minimum is not None or maximum is not None:
            coverage = f" | {minimum or '?'} -> {maximum or '?'}"
        print(f"{source:24} {domain:18} {grain:22} {tables:4} tables {count:12,} rows{coverage}")
finally:
    db.close()
PY
