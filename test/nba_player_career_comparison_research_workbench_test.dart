import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/screens/product_nba_player_career_comparison_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('permanent comparison mounts the full research workbench',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: _screen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('career-comparison-research-workbench')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('career-comparison-state-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('career-comparison-workflow-state-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('career-comparison-multi-metric-matrix')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('career-comparison-peak-window')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('career-comparison-distribution-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('career-comparison-season-type-delta')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('career-comparison-export-panel')),
      findsOneWidget,
    );
  });

  testWidgets('shared-season filter narrows matrix to exact overlap',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: _screen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filter = find.byKey(
      const ValueKey('career-comparison-shared-season-filter'),
    );
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();

    expect(find.textContaining('1 SHARED CALENDAR SEASON'), findsWidgets);
    expect(find.text('2021-22'), findsWidgets);
  });

  testWidgets('save watch and research controls persist comparison identity',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: _screen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey('career-comparison-toggle-saved'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('SAVED'), findsOneWidget);

    final watch = find.byKey(const ValueKey('career-comparison-toggle-watch'));
    await tester.tap(watch);
    await tester.pumpAndSettle();
    expect(find.text('WATCHING'), findsOneWidget);

    final research =
        find.byKey(const ValueKey('career-comparison-activate-research'));
    await tester.tap(research);
    await tester.pumpAndSettle();
    expect(find.text('ACTIVE RESEARCH'), findsOneWidget);
  });
}

ProductNbaPlayerCareerComparisonScreen _screen() =>
    ProductNbaPlayerCareerComparisonScreen(
      leftPlayerKey: 'p1',
      leftPlayerName: 'Alpha Player',
      rightPlayerKey: 'p2',
      rightPlayerName: 'Beta Player',
      loadPlayer: (key, seasonType) async =>
          _playerPayload(key, seasonType),
      loadTeam: (key) async => _teamDossier(key),
    );

Map<String, dynamic> _playerPayload(String key, String seasonType) {
  final seasons = key == 'p1'
      ? ['2020-21', '2021-22']
      : ['2021-22', '2022-23'];
  final playoff = seasonType == 'playoffs';
  return {
    'profile': {
      'player_key': key,
      'canonical_name': key == 'p1' ? 'Alpha Player' : 'Beta Player',
      'primary_position': 'G',
    },
    'summary': {
      'first_season': seasons.first,
      'last_season': seasons.last,
      'season_rows': 2,
    },
    'seasons': [
      for (var index = 0; index < seasons.length; index++)
        {
          'season_id': seasons[index],
          'season_type': seasonType,
          'league_id': 'NBA',
          'team_key': 'team-$key',
          'team_name': 'Team $key',
          'team_abbreviation': key == 'p1' ? 'ALP' : 'BET',
          'games': playoff ? 5 : 10,
          'pts': (key == 'p1' ? 220 : 200) + index * 10,
          'reb': (key == 'p1' ? 60 : 70) + index * 5,
          'ast': (key == 'p1' ? 80 : 50) + index * 5,
          'stl': 12,
          'blk': 4,
          'tov': 25,
          'ts_pct': key == 'p1' ? .61 : .58,
          'per': key == 'p1' ? 22.0 : 19.0,
          'ws': key == 'p1' ? 6.0 : 5.0,
          'bpm': key == 'p1' ? 4.0 : 2.0,
          'vorp': key == 'p1' ? 3.0 : 2.0,
          'primary_source': 'fixture',
        },
    ],
    'awards': [
      {
        'season_id': seasons.last,
        'award': 'Example Award',
        'source': 'fixture',
      },
    ],
    'all_star': [
      {
        'season_id': seasons.last,
        'selection': 'All-Star',
        'source': 'fixture',
      },
    ],
    'draft': const [],
    'recent_games': const [],
    'identities': const [
      {'source_key': 'fixture'},
    ],
    'field_provenance': const [
      {'field_name': 'canonical_name'},
    ],
  };
}

Map<String, dynamic> _teamDossier(String teamKey) => {
      'profile': {
        'team_key': teamKey,
        'canonical_name': 'Team $teamKey',
        'franchise_key': 'franchise-$teamKey',
        'franchise_name': 'Franchise $teamKey',
      },
    };
