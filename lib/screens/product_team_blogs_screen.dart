import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import 'product_nba_public_pages_screen.dart';

const _bPanel = Color(0xFF0F151C);
const _bPanel2 = Color(0xFF141C25);
const _bLine = Color(0xFF263342);
const _bText = Color(0xFFE8EDF3);
const _bMuted = Color(0xFF8895A5);
const _bBlue = Color(0xFF63A9FF);
const _bAmber = Color(0xFFE2B866);

class ProductTeamBlogsScreen extends StatefulWidget {
  const ProductTeamBlogsScreen({super.key});
  @override
  State<ProductTeamBlogsScreen> createState() => _ProductTeamBlogsScreenState();
}

class _ProductTeamBlogsScreenState extends State<ProductTeamBlogsScreen> {
  final search = TextEditingController();
  String conference = 'All';
  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
    future: const NbaTerminalSeedRepository().load(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const _BlogPanel(child: Center(child: CircularProgressIndicator()));
      final data = snapshot.data!;
      final q = search.text.toLowerCase().trim();
      final records = data.teamRecords.where((r) => q.isEmpty || '${r['team_id']} ${r['team_name'] ?? ''}'.toLowerCase().contains(q)).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _BlogPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TEAM PUBLICATION NETWORK', style: TextStyle(color: _bBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)), SizedBox(height: 7),
          Text('Thirty dedicated NBA team publications', style: TextStyle(color: _bText, fontSize: 29, fontWeight: FontWeight.w900)), SizedBox(height: 7),
          Text('Every franchise gets a permanent editorial home combining beat reporting, analysis, roster/cap context, transactions, schedule, linked players, community conversation, newsletters and team-specific archives.', style: TextStyle(color: _bMuted, height: 1.5)),
        ])),
        const SizedBox(height: 12),
        _BlogPanel(child: Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(width: 280, child: TextField(controller: search, onChanged: (_) => setState(() {}), style: const TextStyle(color: _bText), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Find team publication…', border: OutlineInputBorder(), isDense: true))),
          for (final item in const ['All','East','West']) ChoiceChip(label: Text(item), selected: conference == item, onSelected: (_) => setState(() => conference = item)),
        ])),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth < 700 ? constraints.maxWidth : constraints.maxWidth < 1100 ? (constraints.maxWidth - 10) / 2 : (constraints.maxWidth - 20) / 3;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final record in records)
              SizedBox(width: width, child: _TeamPublicationCard(record: record, onOpen: () => _openTeamPublication(context, '${record['team_id']}', data))),
          ]);
        }),
      ]);
    },
  );

  Future<void> _openTeamPublication(BuildContext context, String team, NbaTerminalSeedSnapshot data) => Navigator.of(context).push<void>(MaterialPageRoute(
    settings: RouteSettings(name: '/blogs/nba/$team'),
    builder: (_) => Scaffold(
      backgroundColor: const Color(0xFF090D12),
      appBar: AppBar(backgroundColor: _bPanel, foregroundColor: _bText, title: Text('$team Team Blog')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1250), child: _TeamPublication(team: team, data: data)))),
    ),
  ));
}

class _TeamPublication extends StatelessWidget {
  const _TeamPublication({required this.team, required this.data});
  final String team;
  final NbaTerminalSeedSnapshot data;
  @override
  Widget build(BuildContext context) {
    final roster = const NbaStatsWorkstationEngine().buildRows(data).where((row) => row.team.split(RegExp(r'[,/ ]+')).contains(team)).toList()..sort((a,b)=>(b.value('pts')??0).compareTo(a.value('pts')??0));
    final record = data.teamRecords.where((r) => '${r['team_id']}' == team).firstOrNull;
    final games = data.teamGameLogs.where((r) => '${r['team_id']}' == team).toList().reversed.take(8).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _BlogPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$team DAILY', style: const TextStyle(color: _bBlue, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)), const SizedBox(height: 8),
        Text('$team news, analysis and intelligence', style: const TextStyle(color: _bText, fontSize: 31, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
        Text(record == null ? 'Team publication' : '${record['wins'] ?? '—'}-${record['losses'] ?? '—'} · ${record['points_per_game'] ?? '—'} PPG', style: const TextStyle(color: _bAmber, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [ActionChip(label: const Text('Team page'), avatar: const Icon(Icons.groups_rounded, size: 16), onPressed: () => openNbaTeamPage(context, team, team)), const Chip(label: Text('Latest')), const Chip(label: Text('Analysis')), const Chip(label: Text('Transactions')), const Chip(label: Text('Draft')), const Chip(label: Text('Cap & Contracts')), const Chip(label: Text('Newsletter'))]),
      ])),
      const SizedBox(height: 12),
      _BlogPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _BlogTitle('TOP STORIES'), const SizedBox(height: 9),
        _Story('$team roster decisions that will define the next phase', 'Front Office Analysis'),
        _Story('What the numbers say about the current rotation', 'Data + Film'),
        _Story('Three questions entering the next stretch of games', 'Beat Report'),
        _Story('Contract, cap and draft-asset notebook', 'Transactions'),
      ])),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final rosterCard = _BlogPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _BlogTitle('ROSTER LEADERS'), const SizedBox(height: 8), for (final row in roster.take(12)) InkWell(onTap: () => openNbaPlayerPage(context, row.playerId, row.player), child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(row.player, style: const TextStyle(color: _bBlue, fontWeight: FontWeight.w800))), Text('${(row.value('pts') ?? 0).toStringAsFixed(1)} PPG', style: const TextStyle(color: _bText, fontWeight: FontWeight.w800))])))]));
        final scheduleCard = _BlogPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const _BlogTitle('RECENT GAMES'), const SizedBox(height: 8), for (final game in games) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text('${game['game_date'] ?? '—'} · ${game['opponent_team_id'] ?? '—'}', style: const TextStyle(color: _bMuted))), Text('${game['result'] ?? ''}', style: const TextStyle(color: _bText, fontWeight: FontWeight.w900))]))]));
        if (constraints.maxWidth < 800) return Column(children: [rosterCard, const SizedBox(height: 12), scheduleCard]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: rosterCard), const SizedBox(width: 12), Expanded(child: scheduleCard)]);
      }),
      const SizedBox(height: 12),
      const _BlogPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_BlogTitle('COMMUNITY & NEWSLETTER'), SizedBox(height: 8), Text('Team publication pages are designed to connect directly to team-specific community threads, writer follows, article saves, push alerts, daily/weekly newsletters, podcasts, live blogs, mailbags, Q&As and game threads as those services are wired to the shared backend.', style: TextStyle(color: _bMuted, height: 1.5))])),
    ]);
  }
}

class _TeamPublicationCard extends StatelessWidget {
  const _TeamPublicationCard({required this.record, required this.onOpen}); final Map<String,dynamic> record; final VoidCallback onOpen;
  @override Widget build(BuildContext context) => InkWell(onTap: onOpen, child: _BlogPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Container(width: 38,height:38,alignment:Alignment.center,decoration:BoxDecoration(color:_bPanel2,border:Border.all(color:_bLine)),child:Text('${record['team_id']}',style:const TextStyle(color:_bBlue,fontWeight:FontWeight.w900))), const SizedBox(width:10), Expanded(child: Text('${record['team_name'] ?? record['team_id']}', style: const TextStyle(color:_bText,fontSize:17,fontWeight:FontWeight.w900)))]),
    const SizedBox(height:10), Text('${record['wins'] ?? '—'}-${record['losses'] ?? '—'} · dedicated beat, analysis, transactions and fan community', style: const TextStyle(color:_bMuted,height:1.4)), const SizedBox(height:9), const Text('OPEN TEAM PUBLICATION →', style: TextStyle(color:_bAmber,fontSize:9,fontWeight:FontWeight.w900)),
  ])));
}
class _Story extends StatelessWidget { const _Story(this.title,this.section); final String title,section; @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:7),padding:const EdgeInsets.symmetric(vertical:8),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:_bLine))),child:Row(children:[Expanded(child:Text(title,style:const TextStyle(color:_bText,fontSize:15,fontWeight:FontWeight.w800))),const SizedBox(width:12),Text(section.toUpperCase(),style:const TextStyle(color:_bBlue,fontSize:8,fontWeight:FontWeight.w900))])); }
class _BlogPanel extends StatelessWidget { const _BlogPanel({required this.child}); final Widget child; @override Widget build(BuildContext context)=>Container(width:double.infinity,padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:_bPanel,border:Border.all(color:_bLine)),child:child); }
class _BlogTitle extends StatelessWidget { const _BlogTitle(this.text); final String text; @override Widget build(BuildContext context)=>Text(text,style:const TextStyle(color:_bText,fontSize:14,fontWeight:FontWeight.w900,letterSpacing:.5)); }
extension _First<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
