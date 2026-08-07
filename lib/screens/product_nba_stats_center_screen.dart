import 'package:flutter/material.dart';

import '../services/nba_research_context_store.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'product_historical_nba_research_lab_screen.dart';
import 'product_historical_nba_workstation_screen.dart';
import 'product_nba_stats_workstation_screen.dart';

enum _StatsCenterMode {
  activeContext,
  historicalStats,
  historicalResearch,
  currentRelease,
}

class ProductNbaStatsCenterScreen extends StatefulWidget {
  const ProductNbaStatsCenterScreen({super.key});

  @override
  State<ProductNbaStatsCenterScreen> createState() =>
      _ProductNbaStatsCenterScreenState();
}

class _ProductNbaStatsCenterScreenState
    extends State<ProductNbaStatsCenterScreen> {
  static const double _embeddedMinHeight = 860;

  _StatsCenterMode _mode = _StatsCenterMode.activeContext;
  int _revision = 0;
  late Future<NbaResearchContext> _contextFuture;

  @override
  void initState() {
    super.initState();
    _contextFuture = const NbaResearchContextStore().load();
  }

  void _openActiveContext() {
    setState(() {
      _mode = _StatsCenterMode.activeContext;
      _revision++;
      _contextFuture = const NbaResearchContextStore().load();
    });
  }

  Future<void> _openCurrentRelease() async {
    await const NbaTerminalSeedRepository().selectCurrent();
    if (!mounted) return;
    setState(() {
      _mode = _StatsCenterMode.currentRelease;
      _revision++;
      _contextFuture = const NbaResearchContextStore().load();
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : _embeddedMinHeight;
          return SizedBox(
            height: height,
            child: Column(
              children: [
                _modeBar(constraints.maxWidth),
                Expanded(child: _modeBody()),
              ],
            ),
          );
        },
      );

  Widget _modeBar(double width) {
    final compact = width < 1180;
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
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
          label: 'Active Context',
          icon: Icons.hub_rounded,
          selected: _mode == _StatsCenterMode.activeContext,
          onTap: _openActiveContext,
        ),
        const SizedBox(width: 6),
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
        if (!compact) ...[
          const SizedBox(width: 16),
          Flexible(child: _modeStatus()),
        ],
      ],
    );

    return Container(
      height: 46,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: const Color(0xFF111824),
      child: compact
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: controls,
            )
          : Row(children: [Expanded(child: controls)]),
    );
  }

  Widget _modeStatus() {
    if (_mode == _StatsCenterMode.activeContext) {
      return FutureBuilder<NbaResearchContext>(
        future: _contextFuture,
        builder: (context, snapshot) {
          final active = snapshot.data;
          return Text(
            active == null
                ? 'SHARED RESEARCH SCOPE'
                : '${active.scopeLabel.toUpperCase()}${active.entityLabel.isEmpty ? '' : ' · ${active.entityLabel.toUpperCase()}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active?.historical == true
                  ? const Color(0xFFFFCB45)
                  : const Color(0xFF65E3A5),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          );
        },
      );
    }
    return Text(
      switch (_mode) {
        _StatsCenterMode.activeContext => 'SHARED RESEARCH SCOPE',
        _StatsCenterMode.historicalStats =>
          '1946–PRESENT · CANONICAL HISTORY',
        _StatsCenterMode.historicalResearch =>
          'CAREERS · RECORDS · GAMES · FRANCHISES',
        _StatsCenterMode.currentRelease => 'VALIDATED RELEASE ASSETS',
      },
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF8D99AA),
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    );
  }

  Widget _modeBody() => switch (_mode) {
        _StatsCenterMode.activeContext => _seedWorkstation('active-$_revision'),
        _StatsCenterMode.historicalStats =>
          const ProductHistoricalNbaWorkstationScreen(),
        _StatsCenterMode.historicalResearch =>
          const ProductHistoricalNbaResearchLabScreen(),
        _StatsCenterMode.currentRelease => _seedWorkstation('current-$_revision'),
      };

  Widget _seedWorkstation(String key) {
    return LayoutBuilder(
      key: ValueKey(key),
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
    );
  }
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
