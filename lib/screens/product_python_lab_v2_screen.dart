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

const _pyPanel = Color(0xFF0F151C);
const _pyPanel2 = Color(0xFF141C25);
const _pyLine = Color(0xFF263342);
const _pyText = Color(0xFFE8EDF3);
const _pyMuted = Color(0xFF8895A5);
const _pyBlue = Color(0xFF63A9FF);
const _pyGreen = Color(0xFF69C99A);
const _pyAmber = Color(0xFFE2B866);
const _pyCode = Color(0xFF08111F);

class ProductPythonLabV2Screen extends StatefulWidget {
  const ProductPythonLabV2Screen({super.key, required this.session});
  final AppSession session;

  @override
  State<ProductPythonLabV2Screen> createState() => _ProductPythonLabV2ScreenState();
}

class _ProductPythonLabV2ScreenState extends State<ProductPythonLabV2Screen> {
  static const _historyKey = 'sports_terminal.python.v2.history';
  static const _titleKey = 'sports_terminal.python.v2.title';
  final ProductLocalStore _store = const ProductLocalStore();
  final PythonRuntimeService _runtime = const PythonRuntimeService();
  final SportsObjectRouter _router = const SportsObjectRouter();
  final WorkspaceRouteImportService _workspaceImporter = const WorkspaceRouteImportService();
  late final TextEditingController _code;
  late final TextEditingController _title;
  String _tab = 'Notebook';
  String _output = 'Ready. Route a dataset into Python Lab or run a notebook against the empty data package.';
  bool _running = false;
  bool _loaded = false;
  Map<String, dynamic>? _capabilities;
  int _durationMs = 0;
  String _status = 'Not run';
  List<_RunRecord> _history = const [];

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: _defaultStarter);
    _title = TextEditingController(text: 'Untitled NBA Analysis');
    _restore();
    _loadCapabilities();
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final code = await _store.loadString(ProductLocalStore.pythonNotebookCodeKey, fallback: _defaultStarter);
    final output = await _store.loadString(ProductLocalStore.pythonNotebookOutputKey, fallback: _output);
    final title = await _store.loadString(_titleKey, fallback: 'Untitled NBA Analysis');
    final historyRaw = await _store.loadString(_historyKey);
    var history = <_RunRecord>[];
    try {
      final decoded = jsonDecode(historyRaw);
      if (decoded is List) {
        history = decoded.whereType<Map>().map((item) => _RunRecord.fromJson(item.map((key, value) => MapEntry(key.toString(), value)))).toList();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _code.text = code.isEmpty ? _defaultStarter : code;
      _output = output;
      _title.text = title.isEmpty ? 'Untitled NBA Analysis' : title;
      _history = history.take(20).toList();
      _loaded = true;
    });
  }

  Future<void> _loadCapabilities() async {
    final capabilities = await _runtime.capabilities();
    if (!mounted) return;
    setState(() => _capabilities = capabilities);
  }

  Future<void> _persist() async {
    await Future.wait([
      _store.saveString(ProductLocalStore.pythonNotebookCodeKey, _code.text),
      _store.saveString(ProductLocalStore.pythonNotebookOutputKey, _output),
      _store.saveString(_titleKey, _title.text),
      _store.saveString(_historyKey, jsonEncode(_history.map((item) => item.toJson()).toList())),
    ]);
  }

  Future<void> _run(RoutePayload? payload) async {
    setState(() {
      _running = true;
      _status = 'Running';
      _output = 'Submitting notebook to the isolated Python runtime…';
    });
    final started = DateTime.now();
    final result = await _runtime.execute(code: _code.text, payload: payload);
    if (!mounted) return;
    final lines = <String>[];
    if (result.completed) {
      lines.add('PYTHON NOTEBOOK COMPLETED');
      lines.add('Notebook: ${_title.text.trim().isEmpty ? 'Untitled NBA Analysis' : _title.text.trim()}');
      lines.add('Rows: ${result.rowCount}');
      lines.add('Columns: ${result.columnCount}');
      lines.add('Duration: ${result.durationMs} ms');
      if (result.warnings.isNotEmpty) lines.add('Warnings: ${result.warnings.join(' ')}');
      if (result.stdout.trim().isNotEmpty) {
        lines.addAll(['', 'STDOUT', result.stdout.trimRight()]);
      }
      lines.addAll(['', 'RESULT', const JsonEncoder.withIndent('  ').convert(result.result)]);
    } else {
      lines.add(result.available ? 'PYTHON NOTEBOOK REJECTED' : 'PYTHON RUNTIME OFFLINE');
      lines.add('');
      lines.add(result.error);
      lines.add('');
      lines.add(result.statusCode == 422
          ? 'The bounded runtime rejected the notebook or execution failed within the sandbox.'
          : 'Start the launch backend and confirm the Python runtime is reachable.');
    }
    final record = _RunRecord(
      title: _title.text.trim().isEmpty ? 'Untitled NBA Analysis' : _title.text.trim(),
      status: result.completed ? 'Completed' : result.available ? 'Rejected' : 'Offline',
      createdAt: started.toIso8601String(),
      durationMs: result.durationMs,
      rowCount: result.rowCount,
      package: payload?.displayLabel ?? 'No routed package',
      codePreview: _code.text.trim().split('\n').take(3).join(' '),
    );
    setState(() {
      _running = false;
      _durationMs = result.durationMs;
      _status = record.status;
      _output = lines.join('\n');
      _history = [record, ..._history].take(20).toList();
    });
    await _persist();
  }

  void _loadTemplate(String key, RoutePayload? payload) {
    final code = switch (key) {
      'summary' => _summaryStarter,
      'leaders' => _leaderStarter,
      'group' => _groupStarter,
      'distribution' => _distributionStarter,
      _ => payload == null ? _defaultStarter : _starterFor(payload),
    };
    setState(() {
      _code.text = code;
      _status = 'Template loaded';
    });
    _persist();
  }

  Future<void> _localSummary(RoutePayload? payload) async {
    if (payload == null || payload.rows.isEmpty) {
      setState(() {
        _output = 'No structured route package is active.';
        _status = 'No package';
      });
      await _persist();
      return;
    }
    final lines = <String>[
      'LOCAL DATA PACKAGE SUMMARY',
      'Package: ${payload.displayLabel}',
      'Rows: ${payload.rowCount}',
      'Columns: ${payload.columnCount}',
      '',
    ];
    for (final column in payload.columns.where((column) => column.dataType == 'number' || column.dataType == 'integer').take(12)) {
      final values = <double>[for (final row in payload.rows) if (row[column.key] is num) (row[column.key] as num).toDouble()];
      if (values.isEmpty) continue;
      final total = values.fold<double>(0, (sum, value) => sum + value);
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);
      lines.add('${column.label}: n=${values.length} · mean=${(total / values.length).toStringAsFixed(3)} · min=${min.toStringAsFixed(3)} · max=${max.toStringAsFixed(3)}');
    }
    lines.addAll(['', 'This preview runs in Dart; it does not execute notebook code.']);
    setState(() {
      _output = lines.join('\n');
      _status = 'Local summary';
      _durationMs = 0;
    });
    await _persist();
  }

  Future<void> _copyOutput() async {
    await Clipboard.setData(ClipboardData(text: _output));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notebook output copied.')));
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _code.text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notebook code copied.')));
  }

  Future<void> _copyTsv(RoutePayload? payload) async {
    if (payload == null) return;
    await Clipboard.setData(ClipboardData(text: _router.toTsv(payload)));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${payload.rowCount} rows copied as TSV.')));
  }

  Future<void> _exportWorkspace(RoutePayload? payload) async {
    if (payload == null) return;
    final routed = payload.copyWith(targetRoute: 'Workspace');
    RoutePayloadScope.maybeOf(context)?.setActivePayload(routed, origin: 'Python Lab v2 export');
    final result = await _workspaceImporter.importPayload(routed);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result.summary}. Open Workspace to continue.')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _PyPanel(child: Center(child: CircularProgressIndicator()));
    final controller = RoutePayloadScope.maybeOf(context);
    final payload = controller?.activePayload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hero(payload: payload, online: _capabilities != null),
        const SizedBox(height: 12),
        _MetricGrid(items: [
          _Metric('Runtime', _capabilities == null ? 'Offline' : 'Isolated Python', _capabilities == null ? 'local summary only' : 'bounded backend subprocess'),
          _Metric('Data package', '${payload?.rowCount ?? 0} rows', payload?.displayLabel ?? 'no routed package'),
          _Metric('Last run', _status, '$_durationMs ms'),
          _Metric('Saved runs', '${_history.length}', 'local notebook history'),
        ]),
        const SizedBox(height: 12),
        _Tabs(selected: _tab, onSelected: (value) => setState(() => _tab = value)),
        const SizedBox(height: 12),
        if (_tab == 'Object Router')
          const ProductObjectRouterScreen()
        else if (_tab == 'Cap Lab')
          const ProductCapLabScreen()
        else if (_tab == 'Run History')
          _RunHistory(rows: _history)
        else if (_tab == 'Runtime Policy')
          _RuntimePolicy(capabilities: _capabilities)
        else
          _NotebookDocument(
            title: _title,
            code: _code,
            output: _output,
            payload: payload,
            running: _running,
            capabilities: _capabilities,
            onChanged: _persist,
            onRun: () => _run(payload),
            onTemplate: (key) => _loadTemplate(key, payload),
            onLocalSummary: () => _localSummary(payload),
            onCopyOutput: _copyOutput,
            onCopyCode: _copyCode,
            onCopyTsv: () => _copyTsv(payload),
            onExportWorkspace: () => _exportWorkspace(payload),
          ),
      ],
    );
  }
}

class _NotebookDocument extends StatelessWidget {
  const _NotebookDocument({
    required this.title,
    required this.code,
    required this.output,
    required this.payload,
    required this.running,
    required this.capabilities,
    required this.onChanged,
    required this.onRun,
    required this.onTemplate,
    required this.onLocalSummary,
    required this.onCopyOutput,
    required this.onCopyCode,
    required this.onCopyTsv,
    required this.onExportWorkspace,
  });
  final TextEditingController title;
  final TextEditingController code;
  final String output;
  final RoutePayload? payload;
  final bool running;
  final Map<String, dynamic>? capabilities;
  final VoidCallback onChanged;
  final VoidCallback onRun;
  final ValueChanged<String> onTemplate;
  final VoidCallback onLocalSummary;
  final VoidCallback onCopyOutput;
  final VoidCallback onCopyCode;
  final VoidCallback onCopyTsv;
  final VoidCallback onExportWorkspace;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PyPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.description_outlined, color: _pyBlue),
              const SizedBox(width: 8),
              const Expanded(child: Text('NOTEBOOK', style: TextStyle(color: _pyText, fontSize: 17, fontWeight: FontWeight.w900))),
              _Tag(payload == null ? 'NO DATA PACKAGE' : 'ROUTED DATA', payload == null ? _pyAmber : _pyGreen),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: title,
              onChanged: (_) => onChanged(),
              style: const TextStyle(color: _pyText, fontSize: 21, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(labelText: 'Notebook title', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            _DataContext(payload: payload),
          ]),
        ),
        const SizedBox(height: 12),
        _PyPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CODE CELL 1', style: TextStyle(color: _pyBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
                SizedBox(height: 3),
                Text('Python analysis', style: TextStyle(color: _pyText, fontSize: 19, fontWeight: FontWeight.w900)),
              ])),
              IconButton(tooltip: 'Copy code', onPressed: onCopyCode, icon: const Icon(Icons.copy_rounded)),
            ]),
            const SizedBox(height: 8),
            const Text('Assign a JSON-compatible value to result. The bounded helper layer is available without imports.', style: TextStyle(color: _pyMuted, fontSize: 11, height: 1.4)),
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _TemplateButton('Starter', 'starter', onTemplate),
              _TemplateButton('Summary', 'summary', onTemplate),
              _TemplateButton('Leaders', 'leaders', onTemplate),
              _TemplateButton('Group by', 'group', onTemplate),
              _TemplateButton('Distribution', 'distribution', onTemplate),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: code,
              minLines: 22,
              maxLines: null,
              onChanged: (_) => onChanged(),
              style: const TextStyle(color: Color(0xFFE6EDF7), fontFamily: 'monospace', fontSize: 12.5, height: 1.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: _pyCode,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _pyLine)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _pyBlue)),
              ),
            ),
            const SizedBox(height: 11),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: running ? null : onRun,
                icon: running ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_rounded),
                label: Text(running ? 'Running…' : 'Run cell'),
              ),
              OutlinedButton.icon(onPressed: onLocalSummary, icon: const Icon(Icons.analytics_outlined), label: const Text('Local data summary')),
              OutlinedButton.icon(onPressed: payload == null ? null : onCopyTsv, icon: const Icon(Icons.copy_all_rounded), label: const Text('Copy routed TSV')),
              OutlinedButton.icon(onPressed: payload == null ? null : onExportWorkspace, icon: const Icon(Icons.grid_on_rounded), label: const Text('Export data to Workspace')),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        // Output intentionally sits below the notebook code cell at every width.
        _PyPanel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CELL OUTPUT', style: TextStyle(color: _pyGreen, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
                SizedBox(height: 3),
                Text('Execution output', style: TextStyle(color: _pyText, fontSize: 19, fontWeight: FontWeight.w900)),
              ])),
              IconButton(tooltip: 'Copy output', onPressed: onCopyOutput, icon: const Icon(Icons.copy_rounded)),
            ]),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 260),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _pyCode, border: Border.all(color: _pyLine), borderRadius: BorderRadius.circular(8)),
              child: SelectableText(output, style: const TextStyle(color: Color(0xFFE6EDF7), fontFamily: 'monospace', fontSize: 12, height: 1.5)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _HelperReference(capabilities: capabilities),
        if (payload != null) ...[
          const SizedBox(height: 12),
          _DataPreview(payload: payload!),
        ],
      ]);
}

class _DataContext extends StatelessWidget {
  const _DataContext({required this.payload});
  final RoutePayload? payload;
  @override
  Widget build(BuildContext context) {
    if (payload == null) return const Text('No routed package. The notebook still runs with an empty data list.', style: TextStyle(color: _pyMuted));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 7, runSpacing: 7, children: [
        _Tag(payload!.displayLabel, _pyBlue),
        _Tag('${payload!.rowCount} ROWS', _pyGreen),
        _Tag('${payload!.columnCount} COLUMNS', _pyAmber),
        _Tag(payload!.sourceSnapshot, _pyMuted),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final column in payload!.columns.take(24))
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: _pyPanel2, border: Border.all(color: _pyLine), borderRadius: BorderRadius.circular(5)), child: Text('${column.key} · ${column.dataType}', style: const TextStyle(color: _pyMuted, fontSize: 8))),
      ]),
    ]);
  }
}

class _HelperReference extends StatelessWidget {
  const _HelperReference({required this.capabilities});
  final Map<String, dynamic>? capabilities;
  @override
  Widget build(BuildContext context) => _PyPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NOTEBOOK HELPERS & RUNTIME CONTRACT', style: TextStyle(color: _pyBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 8),
          const Text('Available analytical helpers are intentionally bounded. The production runtime rejects imports, filesystem access, network access, child processes and reflection-style escape paths.', style: TextStyle(color: _pyMuted, height: 1.4)),
          const SizedBox(height: 9),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (final helper in const ['data', 'columns', 'column(name)', 'numeric(name)', 'mean(values)', 'median(values)', 'percentile(values, p)', 'group_by(name)', 'len', 'sum', 'min', 'max', 'sorted', 'round'])
              _Tag(helper, _pyMuted),
          ]),
          if (capabilities != null) ...[
            const SizedBox(height: 10),
            Text('Runtime limits · ${capabilities!['max_rows'] ?? 500} rows · ${capabilities!['max_columns'] ?? 64} columns · ${capabilities!['max_timeout_seconds'] ?? 5}s execution', style: const TextStyle(color: _pyGreen, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ]),
      );
}

class _DataPreview extends StatelessWidget {
  const _DataPreview({required this.payload});
  final RoutePayload payload;
  @override
  Widget build(BuildContext context) => _PyPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ROUTED DATA PREVIEW', style: TextStyle(color: _pyAmber, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 9),
          for (var i = 0; i < payload.rows.take(8).length; i++)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _pyLine, width: .5))),
              child: SelectableText(const JsonEncoder.withIndent('  ').convert(payload.rows[i]), style: const TextStyle(color: _pyMuted, fontFamily: 'monospace', fontSize: 9.5)),
            ),
          if (payload.rows.length > 8) Padding(padding: const EdgeInsets.only(top: 8), child: Text('+ ${payload.rows.length - 8} additional routed rows', style: const TextStyle(color: _pyMuted, fontSize: 10))),
        ]),
      );
}

class _RunHistory extends StatelessWidget {
  const _RunHistory({required this.rows});
  final List<_RunRecord> rows;
  @override
  Widget build(BuildContext context) => _PyPanel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('RECENT NOTEBOOK RUNS', style: TextStyle(color: _pyBlue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .8))),
          if (rows.isEmpty)
            const Padding(padding: EdgeInsets.fromLTRB(14, 0, 14, 18), child: Text('No notebook runs recorded yet.', style: TextStyle(color: _pyMuted)))
          else
            for (final row in rows)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _pyLine, width: .5))),
                child: Row(children: [
                  Icon(row.status == 'Completed' ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: row.status == 'Completed' ? _pyGreen : _pyAmber, size: 18),
                  const SizedBox(width: 9),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.title, style: const TextStyle(color: _pyText, fontWeight: FontWeight.w900)), Text('${row.package} · ${row.rowCount} rows · ${row.durationMs} ms · ${row.createdAt}', style: const TextStyle(color: _pyMuted, fontSize: 9)), if (row.codePreview.isNotEmpty) Text(row.codePreview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _pyBlue, fontFamily: 'monospace', fontSize: 9))])),
                  _Tag(row.status.toUpperCase(), row.status == 'Completed' ? _pyGreen : _pyAmber),
                ]),
              ),
        ]),
      );
}

class _RuntimePolicy extends StatelessWidget {
  const _RuntimePolicy({required this.capabilities});
  final Map<String, dynamic>? capabilities;
  @override
  Widget build(BuildContext context) => _PyPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Runtime policy', style: TextStyle(color: _pyText, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Python executes in a bounded backend subprocess after syntax validation. It is an analytical runtime, not unrestricted hosted development infrastructure.', style: TextStyle(color: _pyMuted, height: 1.45)),
          const SizedBox(height: 12),
          for (final row in [
            ('Imports', capabilities?['imports'] == false ? 'Blocked' : 'Unknown'),
            ('Filesystem', capabilities?['filesystem'] == false ? 'Blocked' : 'Unknown'),
            ('Network', capabilities?['network'] == false ? 'Blocked' : 'Unknown'),
            ('Child processes', capabilities?['processes'] == false ? 'Blocked' : 'Unknown'),
            ('Reflection / attributes', capabilities?['reflection'] == false ? 'Blocked' : 'Unknown'),
            ('Maximum rows', '${capabilities?['max_rows'] ?? 500}'),
            ('Maximum columns', '${capabilities?['max_columns'] ?? 64}'),
            ('Maximum execution', '${capabilities?['max_timeout_seconds'] ?? 5} seconds'),
          ])
            Container(padding: const EdgeInsets.symmetric(vertical: 7), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _pyLine, width: .5))), child: Row(children: [SizedBox(width: 190, child: Text(row.$1, style: const TextStyle(color: _pyMuted, fontWeight: FontWeight.w800))), Expanded(child: Text(row.$2, style: const TextStyle(color: _pyText)))])),
        ]),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.payload, required this.online});
  final RoutePayload? payload;
  final bool online;
  @override
  Widget build(BuildContext context) => _PyPanel(
        child: LayoutBuilder(builder: (context, constraints) {
          final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TOOLS / PYTHON LAB', style: TextStyle(color: _pyBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
            const SizedBox(height: 5),
            const Text('Notebook', style: TextStyle(color: _pyText, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(payload == null ? 'Write bounded Python, route data in when needed and keep execution output directly below the notebook.' : '${payload!.displayLabel} · ${payload!.rowCount} rows · ${payload!.columnCount} columns routed into the notebook.', style: const TextStyle(color: _pyMuted, height: 1.4)),
          ]);
          final status = Wrap(spacing: 7, runSpacing: 7, children: [_Tag(online ? 'RUNTIME ONLINE' : 'RUNTIME OFFLINE', online ? _pyGreen : _pyAmber), const _Tag('OUTPUT BELOW CODE', _pyBlue), const _Tag('PERSISTENT NOTEBOOK', _pyMuted)]);
          if (constraints.maxWidth < 820) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 12), status]);
          return Row(children: [Expanded(child: copy), const SizedBox(width: 20), status]);
        }),
      );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => _PyPanel(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final item in const ['Notebook', 'Object Router', 'Cap Lab', 'Run History', 'Runtime Policy'])
            ChoiceChip(label: Text(item), selected: selected == item, onSelected: (_) => onSelected(item)),
        ]),
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});
  final List<_Metric> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 550 ? 2 : 1;
        final gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final item in items) SizedBox(width: width, child: _PyPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: const TextStyle(color: _pyMuted, fontSize: 8, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(item.value, style: const TextStyle(color: _pyText, fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(item.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _pyBlue, fontSize: 9))])))]);
      });
}

class _Metric { const _Metric(this.label, this.value, this.detail); final String label; final String value; final String detail; }

class _TemplateButton extends StatelessWidget {
  const _TemplateButton(this.label, this.keyName, this.onSelected);
  final String label;
  final String keyName;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => ActionChip(avatar: const Icon(Icons.code_rounded, size: 14), label: Text(label), onPressed: () => onSelected(keyName));
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .4)));
}

class _PyPanel extends StatelessWidget {
  const _PyPanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _pyPanel, border: Border.all(color: _pyLine), borderRadius: BorderRadius.circular(9)), child: child);
}

class _RunRecord {
  const _RunRecord({required this.title, required this.status, required this.createdAt, required this.durationMs, required this.rowCount, required this.package, required this.codePreview});
  final String title;
  final String status;
  final String createdAt;
  final int durationMs;
  final int rowCount;
  final String package;
  final String codePreview;
  factory _RunRecord.fromJson(Map<String, dynamic> json) => _RunRecord(
        title: json['title']?.toString() ?? 'Untitled NBA Analysis',
        status: json['status']?.toString() ?? 'Unknown',
        createdAt: json['createdAt']?.toString() ?? '',
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        rowCount: (json['rowCount'] as num?)?.toInt() ?? 0,
        package: json['package']?.toString() ?? '',
        codePreview: json['codePreview']?.toString() ?? '',
      );
  Map<String, dynamic> toJson() => {'title': title, 'status': status, 'createdAt': createdAt, 'durationMs': durationMs, 'rowCount': rowCount, 'package': package, 'codePreview': codePreview};
}

String _starterFor(RoutePayload payload) {
  final numeric = payload.columns.where((column) => column.dataType == 'number' || column.dataType == 'integer').map((column) => column.key).take(4).toList();
  final first = numeric.isEmpty ? '' : numeric.first;
  return '''# ${payload.displayLabel}
# Routed rows: ${payload.rowCount}
# Available columns: ${payload.columns.map((column) => column.key).join(', ')}

summary = {
    "row_count": len(data),
    "columns": columns,
}
${first.isEmpty ? '' : 'values = numeric("$first")\nsummary["${first}_mean"] = mean(values) if values else None\n'}
result = summary
''';
}

const _defaultStarter = '''# Sports Terminal Python Lab
# data is a list of routed row dictionaries.
# Assign a JSON-compatible value to result.

result = {
    "row_count": len(data),
    "columns": columns,
    "preview": data[:5],
}
''';

const _summaryStarter = '''# Numeric summary across available columns
summary = {}
for name in columns:
    values = numeric(name)
    if values:
        summary[name] = {
            "n": len(values),
            "mean": mean(values),
            "median": median(values),
            "min": min(values),
            "max": max(values),
        }
result = summary
''';

const _leaderStarter = '''# Replace pts with any numeric field in the routed package.
metric = "pts"
ranked = sorted(data, key=lambda row: row.get(metric) or 0, reverse=True)
result = ranked[:20]
''';

const _groupStarter = '''# Replace team with any categorical field.
groups = group_by("team")
result = {name: len(rows) for name, rows in groups.items()}
''';

const _distributionStarter = '''# Replace pts with any numeric field.
values = numeric("pts")
result = {
    "n": len(values),
    "mean": mean(values) if values else None,
    "median": median(values) if values else None,
    "p25": percentile(values, 25) if values else None,
    "p75": percentile(values, 75) if values else None,
}
''';
