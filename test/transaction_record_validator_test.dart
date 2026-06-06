import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/models/team.dart';
import 'package:sports_terminal/models/transaction_record.dart';
import 'package:sports_terminal/services/transaction_record_validator.dart';

void main() {
  const players = [PlayerProfile(id: 'nba-2544', displayName: 'LeBron James', sourceId: 'source', asOf: '2026-06-05')];
  const teams = [
    Team(id: 'cle', name: 'Cavaliers', abbreviation: 'CLE', city: 'Cleveland', conference: 'East', division: 'Central'),
    Team(id: 'lal', name: 'Lakers', abbreviation: 'LAL', city: 'Los Angeles', conference: 'West', division: 'Pacific'),
  ];

  group('TransactionRecordValidator', () {
    test('passes clean joined rows', () {
      final summary = const TransactionRecordValidator().validate(
        players: players,
        teams: teams,
        transactions: const [TransactionRecord(id: 'tx-1', date: '2018-07-01', transactionType: 'Signing', playerId: 'nba-2544', fromTeamId: 'cle', toTeamId: 'lal', sourceId: 'source', asOf: '2026-06-05')],
      );
      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks missing joins and source metadata', () {
      final summary = const TransactionRecordValidator().validate(
        players: players,
        teams: teams,
        transactions: const [TransactionRecord(id: 'bad-tx', playerId: 'missing-player', fromTeamId: 'missing-from', toTeamId: 'missing-to')],
      );
      expect(summary.issues.where((issue) => issue.code == 'player-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'from-team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'to-team-join-missing'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks duplicate IDs and warns on same-team transactions', () {
      final summary = const TransactionRecordValidator().validate(
        players: players,
        teams: teams,
        transactions: const [
          TransactionRecord(id: 'dup-tx', playerId: 'nba-2544', fromTeamId: 'lal', toTeamId: 'lal', sourceId: 'source', asOf: '2026-06-05'),
          TransactionRecord(id: 'dup-tx', playerId: 'nba-2544', fromTeamId: 'lal', toTeamId: 'lal', sourceId: 'source', asOf: '2026-06-05'),
        ],
      );
      expect(summary.issues.where((issue) => issue.code == 'duplicate-row-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'same-from-to-team'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
