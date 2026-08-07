# NBA Historical Intelligence

## Purpose

The canonical historical warehouse is not only a season selector. Professional research also requires league-wide records, cross-era comparisons, franchise lineage and game-level investigation. Historical Intelligence exposes those workflows as a connected terminal surface while preserving the shared NBA research context introduced by NBA Universe.

Historical data is always labeled as canonical history. It is never relabeled as a certified/current release, and fields are not fabricated for eras or sources where they do not exist.

## All-Time Records

The records surface queries the canonical `/v2/nba/history/all-time` contract.

Analysts can rank historical players by:

- league: NBA, ABA or BAA
- metric
- totals, per-game, per-36, per-48, per-75 or per-100 basis
- full career, peak season or best-N-season mode
- regular season, playoffs or combined segment
- minimum seasons and minimum career games

Each row exposes career span, eligible seasons, career games, the selected ranking metric and the player's peak season/team. The peak season/player can become shared terminal context or can be activated and handed directly into Active Context Stats.

Best-N and era-normalized outputs are derived transparently from canonical rows; they are not stored as invented source facts.

## Cross-Era Compare

The compare surface uses canonical player discovery plus `/v2/nba/history/compare`.

Analysts can build a 2–6 player comparison set and select a common metric, rate basis, league and season segment. Each player card reports:

- canonical identity
- career metric value on the selected basis
- career aggregate games and core production
- peak season/team
- best era-relative z-score where eligible

A player's peak can be activated as shared context and opened in the same professional Stats Workstation used by current-release and historical seed-compatible data.

## Franchise Lineage

The franchise surface uses canonical franchise dimensions rather than treating every historical team name as unrelated.

It exposes:

- canonical franchise identity
- current abbreviation when available
- source count
- distinct team identities
- historical abbreviations and league eras
- first/last season and season count
- every canonical team-season row linked to the franchise

Each franchise season can become shared season/team context and can hand off to Stats or Analytics. This preserves relocations and renames without flattening distinct team identities.

## Games and Play-by-Play

The game surface queries canonical games by league, season and segment. Opening a game loads:

- canonical game identity and scores
- available team-game facts
- available player-game box-score rows
- the first 250 linked canonical play-by-play events from the zero-copy PBP view

Game-level coverage varies materially by era and source. Missing player-game or PBP data is displayed as missing coverage rather than synthesized.

A game can become the active shared NBA game context for downstream workflows.

## Product integration

Historical Intelligence is a first-class analyst/organization shell launcher. It is mutually reachable from NBA Research and NBA Universe, and it can hand contexts into Stats and Analytics.

The three research surfaces therefore have distinct roles while sharing one state contract:

- **NBA Universe:** entity discovery and season/entity navigation.
- **NBA Historical Intelligence:** records, comparisons, franchise lineage and games/PBP.
- **NBA Research Command Center:** professional Stats, Analytics, workspaces and methodology/coverage.

All shared context writes go through `NbaResearchContextStore`, which in turn writes historical scope through `NbaTerminalSeedRepository.selectHistorical`.

## Validation

The build adds responsive smoke coverage for Historical Intelligence at desktop and narrow widths. Existing Historical Research Quality continues to validate the underlying all-time, compare, franchise, game and play-by-play contracts, while Flutter Quality gates analyzer, the complete test suite and release web build.
