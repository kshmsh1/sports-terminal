import 'package:flutter/material.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF6F8FC);
const _green = Color(0xFF059669);

class ProductStrategyMapScreen extends StatelessWidget {
  const ProductStrategyMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      _HeroBand(),
      SizedBox(height: 18),
      _SectionHeader('What we are trying to beat', 'A competitor-informed product map that turns the fragmented NBA tool market into Sports Terminal build targets.'),
      SizedBox(height: 12),
      _CompetitorGrid(),
      SizedBox(height: 18),
      _PillarGrid(),
      SizedBox(height: 18),
      _MoatSurface(),
      SizedBox(height: 18),
      _BuildSequence(),
    ]);
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _blue, _orange]),
          boxShadow: const [BoxShadow(color: Color(0x24071A33), blurRadius: 34, offset: Offset(0, 16))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('MARKET MAP', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          const Text('Turn every competing NBA tool into one connected workflow.', style: TextStyle(color: Colors.white, fontSize: 39, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          const SizedBox(height: 12),
          const SizedBox(
            width: 850,
            child: Text(
              'Sports Terminal should not become another isolated stats site. It should absorb the jobs users hire StatMuse, NBA.com/stats, Cleaning the Glass, PBP Stats, cap/trade tools, fantasy tools, and community products for, then connect all of them through player, team, game, workspace, article, scenario, and community objects.',
              style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 9, runSpacing: 9, children: const [
            _GlassChip('ONE IDENTITY GRAPH'),
            _GlassChip('ONE WORKSPACE'),
            _GlassChip('SOURCE TRANSPARENCY'),
            _GlassChip('SCENARIO MODELING'),
            _GlassChip('COMMUNITY ATTACHED TO DATA'),
          ]),
        ]),
      );
}

class _CompetitorGrid extends StatelessWidget {
  const _CompetitorGrid();

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 760 ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final item in _competitors) SizedBox(width: width, child: _CompetitorCard(item)),
        ]);
      });
}

const _competitors = [
  _Competitor('StatMuse', 'Natural-language facts', 'Command answers with source tables, saved queries, charts, and workspace export.'),
  _Competitor('NBA.com/stats', 'Official taxonomy', 'Player/team/game stat pages, leaders, lineups, clutch, shot/tracking-style modules.'),
  _Competitor('Cleaning the Glass', 'Adjusted interpretation', 'Raw vs adjusted toggles, method panels, percentiles, on/off and context cards.'),
  _Competitor('PBP Stats', 'Possession tools', 'Play-by-play explorer, lineup stints, score-margin filters, WOWY-style workflows.'),
  _Competitor('Dunks & Threes / RAPM', 'Impact metrics', 'Impact comparison slots, disagreement views, explainable model context.'),
  _Competitor('Salary / trade sites', 'Cap and scenarios', 'Contracts, cap sheets, trade lab, scenario save/share, community voting.'),
  _Competitor('Fanspo / HoopsMatic', 'Social roster tools', 'Data-backed trades, polls, tier lists, grids, and moderated entity discussion.'),
  _Competitor('Fantasy tools', 'Decisions and alerts', 'Watchlists, dynasty value, role volatility, waiver boards, league imports later.'),
  _Competitor('ESPN / mainstream', 'Friendly entry point', 'Keep the surface readable while offering terminal depth underneath.'),
];

const _pillars = [
  _Pillar('Universal command layer', 'Ask, search, jump, save, chart, compare, export, and cite from one place.'),
  _Pillar('Player command centers', 'Overview, game log, role, impact, shot profile, fantasy, contract, discussion, articles.'),
  _Pillar('Team front-office pages', 'Roster, rotation, schedule, four factors, lineup context, cap table, trade needs.'),
  _Pillar('Game postgame workflow', 'Score, box, advanced box, momentum, PBP, lineup stints, recap draft, comments.'),
  _Pillar('Excel for sports objects', 'Tables, formulas, imports, charts, saved scenarios, multi-sheet workbooks.'),
  _Pillar('Front-office simulator', 'CBA legality, salary matching, basketball impact, rotation fit, fan response.'),
];

class _PillarGrid extends StatelessWidget {
  const _PillarGrid();

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionHeader('Sports Terminal product pillars', 'The actual features that should make switching between competitor sites unnecessary.'),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth < 800 ? constraints.maxWidth : (constraints.maxWidth - 18) / 2;
            return Wrap(spacing: 18, runSpacing: 12, children: [for (final pillar in _pillars) SizedBox(width: width, child: pillar)]);
          }),
        ]),
      );
}

class _MoatSurface extends StatelessWidget {
  const _MoatSurface();

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          _SectionHeader('The moat', 'The advantage is the integration layer, not one isolated stat.'),
          SizedBox(height: 12),
          _ChecklistItem('Every stat has source, filter, date, and method metadata.'),
          _ChecklistItem('Every entity has pages, comments, articles, saved notes, and workspace export.'),
          _ChecklistItem('Every scenario can be saved, shared, compared, discussed, and revised.'),
          _ChecklistItem('Casual users get readable pages; power users get terminal depth.'),
        ]),
      );
}

class _BuildSequence extends StatelessWidget {
  const _BuildSequence();

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          _SectionHeader('Immediate build sequence', 'What this strategy changes about the next few pushes.'),
          SizedBox(height: 12),
          _TimelineRow('1', 'Upgrade NBA pages into command centers', 'Add role, impact, method, discussion, article, workspace, and fantasy modules.'),
          _TimelineRow('2', 'Build front-office scenario primitives', 'Use current player/team data as the prototype layer before real salary/cap feeds exist.'),
          _TimelineRow('3', 'Make workspace imports real', 'Send player/team/game/scenario tables into workbook tabs.'),
          _TimelineRow('4', 'Wire community to entities', 'Threads should attach to players, teams, games, trades, articles, and workbooks.'),
        ]),
      );
}

class _CompetitorCard extends StatelessWidget {
  const _CompetitorCard(this.item);
  final _Competitor item;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF3E8), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.radar_rounded, color: _orange)),
            const Spacer(),
            const Icon(Icons.arrow_outward_rounded, color: _muted, size: 18),
          ]),
          const SizedBox(height: 14),
          Text(item.name, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(item.job, style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 10),
          Text(item.response, style: const TextStyle(color: _muted, height: 1.4, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Pillar extends StatelessWidget {
  const _Pillar(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _soft, border: Border.all(color: _line), borderRadius: BorderRadius.circular(18)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_circle_rounded, color: _green, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600)),
          ])),
        ]),
      );
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.check_rounded, color: _green, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, height: 1.35))),
        ]),
      );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.step, this.title, this.body);
  final String step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 16, backgroundColor: _navy, child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(body, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600)),
          ])),
        ]),
      );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.26))),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 22, offset: Offset(0, 10))]),
        child: child,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600)),
      ]);
}

class _Competitor {
  const _Competitor(this.name, this.job, this.response);
  final String name;
  final String job;
  final String response;
}
