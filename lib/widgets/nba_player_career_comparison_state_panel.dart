import 'package:flutter/material.dart';

import '../services/nba_player_career_comparison_preset_catalog.dart';
import '../services/nba_player_career_comparison_state_store.dart';

class NbaPlayerCareerComparisonStatePanel extends StatelessWidget {
  const NbaPlayerCareerComparisonStatePanel({
    super.key,
    required this.state,
    required this.onApplyPreset,
    required this.onRestore,
    this.activePresetId = '',
  });

  final NbaPlayerCareerComparisonState state;
  final ValueChanged<NbaPlayerCareerComparisonPreset> onApplyPreset;
  final ValueChanged<NbaPlayerCareerComparisonStateItem> onRestore;
  final String activePresetId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('career-comparison-state-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F151C),
        border: Border.all(color: const Color(0xFF263342)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RESEARCH PRESETS & RECENTS',
            style: TextStyle(
              color: Color(0xFFE2B866),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in NbaPlayerCareerComparisonPresetCatalog.presets)
                ChoiceChip(
                  key: ValueKey('career-comparison-preset-${preset.id}'),
                  selected: activePresetId == preset.id,
                  label: Text(preset.label),
                  onSelected: (_) => onApplyPreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Presets select metrics/scope only. They do not apply weights, rankings or era adjustments.',
            style: TextStyle(color: Color(0xFF8895A5), fontSize: 9),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'RECENT COMPARISONS',
                  style: TextStyle(
                    color: Color(0xFF63A9FF),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${state.saved.length} SAVED · ${state.recents.length} RECENT',
                style: const TextStyle(color: Color(0xFF8895A5), fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (state.recents.isEmpty)
            const Text(
              'No prior comparison configuration has been recorded yet.',
              style: TextStyle(color: Color(0xFF8895A5), fontSize: 9),
            )
          else
            for (final item in state.recents.take(6))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${item.leftPlayerName} vs ${item.rightPlayerName}',
                  style: const TextStyle(
                    color: Color(0xFFE8EDF3),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                subtitle: Text(
                  '${item.seasonType.toUpperCase()} · ${item.alignment.label} · ${item.metric.label}${item.sharedOnly ? ' · SHARED' : ''}${item.presetId.isEmpty ? '' : ' · ${item.presetId.toUpperCase()}'}',
                  style: const TextStyle(color: Color(0xFF8895A5), fontSize: 8),
                ),
                trailing: TextButton(
                  key: ValueKey('career-comparison-restore-${item.signature}'),
                  onPressed: () => onRestore(item),
                  child: const Text('RESTORE'),
                ),
              ),
        ],
      ),
    );
  }
}
