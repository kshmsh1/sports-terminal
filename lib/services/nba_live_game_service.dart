import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class NbaScheduledGame {
  const NbaScheduledGame({
    required this.gameId,
    required this.date,
    required this.gameLabel,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeTricode,
    required this.awayTricode,
    required this.timeEt,
    required this.datetimeUtc,
    required this.nationalTv,
    required this.arena,
  });

  final String gameId;
  final String date;
  final String gameLabel;
  final String homeTeam;
  final String awayTeam;
  final String homeTricode;
  final String awayTricode;
  final String timeEt;
  final String datetimeUtc;
  final String nationalTv;
  final String arena;

  factory NbaScheduledGame.fromMap(Map<String, dynamic> map) {
    final home = _map(map['home_team']);
    final away = _map(map['away_team']);
    return NbaScheduledGame(
      gameId: _text(map['game_id']),
      date: _text(map['date']),
      gameLabel: _text(map['game_label']),
      homeTeam: _teamName(home),
      awayTeam: _teamName(away),
      homeTricode: _text(home['tricode']),
      awayTricode: _text(away['tricode']),
      timeEt: _text(map['time_et']),
      datetimeUtc: _text(map['datetime_utc']),
      nationalTv: _text(map['national_tv']),
      arena: _text(map['arena']),
    );
  }
}

class NbaScheduleSnapshot {
  const NbaScheduleSnapshot({
    required this.dates,
    required this.games,
    required this.source,
    required this.subjectToChange,
  });

  final List<String> dates;
  final List<NbaScheduledGame> games;
  final String source;
  final bool subjectToChange;

  List<NbaScheduledGame> forDate(String date) =>
      games.where((game) => game.date == date).toList(growable: false);
}

class NbaLiveGameState {
  const NbaLiveGameState({
    required this.gameId,
    required this.status,
    required this.statusText,
    required this.clock,
    required this.period,
    required this.homeTricode,
    required this.awayTricode,
    required this.homeScore,
    required this.awayScore,
    required this.homeRecord,
    required this.awayRecord,
  });

  final String gameId;
  final int status;
  final String statusText;
  final String clock;
  final int period;
  final String homeTricode;
  final String awayTricode;
  final int? homeScore;
  final int? awayScore;
  final String homeRecord;
  final String awayRecord;

  bool get isLive => status == 2;
  bool get isFinal => status == 3;

  factory NbaLiveGameState.fromMap(Map<String, dynamic> map) {
    final home = _map(map['homeTeam']);
    final away = _map(map['awayTeam']);
    return NbaLiveGameState(
      gameId: _text(map['gameId']),
      status: _int(map['gameStatus']) ?? 0,
      statusText: _text(map['gameStatusText']),
      clock: _text(map['gameClock']),
      period: _int(map['period']) ?? 0,
      homeTricode: _text(home['teamTricode']),
      awayTricode: _text(away['teamTricode']),
      homeScore: _int(home['score']),
      awayScore: _int(away['score']),
      homeRecord: _record(home),
      awayRecord: _record(away),
    );
  }
}

class NbaLiveGameService {
  NbaLiveGameService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  NbaScheduleSnapshot? _schedule;

  static const schedulePath = 'data/nba_live/schedule_2026_27.json';
  Future<NbaScheduleSnapshot> schedule() async {
    final cached = _schedule;
    if (cached != null) return cached;
    final uri = Uri.base.resolve(schedulePath);
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NbaLiveGameException(
        '2026-27 schedule snapshot is unavailable (${response.statusCode}). Run the Sports Terminal launcher once to materialize it.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const NbaLiveGameException('2026-27 schedule snapshot has an invalid shape.');
    }
    final payload = Map<String, dynamic>.from(decoded);
    final games = [
      for (final item in _list(payload['games']))
        if (item is Map)
          NbaScheduledGame.fromMap(Map<String, dynamic>.from(item)),
    ];
    final dates = <String>{
      ..._list(payload['dates']).map((item) => _text(item)).where((item) => item.isNotEmpty),
      ...games.map((game) => game.date).where((item) => item.isNotEmpty),
    }.toList()
      ..sort();
    final result = NbaScheduleSnapshot(
      dates: dates,
      games: games,
      source: _text(payload['source']),
      subjectToChange: payload['subject_to_change'] != false,
    );
    _schedule = result;
    return result;
  }

  /// Live network access is deliberately disabled. Sports Terminal runtime data
  /// is snapshot-only; callers receive no mutable scoreboard overlay.
  Future<Map<String, NbaLiveGameState>> todayScoreboard() async => const {};

  /// Live box-score endpoints are deliberately disabled. Completed box scores
  /// are served from the immutable historical/static corpus instead.
  Future<Map<String, dynamic>> liveBoxScore(String gameId) {
    throw const NbaLiveGameException(
      'Live network box scores are disabled. Use the static Box Scores archive.',
    );
  }
}

class NbaLiveGameException implements Exception {
  const NbaLiveGameException(this.message);
  final String message;

  @override
  String toString() => message;
}

String _teamName(Map<String, dynamic> team) {
  final city = _text(team['city']);
  final name = _text(team['name']);
  final combined = [city, name].where((item) => item.isNotEmpty).join(' ');
  return combined.isNotEmpty ? combined : _text(team['tricode'], 'Team');
}

String _record(Map<String, dynamic> team) {
  final wins = _int(team['wins']);
  final losses = _int(team['losses']);
  if (wins == null || losses == null) return '';
  return '$wins-$losses';
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _text(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text.toLowerCase() == 'null' ? fallback : text;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}
