#!/usr/bin/env bash
set -euo pipefail

dart run tools/validate_source_pending_assets.dart
bash tools/run_pre_data_tests.sh
bash tools/run_all_asset_validators.sh

echo "Pre-import state check passed."
