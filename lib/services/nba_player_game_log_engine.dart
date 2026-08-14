import 'nba_terminal_seed_repository.dart';

/// Projects one player's available game-log rows onto the canonical game graph.
///
/// The engine is deliberately pure: it performs no I/O, preserves null/missing
/// sports fields, and only derives matchup/result context when the underlying
/// canonical game row supports it.
class NbaPlayerGameLogEngine {
  const NbaPlayerGameLogEngine();

  NbaPlayerGameLogResult build(
    NbaTerminalSeedSnapshot seed, {
    required String playerId,
    String playerName = '',
    String seasonType = 'All',
    int? limit,
    bool ascending = false,
  }) {
    final normalizedPlayerId = _normalize(playerId);
    final normalizedPlayerName = playerName.trim().toLowerCase();
    if (normalizedPlayerId.isEmpty && normalizedPlayerName.isEmpty) {
      throw ArgumentError('playerId or playerName is required.');
    }

    final gamesById = <String, Map<String, dynamic>>{};
    for (final game in seed.games) {
      final id = _text(game, _gameIdKeys);
      if (id.isNotEmpty) gamesById[_normalize(id)] = game;
    }

    final teams = <String, NbaPlayerGameTeamIdentity>{};
    for (final team in seed.teams) {
      final id = _text(team, const ['team_id', 'teamId', 'id', 'abbreviation']);
      if (id.isEmpty) continue;
      teams[_normalize(id)] = NbaPlayerGameTeamIdentity(
        id: id,
        name: _text(
          team,
          const ['team_name', 'teamName', 'full_name', 'name'],
          fallback: id,
        ),
        abbreviation: _text(
          team,
          const ['abbreviation', 'team_abbreviation', 'tricode', 'team_id'],
          fallback: id,
        ),
      );
    }

    final targetSeasonType = _normalizeSeasonType(seasonType);
    final rows = <NbaPlayerGameLogRow>[];
    var unlinkedRows = 0;

    for (final raw in seed.playerGameLogsTop) {
      final rowPlayerId = _text(raw, const ['player_id', 'playerId', 'person_id', 'id']);
      final rowPlayerName = _text(
        raw,
        const ['player_name', 'playerName', 'display_name', 'name'],
      );
      final matchesId = normalizedPlayerId.isNotEmpty &&
          rowPlayerId.isNotEmpty &&
          _normalize(rowPlayerId) == normalizedPlayerId;
      final matchesName = normalizedPlayerName.isNotEmpty &&
          rowPlayerName.toLowerCase() == normalizedPlayerName;
      if (!matchesId && !matchesName) continue;

      final rawGameId = _text(raw, _gameIdKeys);
      Map<String, dynamic>? game = rawGameId.isEmpty
          ? _compatibilityGame(seed.games, raw)
          : gamesById[_normalize(rawGameId)];
      final gameId = game == null
          ? rawGameId
          : _text(game, _gameIdKeys, fallback: rawGameId);
      if (game == null) unlinkedRows += 1;

      final rowSeasonType = _text(
        game ?? raw,
        const ['season_type', 'seasonType', 'game_type', 'gameType'],
      );
      if (targetSeasonType != 'all' &&
          _normalizeSeasonType(rowSeasonType) != targetSeasonType) {
        continue;
      }

      final teamId = _text(raw, const ['team_id', 'teamId', 'team', 'team_abbreviation']);
      final homeTeamId = game == null ? '' : _text(game, _homeTeamKeys);
      final awayTeamId = game == null ? '' : _text(game, _awayTeamKeys);
      final normalizedTeam = _normalize(teamId);
      final isHome = normalizedTeam.isNotEmpty &&
          normalizedTeam == _normalize(homeTeamId);
      final isAway = normalizedTeam.isNotEmpty &&
          normalizedTeam == _normalize(awayTeamId);
      final opponentTeamId = game == null
          ? _text(
              raw,
              const ['opponent_team_id', 'opponentTeamId', 'opponent_team', 'opponent'],
            )
          : isHome
              ? awayTeamId
              : isAway
                  ? homeTeamId
                  : _text(
                      raw,
                      const ['opponent_team_id', 'opponentTeamId', 'opponent_team', 'opponent'],
                    );

      final team = teams[normalizedTeam] ?? NbaPlayerGameTeamIdentity.fromId(teamId);
      final opponent = teams[_normalize(opponentTeamId)] ??
          NbaPlayerGameTeamIdentity.fromId(opponentTeamId);
      final homeScore = game == null
          ? null
          : _integer(
              game,
              const ['home_score', 'homeScore', 'home_points', 'pts_home'],
            );
      final awayScore = game == null
          ? null
          : _integer(
              game,
              const [
                'away_score',
                'awayScore',
                'visitor_score',
                'away_points',
                'pts_away',
              ],
            );
      final teamScore = isHome ? homeScore : isAway ? awayScore : null;
      final opponentScore = isHome ? awayScore : isAway ? homeScore : null;

      rows.add(
        NbaPlayerGameLogRow(
          gameId: gameId,
          gameDate: _text(
            game ?? raw,
            const ['game_date', 'gameDate', 'date'],
            fallback: _text(raw, const ['game_date', 'gameDate', 'date']),
          ),
          parsedDate: _parseDate(
            _text(
              game ?? raw,
              const ['game_date', 'gameDate', 'date'],
              fallback: _text(raw, const ['game_date', 'gameDate', 'date']),
            ),
          ),
          seasonId: _text(
            game ?? raw,
            const ['season_id', 'seasonId', 'season', 'season_label'],
            fallback: seed.supportedSeason,
          ),
          seasonType: rowSeasonType,
          status: _text(
            game ?? raw,
            const ['status', 'game_status_text', 'game_status', 'result'],
          ),
          playerId: rowPlayerId.isEmpty ? playerId : rowPlayerId,
          playerName: rowPlayerName.isEmpty ? playerName : rowPlayerName,
          team: team,
          opponent: opponent,
          location: isHome
              ? NbaPlayerGameLocation.home
              : isAway
                  ? NbaPlayerGameLocation.away
                  : NbaPlayerGameLocation.unknown,
          teamScore: teamScore,
          opponentScore: opponentScore,
          minutes: _text(raw, const ['minutes', 'min', 'mp']),
          points: _integer(raw, const ['points', 'pts']),
          rebounds: _integer(raw, const ['rebounds', 'reb', 'trb']),
          assists: _integer(raw, const ['assists', 'ast']),
          steals: _integer(raw, const ['steals', 'stl']),
          blocks: _integer(raw, const ['blocks', 'blk']),
          turnovers: _integer(raw, const ['turnovers', 'tov']),
          fieldGoalsMade: _integer(raw, const ['fgm', 'field_goals_made']),
          fieldGoalsAttempted: _integer(raw, const ['fga', 'field_goals_attempted']),
          threePointersMade: _integer(raw, const ['fg3m', 'three_pm']),
          threePointersAttempted: _integer(raw, const ['fg3a', 'three_pa']),
          freeThrowsMade: _integer(raw, const ['ftm', 'free_throws_made']),
          freeThrowsAttempted: _integer(raw, const ['fta', 'free_throws_attempted']),
          plusMinus: _number(raw, const ['plus_minus', 'plusMinus', 'pm']),
          sourceId: _text(
            raw,
            const ['source_id', 'sourceId', 'source'],
            fallback: game == null
                ? ''
                : _text(game, const ['source_id', 'sourceId', 'source']),
          ),
          linkedCanonicalGame: game != null && gameId.isNotEmpty,
        ),
      );
    }

    rows.sort((left, right) {
      int comparison;
      if (left.parsedDate == null && right.parsedDate == null) {
        comparison = left.gameId.compareTo(right.gameId);
      } else if (left.parsedDate == null) {
        comparison = 1;
      } else if (right.parsedDate == null) {
        comparison = -1;
      } else {
        comparison = left.parsedDate!.compareTo(right.parsedDate!);
        if (comparison == 0) comparison = left.gameId.compareTo(right.gameId);
      }
      return ascending ? comparison : -comparison;
    });

    final bounded = limit == null || limit < 0 ? rows : rows.take(limit).toList();
    return NbaPlayerGameLogResult(
      rows: List.unmodifiable(bounded),
      totalMatchingRows: rows.length,
      unlinkedRows: unlinkedRows,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }

  Map<String, dynamic>? _compatibilityGame(
    List<Map<String, dynamic>> games,
    Map<String, dynamic> log,
  ) {
    final date = _dateKey(_text(log, const ['game_date', 'gameDate', 'date']));
    final team = _normalize(
      _text(log, const ['team_id', 'teamId', 'team', 'team_abbreviation']),
    );
    final opponent = _normalize(
      _text(
        log,
        const ['opponent_team_id', 'opponentTeamId', 'opponent_team', 'opponent'],
      ),
    );
    if (date.isEmpty || team.isEmpty) return null;
    for (final game in games) {
      if (_dateKey(_text(game, const ['game_date', 'gameDate', 'date'])) != date) {
        continue;
      }
      final home = _normalize(_text(game, _homeTeamKeys));
      final away = _normalize(_text(game, _awayTeamKeys));
      if (team != home && team != away) continue;
      if (opponent.isNotEmpty && opponent != (team == home ? away : home)) continue;
      return game;
    }
    return null;
  }
}

class NbaPlayerGameLogResult {
  const NbaPlayerGameLogResult({
    required this.rows,
    required this.totalMatchingRows,
    required this.unlinkedRows,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final List<NbaPlayerGameLogRow> rows;
  final int totalMatchingRows;
  final int unlinkedRows;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  int get linkedRows => rows.where((row) => row.linkedCanonicalGame).length;
  int get completedRows => rows.where((row) => row.hasScore).length;
}

class NbaPlayerGameLogRow {
  const NbaPlayerGameLogRow({
    required this.gameId,
    required this.gameDate,
    required this.parsedDate,
    required this.seasonId,
    required this.seasonType,
    required this.status,
    required this.playerId,
    required this.playerName,
    required this.team,
    required this.opponent,
    required this.location,
    required this.teamScore,
    required this.opponentScore,
    required this.minutes,
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
    required this.plusMinus,
    required this.sourceId,
    required this.linkedCanonicalGame,
  });

  final String gameId;
  final String gameDate;
  final DateTime? parsedDate;
  final String seasonId;
  final String seasonType;
  final String status;
  final String playerId;
  final String playerName;
  final NbaPlayerGameTeamIdentity team;
  final NbaPlayerGameTeamIdentity opponent;
  final NbaPlayerGameLocation location;
  final int? teamScore;
  final int? opponentScore;
  final String minutes;
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
  final num? plusMinus;
  final String sourceId;
  final bool linkedCanonicalGame;

  bool get hasScore => teamScore != null && opponentScore != null;
  bool get won => hasScore && teamScore! > opponentScore!;
  bool get lost => hasScore && teamScore! < opponentScore!;
  String get resultLabel => !hasScore ? '—' : '${won ? 'W' : lost ? 'L' : 'T'} $teamScore–$opponentScore';
  String get matchupPrefix => switch (location) {
        NbaPlayerGameLocation.home => 'vs',
        NbaPlayerGameLocation.away => '@',
        NbaPlayerGameLocation.unknown => 'vs',
      };
  String get matchupLabel {
    final opponentLabel = opponent.abbreviation.isEmpty ? opponent.id : opponent.abbreviation;
    return opponentLabel.isEmpty ? '—' : '$matchupPrefix $opponentLabel';
  }
}

class NbaPlayerGameTeamIdentity {
  const NbaPlayerGameTeamIdentity({
    required this.id,
    required this.name,
    required this.abbreviation,
  });

  factory NbaPlayerGameTeamIdentity.fromId(String id) =>
      NbaPlayerGameTeamIdentity(id: id, name: id, abbreviation: id);

  final String id;
  final String name;
  final String abbreviation;
}

enum NbaPlayerGameLocation { home, away, unknown }

const _gameIdKeys = ['game_id', 'gameId', 'id'];
const _homeTeamKeys = ['home_team_id', 'homeTeamId', 'home_team', 'homeTeam', 'home'];
const _awayTeamKeys = [
  'away_team_id',
  'awayTeamId',
  'visitor_team_id',
  'visitorTeamId',
  'away_team',
  'awayTeam',
  'away',
];

String _normalize(String value) => value.trim().toUpperCase();

String _normalizeSeasonType(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  if (normalized.isEmpty || normalized == 'all') return 'all';
  if (normalized.contains('playoff') || normalized.contains('postseason')) {
    return 'playoffs';
  }
  if (normalized.contains('regular')) return 'regular';
  return normalized;
}

String _dateKey(String value) {
  final parsed = _parseDate(value);
  if (parsed == null) return value.trim();
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day';
}

DateTime? _parseDate(String value) {
  if (value.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(value.trim());
  if (parsed != null) return DateTime.utc(parsed.year, parsed.month, parsed.day);
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
  if (match == null) return null;
  return DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

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

num? _number(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value is num) return value;
    if (value != null) {
      final parsed = num.tryParse(
        value.toString().replaceAll(',', '').replaceAll('+', ''),
      );
      if (parsed != null) return parsed;
    }
  }
  return null;
}

int? _integer(Map<String, dynamic> row, List<String> keys) {
  final value = _number(row, keys);
  return value == null ? null : value.round();
}
