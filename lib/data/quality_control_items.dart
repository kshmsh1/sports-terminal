class QualityControlItem {
  const QualityControlItem({
    required this.check,
    required this.category,
    required this.severity,
    required this.status,
    required this.description,
  });

  final String check;
  final String category;
  final String severity;
  final String status;
  final String description;
}

const qualityControlItems = <QualityControlItem>[
  QualityControlItem(
    check: 'Required identifier coverage',
    category: 'Completeness',
    severity: 'Critical',
    status: 'Planned',
    description: 'Every record that enters the app must have the required internal IDs for its model, such as playerId, teamId, seasonId, or gameId.',
  ),
  QualityControlItem(
    check: 'Null vs zero distinction',
    category: 'Integrity',
    severity: 'Critical',
    status: 'Started',
    description: 'Unavailable values must remain null and display as blank. Zero should only mean the true recorded value is zero.',
  ),
  QualityControlItem(
    check: 'Source metadata presence',
    category: 'Lineage',
    severity: 'Critical',
    status: 'Planned',
    description: 'Imported datasets should carry sourceId, asOf, season, seasonType, and usage notes when applicable.',
  ),
  QualityControlItem(
    check: 'Duplicate record detection',
    category: 'Integrity',
    severity: 'High',
    status: 'Planned',
    description: 'Prevent duplicate player-season-team records, duplicate game records, duplicate draft picks, and duplicate transaction rows.',
  ),
  QualityControlItem(
    check: 'Season key validation',
    category: 'Reference',
    severity: 'High',
    status: 'Planned',
    description: 'Every season field should map to the internal season catalog and use the same season key format.',
  ),
  QualityControlItem(
    check: 'Team abbreviation validation',
    category: 'Reference',
    severity: 'High',
    status: 'Planned',
    description: 'Team abbreviations should map to the internal team directory or to a historical franchise alias table once created.',
  ),
  QualityControlItem(
    check: 'Numeric range checks',
    category: 'Statistics',
    severity: 'Medium',
    status: 'Planned',
    description: 'Validate impossible values such as negative games played, shooting percentages above 100, or minutes per game above regulation limits without context.',
  ),
  QualityControlItem(
    check: 'Provider definition tracking',
    category: 'Statistics',
    severity: 'Medium',
    status: 'Planned',
    description: 'Advanced statistics should carry source definitions because formulas and naming conventions can differ across providers.',
  ),
  QualityControlItem(
    check: 'Historical franchise mapping',
    category: 'Reference',
    severity: 'Medium',
    status: 'Future',
    description: 'Historical team aliases, relocations, renames, and predecessor franchises must be mapped before long historical queries are trusted.',
  ),
  QualityControlItem(
    check: 'Manual override audit trail',
    category: 'Governance',
    severity: 'Medium',
    status: 'Future',
    description: 'Manual corrections should record who changed the data, when it changed, why it changed, and what source supports the correction.',
  ),
];
