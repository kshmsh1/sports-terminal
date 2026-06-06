import 'dart:convert';
import 'dart:io';

import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/models/transaction_record.dart';
import 'package:sports_terminal/services/transaction_record_validator.dart';

void main() {
  final players = _loadPlayers();
  final teams = _loadTeams();
  final transactions = _loadTransactions();
  final summary = const TransactionRecordValidator().validate(transactions: transactions, players: players, teams: teams);

  print('Transactions validation summary');
  print('Players: ${players.length}');
  print('Teams: ${teams.length}');
  print('Transaction rows: ${transactions.length}');
  print('Blockers: ${summary.blockers}');
  print('Warnings: ${summary.warnings}');

  for (final issue in summary.issues) {
    print('- ${issue.severity} ${issue.code} ${issue.rowId ?? 'global'}: ${issue.message}');
  }

  if (!summary.canConnect) throw StateError('Transaction assets are blocked and should not be connected.');
  print('Transaction assets are connectable.');
}

List<PlayerProfile> _loadPlayers() {
  final decoded = jsonDecode(File('assets/data/nba/players/player_profiles.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['players'] as List<dynamic>).map((row) => PlayerProfile.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<Team> _loadTeams() {
  final decoded = jsonDecode(File('assets/data/nba/teams/teams.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['teams'] as List<dynamic>).map((row) => Team.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}

List<TransactionRecord> _loadTransactions() {
  final decoded = jsonDecode(File('assets/data/nba/transactions/transaction_records.json').readAsStringSync()) as Map<String, dynamic>;
  return (decoded['transactions'] as List<dynamic>).map((row) => TransactionRecord.fromJson(row as Map<String, dynamic>)).toList(growable: false);
}
