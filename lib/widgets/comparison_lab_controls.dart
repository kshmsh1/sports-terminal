import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';

/// Controlled selectors for comparison pages. Their displayed values always
/// reflect parent state; selecting an item never depends on initialValue.
class ComparisonSeasonTypeSelector extends StatelessWidget {
  const ComparisonSeasonTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NbaStatsSeasonType value;
  final ValueChanged<NbaStatsSeasonType> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<NbaStatsSeasonType>(
        segments: const [
          ButtonSegment(
            value: NbaStatsSeasonType.regular,
            label: Text('Regular Season'),
          ),
          ButtonSegment(
            value: NbaStatsSeasonType.playoffs,
            label: Text('Playoffs'),
          ),
        ],
        selected: {value},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty && selection.first != value) {
            onChanged(selection.first);
          }
        },
      );
}

class ComparisonRateBasisSelector extends StatelessWidget {
  const ComparisonRateBasisSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NbaStatsBasis value;
  final ValueChanged<NbaStatsBasis> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 165,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Rate basis',
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<NbaStatsBasis>(
              value: value,
              isDense: true,
              isExpanded: true,
              items: [
                for (final basis in NbaStatsBasis.values)
                  DropdownMenuItem(value: basis, child: Text(basis.label)),
              ],
              onChanged: (next) {
                if (next != null && next != value) onChanged(next);
              },
            ),
          ),
        ),
      );
}
