# Player Identity Route Proof Checklist

Run this after `tools/import_player_identity_candidate.sh` passes.

## Setup

```bash
flutter run -d chrome
```

## Search proof

1. Open Search.
2. Confirm the Search RoutePayload Producer shows non-zero player count.
3. Publish at least one imported Player payload.
4. Confirm the active payload label uses the imported player display name.

## Consumer proof

Retarget the active Player payload to:

1. Workspace.
2. Compare.
3. Reports.
4. Export.
5. Alerts.
6. Dashboard.
7. Action Center.
8. Source Audit.

Each consumer should show the active Player payload without crashing.

## Source proof

Confirm the Player payload shows source-backed context:

1. `sourceObjectType` is `Player`.
2. `sourceObjectId` is the canonical player ID.
3. `sourceSnapshot` references `player_profiles.json`.
4. `readinessState` says player identity is connected and player stats are pending.

## Unlock condition

Player season stats remain locked until:

1. Candidate command passes.
2. Import report is reviewed.
3. Route proof is complete.
4. No browser runtime errors occur during the proof.
