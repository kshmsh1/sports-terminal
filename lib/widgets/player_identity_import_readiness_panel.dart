import 'package:flutter/material.dart';

import '../data/player_identity_contract_items.dart';
import '../data/player_identity_source_items.dart';
import '../data/player_identity_validation_items.dart';
import '../services/player_identity_import_readiness_service.dart';
import 'terminal_primitives.dart';

class PlayerIdentityImportReadinessPanel extends StatelessWidget {
  const PlayerIdentityImportReadinessPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlayerIdentityImportReadinessSummary>(
      future: const PlayerIdentityImportReadinessService().evaluate(),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (summary == null) {
          return const TerminalCard(child: Text('Checking player identity import readiness...', style: TextStyle(color: terminalTextSoft)));
        }
        return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(child: Text('Player Identity Import Readiness', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            InfoPill(label: summary.canImportRealRows ? 'Ready to import' : summary.canBeginSourceSelection ? 'Choose source path' : 'Pre-source work left'),
          ]),
          const SizedBox(height: 10),
          const Text('This is the cutover signal for the first real NBA data unlock. The local asset is allowed to stay empty, but the contract, validator, source decision, and import plan must be explicit before real rows are connected.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(crossAxisCount: isWide ? 6 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: isWide ? 2.05 : 1.45, children: [
              _Metric(label: 'Player Rows', value: '${summary.currentPlayerRows}', detail: 'current asset'),
              _Metric(label: 'Contract', value: '${summary.contractDone}/${playerIdentityContractItems.length}', detail: 'locked rows'),
              _Metric(label: 'Validator', value: '${summary.validationImplemented}/${playerIdentityValidationItems.length}', detail: 'implemented checks'),
              _Metric(label: 'Source Gates', value: '${summary.sourceRequired}/${playerIdentitySourceItems.length}', detail: 'still required'),
              _Metric(label: 'Blockers', value: '${summary.validatorBlockers}', detail: 'validator'),
              _Metric(label: 'Warnings', value: '${summary.validatorWarnings}', detail: 'validator'),
            ]);
          }),
        ]));
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
    Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
  ]));
}
