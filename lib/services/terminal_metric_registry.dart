import '../models/terminal_metric_definition.dart';

class TerminalMetricRegistry {
  const TerminalMetricRegistry();

  static const definitions = <TerminalMetricDefinition>[
    TerminalMetricDefinition(
      key: 'pts',
      name: 'Points',
      category: 'Box Score',
      objectTypes: ['PlayerGame', 'PlayerSeason', 'TeamGame'],
      description: 'Explicit points value supplied by the source-backed record.',
      method: 'Use the observed source value without reconstruction from prose.',
      sourcePolicy: 'Requires an explicit source-backed numeric field.',
      releasePolicy: 'Retain the release attached to the originating record.',
      coveragePolicy: 'Missing values remain missing and are never imputed.',
      unit: 'points',
      aliases: ['points'],
    ),
    TerminalMetricDefinition(
      key: 'reb',
      name: 'Rebounds',
      category: 'Box Score',
      objectTypes: ['PlayerGame', 'PlayerSeason'],
      description: 'Explicit rebound total supplied by the source-backed record.',
      method: 'Use the observed source value without inferred event reconstruction.',
      sourcePolicy: 'Requires an explicit source-backed numeric field.',
      releasePolicy: 'Retain the release attached to the originating record.',
      coveragePolicy: 'Missing values remain missing.',
      unit: 'rebounds',
      aliases: ['rebounds'],
    ),
    TerminalMetricDefinition(
      key: 'ast',
      name: 'Assists',
      category: 'Box Score',
      objectTypes: ['PlayerGame', 'PlayerSeason'],
      description: 'Explicit assist total supplied by the source-backed record.',
      method: 'Use the observed source value.',
      sourcePolicy: 'Requires an explicit source-backed numeric field.',
      releasePolicy: 'Retain the release attached to the originating record.',
      coveragePolicy: 'Missing values remain missing.',
      unit: 'assists',
      aliases: ['assists'],
    ),
    TerminalMetricDefinition(
      key: 'stl',
      name: 'Steals',
      category: 'Box Score',
      objectTypes: ['PlayerGame', 'PlayerSeason'],
      description: 'Explicit steal total supplied by the source-backed record.',
      method: 'Use the observed source value.',
      sourcePolicy: 'Requires an explicit source-backed numeric field.',
      releasePolicy: 'Retain the release attached to the originating record.',
      coveragePolicy: 'Missing values remain missing.',
      unit: 'steals',
      aliases: ['steals'],
    ),
    TerminalMetricDefinition(
      key: 'blk',
      name: 'Blocks',
      category: 'Box Score',
      objectTypes: ['PlayerGame', 'PlayerSeason'],
      description: 'Explicit block total supplied by the source-backed record.',
      method: 'Use the observed source value.',
      sourcePolicy: 'Requires an explicit source-backed numeric field.',
      releasePolicy: 'Retain the release attached to the originating record.',
      coveragePolicy: 'Missing values remain missing.',
      unit: 'blocks',
      aliases: ['blocks'],
    ),
    TerminalMetricDefinition(
      key: 'tov',
      name: 'Turnovers',
      category: 'Box Score',
      objectTypes: ['PlayerGame', 'PlayerSeason', 'TeamGame'],
      description: 'Explicit turnover total supplied by the source-backed record.',
      method: 'Use the observed source value.',
      sourcePolicy: 'Requires an explicit source-backed numeric field.',
      releasePolicy: 'Retain the release attached to the originating record.',
      coveragePolicy: 'Missing values remain missing.',
      unit: 'turnovers',
      aliases: ['turnovers'],
    ),
    TerminalMetricDefinition(
      key: 'plus_minus',
      name: 'Plus / Minus',
      category: 'Box Score',
      objectTypes: ['PlayerGame'],
      description: 'Explicit plus-minus field when the source supplies it.',
      method: 'Never reconstruct plus-minus when the source row omits it.',
      sourcePolicy: 'Requires an explicit source-backed plus-minus value.',
      releasePolicy: 'Retain the release attached to the originating record.',
      coveragePolicy: 'Unavailable source values remain unavailable.',
      unit: 'points',
      aliases: ['+/-', 'plusminus'],
    ),
    TerminalMetricDefinition(
      key: 'points_for',
      name: 'Points For',
      category: 'Team Results',
      objectTypes: ['TeamGame', 'TeamSeason'],
      description: 'Observed points scored by the focal team.',
      method: 'Use explicit final/observed score evidence only.',
      sourcePolicy: 'Requires source-backed score state.',
      releasePolicy: 'Retain the originating game or season release.',
      coveragePolicy: 'Scheduled or unscored games do not contribute.',
      unit: 'points',
      aliases: ['pf'],
    ),
    TerminalMetricDefinition(
      key: 'points_against',
      name: 'Points Against',
      category: 'Team Results',
      objectTypes: ['TeamGame', 'TeamSeason'],
      description: 'Observed points scored by the opponent.',
      method: 'Use explicit final/observed score evidence only.',
      sourcePolicy: 'Requires source-backed score state.',
      releasePolicy: 'Retain the originating game or season release.',
      coveragePolicy: 'Scheduled or unscored games do not contribute.',
      unit: 'points',
      aliases: ['pa'],
    ),
    TerminalMetricDefinition(
      key: 'point_differential',
      name: 'Point Differential',
      category: 'Derived',
      objectTypes: ['TeamGame', 'TeamSeason'],
      description: 'Difference between observed points for and points against.',
      method: 'Subtract points_against from points_for only when both are available.',
      sourcePolicy: 'Derived from two source-backed score fields.',
      releasePolicy: 'Uses the restrictive release/provenance context of both inputs.',
      coveragePolicy: 'Unavailable when either dependency is unavailable.',
      unit: 'points',
      formula: 'points_for - points_against',
      dependencies: ['points_for', 'points_against'],
      aliases: ['diff', 'margin'],
    ),
    TerminalMetricDefinition(
      key: 'observed_score_margin',
      name: 'Observed Score Margin',
      category: 'Game Events',
      objectTypes: ['GameEvent'],
      description: 'Score margin at an explicit event score state.',
      method: 'Compute from the explicit score state attached to that event; no interpolation.',
      sourcePolicy: 'Requires explicit event-level score evidence.',
      releasePolicy: 'Retain parent-game release provenance.',
      coveragePolicy: 'Events without score state remain unavailable.',
      unit: 'points',
      aliases: ['event margin'],
    ),
    TerminalMetricDefinition(
      key: 'rolling_average',
      name: 'Rolling Average',
      category: 'Derived',
      objectTypes: ['PlayerTrend', 'TeamTrend'],
      description: 'Mean of available observed values in an explicit ordered window.',
      method: 'Average only non-null observations inside the declared window; preserve gaps outside calculations.',
      sourcePolicy: 'Requires source-backed ordered observations.',
      releasePolicy: 'Retain the release context of the underlying series.',
      coveragePolicy: 'Window size and available observation count must be visible.',
      aliases: ['rolling avg', 'moving average'],
    ),
    TerminalMetricDefinition(
      key: 'career_year_index',
      name: 'Career Year Index',
      category: 'Alignment',
      objectTypes: ['PlayerCareerComparison'],
      description: 'Ordinal index of an observed player season within the compared career.',
      method: 'Sort observed seasons chronologically and assign an ordinal; no era normalization.',
      sourcePolicy: 'Requires canonical observed player-season identity.',
      releasePolicy: 'Retain the release context of each career series.',
      coveragePolicy: 'Only observed seasons receive an index.',
      unit: 'ordinal',
      aliases: ['career year'],
    ),
    TerminalMetricDefinition(
      key: 'event_count',
      name: 'Observed Event Count',
      category: 'Game Events',
      objectTypes: ['Game', 'PlayerGame', 'TeamGame'],
      description: 'Count of explicit play-by-play events matching a declared filter.',
      method: 'Count only event rows actually exposed by the source-backed payload.',
      sourcePolicy: 'Requires row-level event exposure.',
      releasePolicy: 'Retain parent-game release provenance.',
      coveragePolicy: 'Unavailable row feeds are not treated as zero events.',
      unit: 'events',
      aliases: ['events'],
    ),
  ];

  TerminalMetricDefinition? byKey(String key) {
    final normalized = key.trim().toLowerCase();
    for (final definition in definitions) {
      if (definition.key.toLowerCase() == normalized) return definition;
    }
    return null;
  }

  TerminalMetricDefinition? resolve(String keyOrAlias) {
    final normalized = keyOrAlias.trim().toLowerCase();
    for (final definition in definitions) {
      if (definition.key.toLowerCase() == normalized ||
          definition.aliases.any((alias) => alias.toLowerCase() == normalized)) {
        return definition;
      }
    }
    return null;
  }

  List<TerminalMetricDefinition> search(
    String query, {
    String category = '',
    String objectType = '',
  }) {
    final normalized = query.trim().toLowerCase();
    final normalizedCategory = category.trim().toLowerCase();
    final normalizedObject = objectType.trim().toLowerCase();
    return definitions.where((definition) {
      final haystack = <String>[
        definition.key,
        definition.name,
        definition.category,
        definition.description,
        definition.method,
        ...definition.aliases,
        ...definition.objectTypes,
      ].join(' ').toLowerCase();
      return (normalized.isEmpty || haystack.contains(normalized)) &&
          (normalizedCategory.isEmpty || definition.category.toLowerCase() == normalizedCategory) &&
          (normalizedObject.isEmpty || definition.objectTypes.any((value) => value.toLowerCase() == normalizedObject));
    }).toList(growable: false);
  }

  List<TerminalMetricDefinition> dependenciesOf(String key) {
    final definition = byKey(key);
    if (definition == null) return const [];
    return [
      for (final dependency in definition.dependencies)
        if (byKey(dependency) != null) byKey(dependency)!,
    ];
  }

  List<String> integrityFailures() {
    final failures = <String>[];
    final keys = <String>{};
    final aliases = <String, String>{};
    for (final definition in definitions) {
      if (definition.key.trim().isEmpty) {
        failures.add('metric key must not be empty');
        continue;
      }
      if (!keys.add(definition.key)) failures.add('duplicate metric key: ${definition.key}');
      for (final dependency in definition.dependencies) {
        if (!definitions.any((candidate) => candidate.key == dependency)) {
          failures.add('${definition.key} missing dependency: $dependency');
        }
      }
      for (final alias in definition.aliases) {
        final normalized = alias.toLowerCase();
        final existing = aliases[normalized];
        if (existing != null && existing != definition.key) {
          failures.add('alias collision: $alias -> $existing / ${definition.key}');
        } else {
          aliases[normalized] = definition.key;
        }
      }
    }

    final visiting = <String>{};
    final visited = <String>{};
    bool visit(String key) {
      if (visiting.contains(key)) return true;
      if (visited.contains(key)) return false;
      visiting.add(key);
      final definition = byKey(key);
      if (definition != null) {
        for (final dependency in definition.dependencies) {
          if (visit(dependency)) return true;
        }
      }
      visiting.remove(key);
      visited.add(key);
      return false;
    }

    for (final definition in definitions) {
      visiting.clear();
      if (visit(definition.key)) {
        failures.add('dependency cycle involving ${definition.key}');
        break;
      }
    }
    return failures;
  }
}
