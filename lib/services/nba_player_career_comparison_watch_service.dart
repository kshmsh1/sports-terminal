import 'nba_entity_watchlist_store.dart';
import 'nba_player_career_comparison_engine.dart';

class NbaPlayerCareerComparisonWatchService {
  const NbaPlayerCareerComparisonWatchService({
    NbaEntityWatchlistStore watchlist = const NbaEntityWatchlistStore(),
  }) : _watchlist = watchlist;

  final NbaEntityWatchlistStore _watchlist;

  NbaEntityWatchItem buildItem({
    required NbaPlayerCareerComparisonSnapshot comparison,
    String league = 'NBA',
    String seasonType = 'regular',
    bool sharedOnly = false,
  }) {
    final key = [
      comparison.left.playerKey,
      comparison.right.playerKey,
      comparison.alignment.name,
      sharedOnly ? 'shared' : 'all',
    ].join('__');
    return NbaEntityWatchItem(
      kind: 'player-career-comparison',
      key: key,
      label:
          '${comparison.left.playerName} vs ${comparison.right.playerName} · Career',
      subtitle:
          '${comparison.alignment.label} · ${sharedOnly ? 'SHARED SEASONS' : 'ALL EXPOSED SEASONS'}',
      league: league.trim().isEmpty ? 'NBA' : league.trim().toUpperCase(),
      seasonType: seasonType.trim().isEmpty ? 'regular' : seasonType.trim(),
    );
  }

  Future<List<NbaEntityWatchItem>> toggle({
    required NbaPlayerCareerComparisonSnapshot comparison,
    String league = 'NBA',
    String seasonType = 'regular',
    bool sharedOnly = false,
  }) =>
      _watchlist.toggle(
        buildItem(
          comparison: comparison,
          league: league,
          seasonType: seasonType,
          sharedOnly: sharedOnly,
        ),
      );

  Future<bool> isWatched({
    required NbaPlayerCareerComparisonSnapshot comparison,
    String league = 'NBA',
    String seasonType = 'regular',
    bool sharedOnly = false,
  }) =>
      _watchlist.contains(
        buildItem(
          comparison: comparison,
          league: league,
          seasonType: seasonType,
          sharedOnly: sharedOnly,
        ).signature,
      );
}
