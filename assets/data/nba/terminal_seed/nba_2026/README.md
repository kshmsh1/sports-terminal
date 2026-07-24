# NBA 2025–26 launch assets

This directory is populated by `tools/run_overnight_launch_build.py --season 2026`.

The launch build will only activate this directory after the warehouse, terminal seed, supplemental exports, and release validation all pass. Until then the Flutter repository falls back to the validated `nba_2025` development seed and surfaces that fallback in the dataset snapshot.
