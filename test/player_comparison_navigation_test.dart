import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical navigation exposes grouped NBA comparison tools', () {
    final shell = File('lib/widgets/canonical_product_shell.dart').readAsStringSync();
    final player = File(
      'lib/screens/website_nba_player_comparison_screen.dart',
    ).readAsStringSync();
    final team = File(
      'lib/screens/website_nba_team_comparison_screen.dart',
    ).readAsStringSync();

    expect(shell, contains("id: 'player-compare'"));
    expect(shell, contains("id: 'team-compare'"));
    expect(shell, contains("'Compare'"));
    expect(shell, contains('_CompareMenu'));
    expect(shell, contains('WebsiteNbaPlayerComparisonScreen'));
    expect(shell, contains('WebsiteNbaTeamComparisonScreen'));
    expect(shell, isNot(contains("id: 'compare'")));

    expect(player, contains('Player Comparison Lab'));
    expect(player, contains('1946-47 → 2025-26'));
    expect(player, contains('_maxPlayers = 5'));
    expect(player, contains('Add player'));
    expect(player, contains('Remove player'));
    expect(player, contains('Cross-era mode'));
    expect(player, contains('Season-relative fingerprint'));
    expect(player, contains('winnerIndexes'));
    expect(player, contains('Icons.star_rounded'));
    expect(player, contains('most favorable available value'));
    expect(player, contains('NbaStatsBasis.values'));
    expect(player, contains('Regular Season'));
    expect(player, contains('Playoffs'));
    expect(player, contains("'Basic'"));
    expect(player, contains("'Scoring'"));
    expect(player, contains("'Shooting'"));
    expect(player, contains("'Playmaking'"));
    expect(player, contains("'Rebounding'"));
    expect(player, contains("'Defense'"));
    expect(player, contains("'Impact'"));
    expect(player, contains("'Custom'"));
    expect(player, contains('Custom metric set'));
    expect(player, contains('SharedPreferences'));
    expect(player, contains('Saved views'));
    expect(player, contains('Save As'));
    expect(player, contains('_maxSavedViews = 5'));
    expect(player, contains('Copy comparison'));
    expect(player, contains('Clipboard.setData'));
    expect(player, contains('PLAYER IMAGE PLACEHOLDER'));
    expect(player, contains('WebsiteNbaApiService'));
    expect(player, contains('seasonSnapshot('));
    expect(player, isNot(contains('http://')));
    expect(player, isNot(contains('/v2/nba/history')));

    expect(team, contains('Team Comparison Lab'));
    expect(team, contains('_maxTeams = 5'));
    expect(team, contains('Add team'));
    expect(team, contains('Remove team'));
    expect(team, contains('Cross-era mode'));
    expect(team, contains('nba_team_compare_saved_views_v1'));
    expect(team, contains('SharedPreferences'));
    expect(team, contains('Save As'));
    expect(team, contains('Regular Season'));
    expect(team, contains('Playoffs'));
    expect(team, contains('Icons.star_rounded'));
    expect(team, contains('WebsiteNbaApiService'));
    expect(team, contains('seasonSnapshot('));
    expect(team, isNot(contains('http://')));
    expect(team, isNot(contains('/v2/nba/history')));
  });
}
