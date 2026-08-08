# NBA Entity & Season Intelligence

## Purpose

Sports Terminal historical data should behave like a first-class professional information system, not a collection of isolated historical tables. NBA Entity & Season Intelligence adds durable canonical objects and season-level command workflows on top of the shared historical warehouse.

The surface complements NBA Universe, Historical Intelligence and the NBA Research Command Center:

- **NBA Universe** discovers players and teams and activates shared research context.
- **Entity & Season Intelligence** provides persistent canonical dossiers, universal entity search, season command pages and a watchlist.
- **Historical Intelligence** handles all-time records, cross-era comparison, franchise lineage analysis and game/play-by-play investigation.
- **NBA Research Command Center** provides the professional Stats Workstation, Analytics Suite, research workspaces and methodology/coverage tooling.

All historical data remains explicitly canonical history. Missing-era statistics are never fabricated.

## Universal canonical entity search

`GET /v2/nba/history/entities/search` searches five canonical object classes in one request:

- players
- teams
- franchises
- seasons
- games

Search can be restricted by league (NBA, ABA, BAA) and object type.

The production search path uses `bounded-canonical-entity-search-v2`. Season result counts are calculated with independent correlated subqueries rather than joining player-season, team-season and game facts together. This prevents a season search from creating a multiplicative player × team × game intermediate result in the full historical warehouse.

## Player dossier

`GET /v2/nba/history/players/{player_key}/dossier` exposes:

- canonical player identity
- source identity crosswalks and match confidence
- canonical season history
- awards
- All-Star selections
- draft history
- recent available player-game rows
- material canonical conflicts
- field provenance
- source and coverage summary

A season row can become shared terminal context and open directly in the existing Stats Workstation.

## Team dossier

`GET /v2/nba/history/teams/{team_key}/dossier` exposes:

- canonical team identity
- linked franchise identity
- team-season history
- wins, losses, win percentage, rating fields and source metadata when available
- recent games
- long-tenure/high-volume players linked through canonical player-season facts
- material conflicts

Team seasons can activate shared team/season context and open directly in Analytics.

## Franchise dossier

`GET /v2/nba/history/franchises/{franchise_key}/dossier` combines all team identities attached to a canonical franchise and their season history. Relocations and renames therefore remain queryable without flattening historically distinct team identities.

## Season Command

`GET /v2/nba/history/seasons/{season_id}/command` turns a historical season into a terminal command page. It returns:

- canonical season metadata
- league and segment
- team table and records
- player count and game count
- leaders for points, rebounds, assists, steals, blocks, win shares and BPM when available
- awards
- All-Star selections
- draft rows associated with the following draft year
- canonical coverage domains and source counts

The product Season Desk supports NBA, ABA and BAA and regular season, playoffs or combined context. A selected season can be handed directly into Stats or Analytics using the shared NBA research context.

## Persistent entity watchlist

`NbaEntityWatchlistStore` persists up to 100 locally watched canonical objects across sessions. Supported objects are players, teams, franchises, seasons and games. Each item stores enough season/league/segment metadata to restore or activate an appropriate research context.

The watchlist is intentionally a research working set rather than a notification system. It can later become the foundation for organization-backed shared lists when multi-user persistence is introduced.

## Role and navigation integration

Entity & Season Intelligence is first-class in analyst and organization-admin experiences:

- persistent role-shell launcher
- direct role-home research button
- navigation from NBA Research
- navigation from NBA Universe
- navigation from Historical Intelligence
- direct handoffs from Entity Intelligence into Stats, Analytics and Historical Intelligence

This means a historical entity can move through discovery, dossier research, statistical analysis and historical investigation without requiring the user to re-enter its season/entity context.

## Data integrity

The feature reads canonical objects only. Source conflicts are preserved, provenance can be inspected, and unavailable historical fields remain unavailable. Historical context is never relabeled as a certified current release.

## Validation

CI validates:

- historical source ingestion
- canonical historical build
- traded-player leaderboard semantics
- historical seed compatibility
- deep historical research routes
- optimized entity search
- player/team/franchise dossiers
- season command and leader tables
- launch route mounting
- persistent Flutter entity watchlists
- responsive Entity Intelligence mounting
- Flutter analyzer, complete test suite and release web build
