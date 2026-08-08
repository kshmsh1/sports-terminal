import 'package:flutter/material.dart';

import '../services/nba_research_context_store.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'product_historical_nba_research_lab_screen.dart';
import 'product_historical_nba_workstation_screen.dart';
import 'product_nba_stats_workstation_screen.dart';

const _scInk = Color(0xFF090D12);
const _scSurface = Color(0xFF0F151C);
const _scSurface2 = Color(0xFF141C25);
const _scStroke = Color(0xFF263342);
const _scText = Color(0xFFE8EDF3);
const _scMuted = Color(0xFF8895A5);
const _scFaint = Color(0xFF566273);
const _scBlue = Color(0xFF63A9FF);
const _scGreen = Color(0xFF69C99A);
const _scAmber = Color(0xFFE2B866);

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
          return ColoredBox(
            color: _scInk,
            child: SizedBox(
              height: height,
              child: Column(
                children: [
                  _modeBar(constraints.maxWidth),
                  Expanded(child: _modeBody()),
                ],
              ),
            ),
          );
        },
      );

  Widget _modeBar(double width) {
    final compact = width < 980;
    final controls = <Widget>[
      const _TerminalMark(),
      const SizedBox(width: 12),
      _ModeButton(
        label: 'Active Scope',
        code: 'SCOPE',
        selected: _mode == _StatsCenterMode.activeContext,
        onTap: _openActiveContext,
      ),
      const SizedBox(width: 4),
      _ModeButton(
        label: 'Historical Stats',
        code: 'HIST',
        selected: _mode == _StatsCenterMode.historicalStats,
        onTap: () => setState(() => _mode = _StatsCenterMode.historicalStats),
      ),
      const SizedBox(width: 4),
      _ModeButton(
        label: 'Research Lab',
        code: 'LAB',
        selected: _mode == _StatsCenterMode.historicalResearch,
        onTap: () => setState(() => _mode = _StatsCenterMode.historicalResearch),
      ),
      const SizedBox(width: 4),
      _ModeButton(
        label: 'Current Release',
        code: 'LIVE',
        selected: _mode == _StatsCenterMode.currentRelease,
        onTap: _openCurrentRelease,
      ),
      if (!compact) ...[
        const Spacer(),
        Flexible(child: _modeStatus()),
      ],
    ];

    return Container(
      height: 48,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: _scSurface,
        border: Border(bottom: BorderSide(color: _scStroke)),
      ),
      child: compact
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: controls),
            )
          : Row(children: controls),
    );
  }

  Widget _modeStatus() {
    if (_mode == _StatsCenterMode.activeContext) {
      return FutureBuilder<NbaResearchContext>(
        future: _contextFuture,
        builder: (context, snapshot) {
          final active = snapshot.data;
          final text = active == null
              ? 'SHARED RESEARCH SCOPE'
              : '${active.scopeLabel.toUpperCase()}${active.entityLabel.isEmpty ? '' : ' / ${active.entityLabel.toUpperCase()}'}';
          return _StatusReadout(
            text: text,
            tone: active?.historical == true ? _scAmber : _scGreen,
          );
        },
      );
    }
    return _StatusReadout(
      text: switch (_mode) {
        _StatsCenterMode.activeContext => 'SHARED RESEARCH SCOPE',
        _StatsCenterMode.historicalStats => '1946–PRESENT / CANONICAL HISTORY',
        _StatsCenterMode.historicalResearch => 'CAREERS / RECORDS / GAMES / FRANCHISES',
        _StatsCenterMode.currentRelease => 'VALIDATED CURRENT RELEASE',
      },
      tone: _scMuted,
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

  Widget _seedWorkstation(String key) =>
      ProductNbaStatsWorkstationScreen(key: ValueKey(key));
}

class _TerminalMark extends StatelessWidget {
  const _TerminalMark();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 3, height: 25, color: _scBlue),
          const SizedBox(width: 8),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STATS',
                style: TextStyle(
                  color: _scText,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              Text(
                'COMMAND CENTER',
                style: TextStyle(
                  color: _scFaint,
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .55,
                ),
              ),
            ],
          ),
        ],
      );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1A63A9FF) : _scSurface2,
            border: Border.all(color: selected ? _scBlue : _scStroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: TextStyle(
                  color: selected ? _scBlue : _scFaint,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .55,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _scText : _scMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatusReadout extends StatelessWidget {
  const _StatusReadout({required this.text, required this.tone});
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: tone,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: .45,
        ),
      );
}
