import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sports_terminal/screens/website_nba_box_scores_screen.dart';
import 'package:sports_terminal/services/website_nba_api_service.dart';
import 'package:sports_terminal/widgets/sports_workspace_design.dart';

class _FakeBoxArchive extends WebsiteNbaApiService {
  const _FakeBoxArchive();

  @override
  Future<List<WebsiteNbaSeason>> seasons() async => const [
    WebsiteNbaSeason(id: '2025-26', label: '2025-26',
      startYear: 2025, rowCount: 0),
    WebsiteNbaSeason(id: '2024-25', label: '2024-25',
      startYear: 2024, rowCount: 0),
  ];

  @override
  Future<List<Map<String, dynamic>>> games({
    String? season, String? seasonType, String? team,
  }) async => [
    {
      'game_key': 'game-a',
      'game_date': '2025-11-13 00:00:00',
      'season_id': '2025-26',
      'season_type': 'regular',
      'away_team_name': 'Boston Celtics',
      'away_team_abbreviation': 'BOS',
      'home_team_name': 'Los Angeles Lakers',
      'home_team_abbreviation': 'LAL',
      'away_score': 104,
      'home_score': 101,
      'box_score_available': true,
    },
    {
      'game_key': 'game-b',
      'game_date': '2024-12-11 00:00:00',
      'season_id': '2024-25',
      'season_type': 'playoffs',
      'away_team_name': 'Denver Nuggets',
      'away_team_abbreviation': 'DEN',
      'home_team_name': 'New York Knicks',
      'home_team_abbreviation': 'NYK',
      'away_score': 115,
      'home_score': 112,
      'box_score_available': false,
    },
  ];

  @override
  Future<Map<String, dynamic>> gameDetail(String gameKey) async {
    if (gameKey != 'game-a') return {};
    return {
      'player_box_scores': [
        {
          'player_name': 'Example Celtic',
          'team_abbreviation': 'BOS',
          'minutes': 32,
          'pts': 22,
          'reb': 8,
          'ast': 6,
          'stl': 1,
          'blk': 0,
          'tov': 3,
          'fgm': 9,
          'fga': 16,
          'three_pm': 2,
          'three_pa': 7,
          'ftm': 2,
          'fta': 3,
        },
        {
          'player_name': 'Example Laker',
          'team_abbreviation': 'LAL',
          'minutes': 30,
          'pts': 18,
          'reb': 5,
          'ast': 4,
          'fgm': 8,
          'fga': 15,
        },
        {
          'player_name': 'Unused Celtic',
          'team_abbreviation': 'BOS',
          'minutes': null,
          'pts': null,
        },
      ],
    };
  }
}

Widget _harness({double width = 1200}) => MaterialApp(
  theme: SportsWorkspaceDesign.theme(true),
  home: Scaffold(
    body: SingleChildScrollView(
      child: WebsiteNbaBoxScoresScreen(api: const _FakeBoxArchive()),
    ),
  ),
);

void main() {
  testWidgets('historical archive filters player details without inventing rows',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 930);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('Historical static archive'), findsOneWidget);
    expect(find.textContaining('Boston Celtics'), findsOneWidget);
    expect(find.textContaining('Denver Nuggets'), findsOneWidget);

    await tester.tap(find.text('Detailed box scores only'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Boston Celtics'), findsOneWidget);
    expect(find.textContaining('Denver Nuggets'), findsNothing);

    await tester.tap(find.textContaining('Boston Celtics'));
    await tester.pumpAndSettle();
    expect(find.text('Player box score'), findsOneWidget);
    expect(find.text('Example Celtic'), findsOneWidget);
    expect(find.text('Unused Celtic'), findsNothing);

    await tester.tap(find.text('Home · LAL'));
    await tester.pumpAndSettle();
    expect(find.text('Example Laker'), findsOneWidget);
    expect(find.text('Example Celtic'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile archive reflows without overflowing', (tester) async {
    tester.view.physicalSize = const Size(430, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('Box Scores'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('blue remains readable in both theme configurations', () {
    for (final dark in [true, false]) {
      final theme = SportsWorkspaceDesign.theme(dark);
      final accent = theme.colorScheme.primary;
      final background = theme.colorScheme.surface;
      final a = accent.computeLuminance();
      final b = background.computeLuminance();
      final ratio = (a > b ? a + .05 : b + .05) /
          (a > b ? b + .05 : a + .05);
      expect(ratio, greaterThan(4.5));
      expect(theme.textTheme.titleLarge!.color,
          theme.colorScheme.onSurface);
    }
  });
}
