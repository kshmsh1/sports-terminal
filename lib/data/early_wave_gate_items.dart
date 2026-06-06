import '../models/registry_item.dart';

const earlyWaveGateItems = <RegistryItem>[
  RegistryItem(id: 'ew-teams', title: 'Teams reference gate', category: 'Early Wave', priority: 'P0', status: 'Implemented', description: 'Teams stay connected as the stable team reference spine.', inputs: 'teams.json', nextStep: 'Keep IDs stable.'),
  RegistryItem(id: 'ew-seasons', title: 'Seasons reference gate', category: 'Early Wave', priority: 'P0', status: 'Implemented', description: 'Seasons stay connected as the stable time reference spine.', inputs: 'seasons.json', nextStep: 'Keep IDs stable.'),
  RegistryItem(id: 'ew-identity', title: 'Player identity gate', category: 'Early Wave', priority: 'P0', status: 'Implemented', description: 'Player identity and aliases must validate before player stat rows connect.', inputs: 'PlayerIdentityValidator', nextStep: 'Import player identity first.'),
  RegistryItem(id: 'ew-player-stats', title: 'Player stats gate', category: 'Early Wave', priority: 'P0', status: 'Implemented', description: 'Player stats must validate joins, source fields, keys, and numeric values.', inputs: 'PlayerSeasonStatValidator', nextStep: 'Run stat validator before connecting rows.'),
  RegistryItem(id: 'ew-team-stats', title: 'Team stats gate', category: 'Early Wave', priority: 'P0', status: 'Implemented', description: 'Team stats must validate joins, source fields, keys, records, and numeric values.', inputs: 'TeamSeasonStatValidator', nextStep: 'Run team stat validator before standings depend on rows.'),
];
