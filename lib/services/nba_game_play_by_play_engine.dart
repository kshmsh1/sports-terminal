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

    NbaPbpPlayerIdentity resolvePlayer(
      Map<String, dynamic> raw,
      List<String> idKeys,
      List<String> nameKeys,
    ) {
      final id = _text(raw, idKeys);
      final name = _text(raw, nameKeys);
      if (id.isEmpty && name.isEmpty) return NbaPbpPlayerIdentity.empty;
      return players[_normalize(id)] ?? NbaPbpPlayerIdentity(id: id, name: name);
    }

    final parsed = <_IndexedEvent>[];
    var sourceRowsWithGameId = 0;
    var rowsForOtherGames = 0;
    var classifiedEvents = 0;
    var explicitSubstitutionEvents = 0;

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
      final category = _classifyEvent(actionType, subType, description);
      if (category != NbaPbpEventCategory.other) classifiedEvents += 1;

      final primaryPlayer = resolvePlayer(
        raw,
        const [
          'player_id',
          'playerId',
          'person_id',
          'personId',
          'player1_id',
          'player1Id',
        ],
        const [
          'player_name',
          'playerName',
          'person_name',
          'personName',
          'player1_name',
          'player1Name',
        ],
      );
      final secondaryPlayer = resolvePlayer(
        raw,
        const [
          'player2_id',
          'player2Id',
          'person2_id',
          'person2Id',
          'secondary_player_id',
          'secondaryPlayerId',
        ],
        const [
          'player2_name',
          'player2Name',
          'person2_name',
          'person2Name',
          'secondary_player_name',
          'secondaryPlayerName',
        ],
      );
      final tertiaryPlayer = resolvePlayer(
        raw,
        const [
          'player3_id',
          'player3Id',
          'person3_id',
          'person3Id',
          'tertiary_player_id',
          'tertiaryPlayerId',
        ],
        const [
          'player3_name',
          'player3Name',
          'person3_name',
          'person3Name',
          'tertiary_player_name',
          'tertiaryPlayerName',
        ],
      );

      var substitutionOut = resolvePlayer(
        raw,
        const [
          'player_out_id',
          'playerOutId',
          'out_player_id',
          'outPlayerId',
          'substitution_out_player_id',
        ],
        const [
          'player_out_name',
          'playerOutName',
          'out_player_name',
          'outPlayerName',
          'substitution_out_player_name',
        ],
      );
      var substitutionIn = resolvePlayer(
        raw,
        const [
          'player_in_id',
          'playerInId',
          'in_player_id',
          'inPlayerId',
          'substitution_in_player_id',
        ],
        const [
          'player_in_name',
          'playerInName',
          'in_player_name',
          'inPlayerName',
          'substitution_in_player_name',
        ],
      );

      // Legacy NBA play-by-play substitution rows use PLAYER1 as the player
      // leaving and PLAYER2 as the player entering. We use that convention only
      // when the row itself is explicitly classified as a substitution.
      if (category == NbaPbpEventCategory.substitution &&
          substitutionOut.isEmpty &&
          substitutionIn.isEmpty &&
          !primaryPlayer.isEmpty &&
          !secondaryPlayer.isEmpty) {
        substitutionOut = primaryPlayer;
        substitutionIn = secondaryPlayer;
      }
      final hasExplicitSubstitution =
          category == NbaPbpEventCategory.substitution &&
          !substitutionOut.isEmpty &&
          !substitutionIn.isEmpty;
      if (hasExplicitSubstitution) explicitSubstitutionEvents += 1;

      final result = _eventResult(raw, actionType, subType, description, category);
      final team = teams[_normalize(teamId)] ?? NbaPbpTeamIdentity.fromId(teamId);

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
            category: category,
            result: result,
            description: description,
            team: team,
            player: primaryPlayer,
            secondaryPlayer: secondaryPlayer,
            tertiaryPlayer: tertiaryPlayer,
            substitutionOut: substitutionOut,
            substitutionIn: substitutionIn,
            hasExplicitSubstitution: hasExplicitSubstitution,
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
      if (!event.player.isEmpty ||
          !event.secondaryPlayer.isEmpty ||
          !event.tertiaryPlayer.isEmpty ||
          event.team.id.isNotEmpty) {
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
      classifiedEvents: classifiedEvents,
      explicitSubstitutionEvents: explicitSubstitutionEvents,
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
    required this.classifiedEvents,
    required this.explicitSubstitutionEvents,
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
  final int classifiedEvents;
  final int explicitSubstitutionEvents;
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

enum NbaPbpEventCategory {
  madeFieldGoal,
  missedFieldGoal,
  freeThrow,
  rebound,
  turnover,
  foul,
  violation,
  substitution,
  timeout,
  jumpBall,
  periodStart,
  periodEnd,
  review,
  ejection,
  other,
}

enum NbaPbpEventResult { made, missed, successful, unsuccessful, unknown }

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
    required this.category,
    required this.result,
    required this.description,
    required this.team,
    required this.player,
    required this.secondaryPlayer,
    required this.tertiaryPlayer,
    required this.substitutionOut,
    required this.substitutionIn,
    required this.hasExplicitSubstitution,
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
  final NbaPbpEventCategory category;
  final NbaPbpEventResult result;
  final String description;
  final NbaPbpTeamIdentity team;
  final NbaPbpPlayerIdentity player;
  final NbaPbpPlayerIdentity secondaryPlayer;
  final NbaPbpPlayerIdentity tertiaryPlayer;
  final NbaPbpPlayerIdentity substitutionOut;
  final NbaPbpPlayerIdentity substitutionIn;
  final bool hasExplicitSubstitution;
  final int? homeScore;
  final int? awayScore;
  final String sourceId;

  bool get hasScore => homeScore != null && awayScore != null;
  int? get margin => hasScore ? homeScore! - awayScore! : null;
  String get scoreLabel => hasScore ? '$awayScore–$homeScore' : '—';
  bool get made => result == NbaPbpEventResult.made;
  bool get isScoringAction =>
      category == NbaPbpEventCategory.madeFieldGoal ||
      (category == NbaPbpEventCategory.freeThrow && made);

  String get periodLabel {
    final value = period;
    if (value == null || value <= 0) return '—';
    if (value <= 4) return 'Q$value';
    return 'OT${value - 4}';
  }

  String get categoryLabel => switch (category) {
        NbaPbpEventCategory.madeFieldGoal => 'MADE FG',
        NbaPbpEventCategory.missedFieldGoal => 'MISSED FG',
        NbaPbpEventCategory.freeThrow => 'FREE THROW',
        NbaPbpEventCategory.rebound => 'REBOUND',
        NbaPbpEventCategory.turnover => 'TURNOVER',
        NbaPbpEventCategory.foul => 'FOUL',
        NbaPbpEventCategory.violation => 'VIOLATION',
        NbaPbpEventCategory.substitution => 'SUBSTITUTION',
        NbaPbpEventCategory.timeout => 'TIMEOUT',
        NbaPbpEventCategory.jumpBall => 'JUMP BALL',
        NbaPbpEventCategory.periodStart => 'PERIOD START',
        NbaPbpEventCategory.periodEnd => 'PERIOD END',
        NbaPbpEventCategory.review => 'REVIEW',
        NbaPbpEventCategory.ejection => 'EJECTION',
        NbaPbpEventCategory.other => 'EVENT',
      };

  String get typeLabel {
    final values = [actionType, subType]
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? categoryLabel : values.join(' · ').toUpperCase();
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

  static const empty = NbaPbpPlayerIdentity(id: '', name: '');

  final String id;
  final String name;

  bool get isEmpty => id.trim().isEmpty && name.trim().isEmpty;
  String get label => name.trim().isNotEmpty ? name.trim() : id.trim();
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

NbaPbpEventCategory _classifyEvent(
  String actionType,
  String subType,
  String description,
) {
  final action = _normalize(actionType);
  final combined = _normalize('$actionType $subType $description');

  switch (action) {
    case '1':
      return NbaPbpEventCategory.madeFieldGoal;
    case '2':
      return NbaPbpEventCategory.missedFieldGoal;
    case '3':
      return NbaPbpEventCategory.freeThrow;
    case '4':
      return NbaPbpEventCategory.rebound;
    case '5':
      return NbaPbpEventCategory.turnover;
    case '6':
      return NbaPbpEventCategory.foul;
    case '7':
      return NbaPbpEventCategory.violation;
    case '8':
      return NbaPbpEventCategory.substitution;
    case '9':
      return NbaPbpEventCategory.timeout;
    case '10':
      return NbaPbpEventCategory.jumpBall;
    case '11':
      return NbaPbpEventCategory.ejection;
    case '12':
      return NbaPbpEventCategory.periodStart;
    case '13':
      return NbaPbpEventCategory.periodEnd;
    case '18':
      return NbaPbpEventCategory.review;
  }

  if (_containsAny(combined, const ['SUBSTITUTION', 'SUB:'])) {
    return NbaPbpEventCategory.substitution;
  }
  if (_containsAny(combined, const ['TIMEOUT'])) return NbaPbpEventCategory.timeout;
  if (_containsAny(combined, const ['JUMP BALL'])) return NbaPbpEventCategory.jumpBall;
  if (_containsAny(combined, const ['TURNOVER'])) return NbaPbpEventCategory.turnover;
  if (_containsAny(combined, const ['REBOUND'])) return NbaPbpEventCategory.rebound;
  if (_containsAny(combined, const ['FREE THROW', 'FREETHROW'])) {
    return NbaPbpEventCategory.freeThrow;
  }
  if (_containsAny(combined, const ['MISS', 'MISSED SHOT', 'MISSED FG'])) {
    return NbaPbpEventCategory.missedFieldGoal;
  }
  if (_containsAny(combined, const ['MADE SHOT', 'MADE FG', '3PT', '2PT', 'DUNK', 'LAYUP', 'JUMPER', 'JUMP SHOT'])) {
    return NbaPbpEventCategory.madeFieldGoal;
  }
  if (_containsAny(combined, const ['FOUL'])) return NbaPbpEventCategory.foul;
  if (_containsAny(combined, const ['VIOLATION'])) return NbaPbpEventCategory.violation;
  if (_containsAny(combined, const ['START OF', 'PERIOD START', 'QUARTER START'])) {
    return NbaPbpEventCategory.periodStart;
  }
  if (_containsAny(combined, const ['END OF', 'PERIOD END', 'QUARTER END'])) {
    return NbaPbpEventCategory.periodEnd;
  }
  if (_containsAny(combined, const ['REVIEW', 'REPLAY'])) return NbaPbpEventCategory.review;
  if (_containsAny(combined, const ['EJECTION', 'EJECTED'])) return NbaPbpEventCategory.ejection;
  return NbaPbpEventCategory.other;
}

NbaPbpEventResult _eventResult(
  Map<String, dynamic> row,
  String actionType,
  String subType,
  String description,
  NbaPbpEventCategory category,
) {
  final explicit = _text(
    row,
    const [
      'shot_result',
      'shotResult',
      'result',
      'event_result',
      'eventResult',
      'outcome',
    ],
  );
  final explicitNormalized = _normalize(explicit);
  if (_containsAny(explicitNormalized, const ['MADE', 'MAKE', 'GOOD', 'SUCCESS'])) {
    return category == NbaPbpEventCategory.freeThrow
        ? NbaPbpEventResult.made
        : NbaPbpEventResult.successful;
  }
  if (_containsAny(explicitNormalized, const ['MISS', 'FAILED', 'UNSUCCESS'])) {
    return category == NbaPbpEventCategory.freeThrow
        ? NbaPbpEventResult.missed
        : NbaPbpEventResult.unsuccessful;
  }

  final madeFlag = _boolean(
    row,
    const ['is_made', 'isMade', 'made', 'shot_made_flag', 'shotMadeFlag'],
  );
  if (madeFlag != null) {
    return madeFlag ? NbaPbpEventResult.made : NbaPbpEventResult.missed;
  }

  if (category == NbaPbpEventCategory.madeFieldGoal) return NbaPbpEventResult.made;
  if (category == NbaPbpEventCategory.missedFieldGoal) return NbaPbpEventResult.missed;

  final combined = _normalize('$actionType $subType $description');
  if (category == NbaPbpEventCategory.freeThrow) {
    if (_containsAny(combined, const ['MISS', 'MISSED'])) return NbaPbpEventResult.missed;
    if (_containsAny(combined, const ['MADE', 'GOOD'])) return NbaPbpEventResult.made;
  }
  return NbaPbpEventResult.unknown;
}

bool _containsAny(String value, List<String> tokens) =>
    tokens.any((token) => value.contains(token));

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

bool? _boolean(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value != null) {
      final text = value.toString().trim().toLowerCase();
      if (const {'true', 't', 'yes', 'y', '1', 'made', 'make'}.contains(text)) return true;
      if (const {'false', 'f', 'no', 'n', '0', 'missed', 'miss'}.contains(text)) return false;
    }
  }
  return null;
}
