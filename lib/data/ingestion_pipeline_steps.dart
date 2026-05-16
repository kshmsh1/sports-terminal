class IngestionPipelineStep {
  const IngestionPipelineStep({
    required this.step,
    required this.title,
    required this.owner,
    required this.status,
    required this.description,
  });

  final int step;
  final String title;
  final String owner;
  final String status;
  final String description;
}

const ingestionPipelineSteps = <IngestionPipelineStep>[
  IngestionPipelineStep(
    step: 1,
    title: 'Identify source',
    owner: 'Research',
    status: 'Manual',
    description: 'Determine whether the data comes from official NBA data, public data, manual CSVs, or a future licensed provider.',
  ),
  IngestionPipelineStep(
    step: 2,
    title: 'Check usage rights',
    owner: 'Policy',
    status: 'Required',
    description: 'Record whether the source is private prototype only, attribution required, public-safe, commercial-safe, or restricted.',
  ),
  IngestionPipelineStep(
    step: 3,
    title: 'Extract raw data',
    owner: 'Scripts',
    status: 'Planned',
    description: 'Pull or import source data into a raw local file without changing the original schema.',
  ),
  IngestionPipelineStep(
    step: 4,
    title: 'Normalize records',
    owner: 'Scripts',
    status: 'Planned',
    description: 'Map source fields to Sports Terminal models such as PlayerProfile, Team, Season, and PlayerStatLine.',
  ),
  IngestionPipelineStep(
    step: 5,
    title: 'Validate values',
    owner: 'Quality',
    status: 'Planned',
    description: 'Check required IDs, missing values, duplicate rows, season keys, team abbreviations, and numeric ranges.',
  ),
  IngestionPipelineStep(
    step: 6,
    title: 'Write normalized JSON',
    owner: 'Scripts',
    status: 'Planned',
    description: 'Save app-ready data into assets/data/nba or a future internal database/API.',
  ),
  IngestionPipelineStep(
    step: 7,
    title: 'Load into Flutter',
    owner: 'App',
    status: 'Planned',
    description: 'Use app data services to read normalized records without tying screens to the source website or provider.',
  ),
  IngestionPipelineStep(
    step: 8,
    title: 'Display with source metadata',
    owner: 'App',
    status: 'Planned',
    description: 'Show source, as-of date, blanks for unavailable values, and warnings for limited or restricted datasets.',
  ),
];
