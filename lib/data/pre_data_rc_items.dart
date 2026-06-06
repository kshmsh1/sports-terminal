import '../models/registry_item.dart';

const preDataRcItems = <RegistryItem>[
  RegistryItem(id: 'rc-local-browser', title: 'Local browser smoke test', category: 'Pre-Data RC', priority: 'P0', status: 'User run required', description: 'Launch the app locally in Chrome after pulling the latest build.', inputs: 'flutter run -d chrome', nextStep: 'Navigate major tabs and confirm no runtime blockers.'),
  RegistryItem(id: 'rc-pre-import-check', title: 'Pre-import state check', category: 'Pre-Data RC', priority: 'P0', status: 'Ready', description: 'Run tests, verify source-pending assets are empty, and validate every NBA asset layer.', inputs: 'tools/check_pre_import_state.sh', nextStep: 'Run before normalizing real source rows.'),
  RegistryItem(id: 'rc-post-import-check', title: 'Post-import candidate check', category: 'Pre-Data RC', priority: 'P0', status: 'Ready for later', description: 'Run tests and validators after real source rows are added.', inputs: 'tools/check_post_import_candidate.sh', nextStep: 'Run after real player identity import.'),
  RegistryItem(id: 'rc-ci', title: 'CI gate', category: 'Pre-Data RC', priority: 'P0', status: 'Implemented', description: 'GitHub Actions runs the pre-data gate on pushes and pull requests.', inputs: '.github/workflows/pre_data_gate.yml', nextStep: 'Treat CI failure as a release blocker.'),
  RegistryItem(id: 'rc-real-source', title: 'Real player identity export', category: 'Pre-Data RC', priority: 'P0', status: 'External blocker', description: 'The first real import needs a saved CommonAllPlayers export.', inputs: 'raw/common_all_players.json', nextStep: 'Save the export locally, then run the import wrapper.'),
  RegistryItem(id: 'rc-no-fake', title: 'No fake data check', category: 'Pre-Data RC', priority: 'P0', status: 'Enforced', description: 'Sample rows must not remain in committed app assets.', inputs: 'restore helper, source-pending validator', nextStep: 'Restore placeholders after sample testing.'),
];
