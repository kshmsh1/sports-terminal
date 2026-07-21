import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/route_payload_controller.dart';
import '../models/route_payload.dart';
import '../services/product_local_store.dart';
import '../services/sports_object_router.dart';
import '../services/workspace_route_import_service.dart';
import 'product_cap_lab_screen.dart';
import 'product_object_router_screen.dart';

const _studioNavy = Color(0xFF071A33);
const _studioBlue = Color(0xFF2563EB);
const _studioOrange = Color(0xFFFF7A1A);
const _studioGreen = Color(0xFF059669);
const _studioInk = Color(0xFF102033);
const _studioMuted = Color(0xFF667085);
const _studioLine = Color(0xFFE3E8F0);
const _studioSoft = Color(0xFFF6F8FC);

class ProductPythonDevLabScreen extends StatefulWidget {
  const ProductPythonDevLabScreen({super.key});

  @override
  State<ProductPythonDevLabScreen> createState() =>
      _ProductPythonDevLabScreenState();
}

class _ProductPythonDevLabScreenState extends State<ProductPythonDevLabScreen> {
  final ProductLocalStore store = const ProductLocalStore();
  final SportsObjectRouter router = const SportsObjectRouter();
  final WorkspaceRouteImportService workspaceImporter =
      const WorkspaceRouteImportService();
  late final TextEditingController codeController;

  String tab = 'Notebook';
  String console =
      'Ready. Publish a structured package from Object Router or Cap Lab, then load it into the notebook.';
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController(text: _starterCode);
    _restore();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final savedCode = await store.loadString(
      ProductLocalStore.pythonNotebookCodeKey,
      fallback: _starterCode,
    );
    final savedOutput = await store.loadString(
      ProductLocalStore.pythonNotebookOutputKey,
      fallback: console,
    );
    if (!mounted) return;
    setState(() {
      codeController.text = savedCode.isEmpty ? _starterCode : savedCode;
      console = savedOutput;
      loaded = true;
    });
  }

  Future<void> _persist() async {
    await store.saveString(
      ProductLocalStore.pythonNotebookCodeKey,
      codeController.text,
    );
    await store.saveString(
      ProductLocalStore.pythonNotebookOutputKey,
      console,
    );
  }

  void _loadActivePackage(RoutePayload payload) {
    setState(() {
      codeController.text = router.generatedPython(payload);
      console = _packageSummary(payload);
    });
    _persist();
  }

  void _runPreview(RoutePayload? payload) {
    if (payload == null || payload.rows.isEmpty) {
      setState(() {
        console =
            'No structured package is active. Open Object Router or Cap Lab and publish rows to Python Lab first.';
      });
      _persist();
      return;
    }
    final lines = <String>[
      'LOCAL DATAFRAME PREVIEW COMPLETE',
      '',
      'Package: ${payload.displayLabel}',
      'Rows: ${payload.rowCount}',
      'Columns: ${payload.columnCount}',
      'Source: ${payload.sourceSnapshot}',
      '',
    ];
    final numericColumns = payload.columns
        .where((column) =>
            column.dataType == 'number' || column.dataType == 'integer')
        .take(8);
    if (numericColumns.isEmpty) {
      lines.add('No numeric columns were available for summary statistics.');
    } else {
      lines.add('NUMERIC SUMMARY');
      for (final column in numericColumns) {
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
    }
    lines.addAll([
      '',
      'This is a safe Dart-side dataframe preview, not arbitrary Python execution.',
      'The generated notebook code is ready for a future Pyodide or sandboxed kernel integration.',
    ]);
    setState(() => console = lines.join('\n'));
    _persist();
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
    final controller = RoutePayloadScope.maybeOf(context);
    controller?.setActivePayload(routed, origin: 'Python Lab export');
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
      return const _StudioSurface(
        child: Text('Loading connected data studio...', style: TextStyle(color: _studioMuted)),
      );
    }
    final controller = RoutePayloadScope.maybeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StudioHero(activePayload: controller?.activePayload),
        const SizedBox(height: 18),
        _StudioTabs(
          selected: tab,
          onSelected: (value) => setState(() => tab = value),
        ),
        const SizedBox(height: 18),
        if (tab == 'Object Router')
          const ProductObjectRouterScreen()
        else if (tab == 'Cap Lab')
          const ProductCapLabScreen()
        else if (tab == 'Route History')
          const _RouteHistoryView()
        else
          _NotebookView(
            codeController: codeController,
            console: console,
            controller: controller,
            onChanged: _persist,
            onLoadPackage: _loadActivePackage,
            onRunPreview: _runPreview,
            onCopyTsv: _copyTsv,
            onExportWorkspace: _exportWorkspace,
          ),
      ],
    );
  }
}

class _StudioHero extends StatelessWidget {
  const _StudioHero({required this.activePayload});
  final RoutePayload? activePayload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [_studioNavy, _studioBlue, _studioOrange],
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
          const Text(
            'DATA & CODE STUDIO',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Route data. Model the cap. Analyze in code.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 39,
              height: 1.04,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: 940,
            child: Text(
              'A connected workspace for structured NBA packages, official cap environments, generated Python notebooks, local dataframe previews, persistent route history and one-click workbook exports.',
              style: TextStyle(
                color: Color(0xFFEAF2FF),
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const _StudioChip('OBJECT ROUTER'),
              const _StudioChip('PYTHON NOTEBOOK'),
              const _StudioChip('CAP LAB'),
              const _StudioChip('WORKBOOK EXPORT'),
              _StudioChip(
                activePayload == null
                    ? 'NO ACTIVE PACKAGE'
                    : '${activePayload!.rowCount} ACTIVE ROWS',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudioTabs extends StatelessWidget {
  const _StudioTabs({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _StudioSurface(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in const [
              ('Notebook', Icons.code_rounded),
              ('Object Router', Icons.route_rounded),
              ('Cap Lab', Icons.account_balance_rounded),
              ('Route History', Icons.history_rounded),
            ]) ...[
              ChoiceChip(
                avatar: Icon(item.$2, size: 18),
                label: Text(item.$1),
                selected: selected == item.$1,
                onSelected: (_) => onSelected(item.$1),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotebookView extends StatelessWidget {
  const _NotebookView({
    required this.codeController,
    required this.console,
    required this.controller,
    required this.onChanged,
    required this.onLoadPackage,
    required this.onRunPreview,
    required this.onCopyTsv,
    required this.onExportWorkspace,
  });

  final TextEditingController codeController;
  final String console;
  final RoutePayloadController? controller;
  final VoidCallback onChanged;
  final ValueChanged<RoutePayload> onLoadPackage;
  final ValueChanged<RoutePayload?> onRunPreview;
  final ValueChanged<RoutePayload?> onCopyTsv;
  final ValueChanged<RoutePayload?> onExportWorkspace;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller ?? _NoopListenable.instance,
      builder: (context, _) {
        final payload = controller?.activePayload;
        return Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final editor = _EditorPanel(
                  controller: codeController,
                  payload: payload,
                  onChanged: onChanged,
                  onRunPreview: () => onRunPreview(payload),
                  onLoadPackage: payload == null
                      ? null
                      : () => onLoadPackage(payload),
                );
                final package = _ActivePackagePanel(
                  payload: payload,
                  origin: controller?.lastOrigin ?? 'None',
                  onCopy: payload == null ? null : () => onCopyTsv(payload),
                  onWorkspace:
                      payload == null ? null : () => onExportWorkspace(payload),
                );
                if (constraints.maxWidth < 1000) {
                  return Column(
                    children: [
                      editor,
                      const SizedBox(height: 18),
                      package,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: editor),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: package),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _ConsolePanel(console: console),
            const SizedBox(height: 18),
            if (payload != null) _PayloadPreview(payload: payload),
            const SizedBox(height: 18),
            const _NotebookRoadmap(),
          ],
        );
      },
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.controller,
    required this.payload,
    required this.onChanged,
    required this.onRunPreview,
    required this.onLoadPackage,
  });

  final TextEditingController controller;
  final RoutePayload? payload;
  final VoidCallback onChanged;
  final VoidCallback onRunPreview;
  final VoidCallback? onLoadPackage;

  @override
  Widget build(BuildContext context) {
    return _StudioSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeader(
                  'Notebook editor',
                  'Persistent code plus generated package-specific starter notebooks.',
                ),
              ),
              OutlinedButton.icon(
                onPressed: onLoadPackage,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Generate from package'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onRunPreview,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Run local preview'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            maxLines: 22,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFFEAF2FF),
              fontSize: 13,
              height: 1.4,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0B1220),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              hintText: 'Write Python here...',
              hintStyle: const TextStyle(color: Colors.white38),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            payload == null
                ? 'No active package is bound to this notebook.'
                : 'Bound package: ${payload!.displayLabel} · ${payload!.rowCount} rows.',
            style: const TextStyle(
              color: _studioMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePackagePanel extends StatelessWidget {
  const _ActivePackagePanel({
    required this.payload,
    required this.origin,
    required this.onCopy,
    required this.onWorkspace,
  });

  final RoutePayload? payload;
  final String origin;
  final VoidCallback? onCopy;
  final VoidCallback? onWorkspace;

  @override
  Widget build(BuildContext context) {
    return _StudioSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            'Active structured package',
            'The shared object currently available across the product.',
          ),
          const SizedBox(height: 14),
          if (payload == null)
            const Text(
              'Publish a dataset from Object Router or a scenario from Cap Lab.',
              style: TextStyle(color: _studioMuted, height: 1.4),
            )
          else ...[
            _Detail('Label', payload!.displayLabel),
            _Detail('Object', payload!.sourceObjectType),
            _Detail('Rows', '${payload!.rowCount}'),
            _Detail('Columns', '${payload!.columnCount}'),
            _Detail('Target', payload!.targetRoute),
            _Detail('Origin', origin),
            _Detail('Source', payload!.sourceSnapshot),
            _Detail('Filter', payload!.filterSummary),
            _Detail('Created', payload!.createdAtLabel),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onWorkspace,
              icon: const Icon(Icons.grid_on_rounded),
              label: const Text('Export package to Workspace'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('Copy active package as TSV'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsolePanel extends StatelessWidget {
  const _ConsolePanel({required this.console});
  final String console;

  @override
  Widget build(BuildContext context) {
    return _StudioSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            'Console',
            'Safe local package output today; sandboxed kernel output later.',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(18),
            ),
            child: SelectableText(
              console,
              style: const TextStyle(
                color: Color(0xFFEAF2FF),
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayloadPreview extends StatelessWidget {
  const _PayloadPreview({required this.payload});
  final RoutePayload payload;

  @override
  Widget build(BuildContext context) {
    final columns = payload.columns.take(8).toList();
    return _StudioSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Active dataframe preview · ${payload.rowCount} rows',
              style: const TextStyle(
                color: _studioInk,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1, color: _studioLine),
          if (columns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No structured rows in the active package.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_studioSoft),
                columns: [
                  for (final column in columns)
                    DataColumn(label: Text(column.label)),
                ],
                rows: [
                  for (final row in payload.rows.take(10))
                    DataRow(
                      cells: [
                        for (final column in columns)
                          DataCell(
                            SizedBox(
                              width: 145,
                              child: Text(
                                row[column.key]?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteHistoryView extends StatelessWidget {
  const _RouteHistoryView();

  @override
  Widget build(BuildContext context) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) {
      return const _StudioSurface(
        child: Text('Route payload controller unavailable.'),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          children: [
            _StudioSurface(
              child: Row(
                children: [
                  const Expanded(
                    child: _SectionHeader(
                      'Persistent package history',
                      'Reactivate, retarget or remove recently published sports objects.',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: controller.history.isEmpty
                        ? null
                        : controller.clearHistory,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Clear all'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (controller.history.isEmpty)
              const _StudioSurface(
                child: Text(
                  'No packages have been published yet.',
                  style: TextStyle(color: _studioMuted),
                ),
              )
            else
              for (final payload in controller.history) ...[
                _HistoryCard(controller: controller, payload: payload),
                const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.controller, required this.payload});
  final RoutePayloadController controller;
  final RoutePayload payload;

  @override
  Widget build(BuildContext context) {
    return _StudioSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.route_rounded, color: _studioBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payload.conciseDebugLabel,
                  style: const TextStyle(
                    color: _studioInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${payload.sourceObjectType} · ${payload.rowCount} rows · ${payload.columnCount} columns · ${payload.createdAtLabel}',
                  style: const TextStyle(color: _studioMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  payload.sourceSnapshot,
                  style: const TextStyle(color: _studioMuted, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Activate',
            onPressed: () => controller.activateHistoryItem(payload),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => controller.removeHistoryItem(payload),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _NotebookRoadmap extends StatelessWidget {
  const _NotebookRoadmap();

  @override
  Widget build(BuildContext context) {
    return const _StudioSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            'Execution roadmap',
            'The connected product boundary is now ready for a real kernel.',
          ),
          SizedBox(height: 12),
          _ChecklistItem(
            'Pyodide in-browser execution for zero-install public notebooks.',
          ),
          _ChecklistItem(
            'Sandboxed backend kernels for larger datasets, package controls and quotas.',
          ),
          _ChecklistItem(
            'Dataframes generated directly from the active schema-v2 route payload.',
          ),
          _ChecklistItem(
            'Charts, notebook persistence, sharing and article/community attachments.',
          ),
          _ChecklistItem(
            'Two-way exports between notebook results and the workbook grid.',
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                color: _studioMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _studioInk,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _studioInk,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: _studioMuted,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_rounded, color: _studioGreen, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _studioMuted,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioChip extends StatelessWidget {
  const _StudioChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.26)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _StudioSurface extends StatelessWidget {
  const _StudioSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _studioLine),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F071A33),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NoopListenable extends ChangeNotifier {
  _NoopListenable._();
  static final instance = _NoopListenable._();
}

String _packageSummary(RoutePayload payload) {
  return '''ACTIVE PACKAGE LOADED

Label: ${payload.displayLabel}
Object: ${payload.sourceObjectType}
Rows: ${payload.rowCount}
Columns: ${payload.columnCount}
Target: ${payload.targetRoute}
Readiness: ${payload.readinessState}
Source: ${payload.sourceSnapshot}
Filter: ${payload.filterSummary}

Generated notebook code now references st.active_payload_dataframe().''';
}

const _starterCode = '''# Sports Terminal connected notebook
# Publish a package from Object Router or Cap Lab, then click
# "Generate from package" to bind the active dataset.

import pandas as pd
import matplotlib.pyplot as plt

active = st.active_payload_dataframe()
st.display(active.head(25))
st.display(active.describe(include="all"))

# Future sandboxed execution examples:
# leaders = active.sort_values("points_per_game", ascending=False).head(20)
# st.plot_bar(leaders, x="player_label", y="points_per_game")
# st.export_to_workspace(leaders, sheet="Analysis Output")
''';
