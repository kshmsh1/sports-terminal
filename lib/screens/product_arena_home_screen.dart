import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_terminal_seed_repository.dart';

const _navy = Color(0xFF071A33);
const _navy2 = Color(0xFF0F2D56);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _lime = Color(0xFF8BEA7A);
const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE3E8F0);
const _paper = Color(0xFFFFFFFF);
const _soft = Color(0xFFF4F7FB);

class ProductArenaHomeScreen extends StatelessWidget {
  const ProductArenaHomeScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Surface(child: Text('Loading your arena...', style: TextStyle(color: _muted)));
        }
        if (snapshot.hasError) {
          return _Surface(child: Text('NBA data unavailable: ${snapshot.error}', style: const TextStyle(color: _muted)));
        }
        final data = snapshot.data!;
        final leaders = _rows(data.playerLeaders['points_per_game']).take(6).toList();
        final teams = List<Map<String, dynamic>>.from(data.teamRecords)
          ..sort((a, b) => _num(b['average_margin']).compareTo(_num(a['average_margin'])));
        final games = data.games.length <= 8 ? data.games.reversed.toList() : data.games.sublist(data.games.length - 8).reversed.toList();
        final highs = _rows(data.playerGameHighs['points']).take(4).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ArenaHero(session: session, data: data, leaders: leaders, games: games),
          const SizedBox(height: 18),
          _ActionDock(actions: const [
            _DockAction(Icons.sports_basketball_rounded, 'NBA Hub', 'Open player, team, and game pages'),
            _DockAction(Icons.bolt_rounded, 'Fantasy War Room', 'Build watchlists and compare targets'),
            _DockAction(Icons.forum_rounded, 'Community', 'Discuss teams, fantasy, and product ideas'),
            _DockAction(Icons.grid_on_rounded, 'Workspace', 'Track analysis in an Excel-like workbook'),
          ]),
          const SizedBox(height: 18),
          _SectionHeader('Live product pulse', 'A more sports-app-style home surface powered by the generated NBA data layer.'),
          const SizedBox(height: 12),
          _TwoColumn(
            left: _SpotlightCard(leaders: leaders),
            right: _TeamPowerCards(teams: teams.take(5).toList()),
          ),
          const SizedBox(height: 18),
          _TwoColumn(
            left: _GameReel(games: games),
            right: _MomentBoard(highs: highs),
          ),
          const SizedBox(height: 18),
          const _RoadmapCards(),
        ]);
      },
    );
  }
}

class _ArenaHero extends StatelessWidget {
  const _ArenaHero({required this.session, required this.data, required this.leaders, required this.games});

  final AppSession session;
  final NbaTerminalSeedSnapshot data;
  final List<Map<String, dynamic>> leaders;
  final List<Map<String, dynamic>> games;

  @override
  Widget build(BuildContext context) {
    final topLeader = leaders.isEmpty ? null : leaders.first;
    final latestGame = games.isEmpty ? null : games.first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_navy, _navy2, _blue, _orange]),
        boxShadow: const [BoxShadow(color: Color(0x33071A33), blurRadius: 36, offset: Offset(0, 18))],
      ),
      child: Stack(children: [
        Positioned(right: -40, top: -55, child: _GlowBall(size: 190, color: Colors.white.withValues(alpha: 0.10))),
        Positioned(right: 125, bottom: -70, child: _GlowBall(size: 150, color: _orange.withValues(alpha: 0.22))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            _GlassPill('SPORTS TERMINAL'),
            _GlassPill('NBA 2024-25 DATA READY'),
            _GlassPill('${data.games.length} GAMES'),
            _GlassPill('${_compact(data.playByPlayEvents)} PBP EVENTS'),
          ]),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Text(
              'Welcome back, ${session.displayName}. Your sports command center is starting to feel like a real product.',
              style: const TextStyle(color: Colors.white, fontSize: 42, height: 1.02, fontWeight: FontWeight.w900, letterSpacing: -1.2),
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(
            width: 760,
            child: Text(
              'Jump into NBA pages, fantasy watchlists, community conversations, or an Excel-style workspace without exposing users to raw internal tooling.',
              style: TextStyle(color: Color(0xFFEAF2FF), fontSize: 16, height: 1.45, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 800;
            final cards = [
              _HeroStat('Top scorer', _txt(topLeader?['player_label']), '${_d(topLeader?['points_per_game'])} PPG'),
              _HeroStat('Latest loaded game', _txt(latestGame?['game_id']), _txt(latestGame?['winner_team_id'])),
              _HeroStat('Data health', data.validationStatus.toUpperCase(), '${data.copiedAssetFiles} asset files'),
            ];
            if (compact) return Column(children: [for (final card in cards) ...[card, const SizedBox(height: 10)]]);
            return Row(children: [for (final card in cards) Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: card))]);
          }),
        ]),
      ]),
    );
  }
}

class _GlowBall extends StatelessWidget {
  const _GlowBall({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _GlassPill extends StatelessWidget {
  const _GlassPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.24))),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.9)),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withValues(alpha: 0.24))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFFDCEBFF), fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
          const SizedBox(height: 3),
          Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _lime, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      );
}

class _ActionDock extends StatelessWidget {
  const _ActionDock({required this.actions});
  final List<_DockAction> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        return GridView.count(
          crossAxisCount: wide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: wide ? 1.55 : 1.25,
          children: [for (final action in actions) _DockCard(action)],
        );
      });
}

class _DockAction {
  const _DockAction(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _DockCard extends StatelessWidget {
  const _DockCard(this.action);
  final _DockAction action;

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16)), child: Icon(action.icon, color: _blue)),
            const Spacer(),
            const Icon(Icons.arrow_outward_rounded, color: _muted, size: 18),
          ]),
          const SizedBox(height: 15),
          Text(action.title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 7),
          Expanded(child: Text(action.body, style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600), overflow: TextOverflow.fade)),
        ]),
      );
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.leaders});
  final List<Map<String, dynamic>> leaders;

  @override
  Widget build(BuildContext context) => _Surface(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _CardHeader('Scoring spotlight', 'Top loaded PPG leaders, rounded to one decimal.'),
          for (var i = 0; i < leaders.length; i++)
            _RankRow(rank: i + 1, title: _txt(leaders[i]['player_label']), subtitle: _txt(leaders[i]['team_ids']), metric: '${_d(leaders[i]['points_per_game'])} PPG'),
        ]),
      );
}

class _TeamPowerCards extends StatelessWidget {
  const _TeamPowerCards({required this.teams});
  final List<Map<String, dynamic>> teams;

  @override
  Widget build(BuildContext context) => _Surface(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _CardHeader('Team power pulse', 'Best average margins from the loaded season.'),
          for (var i = 0; i < teams.length; i++)
            _RankRow(rank: i + 1, title: _txt(teams[i]['team_id']), subtitle: '${_txt(teams[i]['wins'])}-${_txt(teams[i]['losses'])} record', metric: '${_d(teams[i]['average_margin'])} margin'),
        ]),
      );
}

class _GameReel extends StatelessWidget {
  const _GameReel({required this.games});
  final List<Map<String, dynamic>> games;

  @override
  Widget build(BuildContext context) => _Surface(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _CardHeader('Game reel', 'Recent loaded games from the 2024-25 asset set.'),
          for (final game in games)
            _MatchRow(
              title: '${_txt(game['away_team_id'])} @ ${_txt(game['home_team_id'])}',
              subtitle: '${_txt(game['game_date'])} • ${_txt(game['game_id'])}',
              score: '${_d(game['away_score'], decimals: 0)}-${_d(game['home_score'], decimals: 0)}',
            ),
        ]),
      );
}

class _MomentBoard extends StatelessWidget {
  const _MomentBoard({required this.highs});
  final List<Map<String, dynamic>> highs;

  @override
  Widget build(BuildContext context) => _Surface(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _CardHeader('Big nights', 'Single-game scoring highs available in the seed.'),
          for (final row in highs)
            _RankRow(rank: highs.indexOf(row) + 1, title: _txt(row['player_label']), subtitle: '${_txt(row['team_id'])} vs ${_txt(row['opponent_team_id'])}', metric: '${_d(row['pts'], decimals: 0)} pts'),
        ]),
      );
}

class _RoadmapCards extends StatelessWidget {
  const _RoadmapCards();

  @override
  Widget build(BuildContext context) => _Surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          _SectionHeader('Launch path', 'What this home page is organizing toward.'),
          SizedBox(height: 12),
          _RoadmapRow('Consumer product', 'Home, NBA, fantasy, community, articles, workspace, messages, profile.'),
          _RoadmapRow('Operator product', 'Admin console, data operations, content, moderation, users, billing, legal, feature flags.'),
          _RoadmapRow('Data product', 'Historical warehouse now works; current-season refresh and live integrations come later.'),
        ]),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: _muted, fontWeight: FontWeight.w600, height: 1.35)),
      ]);
}

class _CardHeader extends StatelessWidget {
  const _CardHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _muted, fontWeight: FontWeight.w600))])),
          const Icon(Icons.more_horiz_rounded, color: _muted),
        ]),
      );
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.title, required this.subtitle, required this.metric});
  final int rank;
  final String title;
  final String subtitle;
  final String metric;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
        child: Row(children: [
          Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: rank <= 3 ? _navy : _soft, borderRadius: BorderRadius.circular(12)), child: Text('$rank', style: TextStyle(color: rank <= 3 ? Colors.white : _muted, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))])),
          Text(metric, style: const TextStyle(color: _blue, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.title, required this.subtitle, required this.score});
  final String title;
  final String subtitle;
  final String score;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _line))),
        child: Row(children: [
          const Icon(Icons.sports_basketball_rounded, color: _orange),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w600))])),
          Text(score, style: const TextStyle(color: _navy, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      );
}

class _RoadmapRow extends StatelessWidget {
  const _RoadmapRow(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(shape: BoxShape.circle, color: _orange)),
          const SizedBox(width: 10),
          Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: _muted, height: 1.35, fontWeight: FontWeight.w600), children: [TextSpan(text: '$title — ', style: const TextStyle(color: _ink, fontWeight: FontWeight.w900)), TextSpan(text: body)]))),
        ]),
      );
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 920) return Column(children: [left, const SizedBox(height: 18), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 18), Expanded(child: right)]);
      });
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: _paper, borderRadius: BorderRadius.circular(26), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x0F071A33), blurRadius: 24, offset: Offset(0, 10))]),
        child: child,
      );
}

List<Map<String, dynamic>> _rows(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) item.cast<String, dynamic>()];
}

String _txt(Object? value) => value?.toString() ?? '—';

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _d(Object? value, {int decimals = 1}) => _num(value).toStringAsFixed(decimals);

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
