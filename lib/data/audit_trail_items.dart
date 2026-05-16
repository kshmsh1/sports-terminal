import '../models/registry_item.dart';

const auditTrailItems = <RegistryItem>[
  RegistryItem(id: 'source-decision-records', title: 'Source Decision Records', category: 'Source Governance', priority: 'P1', status: 'Planned', description: 'Track why a source was accepted, deferred, rejected, or limited.', inputs: 'Research sources, source policy, import jobs', nextStep: 'Create a source decision record model later.'),
  RegistryItem(id: 'import-run-records', title: 'Import Run Records', category: 'Data Operations', priority: 'P1', status: 'Future', description: 'Track import job runs, snapshot dates, row counts, errors, and quality checks.', inputs: 'Import jobs, QA checks, repository loaders', nextStep: 'Add once import scripts exist.'),
  RegistryItem(id: 'schema-change-records', title: 'Schema Change Records', category: 'Data Model', priority: 'P2', status: 'Future', description: 'Track changes to fields, models, assets, and entity relationships.', inputs: 'Field dictionary, data model, entity graph', nextStep: 'Add versioning to major data assets.'),
  RegistryItem(id: 'release-review-records', title: 'Release Review Records', category: 'Release', priority: 'P2', status: 'Future', description: 'Track what was checked before a release milestone was considered complete.', inputs: 'Release plan, QA console, product backlog', nextStep: 'Use when releases become more formal.'),
  RegistryItem(id: 'workspace-change-records', title: 'Workspace Change Records', category: 'User Workflows', priority: 'P4', status: 'Future', description: 'Potential local-only record trail for saved views, exports, and user-authored notes.', inputs: 'Saved views, exports, reports, privacy controls', nextStep: 'Do not add until user persistence is designed.'),
];
