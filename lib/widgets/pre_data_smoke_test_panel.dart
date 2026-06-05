import 'package:flutter/material.dart';

import '../services/pre_data_smoke_test_service.dart';
import 'terminal_primitives.dart';

class PreDataSmokeTestPanel extends StatelessWidget {
  const PreDataSmokeTestPanel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PreDataSmokeTestSummary>(
      future: const PreDataSmokeTestService().run(),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (summary == null) {
          return const TerminalCard(child: Text('Running pre-data smoke tests...', style: TextStyle(color: terminalTextSoft)));
        }
        final rows = compact ? summary.results.take(8).toList() : summary.results;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Expanded(child: Text('Pre-Data Smoke Test', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
              InfoPill(label: summary.canAttemptPlayerIdentityImport ? 'Import gate near-ready' : 'Import gate blocked'),
            ]),
            const SizedBox(height: 10),
            const Text('This panel checks whether the local-first app is structurally ready for the first real NBA data wave without fake records or broken joins.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              return GridView.count(crossAxisCount: isWide ? 5 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: isWide ? 2.1 : 1.45, children: [
                _Metric(label: 'Tests', value: '${summary.total}', detail: 'smoke checks'),
                _Metric(label: 'Pass', value: '${summary.passed}', detail: 'green checks'),
                _Metric(label: 'Warn', value: '${summary.warnings}', detail: 'needs review'),
                _Metric(label: 'Fail', value: '${summary.failed}', detail: 'blocking'),
                _Metric(label: 'Score', value: '${summary.completion}%', detail: 'pass rate'),
              ]);
            }),
          ])),
          const SizedBox(height: 18),
          TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Text('Smoke Test Results', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const Spacer(), Text('${rows.length}/${summary.total} shown', style: const TextStyle(color: terminalTextMuted))])),
            const Divider(height: 1, color: terminalBorder),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              headingRowColor: WidgetStateProperty.all(terminalPanelDark),
              headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
              dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
              columnSpacing: 30,
              columns: const [DataColumn(label: Text('Status')), DataColumn(label: Text('Check')), DataColumn(label: Text('Category')), DataColumn(label: Text('Detail')), DataColumn(label: Text('Next Step'))],
              rows: [for (final item in rows) DataRow(cells: [
                DataCell(InfoPill(label: item.status)),
                DataCell(SizedBox(width: 260, child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)))),
                DataCell(SizedBox(width: 180, child: Text(item.category))),
                DataCell(SizedBox(width: 420, child: Text(item.detail))),
                DataCell(SizedBox(width: 520, child: Text(item.nextStep))),
              ])],
            )),
          ])),
        ]);
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
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
    Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
  ]));
}
