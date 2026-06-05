# Local Smoke Test Checklist

Run this checklist after the latest pre-data pushes.

## Command

```bash
cd ~/sports_terminal
git pull
flutter run -d chrome
```

## RoutePayload loop

1. Open the app.
2. Go to Core MVP Gaps or the first-release workflow area.
3. Publish a Team payload.
4. Retarget it to Workspace, Compare, Reports, Saved View, Export, Alerts, Dashboard, Search, Action Center, and Source Audit.
5. Confirm each surface shows the active payload without crashing.
6. Repeat with a Season payload.
7. Repeat with an operations payload if available from the route engine.

## Search producer

1. Open Search.
2. Use the Search RoutePayload Producer panel.
3. Publish a Team result.
4. Retarget the active payload from another consumer.
5. Publish a Season result.
6. Confirm history and active state update.

## Player identity pre-import checks

1. Open Player Identity Import.
2. Search for `cutover`.
3. Search for `source decision`.
4. Search for `validation`.
5. Search for `alias`.
6. Confirm the import screen shows cutover, source, contract, validation, schema, acceptance, and wave items.

## Expected state before real data

1. Teams should be connected.
2. Seasons should be connected.
3. Player profiles should be empty.
4. Player stats should be empty.
5. Team stats should be empty.
6. Games, rosters, awards, draft, transactions, standings, and playoffs should be empty.
7. Empty means source-pending, not broken.

## Known manual follow-up

The `player_aliases.json` asset exists, and `NbaAssetRepository.loadPlayerAliases()` exists, but `pubspec.yaml` still needs the asset entry added locally if the connector blocks that write. Add this line under the other player asset entries if needed:

```yaml
    - assets/data/nba/players/player_aliases.json
```
