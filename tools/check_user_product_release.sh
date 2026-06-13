#!/usr/bin/env bash
set -euo pipefail

echo "User product release gate"

echo "1/7 Analyze Flutter sources"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "2/7 Run application tests"
bash tools/run_pre_data_tests.sh

echo "3/7 Compile Python ingestion and historical catalog utilities"
python3 -m py_compile \
  tools/sports_reference/client.py \
  tools/sports_reference/basketball_reference.py \
  tools/sports_reference/table_extractor.py \
  tools/sports_reference/linked_table.py \
  tools/sports_reference/url_scope.py \
  tools/sports_reference/table_parser.py \
  tools/sports_reference/catalog_schema.py \
  tools/sports_reference/snapshot_archive.py \
  tools/sports_reference/page_store.py \
  tools/sports_reference/crawler.py \
  tools/import_basketball_reference.py \
  tools/import_basketball_reference_page.py \
  tools/crawl_basketball_reference.py \
  tools/build_source_index.py \
  tools/normalize_team_table.py \
  tools/prepare_player_stats.py \
  tools/probe_sportsreference.py \
  tools/test_sports_reference_parsers.py \
  tools/test_sports_reference_catalog.py \
  tools/test_sports_reference_scope.py

echo "4/7 Run offline ingestion tests when the virtual environment exists"
if [[ -x .venv/bin/python ]]; then
  .venv/bin/python tools/test_sports_reference_parsers.py
  .venv/bin/python tools/test_sports_reference_catalog.py
  .venv/bin/python tools/test_sports_reference_scope.py
fi

echo "5/7 Smoke-test the no-network catalog planner"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT
python3 tools/crawl_basketball_reference.py \
  --database "$temporary_dir/catalog.sqlite" \
  --snapshot-root "$temporary_dir/snapshots" \
  plan --from-season 2025 --to-season 2025 --profile historical >/dev/null
bash tools/prepare_historical_nba_catalog.sh plan 2025 2025 historical >/dev/null
python3 tools/crawl_basketball_reference.py \
  --database "$temporary_dir/catalog.sqlite" \
  --snapshot-root "$temporary_dir/snapshots" \
  status >/dev/null

echo "6/7 Compile Flutter web application"
flutter build web --debug --no-pub

echo "7/7 Confirm documentation"
test -f docs/user_mode_and_workspaces.md
test -f docs/basketball_reference_ingestion.md
test -f docs/historical_basketball_reference_crawler.md

echo "User product release gate passed."
