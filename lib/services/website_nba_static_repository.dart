import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nba_terminal_seed_repository.dart';

class WebsiteNbaStaticSeason {
  const WebsiteNbaStaticSeason({
    required this.id,
    required this.label,
    required this.startYear,
    required this.playerCount,
    required this.teamCount,
    required this.gameCount,
  });

  final String id;
  final String label;
  final int startYear;
  final int playerCount;
  final int teamCount;
  final int gameCount;

  factory WebsiteNbaStaticSeason.fromMap(Map<String, dynamic> map) {
    final id = (map['season_id'] ?? '').toString();
    return WebsiteNbaStaticSeason(
      id: id,
      label: (map['label'] ?? id).toString(),
      startYear: _int(map['start_year']) ?? _seasonStart(id),
      playerCount: _int(map['players']) ?? 0,
      teamCount: _int(map['teams']) ?? 0,
      gameCount: _int(map['games']) ?? 0,
    );
  }
}

class WebsiteNbaStaticRepository {
  WebsiteNbaStaticRepository({
    http.Client? client,
    this.basePath = 'data/nba_static',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String basePath;

  Map<String, dynamic>? _manifest;
  List<WebsiteNbaStaticSeason>? _seasons;
  List<Map<String, dynamic>>? _players;
  List<Map<String, dynamic>>? _teams;
  List<Map<String, dynamic>>? _games;
  final Map<String, Map<String, dynamic>> _dashboardCache = {};
  final Map<String, NbaTerminalSeedSnapshot> _seasonCache = {};
  final Map<String, Map<String, dynamic>> _playerCache = {};
  final Map<String, Map<String, dynamic>> _teamCache = {};
  final Map<String, Map<String, dynamic>> _gameCache = {};
  final Map<String, List<Map<String, dynamic>>> _pbpCache = {};

  Future<Map<String, dynamic>> manifest() async {
    return _manifest ??= await _object('manifest.json');
  }

  Future<List<WebsiteNbaStaticSeason>> seasons() async {
    if (_seasons != null) return _seasons!;
    final raw = await _list('seasons.json');
    final result = [
      for (final row in raw) WebsiteNbaStaticSeason.fromMap(row),
    ]..sort((a, b) => b.startYear.compareTo(a.startYear));
    _seasons = result;
    return result;
  }

  Future<Map<String, dynamic>> seasonDashboard(String season) async {
    final normalized = season.trim();
    final cached = _dashboardCache[normalized];
    if (cached != null) return cached;
    final payload = await _object('dashboard/$normalized.json');
    _dashboardCache[normalized] = payload;
    return payload;
  }

  Future<List<Map<String, dynamic>>> playerIndex() async {
    return _players ??= await _list('players/index.json');
  }

  Future<List<Map<String, dynamic>>> teamIndex() async {
    return _teams ??= await _list('teams/index.json');
  }

  Future<List<Map<String, dynamic>>> gameIndex() async {
    return _games ??= await _list('games/index.json');
  }

  Future<NbaTerminalSeedSnapshot> seasonSnapshot(
    String season, {
    String seasonType = 'regular',
  }) async {
    final normalizedSeason = season.trim();
    final normalizedType = seasonType.toLowerCase().contains('play')
        ? 'playoffs'
        : 'regular';
    final key = '$normalizedSeason/$normalizedType';
    final cached = _seasonCache[key];
    if (cached != null) return cached;
    final payload = await _object('seasons/$normalizedSeason/$normalizedType.json');
    final snapshot = NbaTerminalSeedSnapshot.fromMap(payload);
    _seasonCache[key] = snapshot;
    return snapshot;
  }

  Future<Map<String, dynamic>> playerDossier(String playerKey) async {
    final cached = _playerCache[playerKey];
    if (cached != null) return cached;
    final index = await playerIndex();
    Map<String, dynamic>? match;
    for (final row in index) {
      if (row['player_key']?.toString() == playerKey) {
        match = row;
        break;
      }
    }
    if (match == null) {
      throw WebsiteNbaStaticException('Historical player not found: $playerKey');
    }
    final file = match['file']?.toString() ?? '';
    if (file.isEmpty) {
      throw WebsiteNbaStaticException('Static player file is missing for $playerKey');
    }
    final dossier = await _object(file);
    _playerCache[playerKey] = dossier;
    return dossier;
  }

  Future<Map<String, dynamic>> teamDossier(String teamKey) async {
    final resolved = await resolveTeamKey(teamKey);
    if (resolved == null) {
      throw WebsiteNbaStaticException('Historical team not found: $teamKey');
    }
    final cached = _teamCache[resolved];
    if (cached != null) return cached;
    final index = await teamIndex();
    Map<String, dynamic>? match;
    for (final row in index) {
      if (row['team_key']?.toString() == resolved) {
        match = row;
        break;
      }
    }
    if (match == null) {
      throw WebsiteNbaStaticException('Static team index is missing $resolved');
    }
    final file = match['file']?.toString() ?? '';
    if (file.isEmpty) {
      throw WebsiteNbaStaticException('Static team file is missing for $resolved');
    }
    final dossier = await _object(file);
    _teamCache[resolved] = dossier;
    return dossier;
  }

  Future<Map<String, dynamic>> gameDetail(String gameKey) async {
    final cached = _gameCache[gameKey];
    if (cached != null) return cached;
    final match = await _gameIndexRow(gameKey);
    final file = match?['file']?.toString() ?? '';
    if (file.isEmpty) {
      throw WebsiteNbaStaticException(
        'Static game detail has not been materialized for $gameKey',
      );
    }
    final detail = await _object(file);
    _gameCache[gameKey] = detail;
    return detail;
  }

  Future<List<Map<String, dynamic>>> gamePlayByPlay(String gameKey) async {
    final cached = _pbpCache[gameKey];
    if (cached != null) return cached;
    final match = await _gameIndexRow(gameKey);
    final file = match?['pbp_file']?.toString() ?? '';
    if (file.isEmpty) return const [];
    final payload = await _object(file);
    final rows = _mapList(payload['rows']);
    _pbpCache[gameKey] = rows;
    return rows;
  }

  Future<Map<String, dynamic>?> _gameIndexRow(String gameKey) async {
    for (final row in await gameIndex()) {
      if (row['game_key']?.toString() == gameKey ||
          row['nba_game_id']?.toString() == gameKey) {
        return row;
      }
    }
    return null;
  }

  Future<String?> resolveTeamKey(String idOrAbbreviation) async {
    final value = idOrAbbreviation.trim();
    if (value.isEmpty) return null;
    final needle = value.toLowerCase();
    final teams = await teamIndex();
    Map<String, dynamic>? partial;
    for (final row in teams) {
      final key = (row['team_key'] ?? '').toString();
      final abbr = (row['abbreviation'] ?? '').toString();
      final name = (row['canonical_name'] ?? '').toString();
      if (key.toLowerCase() == needle || abbr.toLowerCase() == needle) {
        return key;
      }
      if (partial == null && name.toLowerCase().contains(needle)) partial = row;
    }
    return partial?['team_key']?.toString();
  }

  Future<Map<String, dynamic>> searchEntities(
    String query, {
    String kinds = 'player,team',
    int limitPerKind = 12,
  }) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return {'query': '', 'league': 'NBA', 'groups': <String, dynamic>{}, 'count': 0};
    }
    final requested = kinds
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
    final groups = <String, dynamic>{};
    if (requested.contains('player')) {
      final players = await playerIndex();
      final matches = players.where((row) {
        final haystack = [
          row['canonical_name'],
          row['bref_id'],
          row['nba_id'],
          row['primary_position'],
        ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
        return haystack.contains(needle);
      }).take(limitPerKind).map((row) => {
            ...row,
            'player_key': row['player_key'],
            'canonical_name': row['canonical_name'],
          }).toList();
      groups['players'] = matches;
    }
    if (requested.contains('team')) {
      final teams = await teamIndex();
      final matches = teams.where((row) {
        final haystack = [
          row['canonical_name'],
          row['abbreviation'],
          row['franchise_key'],
        ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
        return haystack.contains(needle);
      }).take(limitPerKind).toList();
      groups['teams'] = matches;
    }
    final count = groups.values
        .whereType<List>()
        .fold<int>(0, (sum, list) => sum + list.length);
    return {'query': query.trim(), 'league': 'NBA', 'groups': groups, 'count': count};
  }

  Future<List<Map<String, dynamic>>> awards() => _list('history/awards.json');
  Future<List<Map<String, dynamic>>> allStar() => _list('history/all_star.json');
  Future<List<Map<String, dynamic>>> draft() => _list('history/draft.json');
  Future<List<Map<String, dynamic>>> coverage() => _list('history/coverage.json');

  Future<Map<String, dynamic>> _object(String relative) async {
    final decoded = await _json(relative);
    if (decoded is! Map) {
      throw WebsiteNbaStaticException('Static NBA document has an invalid shape: $relative');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<List<Map<String, dynamic>>> _list(String relative) async {
    final decoded = await _json(relative);
    if (decoded is! List) {
      throw WebsiteNbaStaticException('Static NBA list has an invalid shape: $relative');
    }
    return _mapList(decoded);
  }

  Future<Object?> _json(String relative) async {
    final uri = Uri.base.resolve('${_normalizedBase()}/$relative');
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw WebsiteNbaStaticException(
          'Static NBA data is unavailable (${response.statusCode}): $relative',
        );
      }
      return jsonDecode(response.body);
    } on TimeoutException {
      throw WebsiteNbaStaticException('Static NBA file timed out: $relative');
    } on WebsiteNbaStaticException {
      rethrow;
    } catch (error) {
      throw WebsiteNbaStaticException('Unable to read static NBA data $relative: $error');
    }
  }

  String _normalizedBase() => basePath.replaceAll(RegExp(r'^/+|/+$'), '');
}

class WebsiteNbaStaticException implements Exception {
  const WebsiteNbaStaticException(this.message);
  final String message;

  @override
  String toString() => message;
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map)
        item.map((key, field) => MapEntry(key.toString(), field)),
  ];
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

int _seasonStart(String value) {
  final match = RegExp(r'(19|20)\d{2}').firstMatch(value);
  return match == null ? 0 : int.tryParse(match.group(0) ?? '') ?? 0;
}
