#!/usr/bin/env bash
set -euo pipefail

bash tools/run_pre_data_tests.sh
bash tools/run_all_asset_validators.sh

echo "Full pre-data gate passed."
