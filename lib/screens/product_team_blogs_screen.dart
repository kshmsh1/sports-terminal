import 'package:flutter/material.dart';

import '../services/nba_terminal_seed_repository.dart';

const _navy = Color(0xFF071A33);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _green = Color(0xFF059669);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _soft = Color(0xFFF6F8FC);

class ProductTeamBlogsScreen extends StatelessWidget {
  const ProductTeamBlogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const _Surface(child: Text('Loading team blogs...', style: TextStyle(color: _muted)));
        if (snapshot.hasError) return _Surface(child: Text('Team blog data unavailable: ${snapshot.error}', style: const TextStyle(color: _muted)));
        final teams = snapshot.data!.teamRecords.map((row) => _txt(row['team_id'])).where((team) => team != '—').toList()..sort();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _HeroBand(),
          const SizedBox(height: 18),
          const _Surface(child: _SectionHeader('30 team blog network', 'Each NBA team should eventually have a dedicated blog/homepage with articles, game recaps, trade ideas, injuries, transactions, comments, and team-room discussion.')),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth < 760 ? constraints.maxWidth : (constraints.maxWidth - 36) / 4;
            return Wrap(spacing: 12, runSpacing: 12, children: [for (final team in teams) SizedBox(width: width, child: _TeamBlogCard(team: team))]);
          }),
          const SizedBox(height: 18),
          const _Surface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _SectionHeader('Team blog modules', 'What every team site needs before launch.'),
              SizedBox(height: 12),
              _ChecklistItem('Team news feed, editorial posts, postgame recaps, trade ideas, free-agency updates, and injury/transaction notes.'),
              _ChecklistItem('Team-specific stats, schedule, roster, depth chart, contracts, cap view, lineup data, and fan polls.'),
              _ChecklistItem('Comment moderation, author profiles, tags, featured cards, RSS/email digest, and entity links back to players/games/trades.'),
            ]),
          ),
        ]);
      },
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), gradient: const LinearGradient(colors: [_navy, _blue, _orange]), boxShadow: const [BoxShadow(color: Color(0x24071A33), blurRadius: 32, offset: Offset(0, 16))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('TEAM BLOGS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.4)),
          SizedBox(height: 12),
          Text('A dedicated publication layer for every NBA team.', style: TextStyle(color: Colors.white, fontSize: 39, height: 1.04, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
          SizedBox(height: 12),
          SizedBox(width: 880, child: Text('Sports Terminal should eventually have a self-contained team blog site for all 30 NBA teams, attached to stats, schedules, rosters, injuries, transactions, trade scenarios, and community rooms.', style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600))),
          SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [_GlassChip('30 TEAM SITES'), _GlassChip('CMS'), _GlassChip('RECAPS'), _GlassChip('TEAM ROOMS'), _GlassChip('ENTITY LINKS')]),
        ]),
      );
}

class _TeamBlogCard extends StatelessWidget {
  const _TeamBlogCard({required this.team});
  final String team;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [CircleAvatar(backgroundColor: const Color(0xFFEFF6FF), child: Text(team, style: const TextStyle(color: _blue, fontWeight: FontWeight.w900, fontSize: 11))), const Spacer(), const Icon(Icons.arrow_outward_rounded, color: _muted, size: 18)]),
          const SizedBox(height: 14),
          Text('$team Blog', style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Team homepage for news, recaps, roster notes, trade ideas, fan threads, and embedded stat modules.', style: TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Wrap(spacing: 6, runSpacing: 6, children: [_SmallPill('Recaps'), _SmallPill('Roster'), _SmallPill('Trades'), _SmallPill('Community')]),
        ]),
      );
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: _line)), child: Text(label, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w900)));
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_rounded, color: _green, size: 18), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w700)))]));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600))]);
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withOpacity(0.26))), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8)));
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 22, offset: Offset(0, 10))]), child: child);
}

String _txt(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}
