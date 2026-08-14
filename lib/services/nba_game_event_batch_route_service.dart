import '../models/route_payload.dart';
import 'nba_game_event_query_engine.dart';
import 'nba_game_intelligence_engine.dart';
import 'nba_game_play_by_play_engine.dart';
import 'sports_object_router.dart';

/// Packages a filtered canonical event result as one shared terminal payload.
///
/// The service deliberately accepts the already-resolved query result so the
/// routed rows are exactly the analyst-visible selection. It never re-runs or
/// widens the query and never infers possessions, roles, or scoring outcomes.
class NbaGameEventBatchRouteService {
  const NbaGameEventBatchRouteService();

  RoutePayload package({
    required NbaGameIntelligenceSnapshot game,
    required NbaGameEventQueryResult result,
    String targetRoute = 'Open',
  }) {
    final blockers = <String>[];
    final normalizedGame = _normalize(game.gameId);
    final mismatched = <String>[];
    for (final event in result.events) {
      final eventGame = _normalize(event.gameId);
      if (eventGame.isNotEmpty && eventGame != normalizedGame) {
        mismatched.add(event.gameId);
      }
    }
    if (mismatched.isNotEmpty) blockers.add('event-game-mismatch');

    final missingCoreRows = result.events.where((event) {
      return event.sequence == null ||
          event.period == null ||
          event.clock.trim().isEmpty;
    }).length;
    final readinessState = blockers.isNotEmpty
        ? 'Blocked'
        : result.events.isEmpty || missingCoreRows > 0
            ? 'Partial'
            : 'Ready';
    final matchup =
        '${game.awayTeam.abbreviation} @ ${game.homeTeam.abbreviation}';
    final sourceSnapshot = game.provenance.assetPath.trim().isNotEmpty
        ? game.provenance.assetPath
        : game.provenance.datasetStatus;
    final router = const SportsObjectRouter();

    return router.packageRows(
      datasetId: 'nba_game_events_${game.gameId}',
      packageId: '${game.gameId}:event-selection',
      displayLabel:
          '$matchup · ${result.matchedEvents} filtered event${result.matchedEvents == 1 ? '' : 's'}',
      sourceObjectType: 'NBA Game Event Selection',
      targetRoute: targetRoute,
      sourceSnapshot: sourceSnapshot,
      readinessState: readinessState,
      filterSummary: result.filterSummary,
      rowKey: 'event_key',
      blockers: blockers,
      maxRows: 250,
      preferredColumns: const [
        'event_key',
        'game_id',
        'sequence',
        'period',
        'period_label',
        'clock',
        'elapsed_game_seconds',
        'category',
        'result',
        'action_type',
        'sub_type',
        'team_id',
        'team',
        'player_id',
        'player',
        'secondary_player_id',
        'secondary_player',
        'tertiary_player_id',
        'tertiary_player',
        'substitution_out_id',
        'substitution_out',
        'substitution_in_id',
        'substitution_in',
        'home_score',
        'away_score',
        'home_margin',
        'description',
        'source_id',
      ],
      rows: [
        for (var index = 0; index < result.events.length; index++)
          _eventRow(game.gameId, result.events[index], index),
      ],
      metadata: {
        'gameId': game.gameId,
        'selectionType': 'filtered-canonical-game-events',
        'totalGameEvents': result.totalEvents,
        'matchedEvents': result.matchedEvents,
        'returnedEvents': result.returnedEvents,
        'queryTruncated': result.truncated,
        'missingCoreRows': missingCoreRows,
        'historicalContext': game.provenance.historicalContext,
        'datasetStatus': game.provenance.datasetStatus,
        'validationStatus': game.provenance.validationStatus,
        'releaseId': game.provenance.releaseId,
        'releaseVersion': game.provenance.releaseVersion,
        'releaseStatus': game.provenance.releaseStatus,
        'sourceIds': game.provenance.sourceIds,
        'asOfValues': game.provenance.asOfValues,
        'usedFallbackDataset': game.provenance.usedFallbackDataset,
      },
    );
  }

  Map<String, dynamic> _eventRow(
    String gameId,
    NbaGamePlayByPlayEvent event,
    int index,
  ) {
    final sequenceLabel = event.sequence?.toString() ?? 'unsequenced-${index + 1}';
    return {
      'event_key': '$gameId:$sequenceLabel',
      'game_id': event.gameId.isEmpty ? gameId : event.gameId,
      'sequence': event.sequence,
      'period': event.period,
      'period_label': event.periodLabel,
      'clock': event.clock,
      'elapsed_game_seconds': event.elapsedGameSeconds,
      'category': event.category.name,
      'result': event.result.name,
      'action_type': event.actionType,
      'sub_type': event.subType,
      'team_id': event.team.id,
      'team': event.team.name,
      'player_id': event.player.id,
      'player': event.player.label,
      'secondary_player_id': event.secondaryPlayer.id,
      'secondary_player': event.secondaryPlayer.label,
      'tertiary_player_id': event.tertiaryPlayer.id,
      'tertiary_player': event.tertiaryPlayer.label,
      'substitution_out_id': event.substitutionOut.id,
      'substitution_out': event.substitutionOut.label,
      'substitution_in_id': event.substitutionIn.id,
      'substitution_in': event.substitutionIn.label,
      'home_score': event.homeScore,
      'away_score': event.awayScore,
      'home_margin': event.margin,
      'description': event.description,
      'source_id': event.sourceId,
    };
  }
}

String _normalize(String value) => value.trim().toUpperCase();
