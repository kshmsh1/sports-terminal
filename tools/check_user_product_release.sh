#!/usr/bin/env bash
set -euo pipefail

echo "User product release gate"

echo "1/5 Analyze Flutter sources"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "2/5 Run application tests"
bash tools/run_pre_data_tests.sh

echo "3/5 Compile Python ingestion utilities"
python3 -m py_compile \
  tools/sports_reference/client.py \
  tools/sports_reference/basketball_reference.py \
  tools/import_basketball_reference.py \
  tools/probe_sportsreference.py

echo "4/5 Compile Flutter web application"
flutter build web --debug --no-pub

echo "5/5 Confirm internal-output policy documentation"
test -f docs/user_mode_and_workspaces.md
test -f docs/basketball_reference_ingestion.md

echo "User product release gate passed."
