import 'package:flutter/material.dart';

import '../data/route_payload_consumer_items.dart';
import 'terminal_primitives.dart';

class RoutePayloadConsumerRegistryPanel extends StatelessWidget {
  const RoutePayloadConsumerRegistryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final p0 = routePayloadConsumerItems.where((item) => item.priority == 'P0').length;
    final next = routePayloadConsumerItems.where((item) => item.status == 'Next').length;
    final categories = routePayloadConsumerItems.map((item) => item.category).toSet().length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('RoutePayload Consumer Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('This registry turns the shared RoutePayload contract into implementation requirements for every workflow consumer. It defines which payload fields each tab needs and what output that tab should produce.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          InfoPill(label: '${routePayloadConsumerItems.length} consumers'),
          InfoPill(label: '$categories categories'),
          InfoPill(label: '$p0 P0'),
          InfoPill(label: '$next next'),
        ]),
      ])),
      const SizedBox(height: 18),
      TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.all(18), child: Text('Consumer Implementation Registry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        const Divider(height: 1, color: terminalBorder),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          headingRowColor: WidgetStateProperty.all(terminalPanelDark),
          headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
          dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
          columnSpacing: 30,
          columns: const [
            DataColumn(label: Text('Consumer')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Payload Inputs')),
            DataColumn(label: Text('Next Step')),
          ],
          rows: [
            for (final item in routePayloadConsumerItems)
              DataRow(cells: [
                DataCell(SizedBox(width: 230, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))),
                DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))),
                DataCell(InfoPill(label: item.status)),
                DataCell(SizedBox(width: 560, child: Text(item.description))),
                DataCell(SizedBox(width: 460, child: Text(item.inputs))),
                DataCell(SizedBox(width: 520, child: Text(item.nextStep))),
              ]),
          ],
        )),
      ])),
    ]);
  }
}
