import '../models/data_source.dart';

const nbaDataSources = <DataSource>[
  DataSource(
    id: 'nba-team-directory-local',
    name: 'NBA team directory',
    status: DataSourceStatus.connected,
    description: 'Real NBA team identity, conference, and division reference data maintained locally for the MVP.',
    asOf: '2026-05-15',
    attribution: 'NBA team names and league structure are used as reference data.',
  ),
  DataSource(
    id: 'nba-stats-official-planned',
    name: 'NBA.com/stats historical statistics',
    status: DataSourceStatus.planned,
    description: 'Preferred future source for historical player, team, and box score statistics where technically and legally feasible.',
    asOf: null,
    attribution: 'Pending connection. Product screens should not display fake statistics.',
  ),
  DataSource(
    id: 'licensed-provider-future',
    name: 'Licensed sports data provider',
    status: DataSourceStatus.planned,
    description: 'Future production option if the platform becomes public, commercial, betting-related, fantasy-related, or requires comprehensive regularly updated data.',
    asOf: null,
    attribution: 'Pending provider selection.',
  ),
];
