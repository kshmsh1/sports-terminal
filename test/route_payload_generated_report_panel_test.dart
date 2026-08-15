import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/models/route_payload.dart';
import 'package:sports_terminal/widgets/route_payload_generated_report_panel.dart';

void main() {
  const payload = RoutePayload(
    sourceObjectType: 'Team',
    sourceObjectId: 'BOS',
    displayLabel: 'Boston Team Snapshot',
    selectedColumns: ['team', 'wins', 'note'],
    selectedRows: ['BOS'],
    filterSummary: 'season=2025-26',
    sourceSnapshot: 'fixture-release',
    readinessState: 'Ready',
    blockers: [],
    targetRoute: 'Reports',
    availableActions: ['Reports', 'Export'],
    columns: [
      RoutePayloadColumn(key: 'team', label: 'Team'),
      RoutePayloadColumn(key: 'wins', label: 'Wins'),
      RoutePayloadColumn(key: 'note', label: 'Note'),
    ],
    rows: [
      {'team': 'Boston', 'wins': 55, 'note': null},
    ],
  );

  testWidgets('generated report panel previews exact data and output formats',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1200,
              child: RoutePayloadGeneratedReportPanel(payload: payload),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('route-payload-generated-report-panel')),
      findsOneWidget,
    );
    expect(find.text('Generated Report Shell'), findsOneWidget);
    expect(find.text('READY'), findsOneWidget);
    expect(find.text('Boston Team Snapshot — Source-Backed Report'), findsOneWidget);
    expect(find.text('Boston'), findsOneWidget);
    expect(find.text('55'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('generated-report-view-markdown')));
    await tester.pump();
    final markdown = tester.widget<SelectableText>(
      find.byKey(const ValueKey('generated-report-output')),
    );
    expect(markdown.data, contains('# Boston Team Snapshot'));
    expect(markdown.data, contains('| Boston | 55 | — |'));

    await tester.tap(find.byKey(const ValueKey('generated-report-view-json')));
    await tester.pump();
    final json = tester.widget<SelectableText>(
      find.byKey(const ValueKey('generated-report-output')),
    );
    expect(json.data, contains('"coverage": "READY"'));
    expect(json.data, contains('"note": null'));

    await tester.tap(find.byKey(const ValueKey('generated-report-view-tsv')));
    await tester.pump();
    final tsv = tester.widget<SelectableText>(
      find.byKey(const ValueKey('generated-report-output')),
    );
    expect(tsv.data, contains('Team\tWins\tNote'));
    expect(tsv.data, contains('Boston\t55\tNA'));
  });

  test('Reports RoutePayload intake mounts generated report production surface', () {
    final source = File('lib/widgets/active_route_payload_panel.dart')
        .readAsStringSync();

    expect(
      source,
      contains("import 'route_payload_generated_report_panel.dart';"),
    );
    expect(source, contains('RoutePayloadGeneratedReportPanel(payload: payload)'));
    expect(source, contains("consumerName.toLowerCase().contains('report')"));
  });
}
