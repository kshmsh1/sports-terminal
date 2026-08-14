import 'nba_terminal_seed_repository.dart';

/// Canonicalizes raw NBA play-by-play rows for one game without fabricating
/// events, scores, participants, or clock values that are absent upstream.
class NbaGamePlayByPlayEngine {
  const NbaGamePlayByPlayEngine();

  NbaGamePlayByPlayResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
  }) {
    final normalizedGameId = _normalize(gameId);
    if (normalizedGameId.isEmpty) {
      throw ArgumentError.value(gameId, 'gameId', 'A canonical game id is required.');
    }

    final teams = <String, NbaPbpTeamIdentity>{};
    for (final raw in seed.teams) {
      final id = _text(raw, const ['team_id', 'teamId', 'id', 'abbreviation']);
      if (id.isEmpty) continue;
      teams[_normalize(id)] = NbaPbpTeamIdentity(
        id: id,
        name: _text(
          raw,
          const ['team_name', 'teamName', 'full_name', 'name'],
          fallback: id,
        ),
        abbreviation: _text(
          raw,
          const ['abbreviation', 'team_abbreviation', 'tricode', 'team_id'],
          fallback: id,
        ),
      );
    }

    final players = <String, NbaPbpPlayerIdentity>{};
    for (final raw in seed.players) {
      final id = _text(raw, const ['player_id', 'playerId', 'person_id', 'id']);
      if (id.isEmpty) continue;
      players[_normalize(id)] = NbaPbpPlayerIdentity(
        id: id,
        name: _text(
          raw,
          const ['player_name', 'playerName', 'display_name', 'full_name', 'name'],
          fallback: id,
        ),
      );
    }

    final parsed = <_IndexedEvent>[];
    var sourceRowsWithGameId = 0;
    var rowsForOtherGames = 0;
    for (var index = 0; index < seed.playByPlay.length; index += 1) {
      final raw = seed.playByPlay[index];
      final rowGameId = _text(raw, _gameIdKeys);
      if (rowGameId.isNotEmpty) sourceRowsWithGameId += 1;
      if (_normalize(rowGameId) != normalizedGameId) {
        if (rowGameId.isNotEmpty) rowsForOtherGames += 1;
        continue;
      }

      final teamId = _text(
        raw,
        const [
          'team_id',
          'teamId',
          'team_tricode',
          'teamTricode',
          'possession_team_id',
        ],
      );
      final playerId = _text(
        raw,
        const [
          'player_id',
          'playerId',
          'person_id',
          'personId',
          'player1_id',
          'player1Id',
        ],
      );
      final period = _integer(
        raw,
        const ['period', 'period_number', 'periodNumber', 'quarter', 'qtr'],
      );
      final clock = _text(
        raw,
        const ['clock', 'game_clock', 'gameClock', 'clock_time', 'clockTime', 'pctimestring'],
      );
      final clockRemaining = _clockSecondsRemaining(clock);
      final sequence = _integer(
        raw,
        const [
          'action_number',
          'actionNumber',
          'event_num',
          'eventNum',
          'event_number',
          'sequence',
          'order',
        ],
      );
      final homeScore = _integer(
        raw,
        const [
          'score_home',
          'scoreHome',
          'home_score',
          'homeScore',
          'pts_home',
        ],
      );
      final awayScore = _integer(
        raw,
        const [
          'score_away',
          'scoreAway',
          'away_score',
          'awayScore',
          'visitor_score',
          'pts_away',
        ],
      );
      final rawPlayerName = _text(
        raw,
        const [
          'player_name',
          'playerName',
          'person_name',
          'personName',
          'player1_name',
          'player1Name',
        ],
      );
      final player = players[_normalize(playerId)] ??
          NbaPbpPlayerIdentity(id: playerId, name: rawPlayerName);
      final team = teams[_normalize(teamId)] ?? NbaPbpTeamIdentity.fromId(teamId);
      final actionType = _text(
        raw,
        const [
          'action_type',
          'actionType',
          'event_type',
          'eventType',
          'event_msg_type',
          'eventMsgType',
          'type',
        ],
      );
      final subType = _text(
        raw,
        const ['sub_type', 'subType', 'event_subtype', 'eventSubtype', 'action_subtype'],
      );
      final description = _description(raw);

      parsed.add(
        _IndexedEvent(
          sourceIndex: index,
          event: NbaGamePlayByPlayEvent(
            gameId: rowGameId,
            sequence: sequence,
            period: period,
            clock: clock,
            clockSecondsRemaining: clockRemaining,
            elapsedGameSeconds: _elapsedGameSeconds(period, clockRemaining),
            actionType: actionType,
            subType: subType,
            description: description,
            team: team,
            player: player,
            homeScore: homeScore,
            awayScore: awayScore,
            sourceId: _text(
              raw,
              const ['source_id', 'sourceId', 'source', 'provider'],
            ),
          ),
        ),
      );
    }

    parsed.sort(_compareIndexedEvents);
    final events = [for (final item in parsed) item.event];

    var scoreEvents = 0;
    var participantEvents = 0;
    var previousHome = 0;
    var previousAway = 0;
    var hasPreviousScore = false;
    for (final event in events) {
      if (event.team.id.isNotEmpty || event.player.id.isNotEmpty) {
        participantEvents += 1;
      }
      if (!event.hasScore) continue;
      if (!hasPreviousScore ||
          event.homeScore != previousHome ||
          event.awayScore != previousAway) {
        scoreEvents += 1;
      }
      previousHome = event.homeScore!;
      previousAway = event.awayScore!;
      hasPreviousScore = true;
    }

    return NbaGamePlayByPlayResult(
      gameId: gameId.trim(),
      events: List.unmodifiable(events),
      sourceRows: seed.playByPlay.length,
      sourceRowsWithGameId: sourceRowsWithGameId,
      rowsForOtherGames: rowsForOtherGames,
      scoreEvents: scoreEvents,
      participantEvents: participantEvents,
      declaredNormalizedEventCount: seed.playByPlayEvents,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }
}

class NbaGamePlayByPlayResult {
  const NbaGamePlayByPlayResult({
    required this.gameId,
    required this.events,
    required this.sourceRows,
    required this.sourceRowsWithGameId,
    required this.rowsForOtherGames,
    required this.scoreEvents,
    required this.participantEvents,
    required this.declaredNormalizedEventCount,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final List<NbaGamePlayByPlayEvent> events;
  final int sourceRows;
  final int sourceRowsWithGameId;
  final int rowsForOtherGames;
  final int scoreEvents;
  final int participantEvents;
  final int declaredNormalizedEventCount;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  bool get hasEvents => events.isNotEmpty;
  bool get hasScoreTimeline => events.any((event) => event.hasScore);
  int get eventCount => events.length;
  int get periodsCovered => <int>{
        for (final event in events)
          if (event.period != null) event.period!,
      }.length;

  String get availabilityLabel {
    if (hasEvents) return 'AVAILABLE';
    if (sourceRows > 0) return 'NO EVENTS FOR GAME';
    if (declaredNormalizedEventCount > 0) return 'EVENT ROWS NOT EXPOSED';
    return 'UNAVAILABLE';
  }
}

class NbaGamePlayByPlayEvent {
  const NbaGamePlayByPlayEvent({
    required this.gameId,
    required this.sequence,
    required this.period,
    required this.clock,
    required this.clockSecondsRemaining,
    required this.elapsedGameSeconds,
    required this.actionType,
    required this.subType,
    required this.description,
    required this.team,
    required this.player,
    required this.homeScore,
    required this.awayScore,
    required this.sourceId,
  });

  final String gameId;
  final int? sequence;
  final int? period;
  final String clock;
  final double? clockSecondsRemaining;
  final double? elapsedGameSeconds;
  final String actionType;
  final String subType;
  final String description;
  final NbaPbpTeamIdentity team;
  final NbaPbpPlayerIdentity player;
  final int? homeScore;
  final int? awayScore;
  final String sourceId;

  bool get hasScore => homeScore != null && awayScore != null;
  int? get margin => hasScore ? homeScore! - awayScore! : null;
  String get scoreLabel => hasScore ? '$awayScore–$homeScore' : '—';

  String get periodLabel {
    final value = period;
    if (value == null || value <= 0) return '—';
    if (value <= 4) return 'Q$value';
    return 'OT${value - 4}';
  }

  String get typeLabel {
    final values = [actionType, subType]
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? 'EVENT' : values.join(' · ').toUpperCase();
  }
}

class NbaPbpTeamIdentity {
  const NbaPbpTeamIdentity({
    required this.id,
    required this.name,
    required this.abbreviation,
  });

  factory NbaPbpTeamIdentity.fromId(String id) => NbaPbpTeamIdentity(
        id: id,
        name: id,
        abbreviation: id,
      );

  final String id;
  final String name;
  final String abbreviation;
}

class NbaPbpPlayerIdentity {
  const NbaPbpPlayerIdentity({required this.id, required this.name});

  final String id;
  final String name;
}

class _IndexedEvent {
  const _IndexedEvent({required this.sourceIndex, required this.event});

  final int sourceIndex;
  final NbaGamePlayByPlayEvent event;
}

const _gameIdKeys = [
  'game_id',
  'gameId',
  'game_id_nullable',
  'gameIdNullable',
];

int _compareIndexedEvents(_IndexedEvent left, _IndexedEvent right) {
  final leftSequence = left.event.sequence;
  final rightSequence = right.event.sequence;
  if (leftSequence != null && rightSequence != null && leftSequence != rightSequence) {
    return leftSequence.compareTo(rightSequence);
  }

  final leftPeriod = left.event.period;
  final rightPeriod = right.event.period;
  if (leftPeriod != null && rightPeriod != null && leftPeriod != rightPeriod) {
    return leftPeriod.compareTo(rightPeriod);
  }

  final leftClock = left.event.clockSecondsRemaining;
  final rightClock = right.event.clockSecondsRemaining;
  if (leftClock != null && rightClock != null && leftClock != rightClock) {
    return rightClock.compareTo(leftClock);
  }

  return left.sourceIndex.compareTo(right.sourceIndex);
}

String _description(Map<String, dynamic> row) {
  final direct = _text(
    row,
    const [
      'description',
      'event_description',
      'eventDescription',
      'description_text',
      'descriptionText',
      'text',
    ],
  );
  if (direct.isNotEmpty) return direct;

  final fragments = <String>[];
  for (final keys in const [
    ['home_description', 'homeDescription'],
    ['neutral_description', 'neutralDescription'],
    ['visitor_description', 'visitorDescription', 'away_description'],
  ]) {
    final value = _text(row, keys);
    if (value.isNotEmpty && !fragments.contains(value)) fragments.add(value);
  }
  return fragments.join(' · ');
}

double? _elapsedGameSeconds(int? period, double? remaining) {
  if (period == null || period <= 0 || remaining == null) return null;
  if (period <= 4) {
    final periodStart = (period - 1) * 12 * 60.0;
    return periodStart + (12 * 60.0 - remaining).clamp(0, 12 * 60.0);
  }
  final overtimeStart = 4 * 12 * 60.0 + (period - 5) * 5 * 60.0;
  return overtimeStart + (5 * 60.0 - remaining).clamp(0, 5 * 60.0);
}

double? _clockSecondsRemaining(String value) {
  final text = value.trim().toUpperCase();
  if (text.isEmpty) return null;

  final colon = RegExp(r'^(\d{1,2}):(\d{2})(?:\.(\d+))?$').firstMatch(text);
  if (colon != null) {
    final minutes = double.parse(colon.group(1)!);
    final seconds = double.parse('${colon.group(2)!}.${colon.group(3) ?? '0'}');
    return minutes * 60 + seconds;
  }

  final iso = RegExp(r'^PT(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?$')
      .firstMatch(text);
  if (iso != null) {
    final minutes = double.tryParse(iso.group(1) ?? '') ?? 0;
    final seconds = double.tryParse(iso.group(2) ?? '') ?? 0;
    return minutes * 60 + seconds;
  }
  return null;
}

String _normalize(String value) => value.trim().toUpperCase();

String _text(
  Map<String, dynamic> row,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = row[key];
    if (value == null || value is Map || value is Iterable) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != '—' && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return fallback;
}

int? _integer(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is int) return value;
    if (value is num) return value.round();
    if (value != null) {
      final parsed = num.tryParse(value.toString().replaceAll(',', ''));
      if (parsed != null) return parsed.round();
    }
  }
  return null;
}
