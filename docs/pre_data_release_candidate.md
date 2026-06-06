# Pre-Data Release Candidate

This document defines the finish line for the NBA pre-data build phase.

## Release candidate requirement

Before importing source data:

```bash
flutter run -d chrome
bash tools/check_pre_import_state.sh
```

After importing source data:

```bash
flutter run -d chrome
bash tools/check_post_import_candidate.sh
```

GitHub Actions runs the pre-import check through `.github/workflows/pre_data_gate.yml`.

## What is complete

The terminal has a working route-payload spine, source-pending asset policy, import tooling, validators, command-line gates, and registry-visible cutover screens for the NBA-first data spine.

Covered datasets: Teams, Seasons, Player Identity, Player Season Stats, Team Season Stats, Standings, Playoff Series, Awards and MVP Voting, Games, Rosters, Draft Picks, and Transactions.

## What remains before source import

Run the local browser smoke test, run the pre-import check, save the CommonAllPlayers export to `raw/common_all_players.json`, normalize player identity, validate player identity, run the post-import check, and route imported players through Search and every major consumer.

## Rule

Do not add fake rows. Source-pending assets should remain empty until source-backed rows pass validation.

## Next phase

After player identity passes, move one dataset at a time through the same pattern: source decision, field map, normalizer, validator, route proof, then connected asset update.
