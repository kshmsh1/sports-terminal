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

    return switch (operator) {
      NbaStatOperator.greaterThan => actual > value,
      NbaStatOperator.greaterThanOrEqual => actual >= value,
      NbaStatOperator.lessThan => actual < value,
      NbaStatOperator.lessThanOrEqual => actual <= value,
      NbaStatOperator.equal => actual == value,
      NbaStatOperator.between => secondValue != null &&
          actual >= value &&
          actual <= secondValue!,
    };
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
          (row) => constraints.every(
            (constraint) => constraint.matches(row),
          ),
        )
        .toList();

    final field = sortField;
    if (field != null) {
      rows.sort((left, right) {
        final comparison = _number(left[field]).compareTo(_number(right[field]));
        return sortDescending ? -comparison : comparison;
      });
    }

    if (limit != null && rows.length > limit!) {
      rows = rows.take(limit!).toList();
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
    'plus minus': 'plus_minus',
    'offensive rebounds': 'oreb',
    'defensive rebounds': 'dreb',
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
    final matchedFragments = <String>[];

    for (final alias in _aliases.entries) {
      final escapedAlias = RegExp.escape(alias.key);
      _collectMatches(
        query: query,
        field: alias.value,
        aliasPattern: escapedAlias,
        constraints: constraints,
        matchedFragments: matchedFragments,
      );
    }

    _collectAgePhrases(query, constraints, matchedFragments);
    _collectBetweenPhrases(query, constraints, matchedFragments);

    final limitMatch = RegExp(
      r'(?:top|first|show|list|limit(?:ed)? to)\s+(\d+)',
    ).firstMatch(query);
    final limit = limitMatch == null ? null : int.parse(limitMatch.group(1)!);
    if (limitMatch != null) matchedFragments.add(limitMatch.group(0)!);

    String? sortField;
    var sortDescending = true;
    final explicitSort = RegExp(
      r'(?:sort(?:ed)? by|leaders? in)\s+([a-z0-9%+\-/ ]+?)(?=\s+(?:ascending|descending|highest|lowest)|$)',
    ).firstMatch(query);
    if (explicitSort != null) {
      sortField = _resolveAlias(explicitSort.group(1)!.trim());
      sortDescending = !query.contains('ascending') && !query.contains('lowest');
      matchedFragments.add(explicitSort.group(0)!);
    } else {
      final rankedSort = RegExp(
        r'(highest|lowest)\s+([a-z0-9%+\-/ ]+?)(?=\s+(?:among|for|with|in)|$)',
      ).firstMatch(query);
      if (rankedSort != null) {
        sortDescending = rankedSort.group(1) == 'highest';
        sortField = _resolveAlias(rankedSort.group(2)!.trim());
        matchedFragments.add(rankedSort.group(0)!);
      }
    }

    final seasonType = query.contains('playoff') || query.contains('postseason')
        ? 'Playoffs'
        : query.contains('combined') || query.contains('regular season and playoffs')
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

    final residue = _residue(query, matchedFragments);
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

  static void _collectMatches({
    required String query,
    required String field,
    required String aliasPattern,
    required List<NbaStatConstraint> constraints,
    required List<String> matchedFragments,
  }) {
    final operators = <String, NbaStatOperator>{
      r'>=|at least|no fewer than|not less than':
          NbaStatOperator.greaterThanOrEqual,
      r'<=|at most|no more than|not more than':
          NbaStatOperator.lessThanOrEqual,
      r'>|over|more than|greater than|above': NbaStatOperator.greaterThan,
      r'<|under|less than|fewer than|below': NbaStatOperator.lessThan,
      r'=|equal to|exactly': NbaStatOperator.equal,
    };
    const number = r'(\d+(?:\.\d+)?)';

    for (final operator in operators.entries) {
      final fieldFirst = RegExp(
        '(?:^|\\s|\\()($aliasPattern)\\s*(?:${operator.key})\\s*$number',
      );
      final operatorFirst = RegExp(
        '(?:^|\\s|\\()(?:${operator.key})\\s*$number\\s*($aliasPattern)(?=\\s|[.;)]|$)',
      );

      for (final match in fieldFirst.allMatches(query)) {
        final rawValue = match.group(2);
        if (rawValue == null) continue;
        constraints.add(
          NbaStatConstraint(
            field: field,
            operator: operator.value,
            value: _normalizePercent(field, double.parse(rawValue)),
          ),
        );
        matchedFragments.add(match.group(0)!.trim());
      }
      for (final match in operatorFirst.allMatches(query)) {
        final rawValue = match.group(1);
        if (rawValue == null) continue;
        constraints.add(
          NbaStatConstraint(
            field: field,
            operator: operator.value,
            value: _normalizePercent(field, double.parse(rawValue)),
          ),
        );
        matchedFragments.add(match.group(0)!.trim());
      }
    }
  }

  static void _collectAgePhrases(
    String query,
    List<NbaStatConstraint> constraints,
    List<String> matchedFragments,
  ) {
    if (constraints.any((constraint) => constraint.field == 'age')) return;
    final match = RegExp(
      r'(?:over|older than|above)\s+(?:the\s+)?age(?:\s+of)?\s+(\d+(?:\.\d+)?)|age\s+(?:over|above|greater than)\s+(\d+(?:\.\d+)?)',
    ).firstMatch(query);
    if (match == null) return;
    final rawValue = match.group(1) ?? match.group(2);
    if (rawValue == null) return;
    constraints.add(
      NbaStatConstraint(
        field: 'age',
        operator: NbaStatOperator.greaterThan,
        value: double.parse(rawValue),
      ),
    );
    matchedFragments.add(match.group(0)!);
  }

  static void _collectBetweenPhrases(
    String query,
    List<NbaStatConstraint> constraints,
    List<String> matchedFragments,
  ) {
    for (final alias in _aliases.entries) {
      final escaped = RegExp.escape(alias.key);
      final match = RegExp(
        '(?:^|\\s|\\()($escaped)\\s+(?:between|from)\\s+(\\d+(?:\\.\\d+)?)\\s+(?:and|to)\\s+(\\d+(?:\\.\\d+)?)',
      ).firstMatch(query);
      if (match == null) continue;
      final first = double.parse(match.group(2)!);
      final second = double.parse(match.group(3)!);
      constraints.add(
        NbaStatConstraint(
          field: alias.value,
          operator: NbaStatOperator.between,
          value: _normalizePercent(alias.value, first < second ? first : second),
          secondValue:
              _normalizePercent(alias.value, first < second ? second : first),
        ),
      );
      matchedFragments.add(match.group(0)!.trim());
    }
  }

  static String? _resolveAlias(String phrase) {
    for (final alias in _aliases.entries) {
      if (phrase == alias.key || phrase.contains(alias.key)) return alias.value;
    }
    return null;
  }

  static double _normalizePercent(String field, double value) {
    final percentageField =
        field == 'fg_pct' || field == 'three_pct' || field == 'ft_pct';
    if (percentageField && value > 1) return value / 100;
    return value;
  }

  static List<NbaStatConstraint> _deduplicate(
    List<NbaStatConstraint> constraints,
  ) {
    final seen = <String>{};
    return constraints.where((constraint) {
      return seen.add(
        '${constraint.field}:${constraint.operator}:${constraint.value}:${constraint.secondValue}',
      );
    }).toList();
  }

  static String _residue(String query, List<String> fragments) {
    var residue = query;
    for (final fragment in fragments) {
      residue = residue.replaceFirst(fragment, ' ');
    }
    residue = residue
        .replaceAll(
          RegExp(
            r'\b(list|show|find|give me|all|players?|who|that|averaged?|average|with|and|but|at the end of|during|in the|the|of)\b',
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\b(playoffs?|postseason|regular season|combined)\b'), ' ')
        .replaceAll(RegExp(r'\b(per game|per 36 minutes?|per 100 possessions?|totals?)\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return residue;
  }
}
