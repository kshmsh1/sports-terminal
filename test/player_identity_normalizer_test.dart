import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/player_identity_normalizer.dart';
import 'package:sports_terminal/services/player_identity_validator.dart';

void main() {
  group('PlayerIdentityNormalizer', () {
    test('normalizes CommonAllPlayers rows into player and alias rows', () {
      final batch = const PlayerIdentityNormalizer().normalizeCommonAllPlayers(
        sourceId: 'common-all-players-test',
        asOf: '2026-06-05',
        rows: const [
          {
            'PERSON_ID': 203999,
            'DISPLAY_FIRST_LAST': 'Nikola Jokic',
            'DISPLAY_LAST_COMMA_FIRST': 'Jokic, Nikola',
            'ROSTERSTATUS': 1,
            'FROM_YEAR': '2015',
            'PLAYERCODE': 'nikola_jokic',
            'TEAM_ABBREVIATION': 'DEN',
          },
        ],
      );

      expect(batch.players, hasLength(1));
      expect(batch.aliases, hasLength(3));
      expect(batch.heldRows, isEmpty);
      expect(batch.players.first.id, 'nba-203999');
      expect(batch.players.first.displayName, 'Nikola Jokic');
      expect(batch.players.first.firstName, 'Nikola');
      expect(batch.players.first.lastName, 'Jokic');
      expect(batch.players.first.nbaDebutYear, 2015);
      expect(batch.players.first.isActive, isTrue);
      expect(batch.players.first.primaryTeamAbbreviation, 'DEN');
    });

    test('holds rows missing required source fields', () {
      final batch = const PlayerIdentityNormalizer().normalizeCommonAllPlayers(
        sourceId: 'common-all-players-test',
        asOf: '2026-06-05',
        rows: const [
          {'DISPLAY_FIRST_LAST': 'Missing Person Id'},
          {'PERSON_ID': 1},
        ],
      );

      expect(batch.players, isEmpty);
      expect(batch.aliases, isEmpty);
      expect(batch.heldRows, hasLength(2));
    });

    test('normalized rows pass player identity validator', () {
      final batch = const PlayerIdentityNormalizer().normalizeCommonAllPlayers(
        sourceId: 'common-all-players-test',
        asOf: '2026-06-05',
        rows: const [
          {
            'PERSON_ID': 2544,
            'DISPLAY_FIRST_LAST': 'LeBron James',
            'DISPLAY_LAST_COMMA_FIRST': 'James, LeBron',
            'ROSTERSTATUS': 1,
            'FROM_YEAR': 2003,
            'PLAYERCODE': 'lebron_james',
            'TEAM_ABBREVIATION': 'LAL',
          },
        ],
      );
      final summary = const PlayerIdentityValidator().validate(players: batch.players, aliases: batch.aliases);

      expect(summary.blockers, 0);
      expect(summary.canConnect, isTrue);
    });
  });
}
