import 'package:flutter/material.dart';

import '../data/community_product_items.dart';
import '../widgets/terminal_primitives.dart';

class CommunityHubScreen extends StatefulWidget {
  const CommunityHubScreen({super.key});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> {
  String selectedSurface = 'Player Discussion';
  String selectedFormat = 'Analysis Post';
  String selectedAudience = 'Public Terminal';

  @override
  Widget build(BuildContext context) {
    final surface = _communitySurfaces.firstWhere((item) => item.name == selectedSurface);
    final format = _contentFormats.firstWhere((item) => item.name == selectedFormat);
    final audience = _audiences.firstWhere((item) => item.name == selectedAudience);
    final p1 = communityProductItems.where((item) => item.priority == 'P1').length;
    final p2 = communityProductItems.where((item) => item.priority == 'P2').length;
    final p3 = communityProductItems.where((item) => item.priority == 'P3').length;
    final future = communityProductItems.where((item) => item.status == 'Future').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader(
        title: 'Community Hub',
        subtitle: 'Data-native community cockpit for entity-linked forums, blog posts, creator workspaces, comments, private rooms, moderation, trust controls, and shareable analysis.',
      ),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: isWide ? 2.0 : 1.5,
          children: [
            _Metric(label: 'Community Capabilities', value: '${communityProductItems.length}', detail: '$p1 P1 / $p2 P2 / $p3 P3'),
            _Metric(label: 'Future Items', value: '$future', detail: 'Requires auth/backend'),
            _Metric(label: 'Surfaces', value: '${_communitySurfaces.length}', detail: 'Entity-linked places'),
            _Metric(label: 'Content Formats', value: '${_contentFormats.length}', detail: 'Posts, threads, rooms'),
          ],
        );
      }),
      const SizedBox(height: 22),
      TerminalCard(child: Wrap(spacing: 12, runSpacing: 12, children: [
        _Picker(label: 'Surface', value: selectedSurface, values: _communitySurfaces.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedSurface = value)),
        _Picker(label: 'Content Format', value: selectedFormat, values: _contentFormats.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedFormat = value)),
        _Picker(label: 'Audience', value: selectedAudience, values: _audiences.map((item) => item.name).toList(), onChanged: (value) => setState(() => selectedAudience = value)),
      ])),
      const SizedBox(height: 22),
      LayoutBuilder(builder: (context, constraints) {
        final left = _CommunityBuildTicket(surface: surface, format: format, audience: audience);
        final right = const _TrustAndModerationPanel();
        if (constraints.maxWidth < 1050) return Column(children: [left, const SizedBox(height: 14), right]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 14), Expanded(child: right)]);
      }),
      const SizedBox(height: 22),
      const _CommunityPipelinePanel(),
      const SizedBox(height: 22),
      _SurfaceMatrix(selectedSurface: selectedSurface),
      const SizedBox(height: 22),
      _ContentFormatMatrix(selectedFormat: selectedFormat),
      const SizedBox(height: 22),
      const _EmbeddedObjectsPanel(),
      const SizedBox(height: 22),
      const _CommunityCapabilityTable(),
    ]);
  }
}

class _CommunitySurface {
  const _CommunitySurface(this.name, this.status, this.attachments, this.primaryUse, this.riskControl);
  final String name;
  final String status;
  final String attachments;
  final String primaryUse;
  final String riskControl;
}

class _ContentFormat {
  const _ContentFormat(this.name, this.status, this.description, this.embeds);
  final String name;
  final String status;
  final String description;
  final String embeds;
}

class _Audience {
  const _Audience(this.name, this.status, this.description, this.permissions);
  final String name;
  final String status;
  final String description;
  final String permissions;
}

const _communitySurfaces = <_CommunitySurface>[
  _CommunitySurface('Player Discussion', 'Future', 'playerId, stats, rosters, awards, transactions', 'Debate player value, role, fantasy outlook, awards, development, and historical comparisons.', 'Entity moderation, claim flags, source labels'),
  _CommunitySurface('Team Room', 'Future', 'teamId, standings, rosters, games, transactions', 'Discuss franchise direction, lineup choices, trades, draft strategy, and team-building history.', 'Team-specific moderation and spam controls'),
  _CommunitySurface('Game Thread', 'Future', 'gameId, teams, box scores, charts, reports', 'Live or historical discussion around matchups, results, game logs, and tactical takeaways.', 'Game status controls and spoiler settings later'),
  _CommunitySurface('Award Race Board', 'Future', 'awardId, seasonId, player stats, standings, voting records', 'Discuss MVP, DPOY, ROY, All-NBA, and other races with source-backed voting and stat embeds.', 'Source-backed claims and ranking context'),
  _CommunitySurface('Draft Class Forum', 'Future', 'draftYear, picks, players, schools, teams', 'Discuss draft classes, prospect outcomes, development paths, and franchise draft history.', 'Prospect/player identity linking'),
  _CommunitySurface('Transaction Thread', 'Future', 'transactionId, players, teams, rosters, contracts later', 'Discuss trades, signings, waivers, team-building moves, and downstream outcomes.', 'Rumor labeling and source distinction'),
  _CommunitySurface('Fantasy Room', 'Future', 'leagueId, roster, scoring rules, player stats, games', 'Private or public fantasy spaces for trades, waivers, projections, matchup planning, and league notes.', 'Private-room permissions and invite controls'),
  _CommunitySurface('Creator Workspace', 'Future', 'saved views, charts, reports, watchlists', 'Analysts and creators publish recurring boards, rankings, dashboards, reports, and notebooks.', 'Creator identity, publishing controls, moderation queue'),
];

const _contentFormats = <_ContentFormat>[
  _ContentFormat('Analysis Post', 'Planned', 'Long-form post that embeds terminal tables, charts, saved views, source citations, and report sections.', 'Tables, charts, saved views, citations, report blocks'),
  _ContentFormat('Forum Thread', 'Future', 'Threaded discussion attached to an entity, event, saved view, fantasy room, or report.', 'Entity cards, quoted rows, source snippets, user comments'),
  _ContentFormat('Quick Take', 'Future', 'Short post for immediate reactions, game notes, transaction thoughts, or fantasy decisions.', 'Entity link, chart snapshot, claim label'),
  _ContentFormat('Notebook', 'Future', 'Structured analysis page combining text, tables, formulas, charts, and assumptions.', 'Workspace blocks, formulas, charts, audit trail'),
  _ContentFormat('Poll / Ranking', 'Future', 'Community voting format for award races, rankings, trade evaluations, fantasy choices, and debates.', 'Players, teams, ranking lists, saved views'),
  _ContentFormat('Private Room Note', 'Future', 'Private group note for fantasy leagues, scouting groups, analyst teams, or internal dashboards.', 'Group permission, workspace state, comments'),
];

const _audiences = <_Audience>[
  _Audience('Public Terminal', 'Future', 'Visible to all users with moderation and source labeling.', 'Public read, moderated write'),
  _Audience('Followers', 'Future', 'Visible to users following a creator, team, player, topic, or workspace.', 'Follower-gated read/write rules'),
  _Audience('Private Group', 'Future', 'Visible only to invited groups such as fantasy leagues, scouting circles, or analyst workspaces.', 'Invite-only membership and role permissions'),
  _Audience('Personal Draft', 'Planned', 'Private draft attached to a user workspace before publishing.', 'Single-user local or account-backed draft state'),
  _Audience('Admin / Moderation', 'Required Before Launch', 'Internal queue for reviewing reported posts, flagged claims, spam, and abuse.', 'Admin-only access with audit trail'),
];

class _CommunityBuildTicket extends StatelessWidget {
  const _CommunityBuildTicket({required this.surface, required this.format, required this.audience});
  final _CommunitySurface surface;
  final _ContentFormat format;
  final _Audience audience;

  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Community Build Ticket', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    const SizedBox(height: 14),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: surface.status), InfoPill(label: format.status), InfoPill(label: audience.status)]),
    const SizedBox(height: 16),
    _DetailLine(label: 'Surface', value: '${surface.name}: ${surface.primaryUse}'),
    _DetailLine(label: 'Attachments', value: surface.attachments),
    _DetailLine(label: 'Format', value: '${format.name}: ${format.description}'),
    _DetailLine(label: 'Embeds', value: format.embeds),
    _DetailLine(label: 'Audience', value: '${audience.name}: ${audience.description}'),
    _DetailLine(label: 'Permissions', value: audience.permissions),
    _DetailLine(label: 'Risk Control', value: surface.riskControl),
  ]));
}

class _TrustAndModerationPanel extends StatelessWidget {
  const _TrustAndModerationPanel();

  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Trust + Moderation Gate', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 12),
    Text('Community features should not launch publicly until accounts, permissions, moderation queues, spam controls, report abuse, source labels, and claim flags exist. The correct first step is designing entity-linked content and private drafts before open posting.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    SizedBox(height: 16),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Accounts required'), InfoPill(label: 'Moderation required'), InfoPill(label: 'Source labels'), InfoPill(label: 'Claim flags'), InfoPill(label: 'Report abuse'), InfoPill(label: 'Private drafts first')]),
  ]));
}

class _CommunityPipelinePanel extends StatelessWidget {
  const _CommunityPipelinePanel();

  @override
  Widget build(BuildContext context) {
    final steps = ['Attach entity', 'Choose format', 'Embed data', 'Add source labels', 'Set audience', 'Moderate', 'Publish', 'Discuss and save'];
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Community Publishing Pipeline', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < steps.length; i++) InfoPill(label: '${i + 1}. ${steps[i]}')]),
    ]));
  }
}

class _SurfaceMatrix extends StatelessWidget {
  const _SurfaceMatrix({required this.selectedSurface});
  final String selectedSurface;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Entity-Linked Surface Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('Surface')), DataColumn(label: Text('Status')), DataColumn(label: Text('Attachments')), DataColumn(label: Text('Primary Use')), DataColumn(label: Text('Risk Control'))],
      rows: [for (final surface in _communitySurfaces) DataRow(selected: surface.name == selectedSurface, cells: [DataCell(SizedBox(width: 210, child: Text(surface.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: surface.status)), DataCell(SizedBox(width: 360, child: Text(surface.attachments))), DataCell(SizedBox(width: 520, child: Text(surface.primaryUse))), DataCell(SizedBox(width: 360, child: Text(surface.riskControl)))])],
    )),
  ]));
}

class _ContentFormatMatrix extends StatelessWidget {
  const _ContentFormatMatrix({required this.selectedFormat});
  final String selectedFormat;

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Content Format Matrix', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('Format')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Embedded Objects'))],
      rows: [for (final format in _contentFormats) DataRow(selected: format.name == selectedFormat, cells: [DataCell(SizedBox(width: 210, child: Text(format.name, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(InfoPill(label: format.status)), DataCell(SizedBox(width: 620, child: Text(format.description))), DataCell(SizedBox(width: 520, child: Text(format.embeds)))])],
    )),
  ]));
}

class _EmbeddedObjectsPanel extends StatelessWidget {
  const _EmbeddedObjectsPanel();

  @override
  Widget build(BuildContext context) => const TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Embeddable Terminal Objects', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    SizedBox(height: 12),
    Text('The community layer should reuse terminal objects rather than inventing generic posts. A post should be able to embed a player card, team table, stat chart, fantasy board, report block, saved view, source citation, transaction timeline, award race board, or workspace formula.', style: TextStyle(color: terminalTextSoft, height: 1.45)),
    SizedBox(height: 16),
    Wrap(spacing: 10, runSpacing: 10, children: [InfoPill(label: 'Player cards'), InfoPill(label: 'Team tables'), InfoPill(label: 'Charts'), InfoPill(label: 'Fantasy boards'), InfoPill(label: 'Report blocks'), InfoPill(label: 'Saved views'), InfoPill(label: 'Source citations'), InfoPill(label: 'Award boards'), InfoPill(label: 'Transaction timelines')]),
  ]));
}

class _CommunityCapabilityTable extends StatelessWidget {
  const _CommunityCapabilityTable();

  @override
  Widget build(BuildContext context) => TerminalCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.all(18), child: Text('Community Capability Roadmap', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
    const Divider(height: 1, color: terminalBorder),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
      headingRowColor: WidgetStateProperty.all(terminalPanelDark),
      headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w700),
      dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
      columnSpacing: 30,
      columns: const [DataColumn(label: Text('Priority')), DataColumn(label: Text('Capability')), DataColumn(label: Text('Category')), DataColumn(label: Text('Status')), DataColumn(label: Text('Description')), DataColumn(label: Text('Next Step'))],
      rows: [for (final item in communityProductItems) DataRow(cells: [DataCell(Text(item.priority, style: const TextStyle(fontWeight: FontWeight.w900))), DataCell(SizedBox(width: 260, child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)))), DataCell(SizedBox(width: 180, child: Text(item.category))), DataCell(InfoPill(label: item.status)), DataCell(SizedBox(width: 620, child: Text(item.description))), DataCell(SizedBox(width: 480, child: Text(item.nextStep)))])],
    )),
  ]));
}

class _Picker extends StatelessWidget {
  const _Picker({required this.label, required this.value, required this.values, required this.onChanged});
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(width: 280, child: DropdownButtonFormField<String>(
    value: value,
    dropdownColor: terminalPanelDark,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))),
    items: values.map((item) => DropdownMenuItem(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
    onChanged: (value) { if (value != null) onChanged(value); },
  ));
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 12, fontWeight: FontWeight.w800))), Expanded(child: Text(value, style: const TextStyle(color: terminalTextSoft, height: 1.3)))]));
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail});
  final String label;
  final String value;
  final String detail;
  @override
  Widget build(BuildContext context) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 13)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)), Text(detail, style: const TextStyle(color: terminalAccent, fontSize: 12))]));
}
