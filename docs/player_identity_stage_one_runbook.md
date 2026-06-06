# Player Identity Stage 1 Runbook

This is the first real NBA data unlock.

## Before import

Run:

```bash
flutter run -d chrome
bash tools/check_pre_import_state.sh
```

The pre-import check should pass while player identity is still source-pending.

## Source export

Save the real CommonAllPlayers export here:

```text
raw/common_all_players.json
```

Do not commit raw source exports.

## Candidate command

Run:

```bash
bash tools/import_player_identity_candidate.sh raw/common_all_players.json 2026-06-05
```

This command:

1. Normalizes player profiles and aliases.
2. Runs player identity validation.
3. Requires non-empty connected player rows.
4. Runs the post-import candidate check.

## Browser route proof

After the command passes, launch the app and publish Player payloads from Search into Workspace, Compare, Reports, Export, Alerts, Dashboard, Action Center, and Source Audit.

## Unlock condition

Do not move to player season stats until the candidate command and browser route proof both pass.
