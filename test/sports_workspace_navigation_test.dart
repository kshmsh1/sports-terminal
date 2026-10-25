import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sports_terminal/models/app_session.dart';
import 'package:sports_terminal/widgets/sports_workspace_chrome.dart';
import 'package:sports_terminal/widgets/sports_workspace_design.dart';

const _session = AppSession(
  userId: 'ux-test',
  email: 'ux-test@example.invalid',
  displayName: 'Test Analyst',
  organizationId: 'test-org',
  organizationName: 'Test',
  role: UserRole.analyst,
);

const _items = <WorkspaceNavItem>[
  WorkspaceNavItem(
    id: 'sports', label: 'Overview', icon: Icons.home_outlined,
    group: 'Start',
  ),
  WorkspaceNavItem(
    id: 'research', label: 'Research', icon: Icons.search,
    group: 'Research & analysis',
  ),
  WorkspaceNavItem(
    id: 'trade', label: 'Trade Machine', icon: Icons.swap_horiz,
    group: 'Front office',
  ),
  WorkspaceNavItem(
    id: 'python-lab', label: 'Python Lab', icon: Icons.code,
    group: 'More', enabled: false,
  ),
];

Widget testApp(ValueChanged<String> onSelect) => MaterialApp(
  theme: SportsWorkspaceDesign.theme(true),
  home: SportsWorkspaceChrome(
    session: _session,
    items: _items,
    selected: 'sports',
    darkMode: true,
    onSelect: onSelect,
    onTheme: () {},
    onSearchPeople: () {},
    onSignOut: () {},
    child: const Center(child: Text('Research workspace content')),
  ),
);

void main() {
  test('workspace palettes and density keep dark/light distinction', () {
    final light = SportsWorkspaceDesign.theme(false);
    final dark = SportsWorkspaceDesign.theme(true);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
    expect(
      SportsWorkspaceDesign.maxContentWidth('visualizations'),
      greaterThan(SportsWorkspaceDesign.maxContentWidth('research')),
    );
    expect(SportsWorkspaceDesign.gutters(430, 'stats').left,
      lessThan(SportsWorkspaceDesign.gutters(1400, 'stats').left));
  });

  testWidgets('desktop has top navigation and grouped research menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? opened;
    await tester.pumpWidget(testApp((value) => opened = value));
    await tester.pumpAndSettle();

    expect(find.text('Sports Terminal'), findsOneWidget);
    expect(find.text('Analyze'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();
    expect(find.text('Research'), findsOneWidget);
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();
    expect(opened, 'research');
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile top menu opens a research destination', (tester) async {
    tester.view.physicalSize = const Size(420, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? opened;
    await tester.pumpWidget(testApp((value) => opened = value));
    await tester.tap(find.byTooltip('Navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Research'), findsOneWidget);
    await tester.tap(find.text('Research'));
    await tester.pumpAndSettle();
    expect(opened, 'research');
    expect(tester.takeException(), isNull);
  });

  testWidgets('command palette can open a workbench without navigating to locked tools', (tester) async {
    tester.view.physicalSize = const Size(1100, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? opened;
    await tester.pumpWidget(testApp((value) => opened = value));
    await tester.tap(find.byTooltip('Jump to workspace (Cmd/Ctrl + K)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Trade');
    await tester.pumpAndSettle();
    expect(find.text('Trade Machine'), findsOneWidget);
    await tester.tap(find.text('Trade Machine'));
    await tester.pumpAndSettle();
    expect(opened, 'trade');
    expect(tester.takeException(), isNull);
  });
}
