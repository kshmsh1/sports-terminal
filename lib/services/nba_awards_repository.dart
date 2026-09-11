import 'website_nba_static_repository.dart';

/// Static historical awards repository.
///
/// Awards are immutable historical data. The website now reads the compiled
/// `history/awards.json` and `history/all_star.json` files directly instead of
/// requiring the local FastAPI process merely to browse award history.
class NbaAwardsRepository {
  const NbaAwardsRepository();

  static final WebsiteNbaStaticRepository _static =
      WebsiteNbaStaticRepository();

  Future<Map<String, dynamic>> catalog({String league = 'NBA'}) async {
    final rows = await _allRows();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = row['award_key']?.toString() ?? 'other';
      groups.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(row);
    }

    final catalog = <Map<String, dynamic>>[];
    final unclassified = <String, int>{};
    for (final entry in groups.entries) {
      final definition = _definition(entry.key);
      if (definition.group == 'Other') {
        unclassified[definition.label] = entry.value.length;
      }
      final seasons = entry.value
          .map((row) => row['season_id']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .toList()
        ..sort();
      final winners = entry.value.where(_isWinner).length;
      final hasVoting = entry.value.any(
        (row) => row['share'] != null ||
            row['votes'] != null ||
            row['points'] != null ||
            row['first_place_votes'] != null,
      );
      catalog.add({
        'key': entry.key,
        'label': definition.label,
        'group': definition.group,
        'records': entry.value.length,
        'winners': winners,
        'has_voting': hasVoting,
        'first_season': seasons.isEmpty ? null : seasons.first,
        'last_season': seasons.isEmpty ? null : seasons.last,
      });
    }
    catalog.sort((a, b) {
      final groupCompare = '${a['group']}'.compareTo('${b['group']}');
      return groupCompare != 0
          ? groupCompare
          : '${a['label']}'.compareTo('${b['label']}');
    });

    return {
      'league': league.toUpperCase(),
      'catalog': catalog,
      'unclassified_records':
          unclassified.values.fold<int>(0, (sum, value) => sum + value),
      'unclassified_source_labels': [
        for (final entry in unclassified.entries)
          {'label': entry.key, 'records': entry.value},
      ],
      'runtime_api_required': false,
    };
  }

  Future<Map<String, dynamic>> history(
    String awardKey, {
    String league = 'NBA',
    String season = '',
    bool winnerOnly = false,
    int offset = 0,
    int limit = 500,
  }) async {
    final all = await _allRows();
    var rows = all.where((row) {
      if (row['award_key']?.toString() != awardKey) return false;
      if (season.isNotEmpty && row['season_id']?.toString() != season) {
        return false;
      }
      if (winnerOnly && !_isWinner(row)) return false;
      return true;
    }).toList()
      ..sort(_newestFirst);
    final matched = rows.length;
    final safeOffset = offset < 0 ? 0 : offset;
    if (safeOffset >= rows.length) {
      rows = <Map<String, dynamic>>[];
    } else {
      rows = rows.skip(safeOffset).take(limit < 1 ? 1 : limit).toList();
    }
    return {
      'league': league.toUpperCase(),
      'award_key': awardKey,
      'matched_rows': matched,
      'rows': rows,
      'runtime_api_required': false,
    };
  }

  Future<Map<String, dynamic>> season(
    String seasonId, {
    String league = 'NBA',
  }) async {
    final rows = (await _allRows())
        .where((row) => row['season_id']?.toString() == seasonId)
        .toList()
      ..sort((a, b) =>
          '${a['award_label']}'.compareTo('${b['award_label']}'));
    return {
      'league': league.toUpperCase(),
      'season_id': seasonId,
      'matched_rows': rows.length,
      'rows': rows,
      'runtime_api_required': false,
    };
  }

  Future<Map<String, dynamic>> player(
    String playerKey, {
    String league = '',
  }) async {
    final rows = (await _allRows())
        .where((row) => row['player_key']?.toString() == playerKey)
        .toList()
      ..sort(_newestFirst);
    return {
      if (league.isNotEmpty) 'league': league.toUpperCase(),
      'player_key': playerKey,
      'matched_rows': rows.length,
      'rows': rows,
      'runtime_api_required': false,
    };
  }

  Future<List<Map<String, dynamic>>> _allRows() async {
    final awardRows = await _static.awards();
    final allStarRows = await _static.allStar();
    return [
      for (final raw in awardRows) _normalize(raw),
      for (final raw in allStarRows)
        _normalize({
          ...raw,
          'award_key': 'all_star',
          'award': 'All-Star',
          'award_name': 'All-Star',
          'selected': true,
          'winner': true,
        }),
    ];
  }
}

Map<String, dynamic> _normalize(Map<String, dynamic> raw) {
  final row = Map<String, dynamic>.from(raw);
  final key = row['award_key']?.toString().trim();
  final resolvedKey = key != null && key.isNotEmpty
      ? key
      : _awardKey(
          '${row['award'] ?? ''} ${row['award_name'] ?? ''}',
          '${row['selection_team'] ?? ''} ${row['rank_text'] ?? ''}',
        );
  final definition = _definition(resolvedKey);
  row['award_key'] = resolvedKey;
  row['award_label'] = definition.label;
  row['winner'] = _truthy(row['winner']) || _truthy(row['selected']) ? 1 : 0;
  row['selected'] = _truthy(row['selected']) ? 1 : 0;
  row['source_key'] ??= row['source'] ?? 'static_nba_history';
  return row;
}

bool _truthy(Object? value) {
  if (value == true) return true;
  if (value is num) return value != 0;
  return const {'1', 'true', 'yes', 'winner', 'selected'}
      .contains(value?.toString().trim().toLowerCase());
}

bool _isWinner(Map<String, dynamic> row) =>
    _truthy(row['winner']) || _truthy(row['selected']);

int _newestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
  final season = '${b['season_id']}'.compareTo('${a['season_id']}');
  if (season != 0) return season;
  return '${a['player_name']}'.compareTo('${b['player_name']}');
}

String _awardKey(String rawValue, String tierValue) {
  final raw = rawValue.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');
  final tier = '$tierValue $raw'.toLowerCase();
  String teamSuffix() {
    if (tier.contains('first') || tier.contains('1st')) return 'first';
    if (tier.contains('second') || tier.contains('2nd')) return 'second';
    if (tier.contains('third') || tier.contains('3rd')) return 'third';
    return 'selection';
  }

  if (raw.contains('all star') && raw.contains('mvp')) {
    return 'all_star_game_mvp';
  }
  if (raw.contains('all star')) return 'all_star';
  if (raw.contains('eastern') && raw.contains('final') && raw.contains('mvp')) {
    return 'ecf_mvp';
  }
  if (raw.contains('western') && raw.contains('final') && raw.contains('mvp')) {
    return 'wcf_mvp';
  }
  if (raw.contains('final') && raw.contains('mvp')) return 'finals_mvp';
  if (raw.contains('cup') && raw.contains('mvp')) return 'nba_cup_mvp';
  if (raw.contains('all nba cup')) return 'all_nba_cup_team';
  if (raw.contains('all nba')) return 'all_nba_${teamSuffix()}';
  if (raw.contains('all defense') || raw.contains('all defensive')) {
    return 'all_defense_${teamSuffix()}';
  }
  if (raw.contains('all rookie')) return 'all_rookie_${teamSuffix()}';
  if (raw.contains('rookie') && raw.contains('year')) return 'rookie_of_year';
  if (raw.contains('defensive player') || raw.contains('dpoy')) return 'dpoy';
  if (raw.contains('most improved')) return 'most_improved';
  if (raw.contains('sixth') && raw.contains('man')) return 'sixth_man';
  if (raw.contains('clutch')) return 'clutch_player';
  if (raw.contains('sportsmanship')) return 'sportsmanship';
  if (raw.contains('teammate')) return 'teammate_of_year';
  if (raw.contains('social justice')) return 'social_justice';
  if (raw.contains('hustle')) return 'hustle_award';
  if (raw.contains('mvp') || raw.contains('most valuable')) return 'mvp';
  return raw
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

class _AwardDefinition {
  const _AwardDefinition(this.label, this.group);

  final String label;
  final String group;
}

_AwardDefinition _definition(String key) {
  const known = <String, _AwardDefinition>{
    'mvp': _AwardDefinition('Most Valuable Player', 'Annual Awards'),
    'dpoy': _AwardDefinition('Defensive Player of the Year', 'Annual Awards'),
    'rookie_of_year': _AwardDefinition('Rookie of the Year', 'Annual Awards'),
    'sixth_man': _AwardDefinition('Sixth Man of the Year', 'Annual Awards'),
    'most_improved': _AwardDefinition('Most Improved Player', 'Annual Awards'),
    'clutch_player': _AwardDefinition('Clutch Player of the Year', 'Annual Awards'),
    'finals_mvp': _AwardDefinition('Finals MVP', 'Postseason'),
    'ecf_mvp': _AwardDefinition('Eastern Conference Finals MVP', 'Postseason'),
    'wcf_mvp': _AwardDefinition('Western Conference Finals MVP', 'Postseason'),
    'all_nba_first': _AwardDefinition('First-Team All-NBA', 'All-League Teams'),
    'all_nba_second': _AwardDefinition('Second-Team All-NBA', 'All-League Teams'),
    'all_nba_third': _AwardDefinition('Third-Team All-NBA', 'All-League Teams'),
    'all_defense_first': _AwardDefinition('First-Team All-Defense', 'All-League Teams'),
    'all_defense_second': _AwardDefinition('Second-Team All-Defense', 'All-League Teams'),
    'all_rookie_first': _AwardDefinition('First-Team All-Rookie', 'All-League Teams'),
    'all_rookie_second': _AwardDefinition('Second-Team All-Rookie', 'All-League Teams'),
    'all_star': _AwardDefinition('All-Star', 'All-Star'),
    'all_star_game_mvp': _AwardDefinition('All-Star Game MVP', 'All-Star'),
    'nba_cup_mvp': _AwardDefinition('NBA Cup MVP', 'NBA Cup'),
    'all_nba_cup_team': _AwardDefinition('All-NBA Cup Team', 'NBA Cup'),
    'sportsmanship': _AwardDefinition('Sportsmanship Award', 'Community & Other'),
    'teammate_of_year': _AwardDefinition('Teammate of the Year', 'Community & Other'),
    'social_justice': _AwardDefinition('Social Justice Champion', 'Community & Other'),
    'hustle_award': _AwardDefinition('Hustle Award', 'Community & Other'),
  };
  final match = known[key];
  if (match != null) return match;
  final label = key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
  return _AwardDefinition(label.isEmpty ? 'Other' : label, 'Other');
}

class NbaAwardsException implements Exception {
  const NbaAwardsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
