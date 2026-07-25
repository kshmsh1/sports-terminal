import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/route_payload_controller.dart';
import '../models/app_session.dart';
import '../models/route_payload.dart';
import '../services/product_local_store.dart';
import '../services/python_runtime_service.dart';
import '../services/sports_object_router.dart';
import '../services/workspace_route_import_service.dart';
import 'product_cap_lab_screen.dart';
import 'product_object_router_screen.dart';

const _runtimeNavy = Color(0xFF071A33);
const _runtimeBlue = Color(0xFF2563EB);
const _runtimeOrange = Color(0xFFFF7A1A);
const _runtimeGreen = Color(0xFF059669);
const _runtimeInk = Color(0xFF102033);
const _runtimeMuted = Color(0xFF667085);
const _runtimeLine = Color(0xFFE3E8F0);
const _runtimeSoft = Color(0xFFF6F8FC);

class ProductConnectedDataStudioScreen extends StatefulWidget {
  const ProductConnectedDataStudioScreen({
    super.key,
    required this.session,
  });

  final AppSession session;

  @override
  State<ProductConnectedDataStudioScreen> createState() =>
      _ProductConnectedDataStudioScreenState();
}

class _ProductConnectedDataStudioScreenState
    extends State<ProductConnectedDataStudioScreen> {
  final ProductLocalStore store = const ProductLocalStore();
  final PythonRuntimeService runtime = const PythonRuntimeService();
  final SportsObjectRouter router = const SportsObjectRouter();
  final WorkspaceRouteImportService workspaceImporter =
      const WorkspaceRouteImportService();
  late final TextEditingController codeController;

  String tab = 'Notebook';
  String output = 'Ready. Route a structured dataset into Python Lab and run it in the isolated backend runtime.';
  bool loaded = false;
  bool running = false;
  Map<String, dynamic>? capabilities;
  int lastDurationMs = 0;
  String lastStatus = 'Not run';

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController(text: _defaultStarter);
    _restore();
    _loadCapabilities();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final savedCode = await store.loadString(
      ProductLocalStore.pythonNotebookCodeKey,
      fallback: _defaultStarter,
    );
    final savedOutput = await store.loadString(
      ProductLocalStore.pythonNotebookOutputKey,
      fallback: output,
    );
    if (!mounted) return;
    setState(() {
      codeController.text = savedCode.isEmpty ? _defaultStarter : savedCode;
      output = savedOutput;
      loaded = true;
    });
  }

  Future<void> _loadCapabilities() async {
    final value = await runtime.capabilities();
    if (!mounted) return;
    setState(() => capabilities = value);
  }

  Future<void> _persist() async {
    await store.saveString(
      ProductLocalStore.pythonNotebookCodeKey,
      codeController.text,
    );
    await store.saveString(
      ProductLocalStore.pythonNotebookOutputKey,
      output,
    );
  }

  void _loadStarter(RoutePayload? payload) {
    if (payload == null) {
      codeController.text = _defaultStarter;
    } else {
      codeController.text = _starterFor(payload);
    }
    setState(() {
      output = payload == null
          ? 'Loaded the generic runtime starter.'
          : 'Loaded a sandbox-compatible starter for ${payload.displayLabel}.';
      lastStatus = 'Starter loaded';
    });
    _persist();
  }

  Future<void> _run(RoutePayload? payload) async {
    setState(() {
      running = true;
      lastStatus = 'Running';
      output = 'Submitting notebook to the isolated Python runtime...';
    });
    final result = await runtime.execute(
      code: codeController.text,
      payload: payload,
    );
    if (!mounted) return;
    final lines = <String>[];
    if (result.completed) {
      lines.add('PYTHON NOTEBOOK COMPLETED');
      lines.add('');
      lines.add('Rows: ${result.rowCount}');
      lines.add('Columns: ${result.columnCount}');
      lines.add('Duration: ${result.durationMs} ms');
      if (result.warnings.isNotEmpty) {
        lines.add('Warnings: ${result.warnings.join(' ')}');
      }
      if (result.stdout.trim().isNotEmpty) {
        lines.addAll(['', 'STDOUT', result.stdout.trimRight()]);
      }
      lines.addAll([
        '',
        'RESULT',
        const JsonEncoder.withIndent('  ').convert(result.result),
      ]);
    } else {
      lines.add(result.available
          ? 'PYTHON NOTEBOOK REJECTED'
          : 'PYTHON RUNTIME OFFLINE');
      lines.add('');
      lines.add(result.error);
      lines.add('');
      lines.add(
        result.statusCode == 422
            ? 'The sandbox rejected disallowed syntax or the notebook raised a bounded execution error.'
            : 'Start the launch backend and confirm remote-first collaboration is enabled.',
      );
    }
    setState(() {
      running = false;
      lastDurationMs = result.durationMs;
      lastStatus = result.completed
          ? 'Completed'
          : result.available
              ? 'Rejected'
              : 'Offline';
      output = lines.join('\n');
    });
    await _persist();
  }

  void _localSummary(RoutePayload? payload) {
    if (payload == null || payload.rows.isEmpty) {
      setState(() {
        output = 'No structured route package is active.';
        lastStatus = 'No package';
      });
      _persist();
      return;
    }
    final lines = <String>[
      'LOCAL FALLBACK SUMMARY',
      '',
      'Package: ${payload.displayLabel}',
      'Rows: ${payload.rowCount}',
      'Columns: ${payload.columnCount}',
      '',
    ];
    for (final column in payload.columns.where(
      (column) => column.dataType == 'number' || column.dataType == 'integer',
    ).take(10)) {
      final values = <double>[
        for (final row in payload.rows)
          if (row[column.key] is num)
            (row[column.key] as num).toDouble(),
      ];
      if (values.isEmpty) continue;
      final total = values.fold<double>(0, (sum, value) => sum + value);
      final minimum = values.reduce((a, b) => a < b ? a : b);
      final maximum = values.reduce((a, b) => a > b ? a : b);
      lines.add(
        '${column.label}: count=${values.length}, mean=${(total / values.length).toStringAsFixed(3)}, min=${minimum.toStringAsFixed(3)}, max=${maximum.toStringAsFixed(3)}',
      );
    }
    lines.addAll([
      '',
      'This fallback runs in Dart and does not execute notebook code.',
    ]);
    setState(() {
      output = lines.join('\n');
      lastStatus = 'Local summary';
      lastDurationMs = 0;
    });
    _persist();
  }

  Future<void> _copyOutput() async {
    await Clipboard.setData(ClipboardData(text: output));
    if (!mounted) return;
    _show('Notebook output copied.');
  }

  Future<void> _copyTsv(RoutePayload? payload) async {
    if (payload == null) return;
    await Clipboard.setData(ClipboardData(text: router.toTsv(payload)));
    if (!mounted) return;
    _show('${payload.rowCount} rows copied as TSV.');
  }

  Future<void> _exportWorkspace(RoutePayload? payload) async {
    if (payload == null) return;
    final routed = payload.copyWith(targetRoute: 'Workspace');
    RoutePayloadScope.maybeOf(context)?.setActivePayload(
      routed,
      origin: 'Connected Python runtime export',
    );
    final result = await workspaceImporter.importPayload(routed);
    if (!mounted) return;
    _show('${result.summary}. Open Workspace to continue.');
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const _RuntimeSurface(
        child: Text(
          'Loading connected Data & Code Studio...',
          style: TextStyle(color: _runtimeMuted),
        ),
      );
    }
    final controller = RoutePayloadScope.maybeOf(context);
    final payload = controller?.activePayload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RuntimeHero(
          payload: payload,
          online: capabilities != null,
        ),
        const SizedBox(height: 18),
        _RuntimeMetrics(
          items: [
            _RuntimeMetric(
              'Runtime',
              capabilities == null ? 'Offline' : 'Isolated Python',
              capabilities == null ? 'local fallback available' : 'server subprocess',
            ),
            _RuntimeMetric(
              'Active rows',
              '${payload?.rowCount ?? 0}',
              payload?.displayLabel ?? 'no routed package',
            ),
            _RuntimeMetric('Last status', lastStatus, '$lastDurationMs ms'),
            _RuntimeMetric(
              'Policy',
              'Bounded',
              'no imports, files, network or processes',
            ),
          ],
        ),
        const SizedBox(height: 18),
        _RuntimeTabs(
          selected: tab,
          onSelected: (value) => setState(() => tab = value),
        ),
        const SizedBox(height: 18),
        if (tab == 'Object Router')
          const ProductObjectRouterScreen()
        else if (tab == 'Cap Lab')
          const ProductCapLabScreen()
        else if (tab == 'Route History')
          _RouteHistory(controller: controller)
        else if (tab == 'Runtime Policy')
          _RuntimePolicy(capabilities: capabilities)
        else
          _Notebook(
            codeController: codeController,
            output: output,
            payload: payload,
            running: running,
            onChanged: _persist,
            onStarter: () => _loadStarter(payload),
            onRun: () => _run(payload),
            onLocalSummary: () => _localSummary(payload),
            onCopyOutput: _copyOutput,
            onCopyTsv: () => _copyTsv(payload),
            onExportWorkspace: () => _exportWorkspace(payload),
          ),
      ],
    );
  }
}

class _Notebook extends StatelessWidget {
  const _Notebook({
    required this.codeController,
    required this.output,
    required this.payload,
    required this.running,
    required this.onChanged,
    required this.onStarter,
    required this.onRun,
    required this.onLocalSummary,
    required this.onCopyOutput,
    required this.onCopyTsv,
    required this.onExportWorkspace,
  });

  final TextEditingController codeController;
  final String output;
  final RoutePayload? payload;
  final bool running;
  final VoidCallback onChanged;
  final VoidCallback onStarter;
  final VoidCallback onRun;
  final VoidCallback onLocalSummary;
  final VoidCallback onCopyOutput;
  final VoidCallback onCopyTsv;
  final VoidCallback onExportWorkspace;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 950;
          final editor = _RuntimeSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Python notebook',
                        style: TextStyle(
                          color: _runtimeInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _StatusPill(
                      payload == null ? 'NO PACKAGE' : 'ROUTED DATA',
                      payload == null ? _runtimeOrange : _runtimeGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Assign a JSON-compatible value to result. Approved helpers include column, numeric, mean, median, percentile and group_by.',
                  style: TextStyle(color: _runtimeMuted, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: codeController,
                  minLines: 20,
                  maxLines: 32,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.45,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF08111F),
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: running ? null : onRun,
                      icon: running
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: const Text('Run isolated Python'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onStarter,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('Generate starter'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onLocalSummary,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Local fallback summary'),
                    ),
                    OutlinedButton.icon(
                      onPressed: payload == null ? null : onCopyTsv,
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy TSV'),
                    ),
                    OutlinedButton.icon(
                      onPressed: payload == null ? null : onExportWorkspace,
                      icon: const Icon(Icons.grid_on_rounded),
                      label: const Text('Export to Workspace'),
                    ),
                  ],
                ),
              ],
            ),
          );
          final console = _RuntimeSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Execution output',
                        style: TextStyle(
                          color: _runtimeInk,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy output',
                      onPressed: onCopyOutput,
                      icon: const Icon(Icons.copy_all_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 430),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF08111F),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    output,
                    style: const TextStyle(
                      color: Color(0xFFE6EDF7),
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (compact) {
            return Column(
              children: [
                editor,
                const SizedBox(height: 14),
                console,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: editor),
              const SizedBox(width: 14),
              Expanded(flex: 5, child: console),
            ],
          );
        },
      );
}

class _RouteHistory extends StatelessWidget {
  const _RouteHistory({required this.controller});
  final RoutePayloadController? controller;

  @override
  Widget build(BuildContext context) {
    final rows = controller?.history ?? const <RoutePayload>[];
    return _RuntimeSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${rows.length} routed packages',
                    style: const TextStyle(
                      color: _runtimeInk,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: rows.isEmpty ? null : controller?.clearHistory,
                  child: const Text('Clear history'),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(
                'No route packages have been published yet.',
                style: TextStyle(color: _runtimeMuted),
              ),
            )
          else
            for (final payload in rows)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.route_rounded)),
                title: Text(payload.conciseDebugLabel),
                subtitle: Text(
                  '${payload.rowCount} rows · ${payload.columnCount} columns · ${payload.createdAtLabel}',
                ),
                onTap: () => controller?.activateHistoryItem(payload),
                trailing: IconButton(
                  tooltip: 'Remove route',
                  onPressed: () => controller?.removeHistoryItem(payload),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
        ],
      ),
    );
  }
}

class _RuntimePolicy extends StatelessWidget {
  const _RuntimePolicy({required this.capabilities});
  final Map<String, dynamic>? capabilities;

  @override
  Widget build(BuildContext context) {
    final data = capabilities;
    return _RuntimeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Execution policy',
            style: TextStyle(
              color: _runtimeInk,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The notebook does not run inside the Flutter browser. Code is submitted to a bounded backend subprocess after static syntax validation.',
            style: TextStyle(color: _runtimeMuted, height: 1.45),
          ),
          const SizedBox(height: 18),
          _PolicyRow('Imports', data?['imports'] == false ? 'Blocked' : 'Unknown'),
          _PolicyRow('Filesystem', data?['filesystem'] == false ? 'Blocked' : 'Unknown'),
          _PolicyRow('Network', data?['network'] == false ? 'Blocked' : 'Unknown'),
          _PolicyRow('Child processes', data?['processes'] == false ? 'Blocked' : 'Unknown'),
          _PolicyRow('Reflection / attributes', data?['reflection'] == false ? 'Blocked' : 'Unknown'),
          _PolicyRow('Maximum rows', '${data?['max_rows'] ?? 500}'),
          _PolicyRow('Maximum columns', '${data?['max_columns'] ?? 64}'),
          _PolicyRow('Maximum execution', '${data?['max_timeout_seconds'] ?? 5} seconds'),
          _PolicyRow('Result contract', data?['result_contract']?.toString() ?? 'Assign to result.'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E8),
              border: Border.all(color: const Color(0xFFFFD28A)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'This is a constrained analytical runtime, not a general-purpose hosted development environment. Production deployment should additionally isolate workers at the container or microVM level and maintain per-account quotas and abuse monitoring.',
              style: TextStyle(color: _runtimeInk, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 190,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(child: SelectableText(value)),
          ],
        ),
      );
}

class _RuntimeHero extends StatelessWidget {
  const _RuntimeHero({required this.payload, required this.online});
  final RoutePayload? payload;
  final bool online;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [_runtimeNavy, _runtimeBlue, _runtimeOrange],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24071A33),
              blurRadius: 32,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'DATA & CODE STUDIO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                _StatusPill(
                  online ? 'RUNTIME ONLINE' : 'LOCAL FALLBACK',
                  online ? _runtimeGreen : _runtimeOrange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Route data. Run bounded Python. Keep the result.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              payload == null
                  ? 'Publish a structured package from NBA Object Router, Cap Lab or the front-office registry. The runtime receives only the routed rows and declared columns.'
                  : 'Active package: ${payload.displayLabel} · ${payload.rowCount} rows · ${payload.columnCount} columns · source ${payload.sourceSnapshot}',
              style: const TextStyle(
                color: Color(0xFFEAF2FF),
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _RuntimeTabs extends StatelessWidget {
  const _RuntimeTabs({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => _RuntimeSurface(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in const [
              'Notebook',
              'Object Router',
              'Cap Lab',
              'Route History',
              'Runtime Policy',
            ])
              ChoiceChip(
                label: Text(item),
                selected: selected == item,
                selectedColor: _runtimeNavy,
                labelStyle: TextStyle(
                  color: selected == item ? Colors.white : _runtimeInk,
                  fontWeight: FontWeight.w900,
                ),
                onSelected: (_) => onSelected(item),
              ),
          ],
        ),
      );
}

class _RuntimeMetrics extends StatelessWidget {
  const _RuntimeMetrics({required this.items});
  final List<_RuntimeMetric> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 760
              ? constraints.maxWidth
              : (constraints.maxWidth - 18) / 4;
          return Wrap(
            spacing: 6,
            runSpacing: 8,
            children: [
              for (final item in items) SizedBox(width: width, child: item),
            ],
          );
        },
      );
}

class _RuntimeMetric extends StatelessWidget {
  const _RuntimeMetric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => _RuntimeSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _runtimeMuted, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: _runtimeInk, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: _runtimeMuted, fontSize: 12)),
          ],
        ),
      );
}

class _RuntimeSurface extends StatelessWidget {
  const _RuntimeSurface({required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _runtimeLine),
          boxShadow: const [
            BoxShadow(color: Color(0x10000000), blurRadius: 22, offset: Offset(0, 10)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
        ),
      );
}

String _starterFor(RoutePayload payload) {
  final numeric = payload.columns
      .where((column) =>
          column.dataType == 'number' || column.dataType == 'integer')
      .toList();
  final first = numeric.isEmpty ? '' : numeric.first.key;
  if (first.isEmpty) {
    return "print('Loaded ${payload.displayLabel}')\nresult = {\n    'row_count': len(rows),\n    'column_count': len(columns),\n    'first_rows': rows[:5],\n}\n";
  }
  return "print('Loaded ${payload.displayLabel}')\nvalues = numeric('$first')\nresult = {\n    'row_count': len(rows),\n    'numeric_column': '$first',\n    'count': len(values),\n    'mean': mean(values),\n    'median': median(values),\n    'p90': percentile(values, 90),\n    'minimum': min(values) if values else None,\n    'maximum': max(values) if values else None,\n}\n";
}

const _defaultStarter = """# Sports Terminal isolated Python runtime
# Routed rows are available as a list of dictionaries named rows.
# Assign a JSON-compatible value to result.

print('Sports Terminal notebook ready')
result = {
    'row_count': len(rows),
    'column_count': len(columns),
    'first_rows': rows[:5],
}
""";
