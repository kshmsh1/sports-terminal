enum NbaStatOperator {
  greaterThan,
  greaterThanOrEqual,
  lessThan,
  lessThanOrEqual,
  equal,
  between,
}

class NbaStatConstraint {
  const NbaStatConstraint({
    required this.field,
    required this.operator,
    required this.value,
    this.secondValue,
  });

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
        final upper = secondValue;
        return upper != null && actual >= value && actual <= upper;
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

  List<Map<String, dynamic>> apply(
    Iterable<Map<String, dynamic>> source,
  ) {
    var rows = source
        .where(
          (row) => constraints.every((constraint) => constraint.matches(row)),
        )
        .toList();

    final field = sortField;
    if (field != null) {
      rows.sort((left, right) {
        final comparison = _number(left[field]).compareTo(_number(right[field]));
        return sortDescending ? -comparison : comparison;
      });
    }

    final rowLimit = limit;
    if (rowLimit != null && rows.length > rowLimit) {
      rows = rows.take(rowLimit).toList();
    }
    return rows;
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? double.negativeInfinity;
  }
}

class NbaStatsQueryEngine {
  const NbaStatsQueryEngine();

  static const Map<String, String> _aliases = {
    'field goal percentage': 'fg_pct',
    'three point percentage': 'three_pct',
    '3 point percentage': 'three_pct',
    'free throw percentage': 'ft_pct',
    'offensive rebounds': 'oreb',
    'defensive rebounds': 'dreb',
    'plus minus': 'plus_minus',
    'turnovers': 'tov',
    'rebounds': 'rpg',
    'assists': 'apg',
    'minutes': 'mpg',
    'points': 'ppg',
    'steals': 'spg',
    'blocks': 'bpg',
    'fouls': 'pf',
    'games': 'gp',
    'fg%': 'fg_pct',
    '3p%': 'three_pct',
    'ft%': 'ft_pct',
    '+/-': 'plus_minus',
    'oreb': 'oreb',
    'dreb': 'dreb',
    'ppg': 'ppg',
    'rpg': 'rpg',
    'apg': 'apg',
    'spg': 'spg',
    'bpg': 'bpg',
    'mpg': 'mpg',
    'tov': 'tov',
    'age': 'age',
    'gp': 'gp',
    'pf': 'pf',
  };

  static const String _operatorPattern =
      r'at least|no fewer than|not less than|at most|no more than|not more than|more than|greater than|older than|fewer than|less than|equal to|exactly|above|below|over|under|>=|<=|>|<|=';

  NbaStatsQueryPlan parse(
    String input, {
    String defaultSeasonType = 'Regular Season',
    String defaultBasis = 'Per Game',
  }) {
    final query = input
        .toLowerCase()
        .replaceAll(',', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final constraints = <NbaStatConstraint>[];
    final matched = <String>[];

    for (final entry in _aliases.entries) {
      _collectComparisons(
        query: query,
        alias: entry.key,
        field: entry.value,
        constraints: constraints,
        matched: matched,
      );
      _collectBetween(
        query: query,
        alias: entry.key,
        field: entry.value,
        constraints: constraints,
        matched: matched,
      );
    }

    _collectAgePhrase(query, constraints, matched);

    final limitMatch = RegExp(
      r'(?:top|first|show|list|limit(?:ed)? to)\s+(\d+)',
    ).firstMatch(query);
    final limit = limitMatch == null ? null : int.parse(limitMatch.group(1)!);
    if (limitMatch != null) matched.add(limitMatch.group(0)!);

    String? sortField;
    var sortDescending = true;
    final sortMatch = RegExp(
      r'(?:sort(?:ed)? by|leaders? in)\s+([a-z0-9%+\-/ ]+?)(?=\s+(?:ascending|descending|highest|lowest)|$)',
    ).firstMatch(query);
    if (sortMatch != null) {
      sortField = _resolveAlias(sortMatch.group(1)!.trim());
      sortDescending = !query.contains('ascending') && !query.contains('lowest');
      matched.add(sortMatch.group(0)!);
    } else {
      final rankedMatch = RegExp(
        r'(highest|lowest)\s+([a-z0-9%+\-/ ]+?)(?=\s+(?:among|for|with|in)|$)',
      ).firstMatch(query);
      if (rankedMatch != null) {
        sortDescending = rankedMatch.group(1) == 'highest';
        sortField = _resolveAlias(rankedMatch.group(2)!.trim());
        matched.add(rankedMatch.group(0)!);
      }
    }

    final seasonType = query.contains('playoff') || query.contains('postseason')
        ? 'Playoffs'
        : query.contains('combined') ||
                query.contains('regular season and playoffs')
            ? 'Combined'
            : defaultSeasonType;
    final basis = query.contains('per 36')
        ? 'Per 36 Minutes'
        : query.contains('per 100')
            ? 'Per 100 Possessions'
            : query.contains('total')
                ? 'Totals'
                : query.contains('per game')
                    ? 'Per Game'
                    : defaultBasis;

    final residue = _residue(query, matched);
    return NbaStatsQueryPlan(
      originalQuery: input,
      constraints: _deduplicate(constraints),
      sortField: sortField,
      sortDescending: sortDescending,
      limit: limit,
      seasonType: seasonType,
      basis: basis,
      unparsedFragments: residue.isEmpty ? const [] : [residue],
    );
  }

  static void _collectComparisons({
    required String query,
    required String alias,
    required String field,
    required List<NbaStatConstraint> constraints,
    required List<String> matched,
  }) {
    final escapedAlias = RegExp.escape(alias);
    const number = r'(\d+(?:\.\d+)?)';
    final fieldFirst = RegExp(
      '(?:^|[\\s(])($escapedAlias)\\s*($_operatorPattern)\\s*$number',
    );
    final operatorFirst = RegExp(
      '(?:^|[\\s(])($_operatorPattern)\\s*$number\\s*($escapedAlias)'
      r'(?=\s|[.;,)]|$)',
    );

    for (final match in fieldFirst.allMatches(query)) {
      final operatorText = match.group(2);
      final rawValue = match.group(3);
      if (operatorText == null || rawValue == null) continue;
      constraints.add(
        NbaStatConstraint(
          field: field,
          operator: _operator(operatorText),
          value: _normalizePercent(field, double.parse(rawValue)),
        ),
      );
      matched.add(match.group(0)!.trim());
    }

    for (final match in operatorFirst.allMatches(query)) {
      final operatorText = match.group(1);
      final rawValue = match.group(2);
      if (operatorText == null || rawValue == null) continue;
      constraints.add(
        NbaStatConstraint(
          field: field,
          operator: _operator(operatorText),
          value: _normalizePercent(field, double.parse(rawValue)),
        ),
      );
      matched.add(match.group(0)!.trim());
    }
  }

  static void _collectBetween({
    required String query,
    required String alias,
    required String field,
    required List<NbaStatConstraint> constraints,
    required List<String> matched,
  }) {
    final escapedAlias = RegExp.escape(alias);
    final rangeMatch = RegExp(
      '(?:^|[\\s(])($escapedAlias)\\s+(?:between|from)\\s+'
      r'(\d+(?:\.\d+)?)\s+(?:and|to)\s+(\d+(?:\.\d+)?)',
    ).firstMatch(query);
    if (rangeMatch == null) return;

    final first = double.parse(rangeMatch.group(2)!);
    final second = double.parse(rangeMatch.group(3)!);
    final lower = first <= second ? first : second;
    final upper = first <= second ? second : first;
    constraints.add(
      NbaStatConstraint(
        field: field,
        operator: NbaStatOperator.between,
        value: _normalizePercent(field, lower),
        secondValue: _normalizePercent(field, upper),
      ),
    );
    matched.add(rangeMatch.group(0)!.trim());
  }

  static void _collectAgePhrase(
    String query,
    List<NbaStatConstraint> constraints,
    List<String> matched,
  ) {
    if (constraints.any((constraint) => constraint.field == 'age')) return;
    final ageMatch = RegExp(
      r'(over|older than|above)\s+(?:the\s+)?age(?:\s+of)?\s+(\d+(?:\.\d+)?)|age\s+(over|above|greater than)\s+(\d+(?:\.\d+)?)',
    ).firstMatch(query);
    if (ageMatch == null) return;

    final rawValue = ageMatch.group(2) ?? ageMatch.group(4);
    if (rawValue == null) return;
    constraints.add(
      NbaStatConstraint(
        field: 'age',
        operator: NbaStatOperator.greaterThan,
        value: double.parse(rawValue),
      ),
    );
    matched.add(ageMatch.group(0)!);
  }

  static NbaStatOperator _operator(String raw) {
    final value = raw.trim();
    if (value == '>=' ||
        value == 'at least' ||
        value == 'no fewer than' ||
        value == 'not less than') {
      return NbaStatOperator.greaterThanOrEqual;
    }
    if (value == '<=' ||
        value == 'at most' ||
        value == 'no more than' ||
        value == 'not more than') {
      return NbaStatOperator.lessThanOrEqual;
    }
    if (value == '<' ||
        value == 'under' ||
        value == 'less than' ||
        value == 'fewer than' ||
        value == 'below') {
      return NbaStatOperator.lessThan;
    }
    if (value == '=' || value == 'equal to' || value == 'exactly') {
      return NbaStatOperator.equal;
    }
    return NbaStatOperator.greaterThan;
  }

  static String? _resolveAlias(String phrase) {
    for (final entry in _aliases.entries) {
      if (phrase == entry.key || phrase.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static double _normalizePercent(String field, double value) {
    final isPercentage =
        field == 'fg_pct' || field == 'three_pct' || field == 'ft_pct';
    return isPercentage && value > 1 ? value / 100 : value;
  }

  static List<NbaStatConstraint> _deduplicate(
    List<NbaStatConstraint> constraints,
  ) {
    final seen = <String>{};
    return constraints.where((constraint) {
      final key =
          '${constraint.field}:${constraint.operator}:${constraint.value}:${constraint.secondValue}';
      return seen.add(key);
    }).toList();
  }

  static String _residue(String query, List<String> matched) {
    var residue = query;
    for (final fragment in matched) {
      residue = residue.replaceFirst(fragment, ' ');
    }
    return residue
        .replaceAll(
          RegExp(
            r'\b(list|show|find|give me|all|players?|who|that|averaged?|average|with|and|but|at the end of|during|in the|the|of)\b',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'\b(playoffs?|postseason|regular season|combined)\b'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\b(per game|per 36 minutes?|per 100 possessions?|totals?)\b'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
