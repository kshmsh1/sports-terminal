import 'nba_terminal_seed_repository.dart';

/// Pure domain projection for one canonical NBA game.
///
/// The engine never performs I/O and never manufactures missing sports data.
/// It reconciles the active seed's game, team-game and player-game rows into a
/// single source-aware object that can be consumed by UI, routing, Workspace,
/// Python and future analytics layers.
class NbaGameIntelligenceEngine {
  const NbaGameIntelligenceEngine();

  NbaGameIntelligenceSnapshot build({
    required NbaTerminalSeedSnapshot seed,
    required String gameId,
  }) {
    final requestedId = gameId.trim();
    if (requestedId.isEmpty) {
      throw ArgumentError.value(gameId, 'gameId', 'Game ID is required.');
    }

    final game = _findGame(seed.games, requestedId);
    if (game == null) {
      throw NbaGameNotFoundException(
        gameId: requestedId,
        datasetStatus: seed.datasetStatus,
      );
    }

    final resolvedId = _text(game, _gameIdKeys) ?? requestedId;
    final gameDate = _text(game, _gameDateKeys) ?? '';
    final homeTeamId = _text(game, _homeTeamKeys) ?? '';
    final awayTeamId = _text(game, _awayTeamKeys) ?? '';

    final homeTeam = _team(seed, homeTeamId);
    final awayTeam = _team(seed, awayTeamId);

    final matchingTeamLogs = <Map<String, dynamic>>[];
    for (final row in seed.teamGameLogs) {
      if (_belongsToGame(
        row,
        gameId: resolvedId,
        gameDate: gameDate,
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
      )) {
        matchingTeamLogs.add(row);
      }
    }

    final matchingPlayerLogs = <Map<String, dynamic>>[];
    for (final row in seed.playerGameLogsTop) {
      if (_belongsToGame(
        row,
        gameId: resolvedId,
        gameDate: gameDate,
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
      )) {
        matchingPlayerLogs.add(row);
      }
    }

    final homeTeamLog = _teamLog(matchingTeamLogs, homeTeamId);
    final awayTeamLog = _teamLog(matchingTeamLogs, awayTeamId);

    final homeScore = _integer(
          game,
          const [
            'home_score',
            'homeScore',
            'home_points',
            'homePoints',
            'pts_home',
          ],
        ) ??
        _integer(homeTeamLog, const ['points', 'pts', 'team_points']);
    final awayScore = _integer(
          game,
          const [
            'away_score',
            'awayScore',
            'away_points',
            'awayPoints',
            'visitor_score',
            'pts_away',
          ],
        ) ??
        _integer(awayTeamLog, const ['points', 'pts', 'team_points']);

    final playerLines = <NbaGamePlayerLine>[
      for (final row in matchingPlayerLogs)
        _playerLine(
          seed,
          row,
          homeTeamId: homeTeamId,
          awayTeamId: awayTeamId,
        ),
    ]
      ..sort((left, right) {
        final side = left.side.index.compareTo(right.side.index);
        if (side != 0) return side;
        final minutes = (right.sortableMinutes ?? -1)
            .compareTo(left.sortableMinutes ?? -1);
        if (minutes != 0) return minutes;
        final points = (right.points ?? -1).compareTo(left.points ?? -1);
        if (points != 0) return points;
        return left.playerName.compareTo(right.playerName);
      });

    final periods = _periods(game);
    final sourceRows = <Map<String, dynamic>>[
      game,
      ...matchingTeamLogs,
      ...matchingPlayerLogs,
    ];
    final provenance = NbaGameProvenance(
      assetPath: seed.assetPath,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      releaseId: _text(seed.releaseManifest, const ['id', 'release_id']),
      releaseVersion:
          _text(seed.releaseManifest, const ['version', 'release_version']),
      releaseStatus:
          _text(seed.releaseManifest, const ['status', 'release_status']),
      sourceIds: _collect(sourceRows, const ['source_id', 'sourceId', 'source']),
      asOfValues: _collect(
        sourceRows,
        const ['as_of', 'asOf', 'source_as_of', 'sourceAsOf'],
      ),
      usedFallbackDataset: seed.usedFallback,
      historicalContext: seed.isHistorical,
    );

    final compatibilityJoin = <Map<String, dynamic>>[
      ...matchingTeamLogs,
      ...matchingPlayerLogs,
    ].any((row) => _text(row, _gameIdKeys) == null);

    final integrityIssues = _integrityIssues(
      gameId: resolvedId,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
      homeScore: homeScore,
      awayScore: awayScore,
      homeTeamLog: homeTeamLog,
      awayTeamLog: awayTeamLog,
    );

    return NbaGameIntelligenceSnapshot(
      requestedGameId: requestedId,
      gameId: resolvedId,
      seasonId: _text(
            game,
            const ['season_id', 'seasonId', 'season', 'season_label'],
          ) ??
          seed.supportedSeason,
      seasonType: _text(
            game,
            const ['season_type', 'seasonType', 'game_type', 'gameType'],
          ) ??
          '',
      gameDate: gameDate,
      status: _text(
            game,
            const [
              'status',
              'game_status',
              'gameStatus',
              'game_status_text',
            ],
          ) ??
          '',
      arena: _text(game, const ['arena', 'arena_name', 'venue']),
      city: _text(game, const ['city', 'arena_city', 'location']),
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeScore: homeScore,
      awayScore: awayScore,
      periods: periods,
      homeTeamLine: homeTeamLog == null
          ? null
          : NbaGameTeamLine.fromRow(team: homeTeam, row: homeTeamLog),
      awayTeamLine: awayTeamLog == null
          ? null
          : NbaGameTeamLine.fromRow(team: awayTeam, row: awayTeamLog),
      playerLines: List.unmodifiable(playerLines),
      coverage: NbaGameCoverage(
        scoreboard: homeScore != null && awayScore != null,
        teamBoxScore: homeTeamLog != null && awayTeamLog != null,
        playerBoxScore: playerLines.isNotEmpty,
        periodScoring: periods.isNotEmpty,
        sourceMetadata: provenance.hasSourceMetadata,
        usedCompatibilityJoin: compatibilityJoin,
      ),
      provenance: provenance,
      integrityIssues: List.unmodifiable(integrityIssues),
      rawGame: Map.unmodifiable(Map<String, dynamic>.from(game)),
    );
  }

  Map<String, dynamic>? _findGame(
    List<Map<String, dynamic>> rows,
    String gameId,
  ) {
    final target = _id(gameId);
    for (final row in rows) {
      final candidate = _text(row, _gameIdKeys);
      if (candidate != null && _id(candidate) == target) return row;
    }
    return null;
  }

  NbaGameTeam _team(NbaTerminalSeedSnapshot seed, String teamId) {
    if (teamId.isEmpty) return const NbaGameTeam(id: '', name: '', abbreviation: '');
    final target = _id(teamId);
    Map<String, dynamic>? match;
    for (final row in seed.teams) {
      final candidate = _text(
        row,
        const [
          'team_id',
          'teamId',
          'id',
          'abbreviation',
          'team_abbreviation',
          'tricode',
        ],
      );
      if (candidate != null && _id(candidate) == target) {
        match = row;
        break;
      }
    }
    return NbaGameTeam(
      id: teamId,
      name: match == null
          ? teamId
          : _text(
                match,
                const ['team_name', 'teamName', 'full_name', 'name'],
              ) ??
              teamId,
      abbreviation: match == null
          ? teamId
          : _text(
                match,
                const [
                  'abbreviation',
                  'team_abbreviation',
                  'tricode',
                  'team_id',
                ],
              ) ??
              teamId,
    );
  }

  Map<String, dynamic>? _teamLog(
    List<Map<String, dynamic>> rows,
    String teamId,
  ) {
    if (teamId.isEmpty) return null;
    final target = _id(teamId);
    for (final row in rows) {
      final candidate = _text(
        row,
        const ['team_id', 'teamId', 'team', 'team_abbreviation'],
      );
      if (candidate != null && _id(candidate) == target) return row;
    }
    return null;
  }

  NbaGamePlayerLine _playerLine(
    NbaTerminalSeedSnapshot seed,
    Map<String, dynamic> row, {
    required String homeTeamId,
    required String awayTeamId,
  }) {
    final playerId = _text(row, const ['player_id', 'playerId', 'id']) ?? '';
    var playerName = _text(
          row,
          const ['player_name', 'playerName', 'player_label', 'name'],
        ) ??
        '';
    if (playerName.isEmpty && playerId.isNotEmpty) {
      final target = _id(playerId);
      for (final player in seed.players) {
        final candidate = _text(player, const ['player_id', 'playerId', 'id']);
        if (candidate != null && _id(candidate) == target) {
          playerName = _text(
                player,
                const ['player_name', 'playerName', 'full_name', 'name'],
              ) ??
              playerId;
          break;
        }
      }
    }
    final teamId = _text(
          row,
          const ['team_id', 'teamId', 'team', 'team_abbreviation'],
        ) ??
        '';
    return NbaGamePlayerLine(
      playerId: playerId,
      playerName: playerName.isEmpty ? playerId : playerName,
      teamId: teamId,
      side: _side(teamId, homeTeamId, awayTeamId),
      minutes: _text(row, const ['minutes', 'min', 'mp']) ?? '',
      points: _integer(row, const ['points', 'pts']),
      rebounds: _integer(row, const ['rebounds', 'reb', 'trb']),
      assists: _integer(row, const ['assists', 'ast']),
      steals: _integer(row, const ['steals', 'stl']),
      blocks: _integer(row, const ['blocks', 'blk']),
      turnovers: _integer(row, const ['turnovers', 'tov']),
      fouls: _integer(row, const ['fouls', 'pf', 'personal_fouls']),
      fieldGoalsMade: _integer(row, const ['fgm', 'field_goals_made']),
      fieldGoalsAttempted:
          _integer(row, const ['fga', 'field_goals_attempted']),
      threePointersMade:
          _integer(row, const ['fg3m', 'three_pm', 'three_pointers_made']),
      threePointersAttempted:
          _integer(row, const ['fg3a', 'three_pa', 'three_pointers_attempted']),
      freeThrowsMade: _integer(row, const ['ftm', 'free_throws_made']),
      freeThrowsAttempted: _integer(row, const ['fta', 'free_throws_attempted']),
      plusMinus: _number(row, const ['plus_minus', 'plusMinus', 'plusminus']),
    );
  }

  List<NbaGamePeriodScore> _periods(Map<String, dynamic> game) {
    final nested = game['periods'] ?? game['period_scores'] ?? game['periodScores'];
    if (nested is List) {
      final output = <NbaGamePeriodScore>[];
      for (var index = 0; index < nested.length; index++) {
        final value = nested[index];
        if (value is! Map) continue;
        final row = value.map((key, item) => MapEntry(key.toString(), item));
        final home = _integer(row, const ['home_score', 'homeScore', 'home_points']);
        final away = _integer(row, const ['away_score', 'awayScore', 'away_points']);
        if (home == null && away == null) continue;
        output.add(
          NbaGamePeriodScore(
            label: _text(row, const ['label', 'name']) ?? 'P${index + 1}',
            homeScore: home,
            awayScore: away,
          ),
        );
      }
      if (output.isNotEmpty) return List.unmodifiable(output);
    }

    final output = <NbaGamePeriodScore>[];
    for (var quarter = 1; quarter <= 4; quarter++) {
      final home = _integer(game, ['home_q$quarter', 'homeQ$quarter']);
      final away = _integer(game, ['away_q$quarter', 'awayQ$quarter']);
      if (home != null || away != null) {
        output.add(
          NbaGamePeriodScore(
            label: 'Q$quarter',
            homeScore: home,
            awayScore: away,
          ),
        );
      }
    }
    return List.unmodifiable(output);
  }

  List<NbaGameIntegrityIssue> _integrityIssues({
    required String gameId,
    required String homeTeamId,
    required String awayTeamId,
    required int? homeScore,
    required int? awayScore,
    required Map<String, dynamic>? homeTeamLog,
    required Map<String, dynamic>? awayTeamLog,
  }) {
    final issues = <NbaGameIntegrityIssue>[];
    if (homeTeamId.isEmpty) {
      issues.add(const NbaGameIntegrityIssue.blocking('missing-home-team'));
    }
    if (awayTeamId.isEmpty) {
      issues.add(const NbaGameIntegrityIssue.blocking('missing-away-team'));
    }
    if (homeTeamId.isNotEmpty &&
        awayTeamId.isNotEmpty &&
        _id(homeTeamId) == _id(awayTeamId)) {
      issues.add(const NbaGameIntegrityIssue.blocking('same-team-game'));
    }
    if (homeScore != null && homeScore < 0) {
      issues.add(const NbaGameIntegrityIssue.blocking('negative-home-score'));
    }
    if (awayScore != null && awayScore < 0) {
      issues.add(const NbaGameIntegrityIssue.blocking('negative-away-score'));
    }
    _reconcileScore(issues, 'home-score-mismatch', homeScore, homeTeamLog);
    _reconcileScore(issues, 'away-score-mismatch', awayScore, awayTeamLog);
    return issues;
  }

  void _reconcileScore(
    List<NbaGameIntegrityIssue> issues,
    String code,
    int? scoreboard,
    Map<String, dynamic>? teamLog,
  ) {
    if (scoreboard == null || teamLog == null) return;
    final logScore = _integer(teamLog, const ['points', 'pts', 'team_points']);
    if (logScore != null && logScore != scoreboard) {
      issues.add(NbaGameIntegrityIssue.warning(code));
    }
  }
}

class NbaGameIntelligenceSnapshot {
  const NbaGameIntelligenceSnapshot({
    required this.requestedGameId,
    required this.gameId,
    required this.seasonId,
    required this.seasonType,
    required this.gameDate,
    required this.status,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.periods,
    required this.homeTeamLine,
    required this.awayTeamLine,
    required this.playerLines,
    required this.coverage,
    required this.provenance,
    required this.integrityIssues,
    required this.rawGame,
    this.arena,
    this.city,
  });

  final String requestedGameId;
  final String gameId;
  final String seasonId;
  final String seasonType;
  final String gameDate;
  final String status;
  final String? arena;
  final String? city;
  final NbaGameTeam homeTeam;
  final NbaGameTeam awayTeam;
  final int? homeScore;
  final int? awayScore;
  final List<NbaGamePeriodScore> periods;
  final NbaGameTeamLine? homeTeamLine;
  final NbaGameTeamLine? awayTeamLine;
  final List<NbaGamePlayerLine> playerLines;
  final NbaGameCoverage coverage;
  final NbaGameProvenance provenance;
  final List<NbaGameIntegrityIssue> integrityIssues;
  final Map<String, dynamic> rawGame;

  bool get hasBlockingIssue =>
      integrityIssues.any((issue) => issue.severity == NbaGameIntegritySeverity.blocking);

  String? get winnerTeamId {
    if (homeScore == null || awayScore == null || homeScore == awayScore) return null;
    return homeScore! > awayScore! ? homeTeam.id : awayTeam.id;
  }

  List<NbaGamePlayerLine> get awayPlayers =>
      List.unmodifiable(playerLines.where((line) => line.side == NbaGameSide.away));

  List<NbaGamePlayerLine> get homePlayers =>
      List.unmodifiable(playerLines.where((line) => line.side == NbaGameSide.home));
}

class NbaGameTeam {
  const NbaGameTeam({required this.id, required this.name, required this.abbreviation});
  final String id;
  final String name;
  final String abbreviation;
}

enum NbaGameSide { away, home, unknown }

class NbaGameTeamLine {
  const NbaGameTeamLine({
    required this.team,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.turnovers,
    required this.fieldGoalsMade,
    required this.fieldGoalsAttempted,
    required this.threePointersMade,
    required this.threePointersAttempted,
    required this.freeThrowsMade,
    required this.freeThrowsAttempted,
  });

  factory NbaGameTeamLine.fromRow({
    required NbaGameTeam team,
    required Map<String, dynamic> row,
  }) =>
      NbaGameTeamLine(
        team: team,
        points: _integer(row, const ['points', 'pts']),
        rebounds: _integer(row, const ['rebounds', 'reb', 'trb']),
        assists: _integer(row, const ['assists', 'ast']),
        steals: _integer(row, const ['steals', 'stl']),
        blocks: _integer(row, const ['blocks', 'blk']),
        turnovers: _integer(row, const ['turnovers', 'tov']),
        fieldGoalsMade: _integer(row, const ['fgm', 'field_goals_made']),
        fieldGoalsAttempted: _integer(row, const ['fga', 'field_goals_attempted']),
        threePointersMade: _integer(row, const ['fg3m', 'three_pm']),
        threePointersAttempted: _integer(row, const ['fg3a', 'three_pa']),
        freeThrowsMade: _integer(row, const ['ftm', 'free_throws_made']),
        freeThrowsAttempted: _integer(row, const ['fta', 'free_throws_attempted']),
      );

  final NbaGameTeam team;
  final int? points;
  final int? rebounds;
  final int? assists;
  final int? steals;
  final int? blocks;
  final int? turnovers;
  final int? fieldGoalsMade;
  final int? fieldGoalsAttempted;
  final int? threePointersMade;
  final int? threePointersAttempted;
  final int? freeThrowsMade;
  final int? freeThrowsAttempted;
}

class NbaGamePlayerLine {
  const NbaGamePlayerLine({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.side,
    required this.minutes,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.turnovers,
    required this.fouls,
    required this.fieldGoalsMade,
    required this.fieldGoalsAttempted,
    required this.threePointersMade,
    required this.threePointersAttempted,
    required this.freeThrowsMade,
    required this.freeThrowsAttempted,
    required this.plusMinus,
  });

  final String playerId;
  final String playerName;
  final String teamId;
  final NbaGameSide side;
  final String minutes;
  final int? points;
  final int? rebounds;
  final int? assists;
  final int? steals;
  final int? blocks;
  final int? turnovers;
  final int? fouls;
  final int? fieldGoalsMade;
  final int? fieldGoalsAttempted;
  final int? threePointersMade;
  final int? threePointersAttempted;
  final int? freeThrowsMade;
  final int? freeThrowsAttempted;
  final num? plusMinus;

  double? get sortableMinutes {
    final direct = double.tryParse(minutes);
    if (direct != null) return direct;
    final parts = minutes.split(':');
    if (parts.length != 2) return null;
    final whole = double.tryParse(parts[0]);
    final seconds = double.tryParse(parts[1]);
    if (whole == null || seconds == null || seconds < 0 || seconds >= 60) return null;
    return whole + seconds / 60;
  }
}

class NbaGamePeriodScore {
  const NbaGamePeriodScore({required this.label, required this.homeScore, required this.awayScore});
  final String label;
  final int? homeScore;
  final int? awayScore;
}

class NbaGameCoverage {
  const NbaGameCoverage({
    required this.scoreboard,
    required this.teamBoxScore,
    required this.playerBoxScore,
    required this.periodScoring,
    required this.sourceMetadata,
    required this.usedCompatibilityJoin,
  });

  final bool scoreboard;
  final bool teamBoxScore;
  final bool playerBoxScore;
  final bool periodScoring;
  final bool sourceMetadata;
  final bool usedCompatibilityJoin;

  List<String> get missingSections => List.unmodifiable([
        if (!scoreboard) 'scoreboard',
        if (!teamBoxScore) 'team-box-score',
        if (!playerBoxScore) 'player-box-score',
        if (!periodScoring) 'period-scoring',
        if (!sourceMetadata) 'source-metadata',
      ]);
}

class NbaGameProvenance {
  const NbaGameProvenance({
    required this.assetPath,
    required this.datasetStatus,
    required this.validationStatus,
    required this.releaseId,
    required this.releaseVersion,
    required this.releaseStatus,
    required this.sourceIds,
    required this.asOfValues,
    required this.usedFallbackDataset,
    required this.historicalContext,
  });

  final String assetPath;
  final String datasetStatus;
  final String validationStatus;
  final String? releaseId;
  final String? releaseVersion;
  final String? releaseStatus;
  final List<String> sourceIds;
  final List<String> asOfValues;
  final bool usedFallbackDataset;
  final bool historicalContext;

  bool get hasSourceMetadata =>
      sourceIds.isNotEmpty || asOfValues.isNotEmpty || (releaseId?.isNotEmpty ?? false);
}

enum NbaGameIntegritySeverity { warning, blocking }

class NbaGameIntegrityIssue {
  const NbaGameIntegrityIssue(this.severity, this.code);
  const NbaGameIntegrityIssue.warning(String code)
      : this(NbaGameIntegritySeverity.warning, code);
  const NbaGameIntegrityIssue.blocking(String code)
      : this(NbaGameIntegritySeverity.blocking, code);

  final NbaGameIntegritySeverity severity;
  final String code;
}

class NbaGameNotFoundException implements Exception {
  const NbaGameNotFoundException({required this.gameId, required this.datasetStatus});
  final String gameId;
  final String datasetStatus;

  @override
  String toString() => 'NBA game "$gameId" was not found in $datasetStatus.';
}

const _gameIdKeys = ['game_id', 'gameId', 'id'];
const _gameDateKeys = ['game_date', 'gameDate', 'date'];
const _homeTeamKeys = ['home_team_id', 'homeTeamId', 'home_team', 'homeTeam', 'home'];
const _awayTeamKeys = [
  'away_team_id',
  'awayTeamId',
  'away_team',
  'awayTeam',
  'away',
  'visitor_team_id',
  'visitorTeamId',
];

bool _belongsToGame(
  Map<String, dynamic> row, {
  required String gameId,
  required String gameDate,
  required String homeTeamId,
  required String awayTeamId,
}) {
  final rowGameId = _text(row, _gameIdKeys);
  if (rowGameId != null) return _id(rowGameId) == _id(gameId);
  final rowDate = _date(_text(row, _gameDateKeys));
  final targetDate = _date(gameDate);
  if (rowDate == null || targetDate == null || rowDate != targetDate) return false;
  final team = _text(row, const ['team_id', 'teamId', 'team', 'team_abbreviation']);
  if (team == null) return false;
  final normalized = _id(team);
  if (normalized != _id(homeTeamId) && normalized != _id(awayTeamId)) return false;
  final opponent = _text(row, const ['opponent_team_id', 'opponentTeamId', 'opponent']);
  if (opponent == null) return true;
  return normalized == _id(homeTeamId)
      ? _id(opponent) == _id(awayTeamId)
      : _id(opponent) == _id(homeTeamId);
}

NbaGameSide _side(String teamId, String homeTeamId, String awayTeamId) {
  if (_id(teamId) == _id(awayTeamId)) return NbaGameSide.away;
  if (_id(teamId) == _id(homeTeamId)) return NbaGameSide.home;
  return NbaGameSide.unknown;
}

String _id(String value) => value.trim().toUpperCase();

String? _date(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(value.trim());
  if (parsed != null) {
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '${parsed.year}-$month-$day';
  }
  final match = RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(value.trim());
  return match?.group(0) ?? value.trim();
}

String? _text(Map<String, dynamic>? row, List<String> keys) {
  if (row == null) return null;
  for (final key in keys) {
    final value = row[key];
    if (value == null || value is Map || value is Iterable) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != '—' && text.toLowerCase() != 'null') return text;
  }
  return null;
}

num? _number(Map<String, dynamic>? row, List<String> keys) {
  if (row == null) return null;
  for (final key in keys) {
    final value = row[key];
    if (value is num) return value;
    if (value != null) {
      final parsed = num.tryParse(value.toString().replaceAll(',', '').replaceAll('+', ''));
      if (parsed != null) return parsed;
    }
  }
  return null;
}

int? _integer(Map<String, dynamic>? row, List<String> keys) {
  final value = _number(row, keys);
  if (value == null) return null;
  final number = value.toDouble();
  if (!number.isFinite) return null;
  return number.round();
}

List<String> _collect(Iterable<Map<String, dynamic>> rows, List<String> keys) {
  final values = <String>{};
  for (final row in rows) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      if (value is Iterable) {
        for (final item in value) {
          final text = item?.toString().trim() ?? '';
          if (text.isNotEmpty) values.add(text);
        }
      } else if (value is! Map) {
        final text = value.toString().trim();
        if (text.isNotEmpty) values.add(text);
      }
    }
  }
  final sorted = values.toList()..sort();
  return List.unmodifiable(sorted);
}
