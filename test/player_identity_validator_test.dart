import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/player_alias.dart';
import 'package:sports_terminal/models/player_profile.dart';
import 'package:sports_terminal/services/player_identity_validator.dart';

void main() {
  group('PlayerIdentityValidator', () {
    test('passes clean player identity rows', () {
      final summary = const PlayerIdentityValidator().validate(players: const [
        PlayerProfile(id: 'player-1', displayName: 'Test Player', firstName: 'Test', lastName: 'Player', isActive: true, sourceId: 'test-source', asOf: '2026-01-01'),
      ]);

      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });

    test('blocks duplicate player IDs and duplicate display names', () {
      final summary = const PlayerIdentityValidator().validate(players: const [
        PlayerProfile(id: 'player-1', displayName: 'Same Name', sourceId: 'test-source', asOf: '2026-01-01'),
        PlayerProfile(id: 'player-1', displayName: 'Same Name', sourceId: 'test-source', asOf: '2026-01-01'),
      ]);

      expect(summary.blockers, greaterThanOrEqualTo(2));
      expect(summary.canConnect, isFalse);
    });

    test('blocks missing source metadata', () {
      final summary = const PlayerIdentityValidator().validate(players: const [
        PlayerProfile(id: 'player-1', displayName: 'Missing Source'),
      ]);

      expect(summary.issues.where((issue) => issue.code == 'missing-source-id'), isNotEmpty);
      expect(summary.issues.where((issue) => issue.code == 'missing-as-of'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });

    test('blocks aliases that point to missing player IDs', () {
      final summary = const PlayerIdentityValidator().validate(
        players: const [PlayerProfile(id: 'player-1', displayName: 'Test Player', sourceId: 'test-source', asOf: '2026-01-01')],
        aliases: const [PlayerAlias(playerId: 'missing-player', alias: 'Alias', aliasType: 'provider')],
      );

      expect(summary.issues.where((issue) => issue.code == 'alias-player-missing'), isNotEmpty);
      expect(summary.canConnect, isFalse);
    });
  });
}
