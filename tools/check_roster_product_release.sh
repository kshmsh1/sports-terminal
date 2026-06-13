#!/usr/bin/env bash
set -euo pipefail

echo "Roster product release gate"

echo "1/4 Analyze application sources"
flutter analyze --no-fatal-infos --no-fatal-warnings

echo "2/4 Run pre-data and roster product tests"
bash tools/run_pre_data_tests.sh

echo "3/4 Write current roster completeness report"
dart run tools/write_roster_completeness_report.dart

echo "4/4 Compile Flutter web application"
flutter build web --debug --no-pub

echo "Roster product release gate passed."
