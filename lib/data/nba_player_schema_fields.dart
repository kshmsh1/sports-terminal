class PlayerSchemaField {
  const PlayerSchemaField({
    required this.field,
    required this.group,
    required this.type,
    required this.status,
    required this.description,
  });

  final String field;
  final String group;
  final String type;
  final String status;
  final String description;
}

const nbaPlayerSchemaFields = <PlayerSchemaField>[
  PlayerSchemaField(field: 'playerId', group: 'Identity', type: 'String', status: 'Required', description: 'Stable internal player identifier used across every table.'),
  PlayerSchemaField(field: 'displayName', group: 'Identity', type: 'String', status: 'Required', description: 'Primary player name displayed in the terminal.'),
  PlayerSchemaField(field: 'firstName', group: 'Identity', type: 'String?', status: 'Nullable', description: 'First name when available from source data.'),
  PlayerSchemaField(field: 'lastName', group: 'Identity', type: 'String?', status: 'Nullable', description: 'Last name when available from source data.'),
  PlayerSchemaField(field: 'position', group: 'Bio', type: 'String?', status: 'Nullable', description: 'Listed position. Should remain blank until sourced.'),
  PlayerSchemaField(field: 'height', group: 'Bio', type: 'String?', status: 'Nullable', description: 'Listed player height.'),
  PlayerSchemaField(field: 'weightPounds', group: 'Bio', type: 'int?', status: 'Nullable', description: 'Listed player weight in pounds.'),
  PlayerSchemaField(field: 'birthDate', group: 'Bio', type: 'String?', status: 'Nullable', description: 'Birth date, stored as source-normalized string before date parsing rules are finalized.'),
  PlayerSchemaField(field: 'birthCountry', group: 'Bio', type: 'String?', status: 'Nullable', description: 'Birth country or nationality source field.'),
  PlayerSchemaField(field: 'college', group: 'Bio', type: 'String?', status: 'Nullable', description: 'College, G League, international club, or pre-NBA affiliation.'),
  PlayerSchemaField(field: 'draftYear', group: 'Draft', type: 'int?', status: 'Nullable', description: 'Draft year if drafted.'),
  PlayerSchemaField(field: 'draftRound', group: 'Draft', type: 'int?', status: 'Nullable', description: 'Draft round if drafted.'),
  PlayerSchemaField(field: 'draftPick', group: 'Draft', type: 'int?', status: 'Nullable', description: 'Overall or round pick once source conventions are selected.'),
  PlayerSchemaField(field: 'nbaDebutYear', group: 'Career', type: 'int?', status: 'Nullable', description: 'First NBA season start year when available.'),
  PlayerSchemaField(field: 'isActive', group: 'Career', type: 'bool?', status: 'Nullable', description: 'Active status when the source supports it.'),
  PlayerSchemaField(field: 'primaryTeamAbbreviation', group: 'Career', type: 'String?', status: 'Nullable', description: 'Current or most recent team abbreviation depending on dataset context.'),
  PlayerSchemaField(field: 'seasonId', group: 'Stats', type: 'String', status: 'Required for stat lines', description: 'Season key such as 2025-26.'),
  PlayerSchemaField(field: 'seasonType', group: 'Stats', type: 'String', status: 'Required for stat lines', description: 'Regular Season, Playoffs, Play-In, or other source-defined season type.'),
  PlayerSchemaField(field: 'gamesPlayed', group: 'Stats', type: 'int?', status: 'Nullable', description: 'Games played. Blank means unavailable, not zero.'),
  PlayerSchemaField(field: 'minutesPerGame', group: 'Stats', type: 'double?', status: 'Nullable', description: 'Minutes per game.'),
  PlayerSchemaField(field: 'pointsPerGame', group: 'Stats', type: 'double?', status: 'Nullable', description: 'Points per game.'),
  PlayerSchemaField(field: 'reboundsPerGame', group: 'Stats', type: 'double?', status: 'Nullable', description: 'Rebounds per game.'),
  PlayerSchemaField(field: 'assistsPerGame', group: 'Stats', type: 'double?', status: 'Nullable', description: 'Assists per game.'),
  PlayerSchemaField(field: 'trueShootingPct', group: 'Advanced', type: 'double?', status: 'Nullable', description: 'True shooting percentage once advanced stats are sourced.'),
  PlayerSchemaField(field: 'usageRate', group: 'Advanced', type: 'double?', status: 'Nullable', description: 'Usage rate once advanced stats are sourced.'),
  PlayerSchemaField(field: 'sourceId', group: 'Metadata', type: 'String?', status: 'Nullable', description: 'Reference to the data source registry.'),
  PlayerSchemaField(field: 'asOf', group: 'Metadata', type: 'String?', status: 'Nullable', description: 'Date or timestamp for the data snapshot.'),
];
