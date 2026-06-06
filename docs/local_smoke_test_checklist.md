# Local Smoke Test Checklist

Run this checklist after the latest pre-data pushes.

## Command

```bash
cd ~/sports_terminal
git pull
flutter run -d chrome
```

## Test commands

```bash
bash tools/run_pre_data_tests.sh
```

## Safe import smoke test

```bash
bash tools/smoke_test_common_all_players_import.sh 2026-06-05
```

This writes to `raw/smoke_test/` only.

## Import and validation commands

```bash
bash tools/run_common_all_players_import.sh raw/common_all_players.json 2026-06-05
dart run tools/validate_player_identity.dart
dart run tools/validate_player_season_stats.dart
dart run tools/validate_team_season_stats.dart
dart run tools/validate_standings.dart
dart run tools/validate_playoff_series.dart
dart run tools/validate_awards.dart
dart run tools/validate_games.dart
dart run tools/validate_rosters.dart
dart run tools/validate_draft.dart
dart run tools/validate_transactions.dart
bash tools/restore_player_identity_placeholders.sh
```

## RoutePayload loop

1. Open the app.
2. Publish a Team payload.
3. Retarget it to Workspace, Compare, Reports, Saved View, Export, Alerts, Dashboard, Search, Action Center, and Source Audit.
4. Repeat with a Season payload.
5. After a real player identity import, publish a Player result from Search.

## Player identity and early wave checks

Open Player Identity Import and search for `cutover`, `early wave`, `source decision`, `validation`, `player stat validator`, `team stat validator`, `standings`, `playoffs`, `awards`, `games`, `rosters`, `draft`, and `transactions`.

## Expected state before real data

Teams and Seasons should be connected. Player profiles, player aliases, player stats, team stats, standings, playoffs, awards, games, rosters, draft, and transactions should remain source-pending until real validated imports exist.
