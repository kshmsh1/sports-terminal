import '../models/route_payload.dart';
import 'nba_game_intelligence_engine.dart';
import 'nba_game_play_by_play_engine.dart';

class SportsObjectRouter {
  const SportsObjectRouter();

  RoutePayload packageGame({
    required NbaGameIntelligenceSnapshot game,
    String targetRoute = 'Open',
  }) {
    final blockingIssues = [
      for (final issue in game.integrityIssues)
        if (issue.severity == NbaGameIntegritySeverity.blocking) issue.code,
    ];
    final warnings = [
      for (final issue in game.integrityIssues)
        if (issue.severity == NbaGameIntegritySeverity.warning) issue.code,
    ];
    final missing = game.coverage.missingSections;
    final readinessState = blockingIssues.isNotEmpty
        ? 'Blocked'
        : missing.isEmpty
            ? 'Ready'
            : 'Partial';
    final matchup = '${game.awayTeam.abbreviation} @ ${game.homeTeam.abbreviation}';
    final sourceSnapshot = game.provenance.assetPath.trim().isNotEmpty
        ? game.provenance.assetPath
        : game.provenance.datasetStatus;

    return packageRows(
      datasetId: 'nba_game_${game.gameId}',
      packageId: game.gameId,
      displayLabel: game.gameDate.isEmpty ? matchup : '$matchup · ${game.gameDate}',
      sourceObjectType: 'NBA Game',
      targetRoute: targetRoute,
      sourceSnapshot: sourceSnapshot,
      readinessState: readinessState,
      filterSummary: 'Canonical game ${game.gameId}',
      rowKey: 'game_id',
      blockers: blockingIssues,
      preferredColumns: const [
        'game_id',
        'season_id',
        'season_type',
        'game_date',
        'status',
        'away_team_id',
        'away_team',
        'away_score',
        'home_team_id',
        'home_team',
        'home_score',
        'winner_team_id',
        'arena',
        'city',
        'player_lines',
        'periods',
      ],
      rows: [
        {
          'game_id': game.gameId,
          'season_id': game.seasonId,
          'season_type': game.seasonType,
          'game_date': game.gameDate,
          'status': game.status,
          'away_team_id': game.awayTeam.id,
          'away_team': game.awayTeam.name,
          'away_score': game.awayScore,
          'home_team_id': game.homeTeam.id,
          'home_team': game.homeTeam.name,
          'home_score': game.homeScore,
          'winner_team_id': game.winnerTeamId,
          'arena': game.arena,
          'city': game.city,
          'player_lines': game.playerLines.length,
          'periods': game.periods.length,
        },
      ],
      metadata: {
        'gameId': game.gameId,
        'requestedGameId': game.requestedGameId,
        'historicalContext': game.provenance.historicalContext,
        'datasetStatus': game.provenance.datasetStatus,
        'validationStatus': game.provenance.validationStatus,
        'releaseId': game.provenance.releaseId,
        'releaseVersion': game.provenance.releaseVersion,
        'releaseStatus': game.provenance.releaseStatus,
        'sourceIds': game.provenance.sourceIds,
        'asOfValues': game.provenance.asOfValues,
        'usedFallbackDataset': game.provenance.usedFallbackDataset,
        'usedCompatibilityJoin': game.coverage.usedCompatibilityJoin,
        'missingSections': missing,
        'integrityWarnings': warnings,
        'integrityBlockers': blockingIssues,
      },
    );
  }

  /// Packages one normalized play-by-play event into the shared Sports Terminal
  /// routing contract. This preserves the event's exact evidence and the parent
  /// game's provenance; it never expands an event into inferred possession,
  /// lineup, or win-probability data.
  RoutePayload packageGameEvent({
    required NbaGameIntelligenceSnapshot game,
    required NbaGamePlayByPlayEvent event,
    String targetRoute = 'Open',
  }) {
    final blockers = <String>[];
    if (_normalizedIdentity(event.gameId) != _normalizedIdentity(game.gameId)) {
      blockers.add('event-game-mismatch');
    }
    final missingCore = <String>[
      if (event.sequence == null) 'sequence',
      if (event.period == null) 'period',
      if (event.clock.trim().isEmpty) 'clock',
    ];
    final readinessState = blockers.isNotEmpty
        ? 'Blocked'
        : missingCore.isEmpty
            ? 'Ready'
            : 'Partial';
    final sequenceLabel = event.sequence?.toString() ?? 'unsequenced';
    final eventKey = '${game.gameId}:$sequenceLabel';
    final matchup = '${game.awayTeam.abbreviation} @ ${game.homeTeam.abbreviation}';
    final eventTime = '${event.periodLabel} ${event.clock}'.trim();
    final sourceSnapshot = game.provenance.assetPath.trim().isNotEmpty
        ? game.provenance.assetPath
        : game.provenance.datasetStatus;

    return packageRows(
      datasetId: 'nba_game_event_${game.gameId}_$sequenceLabel',
      packageId: eventKey,
      displayLabel: '$matchup · $eventTime · ${event.categoryLabel}',
      sourceObjectType: 'NBA Game Event',
      targetRoute: targetRoute,
      sourceSnapshot: sourceSnapshot,
      readinessState: readinessState,
      filterSummary: 'Canonical event $eventKey',
      rowKey: 'event_key',
      blockers: blockers,
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
        {
          'event_key': eventKey,
          'game_id': game.gameId,
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
        },
      ],
      metadata: {
        'gameId': game.gameId,
        'eventSequence': event.sequence,
        'eventCategory': event.category.name,
        'eventResult': event.result.name,
        'eventHasScore': event.hasScore,
        'eventHasExplicitSubstitution': event.hasExplicitSubstitution,
        'missingCoreFields': missingCore,
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

  RoutePayload packageRows({
    required String datasetId,
    required String displayLabel,
    required String sourceObjectType,
    required List<Map<String, dynamic>> rows,
    required String targetRoute,
    String? packageId,
    String sourceSnapshot = 'Local Sports Terminal asset',
    String readinessState = 'Ready',
    String filterSummary = 'No filters',
    String rowKey = '',
    List<String> blockers = const [],
    Map<String, dynamic> metadata = const {},
    List<String> preferredColumns = const [],
    int maxRows = 250,
  }) {
    final normalizedRows = [
      for (final row in rows.take(maxRows)) _normalizeRow(row),
    ];
    final keys = _orderedKeys(normalizedRows, preferredColumns);
    final columns = [
      for (final key in keys)
        RoutePayloadColumn(
          key: key,
          label: _labelFor(key),
          dataType: _dataTypeFor(key, normalizedRows),
          unit: _unitFor(key),
        ),
    ];
    final selectedRows = <String>[];
    for (var index = 0; index < normalizedRows.length; index++) {
      final row = normalizedRows[index];
      final candidate = rowKey.isEmpty ? null : row[rowKey];
      selectedRows.add(candidate?.toString() ?? '${index + 1}');
    }

    return RoutePayload(
      sourceObjectType: sourceObjectType,
      sourceObjectId: packageId ?? datasetId,
      displayLabel: displayLabel,
      selectedColumns: keys,
      selectedRows: selectedRows,
      filterSummary: filterSummary,
      sourceSnapshot: sourceSnapshot,
      readinessState: readinessState,
      blockers: blockers,
      targetRoute: targetRoute,
      availableActions: immediateRouteTargets,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      columns: columns,
      rows: normalizedRows,
      metadata: {
        'datasetId': datasetId,
        'rowKey': rowKey,
        'untruncatedRowCount': rows.length,
        'packagedRowCount': normalizedRows.length,
        'truncated': rows.length > normalizedRows.length,
        ...metadata,
      },
    );
  }

  String toTsv(RoutePayload payload) {
    final keys = payload.columns.isNotEmpty
        ? [for (final column in payload.columns) column.key]
        : payload.selectedColumns;
    if (keys.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln(keys.map(_escapeTsv).join('\t'));
    for (final row in payload.rows) {
      buffer.writeln(
        keys.map((key) => _escapeTsv(_displayValue(row[key]))).join('\t'),
      );
    }
    return buffer.toString().trimRight();
  }

  String pythonVariableName(RoutePayload payload) {
    final raw = payload.metadata['datasetId']?.toString() ?? payload.sourceObjectId;
    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) return 'sports_data';
    if (RegExp(r'^\d').hasMatch(normalized)) return 'data_$normalized';
    return normalized;
  }

  String generatedPython(RoutePayload payload) {
    final variable = pythonVariableName(payload);
    final escapedLabel = payload.displayLabel.replaceAll('"', '\\"');
    return '''# Sports Terminal structured package
# Source: $escapedLabel
# Rows: ${payload.rowCount} | Columns: ${payload.columnCount}

import pandas as pd

$variable = st.active_payload_dataframe()

# Inspect and rank the routed data
st.display($variable.head(25))
st.display($variable.describe(include="all"))

# Example export back to the workbook
st.export_to_workspace($variable, sheet="$escapedLabel")
''';
  }

  List<String> _orderedKeys(
    List<Map<String, dynamic>> rows,
    List<String> preferred,
  ) {
    final discovered = <String>{};
    for (final row in rows) {
      discovered.addAll(row.keys);
    }
    final result = <String>[];
    for (final key in preferred) {
      if (discovered.remove(key)) result.add(key);
    }
    final remainder = discovered.toList()..sort();
    result.addAll(remainder);
    return result;
  }

  Map<String, dynamic> _normalizeRow(Map<String, dynamic> row) {
    return {
      for (final entry in row.entries)
        entry.key: _normalizeValue(entry.value),
    };
  }

  dynamic _normalizeValue(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Iterable) return value.map((item) => item.toString()).join(', ');
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }
    return value.toString();
  }

  String _dataTypeFor(String key, List<Map<String, dynamic>> rows) {
    final values = [
      for (final row in rows)
        if (row[key] != null) row[key],
    ];
    if (values.isEmpty) return 'text';
    if (values.every((value) => value is bool)) return 'boolean';
    if (values.every((value) => value is num)) {
      if (values.every((value) => value is int)) return 'integer';
      return 'number';
    }
    if (key.contains('date') || key.endsWith('_at')) return 'date';
    return 'text';
  }

  String _unitFor(String key) {
    final normalized = key.toLowerCase();
    if (normalized.contains('salary') ||
        normalized.contains('cap') ||
        normalized.contains('tax') ||
        normalized.contains('apron') ||
        normalized.contains('cash')) {
      return 'USD';
    }
    if (normalized.endsWith('_pct') ||
        normalized.contains('percentage') ||
        normalized == 'win_pct') {
      return 'ratio';
    }
    if (normalized.contains('minutes')) return 'minutes';
    if (normalized.contains('age')) return 'years';
    return '';
  }

  String _labelFor(String key) {
    final words = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAll('_', ' ')
        .trim()
        .split(RegExp(r'\s+'));
    return words
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _escapeTsv(String value) {
    return value
        .replaceAll('\t', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ');
  }

  String _displayValue(dynamic value) {
    if (value == null) return '';
    if (value is double) {
      return value % 1 == 0 ? value.toStringAsFixed(0) : value.toString();
    }
    return value.toString();
  }
}

String _normalizedIdentity(String value) => value.trim().toUpperCase();
