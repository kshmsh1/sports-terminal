import '../models/player_profile.dart';
import '../models/roster_directory_row.dart';
import '../models/roster_entry.dart';
import '../models/team.dart';

class RosterDirectoryService {
  const RosterDirectoryService();

  List<RosterDirectoryRow> join({
    required List<RosterEntry> rosters,
    required List<PlayerProfile> players,
    required List<Team> teams,
  }) {
    final playerById = {for (final player in players) player.id: player};
    final teamById = {for (final team in teams) team.id: team};

    return [
      for (final entry in rosters)
        RosterDirectoryRow(
          entry: entry,
          player: playerById[entry.playerId],
          team: teamById[entry.teamId],
        ),
    ];
  }
}
