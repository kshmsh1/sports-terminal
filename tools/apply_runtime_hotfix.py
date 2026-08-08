from pathlib import Path


def replace(path_str: str, old: str, new: str, expected: int = 1) -> None:
    path = Path(path_str)
    text = path.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(
            f"{path}: expected {expected} copies, found {count}: {old[:90]!r}"
        )
    path.write_text(text.replace(old, new))


terminal = "lib/screens/product_nba_terminal_screen.dart"
replace(
    terminal,
    "      if (mounted) setState(() => _terminalStateFuture = _stateStore.load());",
    """      if (mounted) {
        setState(() {
          _terminalStateFuture = _stateStore.load();
        });
      }""",
)
replace(
    terminal,
    "    if (mounted) setState(() => _terminalStateFuture = Future.value(next));",
    """    if (mounted) {
      setState(() {
        _terminalStateFuture = Future.value(next);
      });
    }""",
)
replace(
    terminal,
    "    setState(() => _terminalStateFuture = Future.value(next));",
    """    setState(() {
      _terminalStateFuture = Future.value(next);
    });""",
)
replace(
    terminal,
    """          body: scroll
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1480),
                      child: body,
                    ),
                  ),
                )
              : body,""",
    """          // Routed product surfaces own their scrolling and flex layout. Wrapping
          // a full-screen destination in an outer SingleChildScrollView gives its
          // Expanded/Flexible descendants unbounded height and breaks debug layout.
          body: scroll
              ? Padding(
                  padding: const EdgeInsets.all(22),
                  child: body,
                )
              : body,""",
)

stats = "lib/screens/product_nba_stats_workstation_screen.dart"
replace(
    stats,
    """                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {""",
    """                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {""",
)
replace(
    stats,
    """                    final table = Expanded(
                      child: _StatsTable(""",
    """                    final table = _StatsTable(""",
)
replace(
    stats,
    """                        onCompare: _toggleCompare,
                      ),
                    );
                    final inspector""",
    """                        onCompare: _toggleCompare,
                    );
                    final inspector""",
)
replace(
    stats,
    """                    if (wide) {
                      return SizedBox(
                        height: 720,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            table,
                            const SizedBox(width: 8),
                            SizedBox(width: 286, child: inspector),
                          ],
                        ),
                      );
                    }
                    return Column(
                      children: [
                        SizedBox(height: 650, child: table),
                        const SizedBox(height: 8),
                        inspector,
                      ],
                    );""",
    """                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: table),
                          const SizedBox(width: 8),
                          SizedBox(width: 286, child: inspector),
                        ],
                      );
                    }
                    return ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        SizedBox(
                          height: math.max(420.0, constraints.maxHeight * .72),
                          child: table,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(height: 520, child: inspector),
                      ],
                    );""",
)
replace(
    stats,
    """                  },
                ),
                const SizedBox(height: 8),
                _FooterBar(""",
    """                    },
                  ),
                ),
                const SizedBox(height: 8),
                _FooterBar(""",
)
replace(
    stats,
    """      value: values.contains(value) ? value : values.first,
      dropdownColor: _panel2,""",
    """      value: values.contains(value) ? value : values.first,
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down_rounded, size: 14),
      dropdownColor: _panel2,""",
)
replace(
    stats,
    "contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),",
    "contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),",
)

seed = "lib/services/nba_terminal_seed_repository.dart"
replace(
    seed,
    "import 'package:flutter/services.dart' show rootBundle;",
    "import 'package:flutter/services.dart' show AssetManifest, rootBundle;",
)
replace(
    seed,
    """    final allowFallback = config['allowFallback'] != false;

    try {""",
    """    final allowFallback = config['allowFallback'] != false;

    // On Flutter Web, probing a missing asset emits a noisy engine-level 404
    // before rootBundle throws. Consult the bundle manifest first so an absent
    // current-season candidate can fall back without requesting every file.
    if (allowFallback &&
        candidate != fallback &&
        !await _assetExists('$candidate/manifest.json')) {
      return _loadFrom(
        fallback,
        launchConfig: config,
        usedFallback: true,
      );
    }

    try {""",
)
replace(
    seed,
    """  Future<Map<String, dynamic>> _loadObject(
    String resolvedBasePath,""",
    """  Future<bool> _assetExists(String path) async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().contains(path);
    } catch (_) {
      // Tests and older embedding environments may not expose the binary asset
      // manifest. Preserve the existing load-and-catch behavior in that case.
      return true;
    }
  }

  Future<Map<String, dynamic>> _loadObject(
    String resolvedBasePath,""",
)
replace(
    seed,
    """  ) async {
    try {
      return await _loadObject(resolvedBasePath, filename);""",
    """  ) async {
    if (!await _assetExists('$resolvedBasePath/$filename')) return null;
    try {
      return await _loadObject(resolvedBasePath, filename);""",
    expected=1,
)
replace(
    seed,
    """  ) async {
    try {
      return await _loadList(resolvedBasePath, filename);""",
    """  ) async {
    if (!await _assetExists('$resolvedBasePath/$filename')) return null;
    try {
      return await _loadList(resolvedBasePath, filename);""",
    expected=1,
)

dev = "backend/scripts/dev.sh"
replace(
    dev,
    """# A prior Sports Terminal dev server can survive when Flutter is stopped or a
# terminal session is interrupted. Starting a second uvicorn instance then
# fails with \"Address already in use\", while the frontend keeps talking to the
# stale server. Detect that case explicitly so local development is deterministic.
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 1 \"http://127.0.0.1:${PORT_VALUE}/v2/launch/readiness\" >/dev/null 2>&1; then
  echo \"Sports Terminal launch backend is already healthy on port ${PORT_VALUE}.\"
  echo \"Reusing the existing backend process.\"
  exit 0
fi

""",
    """# A prior Sports Terminal dev server can survive when Flutter is stopped or a
# terminal session is interrupted. Always replace an existing Sports Terminal
# listener so freshly-pulled frontend code never talks to stale backend code.
""",
)
replace(
    dev,
    """      for _ in 1 2 3 4 5 6 7 8; do
        if ! lsof -tiTCP:\"${PORT_VALUE}\" -sTCP:LISTEN >/dev/null 2>&1; then
          break
        fi
        sleep 0.4
      done
    else""",
    """      for _ in 1 2 3 4 5 6 7 8; do
        if ! lsof -tiTCP:\"${PORT_VALUE}\" -sTCP:LISTEN >/dev/null 2>&1; then
          break
        fi
        sleep 0.4
      done
      REMAINING_PIDS=\"$(lsof -tiTCP:\"${PORT_VALUE}\" -sTCP:LISTEN 2>/dev/null || true)\"
      if [ -n \"$REMAINING_PIDS\" ]; then
        echo \"Force-stopping stale Sports Terminal backend process(es): ${REMAINING_PIDS//$'\\n'/ }\"
        while IFS= read -r pid; do
          [ -n \"$pid\" ] && kill -9 \"$pid\" 2>/dev/null || true
        done <<< \"$REMAINING_PIDS\"
        sleep 0.5
      fi
    else""",
)

test1 = "test/transaction_convergence_collaboration_test.dart"
replace(
    test1,
    "SharedPreferences.setMockInitialValues({});",
    """SharedPreferences.setMockInitialValues({
      ProductLocalStore.launchRemoteSyncEnabledKey: false,
    });""",
)

test2 = "test/transaction_decision_notification_test.dart"
replace(
    test2,
    "import 'package:sports_terminal/services/transaction_case_repository.dart';",
    """import 'package:sports_terminal/services/product_local_store.dart';
import 'package:sports_terminal/services/transaction_case_repository.dart';""",
)
replace(
    test2,
    "SharedPreferences.setMockInitialValues(<String, Object>{});",
    """SharedPreferences.setMockInitialValues(<String, Object>{
      ProductLocalStore.launchRemoteSyncEnabledKey: false,
    });""",
)

Path("test/nba_terminal_debug_runtime_test.dart").write_text(
    r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_terminal/models/app_session.dart';
import 'package:sports_terminal/screens/product_nba_terminal_screen.dart';
import 'package:sports_terminal/services/product_local_store.dart';

void main() {
  const session = AppSession(
    userId: 'debug-runtime-user',
    email: 'debug@example.com',
    displayName: 'Debug Runtime',
    organizationId: '',
    organizationName: '',
    role: UserRole.analyst,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ProductLocalStore.launchRemoteSyncEnabledKey: false,
    });
  });

  testWidgets('terminal state mutations remain synchronous inside setState',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductNbaTerminalScreen(session: session),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 's');
    await tester.tap(find.widgetWithText(FilledButton, 'GO'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('NBA Terminal Home').first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
'''
)

Path("scripts/dev_all.sh").write_text(
    r'''#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

WEB_HOST="${WEB_HOST:-127.0.0.1}"
WEB_PORT="${WEB_PORT:-5000}"
BACKEND_PORT="${PORT:-8000}"
BACKEND_LOG="${BACKEND_LOG:-/tmp/sports_terminal_backend.log}"
RUN_CHECKS="${RUN_CHECKS:-0}"

flutter pub get

if [ "$RUN_CHECKS" = "1" ]; then
  flutter analyze
  flutter test
fi

PORT="$BACKEND_PORT" bash scripts/dev_backend.sh >"$BACKEND_LOG" 2>&1 &
BACKEND_PID=$!

cleanup() {
  if kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

READY=0
for _ in $(seq 1 90); do
  if curl -fsS --max-time 1 "http://127.0.0.1:${BACKEND_PORT}/v2/launch/readiness" >/tmp/sports_terminal_readiness.json 2>/dev/null; then
    READY=1
    break
  fi
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    break
  fi
  sleep 1
done

if [ "$READY" != "1" ]; then
  echo "Sports Terminal backend failed to become ready on port ${BACKEND_PORT}." >&2
  tail -n 120 "$BACKEND_LOG" >&2 || true
  exit 1
fi

echo "Sports Terminal backend ready on http://127.0.0.1:${BACKEND_PORT}"
echo "Launching Flutter Web on http://${WEB_HOST}:${WEB_PORT}"
echo "Backend log: ${BACKEND_LOG}"

flutter run -d chrome --web-hostname "$WEB_HOST" --web-port "$WEB_PORT"
'''
)
