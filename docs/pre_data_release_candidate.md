# Pre-Data Release Candidate

This document defines the finish line for the NBA pre-data build phase.

## Release candidate requirement

The pre-data phase is considered ready when these commands pass locally:

```bash
flutter run -d chrome
bash tools/run_pre_data_gate.sh
```

The same gate is also run by GitHub Actions through `.github/workflows/pre_data_gate.yml`.

## What is complete

The terminal has a working route-payload spine, source-pending asset policy, import tooling, validators, command-line gates, and registry-visible cutover screens for the NBA-first data spine.

Covered datasets:

1. Teams.
2. Seasons.
3. Player Identity.
4. Player Season Stats.
5. Team Season Stats.
6. Standings.
7. Playoff Series.
8. Awards and MVP Voting.
9. Games.
10. Rosters.
11. Draft Picks.
12. Transactions.

## What remains before real data

1. Run the local browser smoke test.
2. Run the full pre-data gate.
3. Save the real CommonAllPlayers export to `raw/common_all_players.json`.
4. Normalize player identity.
5. Validate player identity.
6. Route imported players through Search and every major consumer.

## Rule

Do not add fake rows. Source-pending assets should remain empty until real source-backed rows pass validation.

## Next phase

After player identity passes, move one dataset at a time through the same pattern: source decision, field map, normalizer, validator, route proof, then connected asset update.
