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

## Optional source inspection

Before importing, you can inspect the raw export without changing app assets:

```bash
dart run tools/inspect_common_all_players_export.dart raw/common_all_players.json
```

## Candidate command

Run:

```bash
bash tools/import_player_identity_candidate.sh raw/common_all_players.json 2026-06-05
```

This command:

1. Inspects the raw CommonAllPlayers export.
2. Normalizes player profiles and aliases.
3. Runs player identity validation.
4. Requires non-empty connected player rows.
5. Writes `raw/player_identity_import_report.json`.
6. Runs the post-import candidate check.

## Review output

Review:

```text
raw/player_identity_held_rows.json
raw/player_identity_import_report.json
```

Held rows should be reviewed and should not be force-joined.

## Browser route proof

After the command passes, launch the app and follow `docs/player_identity_route_proof_checklist.md`.

At minimum, publish Player payloads from Search into Workspace, Compare, Reports, Export, Alerts, Dashboard, Action Center, and Source Audit.

## Unlock condition

Do not move to player season stats until the candidate command, import report review, and browser route proof all pass.
