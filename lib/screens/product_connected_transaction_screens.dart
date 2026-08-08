import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/transaction_case_convergence_service.dart';
import 'product_front_office_scenario_screen.dart';
import 'product_trade_machine_v2_screen.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);

class ProductConnectedTradeMachineScreen extends StatelessWidget {
  const ProductConnectedTradeMachineScreen({
    super.key,
    required this.session,
    required this.organizationMode,
  });

  final AppSession session;
  final bool organizationMode;

  @override
  Widget build(BuildContext context) {
    return _ConnectedTool(
      session: session,
      organizationMode: organizationMode,
      source: 'Trade Machine',
      title: 'Turn the current trade scenario into a governed case.',
      body:
          'Save the scenario in the Trade Machine, then create a persistent case with its teams, routed assets, operating year and source identity.',
      child: ProductTradeMachineV2Screen(session: session),
    );
  }
}

class ProductConnectedFrontOfficeScreen extends StatelessWidget {
  const ProductConnectedFrontOfficeScreen({
    super.key,
    required this.session,
    required this.organizationMode,
  });

  final AppSession session;
  final bool organizationMode;

  @override
  Widget build(BuildContext context) {
    return _ConnectedTool(
      session: session,
      organizationMode: organizationMode,
      source: 'Front Office Ledger',
      title: 'Convert the current ledger into a transaction case.',
      body:
          'Contract rows, draft assets, cap charges, no-trade assumptions and source identity are imported into the shared case workflow.',
      child: const ProductFrontOfficeScenarioScreen(),
    );
  }
}

class _ConnectedTool extends StatefulWidget {
  const _ConnectedTool({
    required this.session,
    required this.organizationMode,
    required this.source,
    required this.title,
    required this.body,
    required this.child,
  });

  final AppSession session;
  final bool organizationMode;
  final String source;
  final String title;
  final String body;
  final Widget child;

  @override
  State<_ConnectedTool> createState() => _ConnectedToolState();
}

class _ConnectedToolState extends State<_ConnectedTool> {
  final convergence = const TransactionCaseConvergenceService();
  bool shareWithOrganization = false;
  bool importing = false;

  @override
  void initState() {
    super.initState();
    shareWithOrganization = widget.organizationMode;
  }

  Future<void> _import() async {
    setState(() => importing = true);
    try {
      final candidates = await convergence.discover();
      final matches = candidates.where((item) => item.source == widget.source);
      if (matches.isEmpty) {
        _show('Save a ${widget.source} scenario before creating a case.');
        return;
      }
      final item = await convergence.importCandidate(
        candidate: matches.first,
        session: widget.session,
        organizationVisible: widget.organizationMode || shareWithOrganization,
      );
      _show('Created “${item.title}” in the transaction command center.');
    } catch (error) {
      _show('Could not create the transaction case: $error');
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_navy, _blue, _orange]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final controls = Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!widget.organizationMode)
                    FilterChip(
                      selected: shareWithOrganization,
                      onSelected: (value) =>
                          setState(() => shareWithOrganization = value),
                      label: const Text('Submit to organization'),
                      selectedColor: Colors.white,
                      checkmarkColor: _blue,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _navy,
                    ),
                    onPressed: importing ? null : _import,
                    icon: Icon(
                      importing
                          ? Icons.hourglass_top_rounded
                          : Icons.add_task_rounded,
                    ),
                    label: Text(importing ? 'Creating case...' : 'Create case'),
                  ),
                ],
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CONNECTED TRANSACTION WORKFLOW',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.body,
                    style: const TextStyle(
                      color: Color(0xFFEAF2FF),
                      height: 1.4,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [copy, const SizedBox(height: 14), controls],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: 18),
                  controls,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(24),
          ),
          child: widget.child,
        ),
        const SizedBox(height: 12),
        const Text(
          'Imported cases remain modeled until contract, timing, cap and draft assumptions are fully sourced.',
          style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
