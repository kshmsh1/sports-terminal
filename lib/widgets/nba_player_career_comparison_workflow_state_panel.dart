import 'package:flutter/material.dart';

class NbaPlayerCareerComparisonWorkflowStatePanel extends StatelessWidget {
  const NbaPlayerCareerComparisonWorkflowStatePanel({
    super.key,
    required this.saved,
    required this.watched,
    required this.activeResearch,
    required this.onToggleSaved,
    required this.onToggleWatch,
    required this.onActivateResearch,
  });

  final bool saved;
  final bool watched;
  final bool activeResearch;
  final VoidCallback onToggleSaved;
  final VoidCallback onToggleWatch;
  final VoidCallback onActivateResearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('career-comparison-workflow-state-panel'),
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
            'PERSISTENT COMPARISON WORKFLOWS',
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
              OutlinedButton.icon(
                key: const ValueKey('career-comparison-toggle-saved'),
                onPressed: onToggleSaved,
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, size: 16),
                label: Text(saved ? 'SAVED' : 'SAVE COMPARISON'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('career-comparison-toggle-watch'),
                onPressed: onToggleWatch,
                icon: Icon(watched ? Icons.visibility : Icons.visibility_outlined, size: 16),
                label: Text(watched ? 'WATCHING' : 'WATCH COMPARISON'),
              ),
              FilledButton.icon(
                key: const ValueKey('career-comparison-activate-research'),
                onPressed: onActivateResearch,
                icon: Icon(activeResearch ? Icons.check_circle : Icons.science_outlined, size: 16),
                label: Text(activeResearch ? 'ACTIVE RESEARCH' : 'ACTIVATE RESEARCH'),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Saved comparisons preserve the exact analyst configuration. Watches use the canonical directional Player pair + scope. Active research is a dedicated comparison checkpoint and does not overwrite single-entity context.',
            style: TextStyle(color: Color(0xFF8895A5), fontSize: 9, height: 1.4),
          ),
        ],
      ),
    );
  }
}
