enum NbaStatOperator { greaterThan, greaterThanOrEqual, lessThan, lessThanOrEqual, equal, between }

class NbaStatConstraint {
  const NbaStatConstraint({required this.field, required this.operator, required this.value, this.secondValue});

  final String field;
  final NbaStatOperator operator;
  final double value;
  final double? secondValue;

  bool matches(Map<String, dynamic> row) {
    final raw = row[field];
    final actual = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (actual == null) return false;
    switch (operator) {
      case NbaStatOperator.greaterThan:
        return actual > value;
      case NbaStatOperator.greaterThanOrEqual:
        return actual >= value;
      case NbaStatOperator.lessThan:
        return actual < value;
      case NbaStatOperator.lessThanOrEqual:
        return actual <= value;
      case NbaStatOperator.equal:
        return actual == value;
      case NbaStatOperator.between:
        return secondValue != null && actual >= value && actual <= secondValue!;
    }
  }
}

class NbaStatsQueryPlan {
  const NbaStatsQueryPlan({
    required this.originalQuery,
    required this.constraints,
    required this.sortField,
    required this.sortDescending,
    required this.limit,
    required this.seasonType,
    required this.basis,
    required this.unparsedFragments,
  });

  final String originalQuery;
  final List<NbaStatConstraint> constraints;
  final String? sortField;
  final bool sortDescending;
  final int? limit;
  final String seasonType;
  final String basis;
  final List<String> unparsedFragments;

  List<Map<String, dynamic>> apply(Iterable<Map<String, dynamic>> source) {
    var rows = source.where((row) => constraints.every((constraint) => constraint.matches(row))).toList();
    final field = sortField;
    if (field != null) {
      rows.sort((a, b) {
        final left = _number(a[field]);
        final right = _number(b[field]);
        final comparison = left.compareTo(right);
        return sortDescending ? -comparison : comparison;
      });
    }
    if (limit != null && rows.length > limit!) rows = rows.take(limit!).toList();
    return rows;
  }

  static double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? double.negativeInfinity;
}

class NbaStatsQueryEngine {
  const NbaStatsQueryEngine();

  static const Map<String, String> _aliases = {
    'age': 'age',
    'games': 'gp',
    'gp': 'gp',
    'minutes': 'mpg',
    'mpg': 'mpg',
    'points': 'ppg',
    'ppg': 'ppg',
    'rebounds': 'rpg',
    'rpg': 'rpg',
    'assists': 'apg',
    'apg': 'apg',
    'steals': 'spg',
    'spg': 'spg',
    'blocks': 'bpg',
    'bpg': 'bpg',
    'turnovers': 'tov',
    'tov': 'tov',
    'fouls': 'pf',
    'pf': 'pf',
    'fg%': 'fg_pct',
    'field goal percentage': 'fg_pct',
    '3p%': 'three_pct',
    'three point percentage': 'three_pct',
    'ft%': 'ft_pct',
    'free throw percentage': 'ft_pct',
    '+/-': 'plus_minus',
    'plus minus': 'plus_minus',
  };

  NbaStatsQueryPlan parse(String input, {String defaultSeasonType = 'Regular Season', String defaultBasis = 'Per Game'}) {
    final query = input.toLowerCase().replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final constraints = <NbaStatConstraint>[];
    final matchedRanges = <String>[];

    for (final entry in _aliases.entries) {
      final escaped = RegExp.escape(entry.key);
      final patterns = <RegExp, NbaStatOperator>{
        RegExp('(?:$escaped)\\s*(?:>|over|more than|greater than)\\s*(\\d+(?:\\.\\d+)?)'): NbaStatOperator.greaterThan,
        RegExp('(?:$escaped)\\s*(?:>=|at least|no fewer than)\\s*(\\d+(?:\\.\\d+)?)'): NbaStatOperator.greaterThanOrEqual,
        RegExp('(?:$escaped)\\s*(?:<|under|less than|fewer than)\\s*(\\d+(?:\\.\\d+)?)'): NbaStatOperator.lessThan,
        RegExp('(?:$escaped)\\s*(?:<=|at most|no more than)\\s*(\\d+(?:\\.\\d+)?)'): NbaStatOperator.lessThanOrEqual,
        RegExp('(?:$escaped)\\s*(?:=|equal to|exactly)\\s*(\\d+(?:\\.\\d+)?)'): NbaStatOperator.equal,
      };
      for (final pattern in patterns.entries) {
        for (final match in pattern.key.allMatches(query)) {
          final value = double.parse(match.group(1)!);
          constraints.add(NbaStatConstraint(field: entry.value, operator: pattern.value, value: _normalizePercent(entry.value, value)));
          matchedRanges.add(match.group(0)!);
        }
      }
    }

    final ageAtEnd = RegExp(r'(?:over|older than|age above)\s+(\d+(?:\.\d+)?)').firstMatch(query);
    if (ageAtEnd != null && !constraints.any((item) => item.field == 'age')) {
      constraints.add(NbaStatConstraint(field: 'age', operator: NbaStatOperator.greaterThan, value: double.parse(ageAtEnd.group(1)!)));
      matchedRanges.add(ageAtEnd.group(0)!);
    }

    final limitMatch = RegExp(r'(?:top|first|show|list)\s+(\d+)').firstMatch(query);
    final limit = limitMatch == null ? null : int.parse(limitMatch.group(1)!);
    if (limitMatch != null) matchedRanges.add(limitMatch.group(0)!);

    String? sortField;
    var descending = true;
    final sortMatch = RegExp(r'(?:sort(?:ed)? by|highest|lowest|leaders? in)\s+([a-z0-9%+\-/ ]+)').firstMatch(query);
    if (sortMatch != null) {
      final phrase = sortMatch.group(1)!.trim();
      sortField = _resolveAlias(phrase);
      descending = !query.contains('lowest');
      matchedRanges.add(sortMatch.group(0)!);
    }

    final seasonType = query.contains('playoff') || query.contains('postseason') ? 'Playoffs' : defaultSeasonType;
    final basis = query.contains('per 36')
        ? 'Per 36 Minutes'
        : query.contains('per 100')
            ? 'Per 100 Possessions'
            : query.contains('totals')
                ? 'Totals'
                : defaultBasis;

    final residue = matchedRanges.fold<String>(query, (value, fragment) => value.replaceFirst(fragment, ' ')).replaceAll(RegExp(r'\s+'), ' ').trim();
    final unparsed = residue.isEmpty ? <String>[] : <String>[residue];

    return NbaStatsQueryPlan(
      originalQuery: input,
      constraints: _deduplicate(constraints),
      sortField: sortField,
      sortDescending: descending,
      limit: limit,
      seasonType: seasonType,
      basis: basis,
      unparsedFragments: unparsed,
    );
  }

  static String? _resolveAlias(String phrase) {
    for (final entry in _aliases.entries) {
      if (phrase.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static double _normalizePercent(String field, double value) {
    if ((field == 'fg_pct' || field == 'three_pct' || field == 'ft_pct') && value > 1) return value / 100;
    return value;
  }

  static List<NbaStatConstraint> _deduplicate(List<NbaStatConstraint> constraints) {
    final seen = <String>{};
    return constraints.where((item) => seen.add('${item.field}:${item.operator}:${item.value}:${item.secondValue}')).toList();
  }
}
