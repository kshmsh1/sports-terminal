import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/widgets/comparison_lab_components.dart';

void main() {
  Widget harness(double width) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: ComparisonSelectionLayout(
              children: [
                for (var i = 1; i <= 5; i++)
                  Card(
                    child: SizedBox(
                      height: 80,
                      child: Center(child: Text('Selection $i')),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  testWidgets('five comparison cards stay accessible on narrow viewports',
      (tester) async {
    await tester.pumpWidget(harness(390));
    final first = tester.getTopLeft(find.text('Selection 1'));
    final second = tester.getTopLeft(find.text('Selection 2'));
    expect(second.dy, greaterThan(first.dy));
    expect(find.text('Selection 5'), findsOneWidget);
  });

  testWidgets('wide viewports place comparison cards on the same row',
      (tester) async {
    await tester.view.setPhysicalSize(const Size(1800, 1100));
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(harness(1750));
    final first = tester.getTopLeft(find.text('Selection 1'));
    final fifth = tester.getTopLeft(find.text('Selection 5'));
    expect((first.dy - fifth.dy).abs(), lessThan(1));
  });

  testWidgets('missing-data guidance is visible and readable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ComparisonEmptyState(
          title: 'No data for this season',
          message: 'Try another season or segment.',
        ),
      ),
    ));
    expect(find.text('No data for this season'), findsOneWidget);
    expect(find.text('Try another season or segment.'), findsOneWidget);
  });

  testWidgets('comparison table expands to the available width',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 900,
          child: ComparisonTableViewport(
            participants: 2,
            builder: (width) => SizedBox(
              width: width,
              child: Text('Matrix width: ${width.round()}'),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Matrix width: 868'), findsOneWidget);
  });
}
