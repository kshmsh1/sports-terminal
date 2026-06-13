#!/usr/bin/env bash
set -euo pipefail

echo "User product release gate"

echo "1/6 Analyze Flutter sources"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "2/6 Run application tests"
bash tools/run_pre_data_tests.sh

echo "3/6 Compile Python ingestion utilities"
python3 -m py_compile tools/sports_reference/client.py tools/sports_reference/basketball_reference.py tools/sports_reference/table_extractor.py tools/sports_reference/linked_table.py tools/import_basketball_reference.py tools/import_basketball_reference_page.py tools/build_source_index.py tools/normalize_team_table.py tools/prepare_player_stats.py tools/probe_sportsreference.py tools/test_sports_reference_parsers.py

echo "4/6 Run parser tests when the virtual environment exists"
if [[ -x .venv/bin/python ]]; then
  .venv/bin/python tools/test_sports_reference_parsers.py
fi

echo "5/6 Compile Flutter web application"
flutter build web --debug --no-pub

echo "6/6 Confirm documentation"
test -f docs/user_mode_and_workspaces.md
test -f docs/basketball_reference_ingestion.md

echo "User product release gate passed."
