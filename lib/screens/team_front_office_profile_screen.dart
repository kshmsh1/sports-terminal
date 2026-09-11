import 'package:flutter/material.dart';

import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import '../services/nba_complete_draft_asset_repository.dart';
import '../services/nba_future_draft_asset_repository.dart';
import '../services/nba_team_cap_reference_2026.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_trade_exception_reference_2026.dart';
import '../widgets/terminal_primitives.dart';

class TeamFrontOfficeProfileScreen extends StatefulWidget {
  const TeamFrontOfficeProfileScreen({super.key, required this.teamId});

  final String teamId;

  @override
  State<TeamFrontOfficeProfileScreen> createState() =>
      _TeamFrontOfficeProfileScreenState();
}

class _TeamFrontOfficeProfileScreenState
    extends State<TeamFrontOfficeProfileScreen> {
  late final Future<_TeamFrontOfficePayload> future = _load();
  int selectedTab = 0;

  Future<_TeamFrontOfficePayload> _load() async {
    final teams = await const NbaAssetRepository().loadTeams();
    Team? team;
    for (final candidate in teams) {
      if (candidate.id == widget.teamId ||
          candidate.abbreviation == widget.teamId) {
        team = candidate;
        break;
      }
    }
    final abbreviation = team?.abbreviation ?? widget.teamId;
    final contracts = await const NbaTradeContractRepository().load();
    return _TeamFrontOfficePayload(
      team: team,
      abbreviation: abbreviation,
      contracts: contracts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: terminalBackground,
      appBar: AppBar(
        backgroundColor: terminalBackground,
        foregroundColor: Colors.white,
        title: const Text('Team Profile'),
      ),
      body: FutureBuilder<_TeamFrontOfficePayload>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Text(
                      'Unable to load team profile: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    )
                  : const CircularProgressIndicator(color: terminalAccent),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _content(snapshot.data!),
          );
        },
      ),
    );
  }

  Widget _content(_TeamFrontOfficePayload payload) {
    final team = payload.team;
    final abbreviation = payload.abbreviation;
    final contracts = payload.contracts.forTeam(abbreviation, '2026-27');
    final activeSalary = contracts.fold<double>(
      0,
      (sum, contract) => sum + contract.salaryFor('2026-27'),
    );
    final ledger = NbaTeamCapReference202627.forTeam(abbreviation);
    final totalCap = ledger?.totalCap ?? activeSalary;
    final draftAssets =
        const NbaCompleteDraftAssetRepository().forTeam(abbreviation);
    final tpes = NbaTradeExceptionReference202627.forTeam(
      abbreviation,
      asOfIso: '2026-09-11',
    );
    final signing =
        NbaTradeExceptionReference202627.signingExceptions[abbreviation] ??
            const <String, double>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: team?.name ?? abbreviation,
          subtitle:
              'Team profile and 2026-27 front-office command page with cap table, contracts, future draft rights, and exception inventory.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InfoPill(label: abbreviation),
            if (team != null) InfoPill(label: team.conference),
            if (team != null) InfoPill(label: team.division),
            InfoPill(label: _tier(totalCap)),
            InfoPill(label: '${contracts.length} contracts'),
            InfoPill(label: '${draftAssets.length} draft interests'),
            InfoPill(label: '${tpes.length} live TPEs'),
          ],
        ),
        const SizedBox(height: 18),
        _metricGrid(abbreviation, totalCap),
        const SizedBox(height: 18),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Overview'),
              icon: Icon(Icons.dashboard_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Cap Table'),
              icon: Icon(Icons.table_chart_outlined),
            ),
            ButtonSegment(
              value: 2,
              label: Text('Contracts'),
              icon: Icon(Icons.people_outline),
            ),
            ButtonSegment(
              value: 3,
              label: Text('Draft Capital'),
              icon: Icon(Icons.sports_basketball_outlined),
            ),
            ButtonSegment(
              value: 4,
              label: Text('Exceptions'),
              icon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ],
          selected: {selectedTab},
          showSelectedIcon: false,
          onSelectionChanged: (values) {
            setState(() => selectedTab = values.first);
          },
        ),
        const SizedBox(height: 18),
        if (selectedTab == 0)
          _overview(
            team,
            abbreviation,
            ledger,
            contracts.length,
            draftAssets.length,
            tpes.length,
          ),
        if (selectedTab == 1) _capTable(ledger, activeSalary),
        if (selectedTab == 2) _contracts(contracts),
        if (selectedTab == 3) _draftCapital(draftAssets),
        if (selectedTab == 4) _exceptions(signing, tpes),
      ],
    );
  }

  Widget _metricGrid(String team, double totalCap) {
    final values = <_FrontOfficeMetric>[
      _FrontOfficeMetric('Total Cap', _money(totalCap), '2026-27 allocation'),
      _FrontOfficeMetric(
        'Cap Room',
        _signed(166000000 - totalCap),
        'vs. \$166.0M cap',
      ),
      _FrontOfficeMetric(
        'Tax Room',
        _signed(201690000 - totalCap),
        'vs. \$201.69M tax',
      ),
      _FrontOfficeMetric(
        '1st Apron Room',
        _signed(210690000 - totalCap),
        'vs. \$210.69M',
      ),
      _FrontOfficeMetric(
        '2nd Apron Room',
        _signed(223690000 - totalCap),
        'vs. \$223.69M',
      ),
      _FrontOfficeMetric(
        'Hard Cap',
        (NbaTeamCapReference202627.hardCap[team] ?? 'None').toUpperCase(),
        'modeled ceiling',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 20) / 3
            : constraints.maxWidth >= 520
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final value in values)
              SizedBox(width: width, child: _metricCard(value)),
          ],
        );
      },
    );
  }

  Widget _metricCard(_FrontOfficeMetric metric) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: const TextStyle(
              color: terminalTextMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            metric.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            metric.note,
            style: const TextStyle(color: terminalTextSoft, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _overview(
    Team? team,
    String abbreviation,
    NbaTeamCapLedgerEntry? ledger,
    int contractCount,
    int draftCount,
    int tpeCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final identity = TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Team Identity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _fact('Team', team?.name ?? abbreviation),
              _fact('Abbreviation', abbreviation),
              _fact('City', team?.city ?? '—'),
              _fact('Conference', team?.conference ?? '—'),
              _fact('Division', team?.division ?? '—'),
            ],
          ),
        );
        final frontOffice = TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Front Office Snapshot',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _fact('Active contract records', '$contractCount'),
              _fact('Future draft interests', '$draftCount'),
              _fact('Live TPEs', '$tpeCount'),
              _fact(
                'Hard cap',
                (NbaTeamCapReference202627.hardCap[abbreviation] ?? 'None')
                    .toUpperCase(),
              ),
              _fact(
                'Known cap components',
                ledger == null ? '—' : _money(ledger.knownComponents),
              ),
            ],
          ),
        );
        if (constraints.maxWidth < 850) {
          return Column(
            children: [
              identity,
              const SizedBox(height: 12),
              frontOffice,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identity),
            const SizedBox(width: 12),
            Expanded(child: frontOffice),
          ],
        );
      },
    );
  }

  Widget _capTable(NbaTeamCapLedgerEntry? ledger, double activeFallback) {
    if (ledger == null) {
      return TerminalCard(
        child: _moneyFact('Active salary fallback', activeFallback),
      );
    }
    final rows = <MapEntry<String, double>>[
      MapEntry('Active salary', ledger.active),
      MapEntry('Dead money', ledger.dead),
      MapEntry('Retained salary', ledger.retained),
      MapEntry('Cap holds', ledger.capHolds),
      MapEntry('Incomplete-roster charges', ledger.incompleteRosterCharges),
      MapEntry('Other / unresolved adjustments', ledger.otherAdjustments),
      MapEntry('Total cap allocation', ledger.totalCap),
    ];
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2026-27 Cap Table',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Unresolved accounting differences remain visible as adjustments rather than being silently forced into dead money, retained salary, or cap holds.',
            style: TextStyle(color: terminalTextSoft, fontSize: 11),
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            _moneyFact(
              row.key,
              row.value,
              bold: row.key == 'Total cap allocation',
            ),
        ],
      ),
    );
  }

  Widget _contracts(List<NbaTradeContract> contracts) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2026-27 Active Contract Salaries',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          for (final contract in contracts)
            _row(
              contract.player,
              contract.guaranteed == null
                  ? 'Salary record'
                  : 'Guaranteed ${_money(contract.guaranteed!)}',
              _money(contract.salaryFor('2026-27')),
            ),
        ],
      ),
    );
  }

  Widget _draftCapital(List<NbaFutureDraftAsset> assets) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Future Draft Capital · 2027-2033',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Both rounds are normalized. Conditional, swap, protected, frozen, and outgoing obligations remain explicit rather than being flattened into generic picks.',
            style: TextStyle(color: terminalTextSoft, fontSize: 11),
          ),
          const SizedBox(height: 10),
          for (final asset in assets)
            _row(
              '${asset.year} ${asset.round == 1 ? '1st' : '2nd'}',
              '${asset.description}${asset.frozen ? ' · FROZEN' : ''}${!asset.tradable ? ' · NOT CURRENTLY TRADEABLE' : ''}',
              asset.swapRight
                  ? 'Swap'
                  : asset.conditional
                      ? 'Conditional'
                      : 'Right',
            ),
        ],
      ),
    );
  }

  Widget _exceptions(
    Map<String, double> signing,
    List<NbaTradeExceptionRecord> tpes,
  ) {
    return Column(
      children: [
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Signing Exceptions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (signing.isEmpty)
                const Text(
                  'No remaining signing-exception balance is recorded.',
                  style: TextStyle(color: terminalTextSoft),
                ),
              for (final entry in signing.entries)
                _moneyFact(_exceptionName(entry.key), entry.value),
              const SizedBox(height: 8),
              Text(
                'Room MLE ${_money(NbaMleRules202627.room)} · Non-tax MLE ${_money(NbaMleRules202627.nonTaxpayer)} · Tax MLE ${_money(NbaMleRules202627.taxpayer)} · BAE ${_money(NbaMleRules202627.biAnnual)}',
                style: const TextStyle(
                  color: terminalTextSoft,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Traded Player Exceptions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              if (tpes.isEmpty)
                const Text(
                  'No unexpired TPE is recorded as of 2026-09-11.',
                  style: TextStyle(color: terminalTextSoft),
                ),
              for (final tpe in tpes)
                _row(
                  tpe.sourceTransaction,
                  'Expires ${tpe.expires}${tpe.note == null ? '' : ' · ${tpe.note}'}',
                  _money(tpe.available),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: terminalTextMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyFact(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? Colors.white : terminalTextMuted,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              color: Colors.white,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String subtitle, String trailing) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF26384C))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: terminalTextSoft,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamFrontOfficePayload {
  const _TeamFrontOfficePayload({
    required this.team,
    required this.abbreviation,
    required this.contracts,
  });

  final Team? team;
  final String abbreviation;
  final NbaTradeContractSnapshot contracts;
}

class _FrontOfficeMetric {
  const _FrontOfficeMetric(this.label, this.value, this.note);

  final String label;
  final String value;
  final String note;
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  if (amount >= 1000000) {
    return '$sign\$${(amount / 1000000).toStringAsFixed(2)}M';
  }
  if (amount >= 1000) {
    return '$sign\$${(amount / 1000).toStringAsFixed(0)}K';
  }
  return '$sign\$${amount.toStringAsFixed(0)}';
}

String _signed(double value) => value >= 0 ? '+${_money(value)}' : _money(value);

String _tier(double totalCap) {
  if (totalCap > 223690000) return 'Second Apron';
  if (totalCap > 210690000) return 'First Apron';
  if (totalCap > 201690000) return 'Tax Team';
  if (totalCap > 166000000) return 'Over Cap';
  return 'Cap Space';
}

String _exceptionName(String key) {
  return switch (key) {
    'room_mle' => 'Room MLE',
    'non_tax_mle' => 'Non-Taxpayer MLE',
    'tax_mle' => 'Taxpayer MLE',
    'bae' => 'Bi-Annual Exception',
    _ => key,
  };
}
