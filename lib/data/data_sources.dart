class DataSourceNote {
  const DataSourceNote({
    required this.label,
    required this.description,
    required this.asOf,
  });

  final String label;
  final String description;
  final String asOf;
}

const nbaTeamDirectorySource = DataSourceNote(
  label: 'NBA team directory',
  description: 'Real NBA franchise reference data maintained locally for the MVP.',
  asOf: '2026-05-15',
);

const nbaPlayerStatsSource = DataSourceNote(
  label: 'NBA player stats',
  description: 'Not yet connected. Player stat tables should remain disabled until sourced data is wired in.',
  asOf: 'pending',
);
