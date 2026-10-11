import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';
import 'package:sports_terminal/widgets/comparison_lab_controls.dart';

void main() {
  testWidgets('rate basis stays controlled through repeated changes',
      (tester) async {
    var basis = NbaStatsBasis.perGame;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, update) => Column(
          children: [
            ComparisonRateBasisSelector(
              value: basis,
              onChanged: (next) => update(() => basis = next),
            ),
            Text('Active: ${basis.name}'),
          ],
        )),
      ),
    ));

    Future<void> choose(String label) async {
      await tester.tap(find.byType(DropdownButton<NbaStatsBasis>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await choose('Per 36');
    expect(find.text('Active: per36'), findsOneWidget);
    await choose('Per 48');
    expect(find.text('Active: per48'), findsOneWidget);
    await choose('Per 100 Poss');
    expect(find.text('Active: per100'), findsOneWidget);
    await choose('Per Game');
    expect(find.text('Active: perGame'), findsOneWidget);
  });

  testWidgets('regular and playoff selection remains reversible',
      (tester) async {
    var segment = NbaStatsSeasonType.regular;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, update) => Column(
          children: [
            ComparisonSeasonTypeSelector(
              value: segment,
              onChanged: (next) => update(() => segment = next),
            ),
            Text('Segment: ${segment.name}'),
          ],
        )),
      ),
    ));

    await tester.tap(find.text('Playoffs'));
    await tester.pumpAndSettle();
    expect(find.text('Segment: playoffs'), findsOneWidget);
    await tester.tap(find.text('Regular Season'));
    await tester.pumpAndSettle();
    expect(find.text('Segment: regular'), findsOneWidget);
    await tester.tap(find.text('Playoffs'));
    await tester.pumpAndSettle();
    expect(find.text('Segment: playoffs'), findsOneWidget);
  });
}
