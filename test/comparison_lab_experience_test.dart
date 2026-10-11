import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/comparison_lab_experience.dart';

void main() {
  testWidgets('two participants show comparable difference, not synthetic score',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ComparisonHeadToHead(
        leftName: 'Player One',
        rightName: 'Player Two',
        leftContext: '2025-26', rightContext: '2025-26',
        leftColor: Colors.indigo,
        rightColor: Colors.pink,
        metrics: [
          ComparisonDuelMetric(
            label: 'PTS', leftValue: 33.5, rightValue: 31.1,
            leftDisplay: '33.5', rightDisplay: '31.1',
            higherIsBetter: true,
          ),
          ComparisonDuelMetric(
            label: 'FG%', leftValue: .523, rightValue: .498,
            leftDisplay: '52.3%', rightDisplay: '49.8%',
            higherIsBetter: true, percent: true,
          ),
        ],
      )),
    ));
    expect(find.text('HEAD-TO-HEAD'), findsOneWidget);
    expect(find.text('Δ 2.4'), findsOneWidget);
    expect(find.text('Δ 2.5 pp'), findsOneWidget);
    expect(find.text('33.5'), findsOneWidget);
    expect(find.text('31.1'), findsOneWidget);
  });

  testWidgets('search filters candidates and returns the explicit choice',
      (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) =>
        ElevatedButton(
          onPressed: () async {
            selected = await showComparisonSearch(context,
              title: 'Select a player',
              accent: Colors.indigo,
              options: const [
                ComparisonSearchOption(
                  id: '1', title: 'Nikola Jokić', subtitle: 'DEN'),
                ComparisonSearchOption(
                  id: '2', title: 'Luka Dončić', subtitle: 'LAL'),
                ComparisonSearchOption(
                  id: '3', title: 'Jayson Tatum', subtitle: 'BOS',
                  disabled: true),
              ],
            );
          },
          child: const Text('Choose player'),
        ),
      )),
    ));
    await tester.tap(find.text('Choose player'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Joki');
    await tester.pumpAndSettle();
    expect(find.text('Nikola Jokić'), findsOneWidget);
    expect(find.text('Luka Dončić'), findsNothing);
    await tester.tap(find.text('Nikola Jokić'));
    await tester.pumpAndSettle();
    expect(selected, '1');
  });

  testWidgets('fingerprint renders all participants, with a missing value',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ComparisonFingerprintPanel(
        title: 'Season-relative fingerprint',
        description: 'Season context',
        rows: [
          ComparisonFingerprintRow(
            metric: 'PTS',
            entries: [
              ComparisonFingerprintEntry(
                label: 'Player A', color: Colors.indigo, value: 98),
              ComparisonFingerprintEntry(
                label: 'Player B', color: Colors.pink, value: 80),
              ComparisonFingerprintEntry(
                label: 'Player C', color: Colors.teal, value: null),
            ],
          ),
        ],
      )),
    ));
    expect(find.text('Player A · 98p'), findsOneWidget);
    expect(find.text('Player B · 80p'), findsOneWidget);
    expect(find.text('Player C · —p'), findsOneWidget);
  });
}
