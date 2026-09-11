import 'package:flutter/material.dart';

import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import '../services/nba_complete_draft_asset_repository.dart';
import '../services/nba_team_cap_reference_2026.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_trade_exception_reference_2026.dart';
import '../widgets/terminal_primitives.dart';

class TeamFrontOfficeProfileScreen extends StatefulWidget {
  const TeamFrontOfficeProfileScreen({super.key, required this.teamId});
  final String teamId;

  @override
  State<TeamFrontOfficeProfileScreen> createState() => _TeamFrontOfficeProfileScreenState();
}

class _TeamFrontOfficeProfileScreenState extends State<TeamFrontOfficeProfileScreen> {
  late final Future<_TeamFrontOfficePayload> future = _load();
  int section = 0;

  Future<_TeamFrontOfficePayload> _load() async {
    const assets = NbaAssetRepository();
    final teams = await assets.loadTeams();
    final team = teams.where((t) => t.id == widget.teamId || t.abbreviation == widget.teamId).firstOrNull;
    final abbreviation = team?.abbreviation ?? widget.teamId;
    final contracts = await const NbaTradeContractRepository().load();
    return _TeamFrontOfficePayload(team: team, abbreviation: abbreviation, contracts: contracts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: terminalBackground,
      appBar: AppBar(backgroundColor: terminalBackground, foregroundColor: Colors.white, title: const Text('Team Profile')),
      body: FutureBuilder<_TeamFrontOfficePayload>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: snapshot.hasError
                ? Text('Unable to load team profile: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent))
                : const CircularProgressIndicator(color: terminalAccent));
          }
          final payload = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _body(payload),
          );
        },
      ),
    );
  }

  Widget _body(_TeamFrontOfficePayload payload) {
    final team = payload.team;
    final abbr = payload.abbreviation;
    final ledger = NbaTeamCapReference202627.forTeam(abbr);
    final activeContracts = payload.contracts.forTeam(abbr, '2026-27');
    final activeContractTotal = activeContracts.fold<double>(0, (sum, p) => sum + p.salaryFor('2026-27'));
    final totalCap = ledger?.totalCap ?? activeContractTotal;
    final draft = const NbaCompleteDraftAssetRepository().forTeam(abbr);
    final tpes = NbaTradeExceptionReference202627.forTeam(abbr, asOfIso: '2026-09-11');
    final signing = NbaTradeExceptionReference202627.signingExceptions[abbr] ?? const <String, double>{};

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
        title: team?.name ?? abbr,
        subtitle: 'Team profile and 2026-27 front-office command page: roster contracts, cap table, tax/apron position, exceptions, traded-player exceptions, and future draft capital.',
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 9, runSpacing: 9, children: [
        InfoPill(label: abbr),
        if (team != null) InfoPill(label: team.conference),
        if (team != null) InfoPill(label: team.division),
        InfoPill(label: _tier(totalCap)),
        InfoPill(label: '${activeContracts.length} salary records'),
        InfoPill(label: '${draft.length} future draft interests'),
      ]),
      const SizedBox(height: 20),
      _metrics(totalCap, ledger),
      const SizedBox(height: 18),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Overview'), icon: Icon(Icons.dashboard_outlined)),
          ButtonSegment(value: 1, label: Text('Cap Table'), icon: Icon(Icons.table_chart_outlined)),
          ButtonSegment(value: 2, label: Text('Contracts'), icon: Icon(Icons.people_outline)),
          ButtonSegment(value: 3, label: Text('Draft Capital'), icon: Icon(Icons.sports_basketball_outlined)),
          ButtonSegment(value: 4, label: Text('Exceptions'), icon: Icon(Icons.account_balance_wallet_outlined)),
        ],
        selected: {section},
        showSelectedIcon: false,
        onSelectionChanged: (value) => setState(() => section = value.first),
      ),
      const SizedBox(height: 18),
      if (section == 0) _overview(team, abbr, ledger, activeContracts.length, draft.length, tpes.length),
      if (section == 1) _capTable(ledger, activeContractTotal),
      if (section == 2) _contracts(activeContracts),
      if (section == 3) _draft(draft),
      if (section == 4) _exceptions(signing, tpes, totalCap),
    ]);
  }

  Widget _metrics(double total, NbaTeamCapLedgerEntry? ledger) => Wrap(spacing: 10, runSpacing: 10, children: [
        _metric('Total Cap', _money(total), '2026-27 cap allocation'),
        _metric('Cap Room', _signed(166000000 - total), 'vs. $166.0M cap'),
        _metric('Tax Room', _signed(201690000 - total), 'vs. $201.69M tax'),
        _metric('1st Apron Room', _signed(210690000 - total), 'vs. $210.69M'),
        _metric('2nd Apron Room', _signed(223690000 - total), 'vs. $223.69M'),
        _metric('Hard Cap', (NbaTeamCapReference202627.hardCap[ledger?.team ?? ''] ?? 'None').toUpperCase(), 'modeled ceiling'),
      ]);

  Widget _metric(String label, String value, String note) => SizedBox(width: 190, child: TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: terminalTextMuted, fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(note, style: const TextStyle(color: terminalTextSoft, fontSize: 10)),
      ])));

  Widget _overview(Team? team, String abbr, NbaTeamCapLedgerEntry? ledger, int contracts, int draft, int tpes) => LayoutBuilder(builder: (context, constraints) {
        final identity = TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Team Identity', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _fact('Team', team?.name ?? abbr),
          _fact('Abbreviation', abbr),
          _fact('City', team?.city ?? '—'),
          _fact('Conference', team?.conference ?? '—'),
          _fact('Division', team?.division ?? '—'),
        ]));
        final office = TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Front Office Snapshot', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          _fact('Active contract records', '$contracts'),
          _fact('Future draft interests', '$draft'),
          _fact('Live TPEs', '$tpes'),
          _fact('Hard cap', (NbaTeamCapReference202627.hardCap[abbr] ?? 'None').toUpperCase()),
          _fact('Known cap components', ledger == null ? '—' : _money(ledger.knownComponents)),
        ]));
        if (constraints.maxWidth < 850) return Column(children: [identity, const SizedBox(height: 12), office]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: identity), const SizedBox(width: 12), Expanded(child: office)]);
      });

  Widget _capTable(NbaTeamCapLedgerEntry? ledger, double activeFallback) {
    if (ledger == null) return const TerminalCard(child: Text('No 2026-27 cap ledger is attached to this team.', style: TextStyle(color: terminalTextSoft)));
    final rows = <MapEntry<String, double>>[
      MapEntry('Active salary', ledger.active),
      MapEntry('Dead money', ledger.dead),
      MapEntry('Retained salary', ledger.retained),
      MapEntry('Cap holds', ledger.capHolds),
      MapEntry('Incomplete-roster charges', ledger.incompleteRosterCharges),
      MapEntry('Other / unresolved adjustments', ledger.otherAdjustments),
      MapEntry('Total cap allocation', ledger.totalCap),
    ];
    return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('2026-27 Cap Table', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Unresolved differences stay visible as adjustments instead of being silently forced into dead money, holds, or retained salary.', style: TextStyle(color: terminalTextSoft, fontSize: 11)),
      const SizedBox(height: 12),
      for (final row in rows) _moneyFact(row.key, row.value, bold: row.key == 'Total cap allocation'),
    ]));
  }

  Widget _contracts(List<NbaTradeContract> contracts) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('2026-27 Active Contract Salaries', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        for (final p in contracts) _row(p.player, p.guaranteed == null ? 'Salary record' : 'Guaranteed ${_money(p.guaranteed!)}', _money(p.salaryFor('2026-27'))),
      ]));

  Widget _draft(List<dynamic> draft) => TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Future Draft Capital · 2027-2033', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('Both rounds are normalized. Conditional, swap, protected, frozen, and outgoing obligations remain explicit.', style: TextStyle(color: terminalTextSoft, fontSize: 11)),
        const SizedBox(height: 10),
        for (final p in draft) _row('${p.year} ${p.round == 1 ? '1st' : '2nd'}', '${p.description}${p.frozen ? ' · FROZEN' : ''}${!p.tradable ? ' · NOT CURRENTLY TRADEABLE' : ''}', p.conditional ? 'Conditional' : p.swapRight ? 'Swap' : 'Right'),
      ]));

  Widget _exceptions(Map<String, double> signing, List<NbaTradeExceptionRecord> tpes, double total) => Column(children: [
        TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Signing Exceptions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (signing.isEmpty) const Text('No remaining signing-exception balance is recorded.', style: TextStyle(color: terminalTextSoft)),
          for (final entry in signing.entries) _moneyFact(_exceptionName(entry.key), entry.value),
          const SizedBox(height: 8),
          Text('Room MLE ${_money(NbaMleRules202627.room)} · Non-tax MLE ${_money(NbaMleRules202627.nonTaxpayer)} · Tax MLE ${_money(NbaMleRules202627.taxpayer)}', style: const TextStyle(color: terminalTextSoft, fontSize: 10)),
        ])),
        const SizedBox(height: 12),
        TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Traded Player Exceptions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (tpes.isEmpty) const Text('No unexpired TPE is recorded as of 2026-09-11.', style: TextStyle(color: terminalTextSoft)),
          for (final tpe in tpes) _row(tpe.sourceTransaction, 'Expires ${tpe.expires}${tpe.note == null ? '' : ' · ${tpe.note}'}', _money(tpe.available)),
        ])),
      ]);

  Widget _fact(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: terminalTextMuted))), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]));
  Widget _moneyFact(String label, double value, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: bold ? Colors.white : terminalTextMuted, fontWeight: bold ? FontWeight.w900 : FontWeight.w500))), Text(_money(value), style: TextStyle(color: Colors.white, fontWeight: bold ? FontWeight.w900 : FontWeight.w700))]));
  Widget _row(String title, String subtitle, String trailing) => Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF26384C)))), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), Text(subtitle, style: const TextStyle(color: terminalTextSoft, fontSize: 10))])), const SizedBox(width: 10), Text(trailing, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))]));
}

class _TeamFrontOfficePayload {
  const _TeamFrontOfficePayload({required this.team, required this.abbreviation, required this.contracts});
  final Team? team;
  final String abbreviation;
  final NbaTradeContractSnapshot contracts;
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  if (amount >= 1000000) return '$sign\$${(amount / 1000000).toStringAsFixed(2)}M';
  if (amount >= 1000) return '$sign\$${(amount / 1000).toStringAsFixed(0)}K';
  return '$sign\$${amount.toStringAsFixed(0)}';
}
String _signed(double value) => value >= 0 ? '+${_money(value)}' : _money(value);
String _tier(double total) {
  if (total > 223690000) return 'Second Apron';
  if (total > 210690000) return 'First Apron';
  if (total > 201690000) return 'Tax Team';
  if (total > 166000000) return 'Over Cap';
  return 'Cap Space';
}
String _exceptionName(String key) => switch (key) {
  'room_mle' => 'Room MLE',
  'non_tax_mle' => 'Non-Taxpayer MLE',
  'tax_mle' => 'Taxpayer MLE',
  'bae' => 'Bi-Annual Exception',
  _ => key,
};
