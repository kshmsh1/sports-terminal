import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical shell exposes NBA media, box scores and live games', () {
    final shell = File('lib/widgets/canonical_product_shell.dart').readAsStringSync();
    final media = File(
      'lib/screens/website_nba_media_feed_screen.dart',
    ).readAsStringSync();
    final box = File(
      'lib/screens/website_nba_box_scores_screen.dart',
    ).readAsStringSync();
    final live = File(
      'lib/screens/website_nba_live_games_screen.dart',
    ).readAsStringSync();
    final service = File(
      'lib/services/nba_live_game_service.dart',
    ).readAsStringSync();
    final launcher = File('scripts/open_terminal.sh').readAsStringSync();
    final scheduleTool = File(
      'tools/materialize_nba_2026_27_schedule.py',
    ).readAsStringSync();
    final boxTool = File(
      'tools/materialize_static_nba_game_details.py',
    ).readAsStringSync();

    expect(shell, contains("id: 'live-games'"));
    expect(shell, contains("id: 'box-scores'"));
    expect(shell, contains("id: 'media-feed'"));
    expect(shell, contains('WebsiteNbaLiveGamesScreen'));
    expect(shell, contains('WebsiteNbaBoxScoresScreen'));
    expect(shell, contains('WebsiteNbaMediaFeedScreen'));

    expect(media, contains('Shams Charania'));
    expect(media, contains('Chris Haynes'));
    expect(media, contains('Marc Stein'));
    expect(media, contains('NbaXTimeline'));
    expect(media, contains('Live X embed'));

    expect(box, contains('Historical static archive'));
    expect(box, contains('Search box scores'));
    expect(box, contains('gameDetail('));
    expect(box, contains('player_box_scores'));
    expect(box, isNot(contains('/v2/nba/history')));

    expect(live, contains('2026-27 schedule'));
    expect(live, contains('15s live refresh'));
    expect(live, contains('Refresh live'));
    expect(live, contains('forDate('));
    expect(service, contains('schedule_2026_27.json'));
    expect(service, contains('todaysScoreboard_00.json'));
    expect(service, contains('boxscore_\$gameId.json'));

    expect(scheduleTool, contains('scheduleLeagueV2_1.json'));
    expect(scheduleTool, contains('source_authority'));
    expect(scheduleTool, contains('runtime_api_required_for_schedule'));
    expect(boxTool, contains('network_requests'));
    expect(launcher, contains('materialize_nba_2026_27_schedule.py'));
    expect(launcher, contains('materialize_static_nba_game_details.py'));
  });
}
