import 'nba_game_intelligence_engine.dart';
import 'nba_player_game_log_engine.dart';
import 'nba_terminal_seed_repository.dart';

/// Builds date-bounded context around one canonical game. All "entering game"
/// form uses completed observations strictly before the focal game's date.
class NbaGameContextEngine {
  const NbaGameContextEngine();

  NbaGameContextResult build(
    NbaTerminalSeedSnapshot seed, {
    required String gameId,
    int teamWindow = 5,
    int playerWindow = 5,
  }) {
    final game = const NbaGameIntelligenceEngine().build(
      seed: seed,
      gameId: gameId,
    );
    final focalDate = _parseDate(game.gameDate);
    final boundedTeamWindow = teamWindow < 1 ? 1 : teamWindow;
    final boundedPlayerWindow = playerWindow < 1 ? 1 : playerWindow;

    final canonicalGames = <_ContextGame>[];
    for (final raw in seed.games) {
      final id = _text(raw, const ['game_id', 'gameId', 'id']);
      if (id.isEmpty) continue;
      canonicalGames.add(
        _ContextGame(
          gameId: id,
          gameDate: _text(raw, const ['game_date', 'gameDate', 'date']),
          parsedDate: _parseDate(
            _text(raw, const ['game_date', 'gameDate', 'date']),
          ),
          seasonId: _text(
            raw,
            const ['season_id', 'seasonId', 'season', 'season_label'],
            fallback: seed.supportedSeason,
          ),
          seasonType: _text(
            raw,
            const ['season_type', 'seasonType', 'game_type', 'gameType'],
          ),
          homeTeamId: _text(
            raw,
            const ['home_team_id', 'homeTeamId', 'home_team', 'home'],
          ),
          awayTeamId: _text(
            raw,
            const [
              'away_team_id',
              'awayTeamId',
              'visitor_team_id',
              'away_team',
              'away',
            ],
          ),
          homeScore: _integer(
            raw,
            const ['home_score', 'homeScore', 'home_points', 'pts_home'],
          ),
          awayScore: _integer(
            raw,
            const [
              'away_score',
              'awayScore',
              'visitor_score',
              'away_points',
              'pts_away',
            ],
          ),
          status: _text(
            raw,
            const ['status', 'game_status', 'gameStatus', 'game_status_text'],
          ),
        ),
      );
    }

    final related = <NbaRelatedGame>[];
    for (final candidate in canonicalGames) {
      if (_normalize(candidate.gameId) == _normalize(game.gameId)) continue;
      if (!_sameSeason(candidate, game)) continue;
      if (!_sameMatchup(candidate, game.homeTeam.id, game.awayTeam.id)) continue;
      related.add(
        NbaRelatedGame(
          gameId: candidate.gameId,
          gameDate: candidate.gameDate,
          parsedDate: candidate.parsedDate,
          homeTeamId: candidate.homeTeamId,
          awayTeamId: candidate.awayTeamId,
          homeScore: candidate.homeScore,
          awayScore: candidate.awayScore,
          status: candidate.status,
          beforeFocalGame: focalDate != null &&
              candidate.parsedDate != null &&
              candidate.parsedDate!.isBefore(focalDate),
        ),
      );
    }
    related.sort((left, right) => _compareDates(left.parsedDate, right.parsedDate));

    final homeForm = _teamForm(
      canonicalGames,
      teamId: game.homeTeam.id,
      focalDate: focalDate,
      seasonId: game.seasonId,
      seasonType: game.seasonType,
      window: boundedTeamWindow,
    );
    final awayForm = _teamForm(
      canonicalGames,
      teamId: game.awayTeam.id,
      focalDate: focalDate,
      seasonId: game.seasonId,
      seasonType: game.seasonType,
      window: boundedTeamWindow,
    );

    final playerForms = <NbaPlayerEnteringForm>[];
    final seenPlayers = <String>{};
    for (final player in game.playerLines) {
      final playerId = player.playerId.trim();
      if (playerId.isEmpty || !seenPlayers.add(_normalize(playerId))) continue;
      final log = const NbaPlayerGameLogEngine().build(
        seed,
        playerId: playerId,
        playerName: player.playerName,
        seasonType: game.seasonType,
        ascending: false,
      );
      final prior = log.rows.where((row) {
        if (!row.linkedCanonicalGame || row.parsedDate == null || focalDate == null) {
          return false;
        }
        if (!row.parsedDate!.isBefore(focalDate)) return false;
        if (game.seasonId.isNotEmpty &&
            row.seasonId.isNotEmpty &&
            _normalize(row.seasonId) != _normalize(game.seasonId)) {
          return false;
        }
        return true;
      }).take(boundedPlayerWindow).toList(growable: false);

      playerForms.add(
        NbaPlayerEnteringForm(
          playerId: playerId,
          playerName: player.playerName,
          teamId: player.teamId,
          windowRequested: boundedPlayerWindow,
          games: prior.length,
          pointsPerGame: _average([for (final row in prior) row.points]),
          reboundsPerGame: _average([for (final row in prior) row.rebounds]),
          assistsPerGame: _average([for (final row in prior) row.assists]),
          plusMinusPerGame: _averageNum([for (final row in prior) row.plusMinus]),
          lastGameId: prior.isEmpty ? '' : prior.first.gameId,
          lastGameDate: prior.isEmpty ? '' : prior.first.gameDate,
        ),
      );
    }
    playerForms.sort((left, right) {
      final team = left.teamId.compareTo(right.teamId);
      if (team != 0) return team;
      final games = right.games.compareTo(left.games);
      if (games != 0) return games;
      final points = (right.pointsPerGame ?? -1).compareTo(left.pointsPerGame ?? -1);
      if (points != 0) return points;
      return left.playerName.compareTo(right.playerName);
    });

    var homePriorWins = 0;
    var awayPriorWins = 0;
    var priorMeetings = 0;
    for (final candidate in related.where((row) => row.beforeFocalGame && row.hasScore)) {
      priorMeetings += 1;
      final winner = candidate.winnerTeamId;
      if (_normalize(winner) == _normalize(game.homeTeam.id)) homePriorWins += 1;
      if (_normalize(winner) == _normalize(game.awayTeam.id)) awayPriorWins += 1;
    }

    return NbaGameContextResult(
      gameId: game.gameId,
      focalDate: focalDate,
      homeTeam: game.homeTeam,
      awayTeam: game.awayTeam,
      relatedGames: List.unmodifiable(related),
      priorMeetings: priorMeetings,
      homePriorWins: homePriorWins,
      awayPriorWins: awayPriorWins,
      homeEnteringForm: homeForm,
      awayEnteringForm: awayForm,
      playerEnteringForms: List.unmodifiable(playerForms),
      teamWindow: boundedTeamWindow,
      playerWindow: boundedPlayerWindow,
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }

  NbaTeamEnteringForm _teamForm(
    List<_ContextGame> games, {
    required String teamId,
    required DateTime? focalDate,
    required String seasonId,
    required String seasonType,
    required int window,
  }) {
    if (teamId.trim().isEmpty || focalDate == null) {
      return NbaTeamEnteringForm.empty(teamId: teamId, windowRequested: window);
    }
    final prior = games.where((game) {
      if (!game.hasScore || game.parsedDate == null || !game.parsedDate!.isBefore(focalDate)) {
        return false;
      }
      if (!_containsTeam(game, teamId)) return false;
      if (seasonId.isNotEmpty &&
          game.seasonId.isNotEmpty &&
          _normalize(game.seasonId) != _normalize(seasonId)) {
        return false;
      }
      if (seasonType.isNotEmpty &&
          game.seasonType.isNotEmpty &&
          _normalizeSeasonType(game.seasonType) != _normalizeSeasonType(seasonType)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((left, right) => _compareDates(right.parsedDate, left.parsedDate));
    final sample = prior.take(window).toList(growable: false);

    var wins = 0;
    var losses = 0;
    final pointsFor = <num>[];
    final pointsAgainst = <num>[];
    final margins = <num>[];
    for (final game in sample) {
      final home = _normalize(game.homeTeamId) == _normalize(teamId);
      final own = home ? game.homeScore! : game.awayScore!;
      final opponent = home ? game.awayScore! : game.homeScore!;
      pointsFor.add(own);
      pointsAgainst.add(opponent);
      margins.add(own - opponent);
      if (own > opponent) {
        wins += 1;
      } else if (own < opponent) {
        losses += 1;
      }
    }

    var streakWins = 0;
    var streakLosses = 0;
    for (final game in sample) {
      final home = _normalize(game.homeTeamId) == _normalize(teamId);
      final own = home ? game.homeScore! : game.awayScore!;
      final opponent = home ? game.awayScore! : game.homeScore!;
      if (own == opponent) break;
      if (streakWins == 0 && streakLosses == 0) {
        if (own > opponent) {
          streakWins = 1;
        } else {
          streakLosses = 1;
        }
        continue;
      }
      if (streakWins > 0 && own > opponent) {
        streakWins += 1;
      } else if (streakLosses > 0 && own < opponent) {
        streakLosses += 1;
      } else {
        break;
      }
    }

    return NbaTeamEnteringForm(
      teamId: teamId,
      windowRequested: window,
      games: sample.length,
      wins: wins,
      losses: losses,
      pointsForPerGame: _averageNum(pointsFor),
      pointsAgainstPerGame: _averageNum(pointsAgainst),
      marginPerGame: _averageNum(margins),
      streakLabel: streakWins > 0
          ? 'W$streakWins'
          : streakLosses > 0
              ? 'L$streakLosses'
              : '—',
      lastGameId: sample.isEmpty ? '' : sample.first.gameId,
      lastGameDate: sample.isEmpty ? '' : sample.first.gameDate,
    );
  }
}

class NbaGameContextResult {
  const NbaGameContextResult({
    required this.gameId,
    required this.focalDate,
    required this.homeTeam,
    required this.awayTeam,
    required this.relatedGames,
    required this.priorMeetings,
    required this.homePriorWins,
    required this.awayPriorWins,
    required this.homeEnteringForm,
    required this.awayEnteringForm,
    required this.playerEnteringForms,
    required this.teamWindow,
    required this.playerWindow,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final String gameId;
  final DateTime? focalDate;
  final NbaGameTeam homeTeam;
  final NbaGameTeam awayTeam;
  final List<NbaRelatedGame> relatedGames;
  final int priorMeetings;
  final int homePriorWins;
  final int awayPriorWins;
  final NbaTeamEnteringForm homeEnteringForm;
  final NbaTeamEnteringForm awayEnteringForm;
  final List<NbaPlayerEnteringForm> playerEnteringForms;
  final int teamWindow;
  final int playerWindow;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  List<NbaRelatedGame> get priorRelatedGames =>
      relatedGames.where((game) => game.beforeFocalGame).toList(growable: false);
}

class NbaRelatedGame {
  const NbaRelatedGame({
    required this.gameId,
    required this.gameDate,
    required this.parsedDate,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.beforeFocalGame,
  });

  final String gameId;
  final String gameDate;
  final DateTime? parsedDate;
  final String homeTeamId;
  final String awayTeamId;
  final int? homeScore;
  final int? awayScore;
  final String status;
  final bool beforeFocalGame;

  bool get hasScore => homeScore != null && awayScore != null;
  String get winnerTeamId {
    if (!hasScore || homeScore == awayScore) return '';
    return homeScore! > awayScore! ? homeTeamId : awayTeamId;
  }

  String get matchupLabel => '$awayTeamId @ $homeTeamId';
  String get scoreLabel => hasScore ? '$awayScore–$homeScore' : '—';
}

class NbaTeamEnteringForm {
  const NbaTeamEnteringForm({
    required this.teamId,
    required this.windowRequested,
    required this.games,
    required this.wins,
    required this.losses,
    required this.pointsForPerGame,
    required this.pointsAgainstPerGame,
    required this.marginPerGame,
    required this.streakLabel,
    required this.lastGameId,
    required this.lastGameDate,
  });

  factory NbaTeamEnteringForm.empty({
    required String teamId,
    required int windowRequested,
  }) =>
      NbaTeamEnteringForm(
        teamId: teamId,
        windowRequested: windowRequested,
        games: 0,
        wins: 0,
        losses: 0,
        pointsForPerGame: null,
        pointsAgainstPerGame: null,
        marginPerGame: null,
        streakLabel: '—',
        lastGameId: '',
        lastGameDate: '',
      );

  final String teamId;
  final int windowRequested;
  final int games;
  final int wins;
  final int losses;
  final double? pointsForPerGame;
  final double? pointsAgainstPerGame;
  final double? marginPerGame;
  final String streakLabel;
  final String lastGameId;
  final String lastGameDate;

  String get recordLabel => games == 0 ? '—' : '$wins–$losses';
}

class NbaPlayerEnteringForm {
  const NbaPlayerEnteringForm({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.windowRequested,
    required this.games,
    required this.pointsPerGame,
    required this.reboundsPerGame,
    required this.assistsPerGame,
    required this.plusMinusPerGame,
    required this.lastGameId,
    required this.lastGameDate,
  });

  final String playerId;
  final String playerName;
  final String teamId;
  final int windowRequested;
  final int games;
  final double? pointsPerGame;
  final double? reboundsPerGame;
  final double? assistsPerGame;
  final double? plusMinusPerGame;
  final String lastGameId;
  final String lastGameDate;
}

class _ContextGame {
  const _ContextGame({
    required this.gameId,
    required this.gameDate,
    required this.parsedDate,
    required this.seasonId,
    required this.seasonType,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeScore,
    required this.awayScore,
    required this.status,
  });

  final String gameId;
  final String gameDate;
  final DateTime? parsedDate;
  final String seasonId;
  final String seasonType;
  final String homeTeamId;
  final String awayTeamId;
  final int? homeScore;
  final int? awayScore;
  final String status;

  bool get hasScore => homeScore != null && awayScore != null;
}

bool _sameSeason(_ContextGame candidate, NbaGameIntelligenceSnapshot focal) {
  if (focal.seasonId.isNotEmpty &&
      candidate.seasonId.isNotEmpty &&
      _normalize(candidate.seasonId) != _normalize(focal.seasonId)) {
    return false;
  }
  if (focal.seasonType.isNotEmpty &&
      candidate.seasonType.isNotEmpty &&
      _normalizeSeasonType(candidate.seasonType) !=
          _normalizeSeasonType(focal.seasonType)) {
    return false;
  }
  return true;
}

bool _sameMatchup(_ContextGame game, String firstTeam, String secondTeam) {
  final home = _normalize(game.homeTeamId);
  final away = _normalize(game.awayTeamId);
  final first = _normalize(firstTeam);
  final second = _normalize(secondTeam);
  return (home == first && away == second) ||
      (home == second && away == first);
}

bool _containsTeam(_ContextGame game, String teamId) {
  final target = _normalize(teamId);
  return _normalize(game.homeTeamId) == target || _normalize(game.awayTeamId) == target;
}

int _compareDates(DateTime? left, DateTime? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

String _normalize(String value) => value.trim().toUpperCase();

String _normalizeSeasonType(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('-', '_')
    .replaceAll(' ', '_')
    .replaceAll('postseason', 'playoffs')
    .replaceAll('playoff', 'playoffs');

DateTime? _parseDate(String value) {
  if (value.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
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

double? _average(List<int?> values) =>
    _averageNum(values.whereType<int>().toList(growable: false));

double? _averageNum(List<num?> values) {
  final present = values.whereType<num>().toList(growable: false);
  if (present.isEmpty) return null;
  return present.fold<double>(0, (sum, value) => sum + value.toDouble()) /
      present.length;
}
