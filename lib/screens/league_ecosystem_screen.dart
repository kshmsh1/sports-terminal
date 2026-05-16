import 'package:flutter/material.dart';

import '../data/league_profiles.dart';
import '../widgets/terminal_primitives.dart';

class LeagueEcosystemScreen extends StatelessWidget {
  const LeagueEcosystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = leagueProfiles.where((league) => league.priority == 0).length;
    final future = leagueProfiles.length - primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Basketball Ecosystem',
          subtitle: 'NBA remains the priority, but the architecture is being prepared for G League, Summer League, and draft-development context.',
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: isWide ? 2.0 : 1.5,
              children: [
                _LeagueMetric(label: 'League Layers', value: '${leagueProfiles.length}', detail: 'Basketball scope'),
                _LeagueMetric(label: 'Primary Focus', value: '$primary', detail: 'NBA first'),
                _LeagueMetric(label: 'Future Layers', value: '$future', detail: 'G League and context'),
                const _LeagueMetric(label: 'Expansion Rule', value: 'Schema', detail: 'Prepare before sourcing'),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        for (final league in leagueProfiles) ...[
          TerminalCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: terminalPanelDark,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: terminalBorder),
                  ),
                  child: Text(
                    league.shortName.split(' ').map((part) => part[0]).join(),
                    style: const TextStyle(color: terminalAccent, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              league.name,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                          ),
                          InfoPill(label: league.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(league.level, style: const TextStyle(color: terminalAccent, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Text(league.description, style: const TextStyle(color: terminalTextSoft, height: 1.4)),
                      const SizedBox(height: 10),
                      Text('Relationship: ${league.relationshipToNba}', style: const TextStyle(color: terminalTextMuted, height: 1.35)),
                      const SizedBox(height: 4),
                      Text('Data posture: ${league.dataPosture}', style: const TextStyle(color: terminalTextMuted, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _LeagueMetric extends StatelessWidget {
  const _LeagueMetric({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12)),
        ],
      ),
    );
  }
}
