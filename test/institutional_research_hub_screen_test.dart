import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/models/app_session.dart';
import 'package:sports_terminal/screens/institutional_research_hub_screen.dart';

void main() {
  testWidgets('institutional research OS mounts all five workflow surfaces',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const session = AppSession(
      userId: 'analyst-1',
      email: 'analyst@example.com',
      displayName: 'Analyst',
      organizationId: 'org-1',
      organizationName: 'Research Org',
      role: UserRole.analyst,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 1000,
            child: InstitutionalResearchHubScreen(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Institutional Research OS'), findsOneWidget);
    expect(find.text('RESEARCH LIBRARY'), findsOneWidget);
    expect(find.text('METRIC REGISTRY'), findsOneWidget);
    expect(find.text('MODEL REGISTRY'), findsOneWidget);
    expect(find.text('WATCHES'), findsOneWidget);
    expect(find.text('BUNDLES'), findsOneWidget);
    expect(find.textContaining('registered metrics'), findsOneWidget);
    expect(find.textContaining('registered models'), findsOneWidget);
  });

  testWidgets('metric and model registry tabs are inspectable', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const session = AppSession(
      userId: 'analyst-1',
      email: 'analyst@example.com',
      displayName: 'Analyst',
      organizationId: 'org-1',
      organizationName: 'Research Org',
      role: UserRole.analyst,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 1000,
            child: InstitutionalResearchHubScreen(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('METRIC REGISTRY'));
    await tester.pumpAndSettle();
    expect(find.textContaining('REGISTRY INTEGRITY PASS'), findsOneWidget);
    expect(find.textContaining('Points · pts'), findsOneWidget);

    await tester.tap(find.text('MODEL REGISTRY'));
    await tester.pumpAndSettle();
    expect(find.textContaining('REGISTRY INTEGRITY PASS'), findsOneWidget);
    expect(find.text('Observed Score Flow'), findsOneWidget);
  });
}
