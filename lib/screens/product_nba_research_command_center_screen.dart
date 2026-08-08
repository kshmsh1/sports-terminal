import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import '../services/nba_research_workspace_store.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'product_advanced_nba_tools_screen.dart';
import 'product_nba_stats_center_screen.dart';

const _bg = Color(0xFF0D1420);
const _panel = Color(0xFF151F2F);
const _panel2 = Color(0xFF1D293B);
const _line = Color(0xFF30405A);
const _text = Color(0xFFF3F7FC);
const _muted = Color(0xFF9EABBD);
const _blue = Color(0xFF65B5FF);
const _yellow = Color(0xFFFFCB45);
const _green = Color(0xFF65E3A5);
const _orange = Color(0xFFFF9A5A);
const _researchMutedFallback = Color(0xFFCFD6E1);

enum NbaResearchSection { overview, stats, analytics, workspaces, coverage }

extension NbaResearchSectionLabel on NbaResearchSection {
  String get label => switch (this) {
        NbaResearchSection.overview => 'Research Home',
        NbaResearchSection.stats => 'Stats Workstation',
        NbaResearchSection.analytics => 'Analytics Suite',
        NbaResearchSection.workspaces => 'Research Workspaces',
        NbaResearchSection.coverage => 'Coverage & Methods',
      };

  IconData get icon => switch (this) {
        NbaResearchSection.overview => Icons.dashboard_customize_rounded,
        NbaResearchSection.stats => Icons.table_chart_rounded,
        NbaResearchSection.analytics => Icons.analytics_rounded,
        NbaResearchSection.workspaces => Icons.folder_copy_rounded,
        NbaResearchSection.coverage => Icons.fact_check_rounded,
      };
}

class ProductNbaResearchCommandCenterScreen extends StatefulWidget {
  const ProductNbaResearchCommandCenterScreen({
    super.key,
    required this.session,
    this.initialSection = NbaResearchSection.overview,
  });

  final AppSession session;
  final NbaResearchSection initialSection;

  @override
  State<ProductNbaResearchCommandCenterScreen> createState() =>
      _ProductNbaResearchCommandCenterScreenState();
}

class _ProductNbaResearchCommandCenterScreenState
    extends State<ProductNbaResearchCommandCenterScreen> {
  final NbaResearchWorkspaceStore _store = const NbaResearchWorkspaceStore();
  final FocusNode _focusNode = FocusNode();
  late final Future<NbaTerminalSeedSnapshot> _seedFuture;
  late Future<List<NbaResearchWorkspace>> _workspaceFuture;
  late NbaResearchSection _section;

  bool get organizationMode => widget.session.role.canManageOrganization;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _seedFuture = const NbaTerminalSeedRepository().load();
    _workspaceFuture = _store.load(widget.session);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final index = switch (key) {
      LogicalKeyboardKey.digit1 => 0,
      LogicalKeyboardKey.digit2 => 1,
      LogicalKeyboardKey.digit3 => 2,
      LogicalKeyboardKey.digit4 => 3,
      LogicalKeyboardKey.digit5 => 4,
      _ => -1,
    };
    if (index < 0) return KeyEventResult.ignored;
    setState(() => _section = NbaResearchSection.values[index]);
    return KeyEventResult.handled;
  }

  Future<void> _createWorkspace() async {
    final result = await showDialog<_WorkspaceDraft>(
      context: context,
      builder: (context) => const _CreateWorkspaceDialog(),
    );
    if (result == null || !mounted) return;
    final current = await _workspaceFuture;
    final workspace = _store.createFromTemplate(
      widget.session,
      result.kind,
      title: result.title,
    );
    final next = await _store.upsert(widget.session, current, workspace);
    if (!mounted) return;
    setState(() {
      _workspaceFuture = Future.value(next);
      _section = NbaResearchSection.workspaces;
    });
  }

  Future<void> _saveWorkspace(NbaResearchWorkspace workspace) async {
    final current = await _workspaceFuture;
    final next = await _store.upsert(widget.session, current, workspace);
    if (!mounted) return;
    setState(() {
      _workspaceFuture = Future.value(next);
    });
  }

  Future<void> _editNotes(NbaResearchWorkspace workspace) async {
    final controller = TextEditingController(text: workspace.notes);
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${workspace.title} notes'),
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              hintText: 'Questions, assumptions, findings and follow-up work…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (notes == null || !mounted) return;
    await _saveWorkspace(
      workspace.copyWith(notes: notes, updatedAt: DateTime.now().toUtc()),
    );
  }

  Future<void> _duplicate(NbaResearchWorkspace workspace) async {
    final now = DateTime.now().toUtc();
    await _saveWorkspace(
      workspace.copyWith(
        id: 'research-${now.microsecondsSinceEpoch}',
        title: '${workspace.title} Copy',
        status: NbaResearchWorkspaceStatus.active,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _delete(NbaResearchWorkspace workspace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete research workspace?'),
        content: Text('“${workspace.title}” will be removed from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final current = await _workspaceFuture;
    final next = await _store.remove(widget.session, current, workspace.id);
    if (!mounted) return;
    setState(() {
      _workspaceFuture = Future.value(next);
    });
  }

  void _openWorkspace(NbaResearchWorkspace workspace) {
    setState(() {
      _section = switch (workspace.kind) {
        NbaResearchWorkspaceKind.playerEvaluation => NbaResearchSection.stats,
        NbaResearchWorkspaceKind.dataAudit => NbaResearchSection.coverage,
        _ => NbaResearchSection.analytics,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: _bg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            return Column(
              children: [
                _topBar(compact),
                if (compact) _compactNav(),
                Expanded(
                  child: Row(
                    children: [
                      if (!compact) SizedBox(width: 250, child: _sideNav()),
                      if (!compact)
                        const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: _line,
                        ),
                      Expanded(child: _content()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(bool compact) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_blue, _orange]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.query_stats_rounded, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NBA RESEARCH COMMAND CENTER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                Text(
                  '${organizationMode ? widget.session.organizationName : widget.session.displayName} · ${_section.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!compact) const _Pill('1–5 SWITCH', _muted),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Reload saved research',
            onPressed: () => setState(() {
            _workspaceFuture = _store.load(widget.session);
          }),
            icon: const Icon(Icons.refresh_rounded, color: _text),
          ),
          if (!compact)
            FilledButton.icon(
              onPressed: _createWorkspace,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New workspace'),
            ),
        ],
      ),
    );
  }

  Widget _sideNav() {
    return ColoredBox(
      color: _panel,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final section in NbaResearchSection.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      selected: section == _section,
                      selectedTileColor: _panel2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(
                          color: section == _section ? _blue : Colors.transparent,
                        ),
                      ),
                      leading: Icon(
                        section.icon,
                        color: section == _section ? _blue : _muted,
                      ),
                      title: Text(
                        section.label,
                        style: TextStyle(
                          color: section == _section ? _text : _muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () => setState(() => _section = section),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organizationMode ? 'ORGANIZATION SCOPE' : 'ANALYST SCOPE',
                    style: const TextStyle(
                      color: _yellow,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    organizationMode
                        ? 'Boards are namespaced to this organization on the current device. Shared research sync remains gated until its backend endpoint exists.'
                        : 'Boards and notes persist to this analyst profile on the current device.',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactNav() {
    return Container(
      color: _panel,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final section in NbaResearchSection.values)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  selected: section == _section,
                  avatar: Icon(section.icon, size: 17),
                  label: Text(section.label),
                  onSelected: (_) => setState(() => _section = section),
                ),
              ),
            FilledButton.icon(
              onPressed: _createWorkspace,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    return switch (_section) {
      NbaResearchSection.overview => _overview(),
      NbaResearchSection.stats => const _ModuleScroller(
          child: ProductNbaStatsCenterScreen(),
        ),
      NbaResearchSection.analytics => const _ModuleScroller(
          child: ProductAdvancedNbaToolsScreen(),
        ),
      NbaResearchSection.workspaces => _workspaces(),
      NbaResearchSection.coverage => _coverage(),
    };
  }

  Widget _overview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF142B4A), Color(0xFF19385D), Color(0xFF5B3521)],
              ),
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organizationMode
                      ? '${widget.session.organizationName.toUpperCase()} · NBA RESEARCH'
                      : '${widget.session.displayName.toUpperCase()} · NBA RESEARCH',
                  style: const TextStyle(
                    color: _yellow,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  organizationMode
                      ? 'A shared decision-support surface for professional basketball research.'
                      : 'Your professional basketball research workstation.',
                  style: const TextStyle(
                    color: _text,
                    fontSize: 27,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  organizationMode
                      ? 'Move from organization questions to player tables, comparisons, team analysis, recent form, modeled scenarios and documented source boundaries without leaving the organization view.'
                      : 'Move from a research question to sortable statistics, comparisons, recent form, modeled scenarios and saved notes without leaving the analyst view.',
                  style: const TextStyle(color: Color(0xFFD7E3F2), height: 1.45),
                ),
                const SizedBox(height: 15),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    FilledButton.icon(
                      onPressed: () => setState(
                        () => _section = NbaResearchSection.stats,
                      ),
                      icon: const Icon(Icons.table_chart_rounded),
                      label: const Text('Open Stats Workstation'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => setState(
                        () => _section = NbaResearchSection.analytics,
                      ),
                      icon: const Icon(Icons.analytics_rounded),
                      label: const Text('Open Analytics Suite'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _createWorkspace,
                      icon: const Icon(Icons.create_new_folder_rounded),
                      label: const Text('Create workspace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<NbaTerminalSeedSnapshot>(
            future: _seedFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final values = [
                ('Players', data?.players.length ?? 0),
                ('Player summaries', data?.playerSeasonTotals.length ?? 0),
                ('Games', data?.games.length ?? 0),
                ('Player game logs', data?.playerGameLogsTop.length ?? 0),
                ('Teams', data?.teams.length ?? 0),
                ('PBP events', data?.playByPlayEvents ?? 0),
              ];
              return _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _Heading(
                            'Connected data pulse',
                            'Actual loaded counts from the active NBA terminal seed.',
                          ),
                        ),
                        _Pill(
                          data == null
                              ? 'LOADING'
                              : data.usedFallback
                                  ? 'DEV FALLBACK'
                                  : 'ACTIVE RELEASE',
                          data == null
                              ? _muted
                              : data.usedFallback
                                  ? _orange
                                  : _green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (final value in values)
                          Container(
                            width: 168,
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: _panel2,
                              border: Border.all(color: _line),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data == null ? '—' : '${value.$2}',
                                  style: const TextStyle(
                                    color: _text,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  value.$1,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (data != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        '${data.supportedSeason} · ${data.datasetStatus} · validation ${data.validationStatus}',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const _Heading(
            'Professional research surfaces',
            'The role product now promotes the full workstation and analytics suite instead of burying them as ordinary pages.',
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 1000
                  ? (constraints.maxWidth - 20) / 3
                  : constraints.maxWidth >= 650
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ModuleCard(
                    width: width,
                    icon: Icons.table_chart_rounded,
                    title: 'Stats Workstation',
                    description:
                        'Views, basis conversion, filters, percentiles, comparisons, charts, glossary, export and density controls.',
                    badge: 'FULL WORKSTATION',
                    onTap: () => setState(
                      () => _section = NbaResearchSection.stats,
                    ),
                  ),
                  _ModuleCard(
                    width: width,
                    icon: Icons.analytics_rounded,
                    title: 'Analytics Suite',
                    description:
                        'Player and team tools, rankings, recent form, shot profile, lineup builder, tiering and modeled offense.',
                    badge: '10 LIVE MODULES',
                    onTap: () => setState(
                      () => _section = NbaResearchSection.analytics,
                    ),
                  ),
                  _ModuleCard(
                    width: width,
                    icon: Icons.fact_check_rounded,
                    title: 'Coverage & Methods',
                    description:
                        'Release completeness, sourced and derived fields, estimates, proxies and explicit source gates.',
                    badge: 'SOURCE TRANSPARENCY',
                    onTap: () => setState(
                      () => _section = NbaResearchSection.coverage,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: _Heading(
                  'Active research workspaces',
                  'Persistent boards connect research intent to the available tools.',
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _section = NbaResearchSection.workspaces,
                ),
                child: const Text('Open all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<NbaResearchWorkspace>>(
            future: _workspaceFuture,
            builder: (context, snapshot) {
              final workspaces = (snapshot.data ?? const <NbaResearchWorkspace>[])
                  .where((item) =>
                      item.status != NbaResearchWorkspaceStatus.archived)
                  .take(4)
                  .toList();
              if (workspaces.isEmpty) {
                return _Panel(
                  child: TextButton.icon(
                    onPressed: _createWorkspace,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create the first research workspace'),
                  ),
                );
              }
              return Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final workspace in workspaces)
                    SizedBox(
                      width: 270,
                      child: _Panel(
                        onTap: () => _openWorkspace(workspace),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              workspace.kind == NbaResearchWorkspaceKind.dataAudit
                                  ? Icons.fact_check_rounded
                                  : Icons.folder_copy_rounded,
                              color: _blue,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              workspace.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              workspace.kind.label,
                              style: const TextStyle(color: _muted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2417),
              border: Border.all(color: const Color(0xFF705A2A)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Professional boundary · The command center does not relabel regular-season rows as playoffs, convert box scores into tracking data, claim lineup possessions without stints, or publish RAPM and shot-quality values without validated source inputs.',
              style: TextStyle(color: _researchMutedFallback, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaces() {
    return FutureBuilder<List<NbaResearchWorkspace>>(
      future: _workspaceFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <NbaResearchWorkspace>[];
        if (items.isEmpty && snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final active = items
            .where((item) => item.status != NbaResearchWorkspaceStatus.archived)
            .toList();
        final archived = items
            .where((item) => item.status == NbaResearchWorkspaceStatus.archived)
            .toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Panel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.folder_copy_rounded, color: _blue, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            organizationMode
                                ? '${widget.session.organizationName} research board'
                                : '${widget.session.displayName} research board',
                            style: const TextStyle(
                              color: _text,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            organizationMode
                                ? 'Organization-scoped structure is available now. Persistence is device-local until a shared research API is deployed.'
                                : 'Saved research structure, notes and workflow status persist in the analyst experience on this device.',
                            style: const TextStyle(color: _muted, height: 1.4),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 7,
                            children: [
                              _Pill('${active.length} ACTIVE', _green),
                              _Pill(
                                '${active.where((item) => item.status == NbaResearchWorkspaceStatus.review).length} REVIEW',
                                _yellow,
                              ),
                              _Pill('${archived.length} ARCHIVED', _muted),
                            ],
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _createWorkspace,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New board'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _Heading(
                'Active boards',
                'Open the relevant tool, preserve notes and move completed work into review or archive.',
              ),
              const SizedBox(height: 9),
              if (active.isEmpty)
                _Panel(
                  child: TextButton.icon(
                    onPressed: _createWorkspace,
                    icon: const Icon(Icons.create_new_folder_rounded),
                    label: const Text('Create a research workspace'),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 1050
                        ? (constraints.maxWidth - 20) / 3
                        : constraints.maxWidth >= 680
                            ? (constraints.maxWidth - 10) / 2
                            : constraints.maxWidth;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final workspace in active)
                          _WorkspaceCard(
                            width: width,
                            workspace: workspace,
                            onOpen: () => _openWorkspace(workspace),
                            onNotes: () => _editNotes(workspace),
                            onDuplicate: () => _duplicate(workspace),
                            onStatus: (status) => _saveWorkspace(
                              workspace.copyWith(
                                status: status,
                                updatedAt: DateTime.now().toUtc(),
                              ),
                            ),
                            onDelete: () => _delete(workspace),
                          ),
                      ],
                    );
                  },
                ),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _Heading(
                  'Archive',
                  'Restore archived work or remove it permanently.',
                ),
                const SizedBox(height: 8),
                for (final workspace in archived)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _Panel(
                      child: Row(
                        children: [
                          const Icon(Icons.archive_rounded, color: _muted),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              workspace.title,
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _saveWorkspace(
                              workspace.copyWith(
                                status: NbaResearchWorkspaceStatus.active,
                                updatedAt: DateTime.now().toUtc(),
                              ),
                            ),
                            child: const Text('Restore'),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _delete(workspace),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _coverage() {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: _seedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: Text('Coverage unavailable: ${snapshot.error}'));
        }
        final data = snapshot.data!;
        final releaseRows = [
          ('Supported season', data.supportedSeason),
          ('Dataset status', data.datasetStatus),
          ('Validation', data.validationStatus),
          ('Asset path', data.assetPath),
          ('Warehouse generated', data.warehouseGeneratedAt),
          ('Resolved files', '${data.copiedAssetFiles}'),
          ('Normalized PBP events', '${data.playByPlayEvents}'),
          ('Fallback active', data.usedFallback ? 'Yes' : 'No'),
        ];
        const capabilities = [
          ('Stats Workstation', 'Ready', 'Source-backed box score plus transparent derived metrics.'),
          ('Player / Team Compare', 'Ready', 'Shared normalized metric engine.'),
          ('Rankings / Tier Lists', 'Ready', 'Direction-aware population percentiles.'),
          ('Last X Games', 'Ready', 'Uses available player-game rows.'),
          ('Shot Profile', 'Ready', 'Aggregate 2P, 3P and free-throw components only.'),
          ('Lineup Builder', 'Partial', 'Selected-player aggregate proxy; no together/apart claim.'),
          ('Offensive Rating Sandbox', 'Modeled', 'Transparent model, not an official NBA output.'),
          ('WOWY / Lineup Net Rating', 'Source gated', 'Requires lineup stints and possessions.'),
          ('Matchup Matrix', 'Source gated', 'Requires assignment or tracking possessions.'),
          ('RAPM / Impact Decomposition', 'Source gated', 'Requires a validated possession matrix and regression methodology.'),
          ('Shot Quality', 'Source gated', 'Requires pre-shot expected-value inputs.'),
          ('Draft Analysis', 'Source gated', 'Requires a normalized prospect dataset.'),
        ];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _Heading(
                            'Active release coverage',
                            'The application reports what it actually loaded instead of displaying misleading zeros.',
                          ),
                        ),
                        _Pill(
                          data.usedFallback ? 'DEVELOPMENT DATA' : 'CERTIFIED DATA',
                          data.usedFallback ? _orange : _green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (final row in releaseRows)
                          Container(
                            width: 250,
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: _panel2,
                              border: Border.all(color: _line),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.$1,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  row.$2.isEmpty ? '—' : row.$2,
                                  style: const TextStyle(
                                    color: _text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _Heading(
                'Capability status',
                'Ready modules are operational, partial modules show their proxy boundary and gated modules remain unavailable.',
              ),
              const SizedBox(height: 8),
              _Panel(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(_panel2),
                    headingTextStyle: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w900,
                    ),
                    dataTextStyle: const TextStyle(color: _text),
                    columns: const [
                      DataColumn(label: Text('Module')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Boundary / source')),
                    ],
                    rows: [
                      for (final row in capabilities)
                        DataRow(
                          cells: [
                            DataCell(Text(row.$1)),
                            DataCell(
                              _Pill(
                                row.$2.toUpperCase(),
                                row.$2 == 'Ready'
                                    ? _green
                                    : (row.$2 == 'Partial' || row.$2 == 'Modeled')
                                        ? _yellow
                                        : _orange,
                              ),
                            ),
                            DataCell(
                              SizedBox(width: 500, child: Text(row.$3)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _Heading(
                'Calculation policy',
                'Stats and Analytics use one shared formula and percentile layer.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: const [
                  _MethodCard(
                    'True shooting percentage',
                    'PTS / [2 × (FGA + 0.44 × FTA)]',
                  ),
                  _MethodCard(
                    'Effective field-goal percentage',
                    '(FGM + 0.5 × 3PM) / FGA',
                  ),
                  _MethodCard(
                    'Estimated individual possessions',
                    'FGA + 0.44 × FTA − OREB + TOV',
                  ),
                  _MethodCard(
                    'Percentile direction',
                    'Lower turnovers and fouls rank better.',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModuleScroller extends StatelessWidget {
  const _ModuleScroller({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.width,
    required this.workspace,
    required this.onOpen,
    required this.onNotes,
    required this.onDuplicate,
    required this.onStatus,
    required this.onDelete,
  });

  final double width;
  final NbaResearchWorkspace workspace;
  final VoidCallback onOpen;
  final VoidCallback onNotes;
  final VoidCallback onDuplicate;
  final ValueChanged<NbaResearchWorkspaceStatus> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (workspace.status) {
      NbaResearchWorkspaceStatus.active => _green,
      NbaResearchWorkspaceStatus.review => _yellow,
      NbaResearchWorkspaceStatus.archived => _muted,
    };
    return SizedBox(
      width: width,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _Pill(workspace.kind.label.toUpperCase(), _blue)),
                PopupMenuButton<String>(
                  tooltip: 'Workspace actions',
                  onSelected: (value) {
                    if (value == 'notes') onNotes();
                    if (value == 'duplicate') onDuplicate();
                    if (value == 'review') {
                      onStatus(NbaResearchWorkspaceStatus.review);
                    }
                    if (value == 'active') {
                      onStatus(NbaResearchWorkspaceStatus.active);
                    }
                    if (value == 'archive') {
                      onStatus(NbaResearchWorkspaceStatus.archived);
                    }
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'notes', child: Text('Edit notes')),
                    const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    if (workspace.status != NbaResearchWorkspaceStatus.review)
                      const PopupMenuItem(
                        value: 'review',
                        child: Text('Move to review'),
                      ),
                    if (workspace.status != NbaResearchWorkspaceStatus.active)
                      const PopupMenuItem(
                        value: 'active',
                        child: Text('Mark active'),
                      ),
                    const PopupMenuItem(value: 'archive', child: Text('Archive')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              workspace.title,
              style: const TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              workspace.description,
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Pill(workspace.status.name.toUpperCase(), statusColor),
                _Pill(workspace.organizationScope ? 'ORG' : 'PERSONAL', _orange),
                if (workspace.notes.isNotEmpty) const _Pill('NOTES', _yellow),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              'Metrics · ${workspace.metricKeys.join(' · ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open research surface'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateWorkspaceDialog extends StatefulWidget {
  const _CreateWorkspaceDialog();

  @override
  State<_CreateWorkspaceDialog> createState() => _CreateWorkspaceDialogState();
}

class _CreateWorkspaceDialogState extends State<_CreateWorkspaceDialog> {
  final TextEditingController controller = TextEditingController();
  NbaResearchWorkspaceKind kind = NbaResearchWorkspaceKind.playerEvaluation;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create research workspace'),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Workspace title',
                  hintText: 'Optional custom title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              for (final value in NbaResearchWorkspaceKind.values)
                RadioListTile<NbaResearchWorkspaceKind>(
                  value: value,
                  groupValue: kind,
                  onChanged: (next) {
                    if (next != null) setState(() => kind = next);
                  },
                  title: Text(value.label),
                  subtitle: Text(value.description),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _WorkspaceDraft(title: controller.text, kind: kind),
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _WorkspaceDraft {
  const _WorkspaceDraft({required this.title, required this.kind});
  final String title;
  final NbaResearchWorkspaceKind kind;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _Panel(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _blue, size: 24),
                const Spacer(),
                _Pill(badge, _yellow),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              title,
              style: const TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard(this.title, this.formula);
  final String title;
  final String formula;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 315,
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            SelectableText(
              formula,
              style: const TextStyle(color: _yellow, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: container,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.description);
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: const TextStyle(color: _muted, fontSize: 10, height: 1.35),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        border: Border.all(color: color.withOpacity(.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .35,
        ),
      ),
    );
  }
}
