import '../models/field_definition.dart';

const fieldDictionaryItems = <FieldDefinition>[
  FieldDefinition(field: 'id', domain: 'All entities', type: 'String', required: 'Yes', nullPolicy: 'Never null', description: 'Stable internal identifier used for joins and navigation.'),
  FieldDefinition(field: 'sourceId', domain: 'All imported data', type: 'String?', required: 'Yes for imported datasets', nullPolicy: 'Null only for internal placeholders', description: 'Identifier for source lineage, provider, manual entry, or generated reference dataset.'),
  FieldDefinition(field: 'asOf', domain: 'All imported data', type: 'String?', required: 'Preferred', nullPolicy: 'Null for pending-source placeholders', description: 'Snapshot or validation date for the record or dataset.'),
  FieldDefinition(field: 'teamId', domain: 'Teams / rosters / games', type: 'String', required: 'Context dependent', nullPolicy: 'Null only when team cannot be resolved', description: 'Internal team identifier used to connect teams to seasons, players, games, rosters, transactions, and salary records.'),
  FieldDefinition(field: 'playerId', domain: 'Players / stats / transactions', type: 'String', required: 'Context dependent', nullPolicy: 'Null only for unresolved names', description: 'Internal player identifier used for profile, roster, stat, award, draft, injury, transaction, and contract joins.'),
  FieldDefinition(field: 'seasonId', domain: 'Seasons / stats / games', type: 'String', required: 'Context dependent', nullPolicy: 'Null only when season does not apply', description: 'Season key such as 2025-26 used across team, player, game, award, draft, roster, and transaction records.'),
  FieldDefinition(field: 'gameId', domain: 'Games / box scores', type: 'String', required: 'Yes for game data', nullPolicy: 'Never null for game records', description: 'Stable game identifier for results, box scores, lineups, logs, and playoff series.'),
  FieldDefinition(field: 'statValue', domain: 'Statistics', type: 'num?', required: 'No', nullPolicy: 'Null means unavailable; zero means true zero', description: 'Generic stat value policy for future normalized stat tables.'),
  FieldDefinition(field: 'status', domain: 'Operational records', type: 'String', required: 'Yes', nullPolicy: 'Never null', description: 'Build, source, ingestion, alert, health, or workflow state.'),
  FieldDefinition(field: 'description', domain: 'Planning / metadata', type: 'String', required: 'Preferred', nullPolicy: 'Avoid null when user-facing', description: 'Human-readable explanation for screens, datasets, checks, reports, and workflows.'),
];
