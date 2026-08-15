import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/services/nba_player_career_analytics_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_engine.dart';
import 'package:sports_terminal/services/nba_player_career_comparison_state_store.dart';
import 'package:sports_terminal/widgets/nba_player_career_comparison_history_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('history dialog filters saved and recent comparisons by Player',
      (tester) async {
    const store = NbaPlayerCareerComparisonStateStore();
    final alphaBeta = _item('p1', 'Alpha', 'p2', 'Beta');
    final gammaDelta = _item('p3', 'Gamma', 'p4', 'Delta');
    await store.record(alphaBeta);
    await store.toggleSaved(alphaBeta);
    await store.record(gammaDelta);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showNbaPlayerCareerComparisonHistory(
                context,
                playerKey: 'p1',
                store: store,
              ),
              child: const Text('History'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('CAREER COMPARISON HISTORY'), findsOneWidget);
    expect(find.text('Alpha vs Beta'), findsNWidgets(2));
    expect(find.text('Gamma vs Delta'), findsNothing);
    expect(find.text('SAVED'), findsOneWidget);
    expect(find.text('RECENT'), findsOneWidget);
  });

  testWidgets('unfiltered history exposes global recent comparison state',
      (tester) async {
    const store = NbaPlayerCareerComparisonStateStore();
    await store.record(
      NbaPlayerCareerComparisonStateItem(
        leftPlayerKey: 'p1',
        leftPlayerName: 'Alpha',
        rightPlayerKey: 'p2',
        rightPlayerName: 'Beta',
        seasonType: 'playoffs',
        alignment: NbaPlayerCareerComparisonAlignment.careerYear,
        metric: NbaPlayerCareerMetric.boxPlusMinus,
        sharedOnly: false,
        presetId: 'career-year',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showNbaPlayerCareerComparisonHistory(
                context,
                store: store,
              ),
              child: const Text('History'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha vs Beta'), findsOneWidget);
    expect(
      find.textContaining('PLAYOFFS · CAREER YEAR · BPM'),
      findsOneWidget,
    );
  });

  testWidgets('empty filtered history renders explicit no-match state',
      (tester) async {
    const store = NbaPlayerCareerComparisonStateStore();
    await store.record(_item('p3', 'Gamma', 'p4', 'Delta'));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showNbaPlayerCareerComparisonHistory(
                context,
                playerKey: 'p1',
                store: store,
              ),
              child: const Text('History'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(
      find.text('No matching saved or recent career comparisons.'),
      findsOneWidget,
    );
  });
}

NbaPlayerCareerComparisonStateItem _item(
  String leftKey,
  String leftName,
  String rightKey,
  String rightName,
) =>
    NbaPlayerCareerComparisonStateItem(
      leftPlayerKey: leftKey,
      leftPlayerName: leftName,
      rightPlayerKey: rightKey,
      rightPlayerName: rightName,
      seasonType: 'regular',
      alignment: NbaPlayerCareerComparisonAlignment.calendarSeason,
      metric: NbaPlayerCareerMetric.pointsPerGame,
      sharedOnly: false,
    );
