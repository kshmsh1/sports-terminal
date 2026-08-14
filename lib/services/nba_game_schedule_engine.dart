import 'nba_terminal_seed_repository.dart';

class NbaGameScheduleEngine {
  const NbaGameScheduleEngine();

  NbaGameScheduleResult build(
    NbaTerminalSeedSnapshot seed, {
    String query = '',
    String teamId = '',
    String status = 'All',
    String seasonType = 'All',
    DateTime? dateFrom,
    DateTime? dateTo,
    bool ascending = true,
  }) {
    final teams = <String, _TeamIdentity>{};
    for (final row in seed.teams) {
      final id = _text(row, const ['team_id', 'teamId', 'id', 'abbreviation']);
      if (id.isEmpty) continue;
      teams[_normalize(id)] = _TeamIdentity(
        id: id,
        name: _text(row, const ['team_name', 'teamName', 'full_name', 'name'], fallback: id),
        abbreviation: _text(
          row,
          const ['abbreviation', 'team_abbreviation', 'tricode', 'team_id'],
          fallback: id,
        ),
      );
    }

    final normalizedQuery = query.trim().toLowerCase();
    final normalizedTeam = _normalize(teamId);
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedSeasonType = seasonType.trim().toLowerCase();
    final fromDay = dateFrom == null ? null : _day(dateFrom);
    final toDay = dateTo == null ? null : _day(dateTo);

    final rows = <NbaGameScheduleRow>[];
    for (final raw in seed.games) {
      final gameId = _text(raw, const ['game_id', 'gameId', 'id']);
      if (gameId.isEmpty) continue;
      final awayId = _text(
        raw,
        const ['away_team_id', 'awayTeamId', 'visitor_team_id', 'away_team', 'away'],
      );
      final homeId = _text(raw, const ['home_team_id', 'homeTeamId', 'home_team', 'home']);
      final away = teams[_normalize(awayId)] ?? _TeamIdentity.fromId(awayId);
      final home = teams[_normalize(homeId)] ?? _TeamIdentity.fromId(homeId);
      final dateText = _text(raw, const ['game_date', 'gameDate', 'date']);
      final parsedDate = _parseDate(dateText);
      final rowStatus = _text(raw, const ['status', 'game_status_text', 'game_status', 'result']);
      final rowSeasonType = _text(raw, const ['season_type', 'seasonType', 'game_type']);
      final awayScore = _integer(
        raw,
        const ['away_score', 'awayScore', 'visitor_score', 'away_points', 'pts_away'],
      );
      final homeScore = _integer(
        raw,
        const ['home_score', 'homeScore', 'home_points', 'pts_home'],
      );
      final searchable = [
        gameId,
        dateText,
        away.id,
        away.name,
        away.abbreviation,
        home.id,
        home.name,
        home.abbreviation,
        rowStatus,
        rowSeasonType,
        _text(raw, const ['arena', 'arena_name', 'venue']),
        _text(raw, const ['city', 'arena_city', 'location']),
      ].join(' ').toLowerCase();

      if (normalizedQuery.isNotEmpty && !searchable.contains(normalizedQuery)) continue;
      if (normalizedTeam.isNotEmpty &&
          normalizedTeam != 'ALL' &&
          _normalize(away.id) != normalizedTeam &&
          _normalize(home.id) != normalizedTeam) {
        continue;
      }
      if (normalizedStatus.isNotEmpty && normalizedStatus != 'all') {
        if (rowStatus.toLowerCase() != normalizedStatus) continue;
      }
      if (normalizedSeasonType.isNotEmpty && normalizedSeasonType != 'all') {
        if (_normalizeSeasonType(rowSeasonType) != _normalizeSeasonType(seasonType)) {
          continue;
        }
      }
      if (parsedDate != null) {
        final day = _day(parsedDate);
        if (fromDay != null && day.isBefore(fromDay)) continue;
        if (toDay != null && day.isAfter(toDay)) continue;
      } else if (fromDay != null || toDay != null) {
        continue;
      }

      rows.add(
        NbaGameScheduleRow(
          gameId: gameId,
          gameDate: dateText,
          parsedDate: parsedDate,
          seasonId: _text(
            raw,
            const ['season_id', 'seasonId', 'season', 'season_label'],
            fallback: seed.supportedSeason,
          ),
          seasonType: rowSeasonType,
          status: rowStatus,
          awayTeamId: away.id,
          awayTeamName: away.name,
          awayTeamAbbreviation: away.abbreviation,
          homeTeamId: home.id,
          homeTeamName: home.name,
          homeTeamAbbreviation: home.abbreviation,
          awayScore: awayScore,
          homeScore: homeScore,
          arena: _text(raw, const ['arena', 'arena_name', 'venue']),
          city: _text(raw, const ['city', 'arena_city', 'location']),
          sourceId: _text(raw, const ['source_id', 'sourceId', 'source']),
        ),
      );
    }

    rows.sort((left, right) {
      final leftDate = left.parsedDate;
      final rightDate = right.parsedDate;
      int result;
      if (leftDate == null && rightDate == null) {
        result = left.gameId.compareTo(right.gameId);
      } else if (leftDate == null) {
        result = 1;
      } else if (rightDate == null) {
        result = -1;
      } else {
        result = leftDate.compareTo(rightDate);
        if (result == 0) result = left.gameId.compareTo(right.gameId);
      }
      return ascending ? result : -result;
    });

    final statusOptions = <String>{'All'};
    final seasonTypeOptions = <String>{'All'};
    final teamOptions = <String>{};
    for (final raw in seed.games) {
      final rawStatus = _text(raw, const ['status', 'game_status_text', 'game_status', 'result']);
      final rawType = _text(raw, const ['season_type', 'seasonType', 'game_type']);
      final away = _text(raw, const ['away_team_id', 'awayTeamId', 'visitor_team_id', 'away_team', 'away']);
      final home = _text(raw, const ['home_team_id', 'homeTeamId', 'home_team', 'home']);
      if (rawStatus.isNotEmpty) statusOptions.add(rawStatus);
      if (rawType.isNotEmpty) seasonTypeOptions.add(rawType);
      if (away.isNotEmpty) teamOptions.add(away);
      if (home.isNotEmpty) teamOptions.add(home);
    }

    return NbaGameScheduleResult(
      rows: List.unmodifiable(rows),
      statusOptions: List.unmodifiable(statusOptions.toList()..sort(_allFirst)),
      seasonTypeOptions: List.unmodifiable(seasonTypeOptions.toList()..sort(_allFirst)),
      teamOptions: List.unmodifiable(teamOptions.toList()..sort()),
      datasetStatus: seed.datasetStatus,
      validationStatus: seed.validationStatus,
      historicalContext: seed.isHistorical,
      usedFallbackDataset: seed.usedFallback,
    );
  }
}

class NbaGameScheduleResult {
  const NbaGameScheduleResult({
    required this.rows,
    required this.statusOptions,
    required this.seasonTypeOptions,
    required this.teamOptions,
    required this.datasetStatus,
    required this.validationStatus,
    required this.historicalContext,
    required this.usedFallbackDataset,
  });

  final List<NbaGameScheduleRow> rows;
  final List<String> statusOptions;
  final List<String> seasonTypeOptions;
  final List<String> teamOptions;
  final String datasetStatus;
  final String validationStatus;
  final bool historicalContext;
  final bool usedFallbackDataset;

  int get completedGames => rows.where((row) => row.hasScore).length;
  int get scheduledGames => rows.length - completedGames;
  int get uniqueTeams => <String>{
        for (final row in rows) ...[row.awayTeamId, row.homeTeamId],
      }.where((value) => value.isNotEmpty).length;
}

class NbaGameScheduleRow {
  const NbaGameScheduleRow({
    required this.gameId,
    required this.gameDate,
    required this.parsedDate,
    required this.seasonId,
    required this.seasonType,
    required this.status,
    required this.awayTeamId,
    required this.awayTeamName,
    required this.awayTeamAbbreviation,
    required this.homeTeamId,
    required this.homeTeamName,
    required this.homeTeamAbbreviation,
    required this.awayScore,
    required this.homeScore,
    required this.arena,
    required this.city,
    required this.sourceId,
  });

  final String gameId;
  final String gameDate;
  final DateTime? parsedDate;
  final String seasonId;
  final String seasonType;
  final String status;
  final String awayTeamId;
  final String awayTeamName;
  final String awayTeamAbbreviation;
  final String homeTeamId;
  final String homeTeamName;
  final String homeTeamAbbreviation;
  final int? awayScore;
  final int? homeScore;
  final String arena;
  final String city;
  final String sourceId;

  bool get hasScore => awayScore != null && homeScore != null;
  String get matchupLabel => '$awayTeamAbbreviation @ $homeTeamAbbreviation';
  String get scoreLabel => hasScore ? '$awayScore–$homeScore' : '—';
  String get locationLabel => [arena, city].where((value) => value.isNotEmpty).join(' · ');
}

class _TeamIdentity {
  const _TeamIdentity({
    required this.id,
    required this.name,
    required this.abbreviation,
  });

  factory _TeamIdentity.fromId(String id) => _TeamIdentity(
        id: id,
        name: id,
        abbreviation: id,
      );

  final String id;
  final String name;
  final String abbreviation;
}

int _allFirst(String left, String right) {
  if (left == 'All') return right == 'All' ? 0 : -1;
  if (right == 'All') return 1;
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

DateTime _day(DateTime value) => DateTime.utc(value.year, value.month, value.day);

DateTime? _parseDate(String value) {
  if (value.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(value.trim());
  if (parsed != null) return _day(parsed.toUtc());
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
