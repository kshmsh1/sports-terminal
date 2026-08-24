#!/usr/bin/env bash
set -euo pipefail

python3 tools/nba_com_stats_contract_test.py
python3 tools/nba_com_static_enrichment_test.py
dart run tools/validate_source_pending_assets.dart
bash tools/run_pre_data_tests.sh
bash tools/run_all_asset_validators.sh

echo "Pre-import state check passed."
