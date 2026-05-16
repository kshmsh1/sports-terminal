class EraPlanItem {
  const EraPlanItem({
    required this.era,
    required this.category,
    required this.status,
    required this.description,
    required this.modelingUse,
  });

  final String era;
  final String category;
  final String status;
  final String description;
  final String modelingUse;
}

const eraPlanItems = <EraPlanItem>[
  EraPlanItem(
    era: 'BAA foundation era',
    category: 'League history',
    status: 'Planned',
    description: 'Early Basketball Association of America seasons before the NBA naming era.',
    modelingUse: 'Keeps early historical seasons clearly separated while preserving continuity.',
  ),
  EraPlanItem(
    era: 'Early NBA era',
    category: 'League history',
    status: 'Planned',
    description: 'Post-BAA early NBA seasons with materially different league structure, pace, talent distribution, and franchise footprint.',
    modelingUse: 'Prevents misleading direct comparisons between early league production and modern production.',
  ),
  EraPlanItem(
    era: 'Shot clock era',
    category: 'Rules',
    status: 'Planned',
    description: 'Era beginning with the introduction of the shot clock, one of the most important rule changes in basketball history.',
    modelingUse: 'Flags major rule regime shifts for historical comparisons.',
  ),
  EraPlanItem(
    era: 'ABA merger era',
    category: 'League structure',
    status: 'Planned',
    description: 'League expansion and talent integration around the ABA-NBA merger period.',
    modelingUse: 'Useful for franchise history, player movement, and changes in competitive environment.',
  ),
  EraPlanItem(
    era: 'Three-point adoption era',
    category: 'Rules and play style',
    status: 'Planned',
    description: 'Period after the introduction of the three-point line and before the modern spacing explosion.',
    modelingUse: 'Helps contextualize shooting, spacing, and efficiency trends.',
  ),
  EraPlanItem(
    era: 'Expansion and globalization era',
    category: 'League growth',
    status: 'Planned',
    description: 'Period marked by expansion franchises, global talent growth, increased media reach, and broader player pipelines.',
    modelingUse: 'Useful for franchise growth, draft history, international player context, and market analysis.',
  ),
  EraPlanItem(
    era: 'Modern pace-and-space era',
    category: 'Play style',
    status: 'Planned',
    description: 'Modern era defined by spacing, three-point volume, switching defenses, heliocentric creation, and efficiency-driven offense.',
    modelingUse: 'Critical for comparing modern players to historical players without flattening context.',
  ),
  EraPlanItem(
    era: 'Current collective bargaining era',
    category: 'Business and roster construction',
    status: 'Future',
    description: 'Modern financial and roster-building environment including cap mechanics, aprons, extensions, options, and team-building constraints.',
    modelingUse: 'Important for salary, roster, transaction, and team-building intelligence once financial data is sourced.',
  ),
];
