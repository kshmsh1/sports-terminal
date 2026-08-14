import 'package:flutter/material.dart';

import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../widgets/nba_game_navigation.dart';
import 'product_nba_public_pages_screen.dart';

const _bPanel = Color(0xFF0F151C);
const _bPanel2 = Color(0xFF141C25);
const _bLine = Color(0xFF263342);
const _bText = Color(0xFFE8EDF3);
const _bMuted = Color(0xFF8895A5);
const _bBlue = Color(0xFF63A9FF);
const _bAmber = Color(0xFFE2B866);
const _bGreen = Color(0xFF69C99A);

class ProductTeamBlogsScreen extends StatefulWidget {
  const ProductTeamBlogsScreen({super.key});

  @override
  State<ProductTeamBlogsScreen> createState() => _ProductTeamBlogsScreenState();
}

class _ProductTeamBlogsScreenState extends State<ProductTeamBlogsScreen> {
  final TextEditingController search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NbaTerminalSeedSnapshot>(
        future: const NbaTerminalSeedRepository().load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _BlogPanel(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final data = snapshot.data!;
          final query = search.text.toLowerCase().trim();
          final records = data.teamRecords
              .where(
                (record) =>
                    query.isEmpty ||
                    '${record['team_id']} ${record['team_name'] ?? ''}'
                        .toLowerCase()
                        .contains(query),
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BlogPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEAM PUBLICATION NETWORK',
                      style: TextStyle(
                        color: _bBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Thirty permanent NBA team publications',
                      style: TextStyle(
                        color: _bText,
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Each franchise has a dedicated editorial home for beat reporting, analysis, roster and cap intelligence, transactions, schedule coverage, linked players, community discussion, newsletters and archives. Team identities always remain one click away from the underlying Sports Terminal team page.',
                      style: TextStyle(color: _bMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _BlogPanel(
                child: SizedBox(
                  width: 320,
                  child: TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: _bText),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Find team publication…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth < 700
                      ? constraints.maxWidth
                      : constraints.maxWidth < 1100
                          ? (constraints.maxWidth - 10) / 2
                          : (constraints.maxWidth - 20) / 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final record in records)
                        SizedBox(
                          width: width,
                          child: _TeamPublicationCard(
                            record: record,
                            onOpenPublication: () => _openTeamPublication(
                              context,
                              '${record['team_id']}',
                              data,
                            ),
                            onOpenTeam: () => openNbaTeamPage(
                              context,
                              '${record['team_id']}',
                              '${record['team_name'] ?? record['team_id']}',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      );

  Future<void> _openTeamPublication(
    BuildContext context,
    String team,
    NbaTerminalSeedSnapshot data,
  ) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: RouteSettings(name: '/blogs/nba/$team'),
          builder: (_) => Scaffold(
            backgroundColor: const Color(0xFF090D12),
            appBar: AppBar(
              backgroundColor: _bPanel,
              foregroundColor: _bText,
              title: Text('$team Team Publication'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1250),
                  child: _TeamPublication(team: team, data: data),
                ),
              ),
            ),
          ),
        ),
      );
}

class _TeamPublication extends StatelessWidget {
  const _TeamPublication({required this.team, required this.data});

  final String team;
  final NbaTerminalSeedSnapshot data;

  @override
  Widget build(BuildContext context) {
    final roster = const NbaStatsWorkstationEngine()
        .buildRows(data)
        .where((row) => row.team.split(RegExp(r'[,/ ]+')).contains(team))
        .toList()
      ..sort(
        (left, right) =>
            (right.value('pts') ?? 0).compareTo(left.value('pts') ?? 0),
      );
    final record = data.teamRecords
        .where((item) => '${item['team_id']}' == team)
        .firstOrNull;
    final games = data.teamGameLogs
        .where((item) => '${item['team_id']}' == team)
        .toList()
        .reversed
        .take(10)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BlogPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => openNbaTeamPage(context, team, team),
                child: Text(
                  '$team DAILY',
                  style: const TextStyle(
                    color: _bBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    decoration: TextDecoration.underline,
                    decorationColor: _bBlue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$team news, analysis and intelligence',
                style: const TextStyle(
                  color: _bText,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                record == null
                    ? 'Team publication'
                    : '${record['wins'] ?? '—'}-${record['losses'] ?? '—'} · ${record['points_per_game'] ?? '—'} PPG',
                style: const TextStyle(
                  color: _bAmber,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Team page'),
                    avatar: const Icon(Icons.groups_rounded, size: 16),
                    onPressed: () => openNbaTeamPage(context, team, team),
                  ),
                  const Chip(label: Text('Latest')),
                  const Chip(label: Text('Analysis')),
                  const Chip(label: Text('Transactions')),
                  const Chip(label: Text('Draft')),
                  const Chip(label: Text('Cap & Contracts')),
                  const Chip(label: Text('Newsletter')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _BlogPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BlogTitle('TOP STORIES'),
              const SizedBox(height: 9),
              _Story('$team roster decisions that will define the next phase', 'Front Office Analysis'),
              _Story('What the numbers say about the current rotation', 'Data + Film'),
              _Story('Three questions entering the next stretch of games', 'Beat Report'),
              _Story('Contract, cap and draft-asset notebook', 'Transactions'),
              _Story('How the team is changing possession by possession', 'Advanced Analytics'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final rosterCard = _BlogPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BlogTitle('ROSTER LEADERS'),
                  const SizedBox(height: 8),
                  for (final row in roster.take(12))
                    InkWell(
                      onTap: () =>
                          openNbaPlayerPage(context, row.playerId, row.player),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.player,
                                style: const TextStyle(
                                  color: _bBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${(row.value('pts') ?? 0).toStringAsFixed(1)} PPG',
                              style: const TextStyle(
                                color: _bText,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
            final scheduleCard = _BlogPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BlogTitle('RECENT GAMES'),
                  const SizedBox(height: 8),
                  for (final game in games)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Builder(
                        builder: (context) {
                          final gameId = _firstGameValue(
                            game,
                            const ['game_id', 'gameId', 'id'],
                          );
                          final opponent = _firstGameValue(
                            game,
                            const ['opponent_team_id', 'opponent_team', 'opponent'],
                          );
                          return Row(
                            children: [
                              SizedBox(
                                width: 94,
                                child: Text(
                                  '${game['game_date'] ?? '—'}',
                                  style: const TextStyle(color: _bMuted),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: opponent == '—'
                                      ? null
                                      : () => openNbaTeamPage(
                                            context,
                                            opponent,
                                            opponent,
                                          ),
                                  child: Text(
                                    opponent,
                                    style: TextStyle(
                                      color: opponent == '—' ? _bMuted : _bBlue,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                '${game['result'] ?? ''}',
                                style: const TextStyle(
                                  color: _bText,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (gameId != '—') ...[
                                const SizedBox(width: 5),
                                IconButton(
                                  tooltip: 'Open Game Command Center',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(
                                    Icons.sports_basketball_rounded,
                                    size: 17,
                                    color: _bAmber,
                                  ),
                                  onPressed: () => openNbaGamePage(
                                    context,
                                    gameId: gameId,
                                    gameLabel: '$team vs $opponent',
                                    onOpenTeam: (teamId) =>
                                        openNbaTeamPage(context, teamId, teamId),
                                    onOpenPlayer: (playerId, playerName) =>
                                        openNbaPlayerPage(
                                      context,
                                      playerId,
                                      playerName,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
            if (constraints.maxWidth < 800) {
              return Column(
                children: [
                  rosterCard,
                  const SizedBox(height: 12),
                  scheduleCard,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: rosterCard),
                const SizedBox(width: 12),
                Expanded(child: scheduleCard),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const _BlogPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BlogTitle('PUBLICATION NETWORK'),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PublicationCapability('Live game blogs'),
                  _PublicationCapability('Mailbags & Q&A'),
                  _PublicationCapability('Beat writers'),
                  _PublicationCapability('Podcasts'),
                  _PublicationCapability('Newsletters'),
                  _PublicationCapability('Community threads'),
                  _PublicationCapability('Saved articles'),
                  _PublicationCapability('Push alerts'),
                ],
              ),
              SizedBox(height: 9),
              Text(
                'These publication pages are designed to share one team identity with Stats, Advanced Stats, contracts, transactions, articles and community so editorial context never becomes a disconnected copy of the team record.',
                style: TextStyle(color: _bMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamPublicationCard extends StatelessWidget {
  const _TeamPublicationCard({
    required this.record,
    required this.onOpenPublication,
    required this.onOpenTeam,
  });

  final Map<String, dynamic> record;
  final VoidCallback onOpenPublication;
  final VoidCallback onOpenTeam;

  @override
  Widget build(BuildContext context) => _BlogPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onOpenTeam,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _bPanel2,
                      border: Border.all(color: _bLine),
                    ),
                    child: Text(
                      '${record['team_id']}',
                      style: const TextStyle(
                        color: _bBlue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: onOpenTeam,
                    child: Text(
                      '${record['team_name'] ?? record['team_id']}',
                      style: const TextStyle(
                        color: _bBlue,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                        decorationColor: _bBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${record['wins'] ?? '—'}-${record['losses'] ?? '—'} · dedicated beat, analysis, transactions and fan community',
              style: const TextStyle(color: _bMuted, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onOpenPublication,
                  icon: const Icon(Icons.newspaper_rounded, size: 16),
                  label: const Text('Open publication'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: onOpenTeam,
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: const Text('Team page'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _Story extends StatelessWidget {
  const _Story(this.title, this.section);
  final String title;
  final String section;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _bLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _bText,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              section.toUpperCase(),
              style: const TextStyle(
                color: _bBlue,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _PublicationCapability extends StatelessWidget {
  const _PublicationCapability(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: _bPanel2,
          border: Border.all(color: _bGreen.withValues(alpha: .5)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _bGreen,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _BlogPanel extends StatelessWidget {
  const _BlogPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _bPanel,
          border: Border.all(color: _bLine),
        ),
        child: child,
      );
}

class _BlogTitle extends StatelessWidget {
  const _BlogTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _bText,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      );
}

String _firstGameValue(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = '${row[key] ?? ''}'.trim();
    if (value.isNotEmpty && value != 'null') return value;
  }
  return '—';
}

extension _First<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
