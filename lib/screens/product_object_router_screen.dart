import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/route_payload_controller.dart';
import '../models/route_payload.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import '../services/sports_object_router.dart';
import '../services/workspace_route_import_service.dart';

const _routerNavy = Color(0xFF071A33);
const _routerBlue = Color(0xFF2563EB);
const _routerOrange = Color(0xFFFF7A1A);
const _routerGreen = Color(0xFF059669);
const _routerInk = Color(0xFF102033);
const _routerMuted = Color(0xFF667085);
const _routerLine = Color(0xFFE3E8F0);
const _routerSoft = Color(0xFFF6F8FC);

class ProductObjectRouterScreen extends StatefulWidget {
  const ProductObjectRouterScreen({super.key});

  @override
  State<ProductObjectRouterScreen> createState() =>
      _ProductObjectRouterScreenState();
}

class _ProductObjectRouterScreenState extends State<ProductObjectRouterScreen> {
  final ProductLocalStore store = const ProductLocalStore();
  final SportsObjectRouter router = const SportsObjectRouter();
  final WorkspaceRouteImportService workspaceImporter =
      const WorkspaceRouteImportService();
  late final Future<NbaTerminalSeedSnapshot> future;

  String dataset = 'player_season_totals';
  String query = '';
  String targetRoute = 'Workspace';
  final Set<String> selectedKeys = {};
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    future = const NbaTerminalSeedRepository().load();
    _restore();
  }

  Future<void> _restore() async {
    final state = await store.loadStringMap(ProductLocalStore.objectRouterStateKey);
    if (!mounted) return;
    setState(() {
      dataset = _datasetIds.contains(state['dataset'])
          ? state['dataset']!
          : dataset;
      query = state['query'] ?? '';
      targetRoute = immediateRouteTargets.contains(state['targetRoute'])
          ? state['targetRoute']!
          : targetRoute;
      loaded = true;
    });
  }

  Future<void> _persist() async {
    await store.saveStringMap(ProductLocalStore.objectRouterStateKey, {
      'dataset': dataset,
      'query': query,
      'targetRoute': targetRoute,
    });
  }

  void _changeDataset(String value) {
    setState(() {
      dataset = value;
      selectedKeys.clear();
    });
    _persist();
  }

  void _toggleRow(String key) {
    setState(() {
      if (!selectedKeys.add(key)) selectedKeys.remove(key);
    });
  }

  RoutePayload _payload(
    NbaTerminalSeedSnapshot snapshot,
    List<Map<String, dynamic>> filtered,
  ) {
    final definition = _definition(dataset);
    final rows = selectedKeys.isEmpty
        ? filtered.take(100).toList()
        : [
            for (var index = 0; index < filtered.length; index++)
              if (selectedKeys.contains(_rowKey(filtered[index], index)))
                filtered[index],
          ];
    return router.packageRows(
      datasetId: definition.id,
      displayLabel: definition.label,
      sourceObjectType: definition.objectType,
      rows: rows,
      targetRoute: targetRoute,
      sourceSnapshot:
          '${definition.sourceSnapshot}; warehouse generated ${snapshot.warehouseGeneratedAt}',
      readinessState: snapshot.validationStatus.toLowerCase() == 'pass'
          ? 'Validated local warehouse'
          : 'Local warehouse',
      filterSummary: query.trim().isEmpty
          ? 'No search filter; ${selectedKeys.isEmpty ? 'first ${rows.length} rows' : '${selectedKeys.length} selected rows'}'
          : 'query="$query"; ${selectedKeys.isEmpty ? 'first ${rows.length} matches' : '${selectedKeys.length} selected matches'}',
      rowKey: definition.rowKey,
      preferredColumns: definition.preferredColumns,
      metadata: {
        'warehouseValidation': snapshot.validationStatus,
        'warehouseGeneratedAt': snapshot.warehouseGeneratedAt,
        'sourceDatasetRows': _rows(snapshot, definition.id).length,
        'filteredRows': filtered.length,
        'explicitSelection': selectedKeys.isNotEmpty,
      },
    );
  }

  Future<void> _publish(RoutePayload payload, String route) async {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) return;
    final routed = payload.copyWith(targetRoute: route);
    controller.setActivePayload(routed, origin: 'NBA Object Router');
    if (route == 'Workspace') {
      final result = await workspaceImporter.importPayload(routed);
      if (!mounted) return;
      _show('${result.summary}. Open Workspace to use the imported sheet.');
      return;
    }
    _show('${routed.displayLabel} published to $route.');
  }

  Future<void> _copyTsv(RoutePayload payload) async {
    await Clipboard.setData(ClipboardData(text: router.toTsv(payload)));
    if (!mounted) return;
    _show('${payload.rowCount} routed rows copied as TSV.');
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (!loaded || snapshot.connectionState != ConnectionState.done) {
          return const _RouterSurface(
            child: Text(
              'Loading universal object router...',
              style: TextStyle(color: _routerMuted),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _RouterSurface(
            child: Text(
              'Object router data unavailable: ${snapshot.error}',
              style: const TextStyle(color: _routerMuted),
            ),
          );
        }
        final data = snapshot.data!;
        final definition = _definition(dataset);
        final baseRows = _rows(data, dataset);
        final filtered = _filter(baseRows, query);
        final payload = _payload(data, filtered);
        final previewColumns = payload.columns.take(8).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RouterHero(
              dataset: definition.label,
              rows: payload.rowCount,
              columns: payload.columnCount,
              target: targetRoute,
            ),
            const SizedBox(height: 18),
            _RouterControls(
              dataset: dataset,
              query: query,
              targetRoute: targetRoute,
              onDataset: _changeDataset,
              onQuery: (value) {
                setState(() {
                  query = value;
                  selectedKeys.clear();
                });
                _persist();
              },
              onTarget: (value) {
                setState(() => targetRoute = value);
                _persist();
              },
              onClearSelection: selectedKeys.isEmpty
                  ? null
                  : () => setState(selectedKeys.clear),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final selection = _SelectionPanel(
                  definition: definition,
                  rows: filtered,
                  selectedKeys: selectedKeys,
                  rowKey: _rowKey,
                  onToggle: _toggleRow,
                );
                final package = _PackagePanel(
                  payload: payload,
                  onPublish: () => _publish(payload, targetRoute),
                  onWorkspace: () => _publish(payload, 'Workspace'),
                  onPython: () => _publish(payload, 'Python Lab'),
                  onCopy: () => _copyTsv(payload),
                );
                if (constraints.maxWidth < 1040) {
                  return Column(
                    children: [
                      selection,
                      const SizedBox(height: 18),
                      package,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: selection),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: package),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _PreviewTable(
              payload: payload,
              columns: previewColumns,
            ),
            const SizedBox(height: 18),
            const _RouteHistoryPanel(),
          ],
        );
      },
    );
  }
}

class _DatasetDefinition {
  const _DatasetDefinition({
    required this.id,
    required this.label,
    required this.objectType,
    required this.rowKey,
    required this.sourceSnapshot,
    required this.preferredColumns,
  });

  final String id;
  final String label;
  final String objectType;
  final String rowKey;
  final String sourceSnapshot;
  final List<String> preferredColumns;
}

const _definitions = <_DatasetDefinition>[
  _DatasetDefinition(
    id: 'player_season_totals',
    label: 'Player Season Board',
    objectType: 'PlayerStatTable',
    rowKey: 'player_id',
    sourceSnapshot: 'Generated player_season_totals.json',
    preferredColumns: [
      'player_id',
      'player_label',
      'team_ids',
      'games',
      'minutes_per_game',
      'points_per_game',
      'rebounds',
      'assists',
      'steals',
      'blocks',
      'avg_ts_pct',
      'avg_bpm',
    ],
  ),
  _DatasetDefinition(
    id: 'team_records',
    label: 'Team Performance Board',
    objectType: 'TeamStatTable',
    rowKey: 'team_id',
    sourceSnapshot: 'Generated team_records.json',
    preferredColumns: [
      'team_id',
      'games',
      'wins',
      'losses',
      'points_per_game',
      'opponent_points_per_game',
      'average_margin',
    ],
  ),
  _DatasetDefinition(
    id: 'games',
    label: 'Game Results Board',
    objectType: 'GameTable',
    rowKey: 'game_id',
    sourceSnapshot: 'Generated games.json',
    preferredColumns: [
      'game_id',
      'game_date',
      'away_team_id',
      'away_score',
      'home_team_id',
      'home_score',
      'winner_team_id',
    ],
  ),
  _DatasetDefinition(
    id: 'team_game_logs',
    label: 'Team Game Log Board',
    objectType: 'TeamGameLogTable',
    rowKey: 'game_id',
    sourceSnapshot: 'Generated team_game_logs.json',
    preferredColumns: [
      'game_id',
      'game_date',
      'team_id',
      'opponent_team_id',
      'result',
      'points',
      'opponent_points',
      'margin',
    ],
  ),
  _DatasetDefinition(
    id: 'player_game_logs',
    label: 'Player Game Log Board',
    objectType: 'PlayerGameLogTable',
    rowKey: 'game_id',
    sourceSnapshot: 'Generated player_game_logs_top.json',
    preferredColumns: [
      'game_id',
      'game_date',
      'player_id',
      'player_label',
      'team_id',
      'opponent_team_id',
      'pts',
      'reb',
      'ast',
    ],
  ),
];

List<String> get _datasetIds => [for (final item in _definitions) item.id];

_DatasetDefinition _definition(String id) {
  return _definitions.firstWhere(
    (item) => item.id == id,
    orElse: () => _definitions.first,
  );
}

List<Map<String, dynamic>> _rows(
  NbaTerminalSeedSnapshot snapshot,
  String id,
) {
  switch (id) {
    case 'team_records':
      return snapshot.teamRecords;
    case 'games':
      return snapshot.games;
    case 'team_game_logs':
      return snapshot.teamGameLogs;
    case 'player_game_logs':
      return snapshot.playerGameLogsTop;
    default:
      return snapshot.playerSeasonTotals;
  }
}

List<Map<String, dynamic>> _filter(
  List<Map<String, dynamic>> rows,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return rows;
  return [
    for (final row in rows)
      if (row.values.any(
        (value) => value?.toString().toLowerCase().contains(normalized) ?? false,
      ))
        row,
  ];
}

String _rowKey(Map<String, dynamic> row, int index) {
  final primary = row['player_id'] ?? row['team_id'] ?? row['game_id'];
  final secondary = row['player_label'] ?? row['opponent_team_id'] ?? index;
  return '${primary ?? index}|$secondary|$index';
}

class _RouterHero extends StatelessWidget {
  const _RouterHero({
    required this.dataset,
    required this.rows,
    required this.columns,
    required this.target,
  });

  final String dataset;
  final int rows;
  final int columns;
  final String target;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [_routerNavy, _routerBlue, _routerOrange],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'UNIVERSAL OBJECT ROUTER',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Package NBA data once. Use it everywhere.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Select live warehouse rows, preserve source and filter context, and route the same structured object into Workspace, Python Lab, Compare, Reports, Export, Alerts or the Action Center.',
            style: TextStyle(
              color: Color(0xFFEAF2FF),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(dataset),
              _HeroChip('$rows rows'),
              _HeroChip('$columns columns'),
              _HeroChip('Target: $target'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RouterControls extends StatelessWidget {
  const _RouterControls({
    required this.dataset,
    required this.query,
    required this.targetRoute,
    required this.onDataset,
    required this.onQuery,
    required this.onTarget,
    required this.onClearSelection,
  });

  final String dataset;
  final String query;
  final String targetRoute;
  final ValueChanged<String> onDataset;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onTarget;
  final VoidCallback? onClearSelection;

  @override
  Widget build(BuildContext context) {
    return _RouterSurface(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              value: dataset,
              isExpanded: true,
              decoration: _input('Dataset'),
              items: [
                for (final item in _definitions)
                  DropdownMenuItem(value: item.id, child: Text(item.label)),
              ],
              onChanged: (value) {
                if (value != null) onDataset(value);
              },
            ),
          ),
          SizedBox(
            width: 330,
            child: TextFormField(
              initialValue: query,
              decoration: _input('Search every field'),
              onChanged: onQuery,
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: targetRoute,
              isExpanded: true,
              decoration: _input('Target route'),
              items: [
                for (final route in immediateRouteTargets)
                  DropdownMenuItem(value: route, child: Text(route)),
              ],
              onChanged: (value) {
                if (value != null) onTarget(value);
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: onClearSelection,
            icon: const Icon(Icons.deselect_rounded),
            label: const Text('Clear selection'),
          ),
        ],
      ),
    );
  }
}

class _SelectionPanel extends StatelessWidget {
  const _SelectionPanel({
    required this.definition,
    required this.rows,
    required this.selectedKeys,
    required this.rowKey,
    required this.onToggle,
  });

  final _DatasetDefinition definition;
  final List<Map<String, dynamic>> rows;
  final Set<String> selectedKeys;
  final String Function(Map<String, dynamic>, int) rowKey;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _RouterSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            definition.label,
            style: const TextStyle(
              color: _routerInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            selectedKeys.isEmpty
                ? 'No explicit selection: the first 100 filtered rows will be packaged.'
                : '${selectedKeys.length} rows selected explicitly.',
            style: const TextStyle(
              color: _routerMuted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 430,
            child: ListView.separated(
              itemCount: rows.length > 150 ? 150 : rows.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: _routerLine,
              ),
              itemBuilder: (context, index) {
                final row = rows[index];
                final key = rowKey(row, index);
                final title = row['player_label'] ??
                    row['team_id'] ??
                    row['game_id'] ??
                    'Row ${index + 1}';
                final subtitle = definition.preferredColumns
                    .where((column) => row[column] != null)
                    .take(4)
                    .map((column) => '$column=${row[column]}')
                    .join(' · ');
                return CheckboxListTile(
                  value: selectedKeys.contains(key),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    title.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _routerInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _routerMuted, fontSize: 12),
                  ),
                  onChanged: (_) => onToggle(key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PackagePanel extends StatelessWidget {
  const _PackagePanel({
    required this.payload,
    required this.onPublish,
    required this.onWorkspace,
    required this.onPython,
    required this.onCopy,
  });

  final RoutePayload payload;
  final VoidCallback onPublish;
  final VoidCallback onWorkspace;
  final VoidCallback onPython;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return _RouterSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Structured package',
                  style: TextStyle(
                    color: _routerInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'SCHEMA V2',
                  style: TextStyle(
                    color: _routerGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PackageLine('Object', payload.sourceObjectType),
          _PackageLine('Rows', '${payload.rowCount}'),
          _PackageLine('Columns', '${payload.columnCount}'),
          _PackageLine('Target', payload.targetRoute),
          _PackageLine('Readiness', payload.readinessState),
          _PackageLine('Source', payload.sourceSnapshot),
          _PackageLine('Filter', payload.filterSummary),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onPublish,
            icon: const Icon(Icons.send_rounded),
            label: Text('Publish to ${payload.targetRoute}'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onWorkspace,
              icon: const Icon(Icons.grid_on_rounded),
              label: const Text('Import into Workspace'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPython,
              icon: const Icon(Icons.code_rounded),
              label: const Text('Send to Python Lab'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_all_rounded),
              label: const Text('Copy TSV'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageLine extends StatelessWidget {
  const _PackageLine(this.label, this.value);
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
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: _routerMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _routerInk,
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

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.payload, required this.columns});
  final RoutePayload payload;
  final List<RoutePayloadColumn> columns;

  @override
  Widget build(BuildContext context) {
    return _RouterSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'Package preview · ${payload.rowCount} rows',
              style: const TextStyle(
                color: _routerInk,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1, color: _routerLine),
          if (columns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text('No rows match this package.', style: TextStyle(color: _routerMuted)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_routerSoft),
                columns: [
                  for (final column in columns)
                    DataColumn(label: Text(column.label)),
                ],
                rows: [
                  for (final row in payload.rows.take(12))
                    DataRow(
                      cells: [
                        for (final column in columns)
                          DataCell(
                            SizedBox(
                              width: 150,
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

class _RouteHistoryPanel extends StatelessWidget {
  const _RouteHistoryPanel();

  @override
  Widget build(BuildContext context) {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return _RouterSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Persistent route history',
                      style: TextStyle(
                        color: _routerInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.history.isEmpty
                        ? null
                        : controller.clearHistory,
                    child: const Text('Clear history'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (controller.history.isEmpty)
                const Text(
                  'Published packages will remain available here after refresh.',
                  style: TextStyle(color: _routerMuted),
                )
              else
                for (final payload in controller.history.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.route_rounded, color: _routerBlue),
                    title: Text(
                      payload.conciseDebugLabel,
                      style: const TextStyle(
                        color: _routerInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${payload.rowCount} rows · ${payload.createdAtLabel}',
                      style: const TextStyle(color: _routerMuted),
                    ),
                    trailing: IconButton(
                      tooltip: 'Activate package',
                      onPressed: () => controller.activateHistoryItem(payload),
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _RouterSurface extends StatelessWidget {
  const _RouterSurface({
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
        border: Border.all(color: _routerLine),
        borderRadius: BorderRadius.circular(22),
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

InputDecoration _input(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _routerSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _routerLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _routerLine),
    ),
  );
}
