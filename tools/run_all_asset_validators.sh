#!/usr/bin/env bash
set -euo pipefail

dart run tools/validate_all_nba_assets.dart

echo "All NBA asset validators passed."
