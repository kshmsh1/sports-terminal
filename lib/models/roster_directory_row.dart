import 'player_profile.dart';
import 'roster_entry.dart';
import 'team.dart';

class RosterDirectoryRow {
  const RosterDirectoryRow({
    required this.entry,
    required this.player,
    required this.team,
  });

  final RosterEntry entry;
  final PlayerProfile? player;
  final Team? team;

  String get playerId => entry.playerId;
  String get playerName => player?.displayName ?? entry.playerId;
  String get teamId => entry.teamId;
  String get teamName => team?.name ?? entry.teamId;
  String get teamAbbreviation => team?.abbreviation ?? player?.primaryTeamAbbreviation ?? '—';
  String get position => entry.position ?? player?.position ?? '—';
  String get from => entry.fromDisplay ?? player?.college ?? player?.birthCountry ?? '—';
  String get sourceId => entry.sourceId ?? player?.sourceId ?? '—';
  bool get isActive => player?.isActive ?? true;
}
