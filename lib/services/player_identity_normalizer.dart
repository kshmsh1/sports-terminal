import '../models/player_alias.dart';
import '../models/player_profile.dart';

class PlayerIdentityNormalizedBatch {
  const PlayerIdentityNormalizedBatch({required this.players, required this.aliases, required this.heldRows});
  final List<PlayerProfile> players;
  final List<PlayerAlias> aliases;
  final List<Map<String, dynamic>> heldRows;
}

class PlayerIdentityNormalizer {
  const PlayerIdentityNormalizer();

  PlayerIdentityNormalizedBatch normalizeCommonAllPlayers({
    required List<Map<String, dynamic>> rows,
    required String sourceId,
    required String asOf,
  }) {
    final players = <PlayerProfile>[];
    final aliases = <PlayerAlias>[];
    final heldRows = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final row in rows) {
      final personId = _text(row['PERSON_ID']);
      final displayName = _text(row['DISPLAY_FIRST_LAST']);
      if (personId == null || displayName == null) {
        heldRows.add(row);
        continue;
      }
      final playerId = 'nba-$personId';
      if (!seen.add(playerId)) {
        heldRows.add(row);
        continue;
      }
      final names = _splitName(displayName);
      players.add(PlayerProfile(
        id: playerId,
        displayName: displayName,
        firstName: names.firstName,
        lastName: names.lastName,
        nbaDebutYear: _number(row['FROM_YEAR']),
        isActive: _active(row['ROSTERSTATUS']),
        primaryTeamAbbreviation: _text(row['TEAM_ABBREVIATION']),
        sourceId: sourceId,
        asOf: asOf,
      ));
      aliases.add(PlayerAlias(playerId: playerId, alias: personId, aliasType: 'providerId', providerId: personId, providerName: 'CommonAllPlayers', sourceId: sourceId, asOf: asOf));
      final code = _text(row['PLAYERCODE']);
      if (code != null) aliases.add(PlayerAlias(playerId: playerId, alias: code, aliasType: 'providerCode', providerId: personId, providerName: 'CommonAllPlayers', sourceId: sourceId, asOf: asOf));
      final lastCommaFirst = _text(row['DISPLAY_LAST_COMMA_FIRST']);
      if (lastCommaFirst != null && lastCommaFirst != displayName) aliases.add(PlayerAlias(playerId: playerId, alias: lastCommaFirst, aliasType: 'displayLastCommaFirst', providerId: personId, providerName: 'CommonAllPlayers', sourceId: sourceId, asOf: asOf));
    }

    return PlayerIdentityNormalizedBatch(players: players, aliases: aliases, heldRows: heldRows);
  }

  bool? _active(dynamic value) {
    final text = _text(value)?.toLowerCase();
    if (text == null) return null;
    if (text == '1' || text == 'active' || text == 'true' || text == 'y') return true;
    if (text == '0' || text == 'inactive' || text == 'false' || text == 'n') return false;
    return null;
  }

  _NameParts _splitName(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return _NameParts(firstName: value.trim(), lastName: null);
    return _NameParts(firstName: parts.first, lastName: parts.sublist(1).join(' '));
  }

  String? _text(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int? _number(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class _NameParts {
  const _NameParts({required this.firstName, required this.lastName});
  final String? firstName;
  final String? lastName;
}
