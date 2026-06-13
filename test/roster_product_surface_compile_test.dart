import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/screens/entity_profile_screens.dart';
import 'package:sports_terminal/screens/final_rosters_screen.dart';
import 'package:sports_terminal/screens/players_screen.dart';
import 'package:sports_terminal/screens/teams_screen.dart';

void main() {
  test('roster product surfaces instantiate', () {
    const surfaces = <Widget>[
      PlayersScreen(),
      TeamsScreen(),
      FinalRostersScreen(),
      PlayerProfileScreen(playerId: 'compile-test-player'),
      TeamProfileScreen(teamId: 'compile-test-team'),
    ];

    expect(surfaces, hasLength(5));
    expect(surfaces[0], isA<PlayersScreen>());
    expect(surfaces[1], isA<TeamsScreen>());
    expect(surfaces[2], isA<FinalRostersScreen>());
    expect(surfaces[3], isA<PlayerProfileScreen>());
    expect(surfaces[4], isA<TeamProfileScreen>());
  });
}
