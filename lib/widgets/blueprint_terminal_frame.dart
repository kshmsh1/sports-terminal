import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/terminal_action.dart';
import '../screens/excel_like_workspace_screen.dart';
import '../screens/product_nba_terminal_screen.dart';
import '../screens/product_python_dev_lab_screen.dart';
import '../screens/product_trade_machine_screen.dart';
import '../services/terminal_density_service.dart';
import 'terminal_command_bar.dart';
import 'terminal_status_bar.dart';

/// Global frame mounted around the existing product shells during convergence.
/// It makes command/status/density behavior universal without rewriting the
/// already-deep NBA object graph or nesting a second static navigation rail.
class BlueprintTerminalFrame extends StatefulWidget {
  const BlueprintTerminalFrame({
    super.key,
    required this.session,
    required this.child,
  });

  final AppSession session;
  final Widget child;

  @override
  State<BlueprintTerminalFrame> createState() => _BlueprintTerminalFrameState();
}

class _BlueprintTerminalFrameState extends State<BlueprintTerminalFrame> {
  final _densityService = const TerminalDensityService();
  TerminalDensity _density = TerminalDensity.analyst;

  List<TerminalCommandEntry> get _entries => const [
        TerminalCommandEntry(
          id: 'nba-terminal',
          label: 'NBA Terminal',
          kind: 'workspace',
          aliases: ['NBA', 'stats', 'research', 'games', 'players', 'teams'],
          subtitle: 'Canonical NBA search, objects, analytics and research',
          payload: {'route': 'nba'},
        ),
        TerminalCommandEntry(
          id: 'trade-machine',
          label: 'Trade Machine',
          kind: 'front-office',
          aliases: ['TRADE', 'cap scenario'],
          subtitle: 'NBA transaction and CBA scenario analysis',
          payload: {'route': 'trade'},
        ),
        TerminalCommandEntry(
          id: 'python-lab',
          label: 'Python Lab',
          kind: 'developer',
          aliases: ['LAB', 'python', 'notebook', 'model'],
          subtitle: 'Programmable sports research environment',
          payload: {'route': 'python'},
        ),
        TerminalCommandEntry(
          id: 'workspace',
          label: 'Workspace',
          kind: 'workflow',
          aliases: ['sheet', 'spreadsheet', 'grid'],
          subtitle: 'Sports Terminal workbook',
          payload: {'route': 'workspace'},
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadDensity();
  }

  Future<void> _loadDensity() async {
    final density = await _densityService.load();
    if (!mounted) return;
    setState(() => _density = density);
  }

  Future<void> _setDensity(TerminalDensity value) async {
    setState(() => _density = value);
    await _densityService.save(value);
  }

  Future<void> _open(Widget child, String title) => showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(title),
              leading: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            body: child,
          ),
        ),
      );

  void _handleCommand(TerminalCommandResult result) {
    final route = result.entry?.payload['route']?.toString() ?? '';
    switch (route) {
      case 'nba':
        _open(
          ProductNbaTerminalScreen(session: widget.session),
          'Sports Terminal · NBA',
        );
        return;
      case 'trade':
        _open(
          const SingleChildScrollView(child: ProductTradeMachineScreen()),
          'Trade Machine',
        );
        return;
      case 'python':
        _open(const ProductPythonDevLabScreen(), 'Python Lab');
        return;
      case 'workspace':
        _open(const ExcelLikeWorkspaceScreen(), 'Workspace');
        return;
    }

    final action = result.action;
    if (action != null) {
      if (action.kind == TerminalActionKind.lab ||
          action.kind == TerminalActionKind.model) {
        _open(const ProductPythonDevLabScreen(), 'Python Lab');
        return;
      }
      if ({
        TerminalActionKind.query,
        TerminalActionKind.compare,
        TerminalActionKind.chart,
        TerminalActionKind.source,
      }.contains(action.kind)) {
        _open(
          ProductNbaTerminalScreen(session: widget.session),
          'Sports Terminal · NBA',
        );
        return;
      }
    }

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          result.mode == 'query'
              ? 'Query captured: ${result.query}. Open NBA Terminal to inspect and execute against canonical data.'
              : 'Command captured: ${result.raw}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TerminalCommandBar(
                entries: _entries,
                actions: TerminalAction.standard,
                onResult: _handleCommand,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TerminalDensitySelector(
                value: _density,
                onChanged: _setDensity,
              ),
            ),
          ],
        ),
        Expanded(child: widget.child),
        TerminalStatusBar(
          sourceLabel: 'CANONICAL NBA',
          releaseLabel: 'SOURCE-AWARE',
          connectionLabel: 'LOCAL / SHARED WHEN AVAILABLE',
          density: _density,
        ),
      ],
    );
  }
}
