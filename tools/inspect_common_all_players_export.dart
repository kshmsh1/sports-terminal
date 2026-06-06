import 'dart:convert';
import 'dart:io';

const _requiredFields = <String>['PERSON_ID', 'DISPLAY_FIRST_LAST'];
const _expectedFields = <String>['PERSON_ID', 'DISPLAY_FIRST_LAST', 'DISPLAY_LAST_COMMA_FIRST', 'ROSTERSTATUS', 'FROM_YEAR', 'PLAYERCODE', 'TEAM_ABBREVIATION'];

void main(List<String> args) {
  final inputPath = args.isEmpty ? 'raw/common_all_players.json' : args.first;
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    stderr.writeln('Save the real CommonAllPlayers export before running this inspector.');
    exit(66);
  }

  final source = jsonDecode(inputFile.readAsStringSync()) as Map<String, dynamic>;
  final rows = _extractRows(source);
  final headers = rows.isEmpty ? <String>{} : rows.first.keys.toSet();
  final missingRequired = _requiredFields.where((field) => !headers.contains(field)).toList();
  final missingExpected = _expectedFields.where((field) => !headers.contains(field)).toList();
  final blankPersonIds = rows.where((row) => _blank(row['PERSON_ID'])).length;
  final blankDisplayNames = rows.where((row) => _blank(row['DISPLAY_FIRST_LAST'])).length;
  final duplicatePersonIds = _duplicateCount(rows.map((row) => row['PERSON_ID']?.toString().trim()).whereType<String>().where((value) => value.isNotEmpty));

  print('CommonAllPlayers export inspection');
  print('Input: $inputPath');
  print('Rows: ${rows.length}');
  print('Fields: ${headers.length}');
  print('Missing required fields: ${missingRequired.isEmpty ? 'none' : missingRequired.join(', ')}');
  print('Missing expected fields: ${missingExpected.isEmpty ? 'none' : missingExpected.join(', ')}');
  print('Blank PERSON_ID rows: $blankPersonIds');
  print('Blank DISPLAY_FIRST_LAST rows: $blankDisplayNames');
  print('Duplicate PERSON_ID values: $duplicatePersonIds');

  var blockers = 0;
  if (rows.isEmpty) blockers += 1;
  if (missingRequired.isNotEmpty) blockers += missingRequired.length;
  if (blankPersonIds > 0) blockers += 1;
  if (blankDisplayNames > 0) blockers += 1;
  if (duplicatePersonIds > 0) blockers += 1;

  if (blockers > 0) {
    stderr.writeln('CommonAllPlayers export inspection failed with $blockers blocker(s).');
    exit(1);
  }

  print('CommonAllPlayers export is importable.');
}

List<Map<String, dynamic>> _extractRows(Map<String, dynamic> source) {
  final rows = source['rows'];
  if (rows is List) return rows.cast<Map>().map((row) => Map<String, dynamic>.from(row)).toList();

  final resultSets = source['resultSets'];
  if (resultSets is List) {
    for (final resultSet in resultSets.cast<Map>()) {
      final name = resultSet['name']?.toString().toLowerCase();
      if (name == 'commonallplayers' || name == 'common_all_players') {
        final headers = (resultSet['headers'] as List).map((item) => item.toString()).toList();
        final rowSet = resultSet['rowSet'] as List;
        return [for (final row in rowSet.cast<List>()) Map<String, dynamic>.fromIterables(headers, row)];
      }
    }
  }

  final dataSets = source['data_sets'];
  final rowSet = source['rowSet'];
  if (dataSets is Map && dataSets['CommonAllPlayers'] is List && rowSet is List) {
    final headers = (dataSets['CommonAllPlayers'] as List).map((item) => item.toString()).toList();
    return [for (final row in rowSet.cast<List>()) Map<String, dynamic>.fromIterables(headers, row)];
  }

  throw StateError('Could not find CommonAllPlayers rows in input JSON.');
}

bool _blank(dynamic value) => value == null || value.toString().trim().isEmpty;

int _duplicateCount(Iterable<String> values) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final value in values) {
    if (!seen.add(value)) duplicates.add(value);
  }
  return duplicates.length;
}
