import 'package:flutter/material.dart';

import 'product_local_store.dart';

enum TerminalDensity { summary, analyst, terminal }

extension TerminalDensityLabel on TerminalDensity {
  String get label => switch (this) {
        TerminalDensity.summary => 'SUMMARY',
        TerminalDensity.analyst => 'ANALYST',
        TerminalDensity.terminal => 'TERMINAL',
      };

  static TerminalDensity parse(String value) => switch (value.trim().toLowerCase()) {
        'summary' => TerminalDensity.summary,
        'terminal' => TerminalDensity.terminal,
        _ => TerminalDensity.analyst,
      };
}

class TerminalDensityService {
  const TerminalDensityService({this.store = const ProductLocalStore()});

  static const storageKey = 'sports_terminal.ui.density';
  final ProductLocalStore store;

  Future<TerminalDensity> load() async {
    final raw = await store.loadString(storageKey, fallback: 'analyst');
    return TerminalDensityLabel.parse(raw);
  }

  Future<void> save(TerminalDensity value) =>
      store.saveString(storageKey, value.name);
}

class TerminalDensitySelector extends StatelessWidget {
  const TerminalDensitySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TerminalDensity value;
  final ValueChanged<TerminalDensity> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TerminalDensity>(
      showSelectedIcon: false,
      segments: [
        for (final density in TerminalDensity.values)
          ButtonSegment<TerminalDensity>(
            value: density,
            label: Text(
              density.label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
      ],
      selected: {value},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) onChanged(selection.first);
      },
    );
  }
}
