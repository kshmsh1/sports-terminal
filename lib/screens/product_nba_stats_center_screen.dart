import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';
import 'product_historical_nba_research_lab_screen.dart';
import 'product_historical_nba_workstation_screen.dart';
import 'product_nba_stats_workstation_screen.dart';

enum _StatsCenterMode { historicalStats, historicalResearch, currentRelease }

class ProductNbaStatsCenterScreen extends StatefulWidget {
  const ProductNbaStatsCenterScreen({super.key});

  @override
  State<ProductNbaStatsCenterScreen> createState() =>
      _ProductNbaStatsCenterScreenState();
}

class _ProductNbaStatsCenterScreenState
    extends State<ProductNbaStatsCenterScreen> {
  _StatsCenterMode _mode = _StatsCenterMode.historicalStats;
  int _currentRevision = 0;

  Future<void> _openCurrentRelease() async {
    await const NbaTerminalSeedRepository().selectCurrent();
    if (!mounted) return;
    setState(() {
      _mode = _StatsCenterMode.currentRelease;
      _currentRevision++;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xFF111824),
            child: Row(
              children: [
                const Text(
                  'STATS CENTER',
                  style: TextStyle(
                    color: Color(0xFFFFCB45),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .9,
                  ),
                ),
                const SizedBox(width: 14),
                _ModeButton(
                  label: 'Historical Stats',
                  icon: Icons.timeline_rounded,
                  selected: _mode == _StatsCenterMode.historicalStats,
                  onTap: () => setState(
                    () => _mode = _StatsCenterMode.historicalStats,
                  ),
                ),
                const SizedBox(width: 6),
                _ModeButton(
                  label: 'Historical Research Lab',
                  icon: Icons.science_outlined,
                  selected: _mode == _StatsCenterMode.historicalResearch,
                  onTap: () => setState(
                    () => _mode = _StatsCenterMode.historicalResearch,
                  ),
                ),
                const SizedBox(width: 6),
                _ModeButton(
                  label: 'Certified Current Release',
                  icon: Icons.verified_outlined,
                  selected: _mode == _StatsCenterMode.currentRelease,
                  onTap: _openCurrentRelease,
                ),
                const Spacer(),
                Text(
                  switch (_mode) {
                    _StatsCenterMode.historicalStats =>
                      '1946–PRESENT · CANONICAL HISTORY',
                    _StatsCenterMode.historicalResearch =>
                      'CAREERS · RECORDS · GAMES · FRANCHISES',
                    _StatsCenterMode.currentRelease =>
                      'VALIDATED RELEASE ASSETS',
                  },
                  style: const TextStyle(
                    color: Color(0xFF8D99AA),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (_mode) {
              _StatsCenterMode.historicalStats =>
                const ProductHistoricalNbaWorkstationScreen(),
              _StatsCenterMode.historicalResearch =>
                const ProductHistoricalNbaResearchLabScreen(),
              _StatsCenterMode.currentRelease => LayoutBuilder(
                  key: ValueKey('current-$_currentRevision'),
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 1180) {
                      return const ProductNbaStatsWorkstationScreen();
                    }
                    return const SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1180,
                        child: ProductNbaStatsWorkstationScreen(),
                      ),
                    );
                  },
                ),
            },
          ),
        ],
      );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0x22FFCB45)
                : const Color(0xFF1B2433),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFCB45)
                  : const Color(0xFF354155),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? const Color(0xFFFFCB45)
                    : const Color(0xFF9DA8BA),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFFFCB45)
                      : const Color(0xFFF3F6FB),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}
