import 'package:flutter/material.dart';

import '../widgets/source_backed_data_wave_panel.dart';
import '../widgets/terminal_primitives.dart';

class SourceBackedDataWaveScreen extends StatelessWidget {
  const SourceBackedDataWaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
        title: 'Source-Backed NBA Data Wave',
        subtitle: 'Execution sequence for moving from first route payloads into player identity, traditional stats, standings, playoffs, MVP voting, games, rosters, draft, transactions, and later expansion layers.',
      ),
      SizedBox(height: 22),
      SourceBackedDataWavePanel(),
    ]);
  }
}
