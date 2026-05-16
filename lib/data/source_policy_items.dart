class SourcePolicyItem {
  const SourcePolicyItem({
    required this.area,
    required this.policy,
    required this.status,
    required this.notes,
  });

  final String area;
  final String policy;
  final String status;
  final String notes;
}

const sourcePolicyItems = <SourcePolicyItem>[
  SourcePolicyItem(
    area: 'Stable NBA reference data',
    policy: 'Allowed in MVP when manually maintained and clearly source-aware.',
    status: 'Use now',
    notes: 'Team names, abbreviations, conferences, divisions, and season identifiers are foundational reference data.',
  ),
  SourcePolicyItem(
    area: 'NBA.com/stats historical statistics',
    policy: 'Preferred official-source path for private prototyping, subject to attribution and usage restrictions.',
    status: 'Investigate',
    notes: 'Do not build a public or commercial comprehensive stats product from scraped official data without proper rights.',
  ),
  SourcePolicyItem(
    area: 'Third-party public datasets',
    policy: 'Can be used only if license terms allow the intended use.',
    status: 'Review required',
    notes: 'Useful for prototyping, but licensing, freshness, completeness, and attribution must be checked dataset by dataset.',
  ),
  SourcePolicyItem(
    area: 'Paid data providers',
    policy: 'Future production option if the platform becomes public, commercial, fantasy-related, betting-related, or live-data dependent.',
    status: 'Future',
    notes: 'Likely providers include league-licensed or commercial sports data companies. Do not assume free access to comprehensive live feeds.',
  ),
  SourcePolicyItem(
    area: 'Manual CSV imports',
    policy: 'Acceptable for development when the source and rights are documented.',
    status: 'Use carefully',
    notes: 'Good bridge between mock data and full API integration. Each import should include metadata and as-of date.',
  ),
  SourcePolicyItem(
    area: 'Generated or estimated stats',
    policy: 'Do not present as real historical data.',
    status: 'Restricted',
    notes: 'Derived projections or estimates must be labeled as modeled outputs, not source statistics.',
  ),
];
