import 'package:flutter/material.dart';

import '../services/nba_complete_draft_asset_repository.dart';
import '../services/nba_contract_status_reference_2026.dart';
import '../services/nba_front_office_tracker_2026.dart';
import '../services/nba_league_environment_2026.dart';
import '../services/nba_transaction_history_2026.dart';
import '../services/nba_two_way_contract_reference_2026.dart';
import '../services/nba_future_draft_asset_repository.dart';
import '../services/nba_team_cap_reference_2026.dart';
import '../services/nba_team_salary_position_2026.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_trade_exception_reference_2026.dart';
import '../services/nba_trade_kicker_reference_2026.dart';
import '../services/trade_machine_engine.dart';

const _bg = Color(0xFF08111D);
const _panel = Color(0xFF0D1927);
const _panel2 = Color(0xFF122235);
const _line = Color(0xFF20364D);
const _text = Color(0xFFF4F7FB);
const _muted = Color(0xFF91A2B5);
const _blue = Color(0xFF62A9FF);
const _cyan = Color(0xFF58D6D1);
const _green = Color(0xFF65D19E);
const _amber = Color(0xFFF2C66D);
const _red = Color(0xFFFF7C83);

const _cap = 164961000.0;
const _tax = 200428000.0;
const _first = 209015000.0;
const _second = 221686000.0;

class ProductTradeMachineCompleteScreen extends StatefulWidget {
  const ProductTradeMachineCompleteScreen({super.key});

  @override
  State<ProductTradeMachineCompleteScreen> createState() =>
      _ProductTradeMachineCompleteScreenState();
}

class _ProductTradeMachineCompleteScreenState
    extends State<ProductTradeMachineCompleteScreen> {
  final contractRepository = const NbaTradeContractRepository();
  final draftRepository = const NbaCompleteDraftAssetRepository();
  final engine = const TradeMachineEngine();

  late final Future<NbaTradeContractSnapshot> future = contractRepository.load();
  final routes = <String, String>{};
  final searches = <String, String>{};
  final tabs = <String, int>{};
  final selectedTpeByTeam = <String, String>{};
  final cashAmounts = <String, double>{};
  final cashDestinations = <String, String>{};

  List<String> teams = ['BOS', 'PHI'];
  DateTime tradeDate = DateTime(2026, 9, 11);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTradeContractSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            color: _bg,
            alignment: Alignment.center,
            child: snapshot.hasError
                ? Text(
                    'Unable to load trade data: ${snapshot.error}',
                    style: const TextStyle(color: _red),
                  )
                : const CircularProgressIndicator(),
          );
        }

        final data = snapshot.data!;
        final allDraftAssets = draftRepository.all();
        _repairTeams(data.teams);
        _repairSelections(data, allDraftAssets);

        final scenario = _scenario(data, allDraftAssets);
        final report = _applyTpeValidation(engine.validate(scenario), scenario);

        return Container(
          color: _bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _topBar(data),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 1120
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final team in teams)
                        SizedBox(width: width, child: _teamBoard(data, team, report)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _tradeResult(report),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(NbaTradeContractSnapshot data) {
    final available = data.teams.where((team) => !teams.contains(team)).toList();
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NBA Trade Machine',
                style: TextStyle(color: _text, fontSize: 30, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3),
              Text(
                'Build the deal first. The cap rules update as you go.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.calendar_today_rounded, size: 15),
          label: Text(_displayDate(tradeDate)),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: tradeDate,
              firstDate: DateTime(2026, 7, 1),
              lastDate: DateTime(2033, 6, 30),
            );
            if (picked != null && mounted) setState(() => tradeDate = picked);
          },
        ),
        const SizedBox(width: 8),
        if (teams.length < 5)
          PopupMenuButton<String>(
            onSelected: (team) => setState(() => teams = [...teams, team]),
            itemBuilder: (_) => [
              for (final team in available)
                PopupMenuItem(value: team, child: Text(team)),
            ],
            child: const Chip(
              avatar: Icon(Icons.add_rounded, size: 15),
              label: Text('Add team'),
            ),
          ),
        const SizedBox(width: 8),
        ActionChip(
          avatar: const Icon(Icons.restart_alt_rounded, size: 15),
          label: const Text('Reset'),
          onPressed: () {
            setState(() {
              routes.clear();
              selectedTpeByTeam.clear();
              cashAmounts.clear();
              cashDestinations.clear();
              searches.clear();
            });
          },
        ),
      ],
    );
  }
  Widget _teamBoard(NbaTradeContractSnapshot data, String team, TradeValidationReport report) {
    final activeSalary = data.payroll(team, '2026-27');
    final ledger = NbaTeamCapReference202627.forTeam(team);
    final salaryPosition = NbaTeamSalaryPosition202627.forTeam(team);
    final totalCap = salaryPosition?.totalSalary ?? ledger?.totalCap ?? activeSalary;
    final tab = tabs[team] ?? 0;
    final summary = report.teamSummaries[team];
    final outgoingPlayers = data.records.where((player) => player.team == team && routes[player.id] != null).toList();
    final outgoingPicks = draftRepository.forTeam(team).where((asset) => routes[asset.id] != null).toList();

    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _blue),
                  color: _panel2,
                ),
                child: Text(
                  team,
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${_money(totalCap)} current salary · ${_money(salaryPosition?.guaranteed ?? ledger?.active ?? activeSalary)} guaranteed',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              _pill(_tier(totalCap), _tierColor(totalCap)),
            ],
          ),
          const SizedBox(height: 10),
          _packagePanel(outgoingPlayers, outgoingPicks, summary, team),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Players'),
                icon: Icon(Icons.person_rounded, size: 15),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Picks'),
                icon: Icon(Icons.sports_basketball_rounded, size: 15),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Cash / Exceptions'),
                icon: Icon(Icons.account_balance_wallet_rounded, size: 15),
              ),
              ButtonSegment(
                value: 3,
                label: Text('Cap'),
                icon: Icon(Icons.table_chart_rounded, size: 15),
              ),
            ],
            selected: {tab},
            showSelectedIcon: false,
            onSelectionChanged: (values) {
              setState(() => tabs[team] = values.first);
            },
          ),
          const SizedBox(height: 10),
          if (tab == 0) _playersTab(data, team),
          if (tab == 1) _draftTab(team),
          if (tab == 2) _exceptionsTab(team, totalCap),
          if (tab == 3) _capTableTab(ledger, activeSalary),
        ],
      ),
    );
  }

  Widget _playersTab(NbaTradeContractSnapshot data, String team) {
    final query = (searches[team] ?? '').trim().toLowerCase();
    var players = data.forTeam(team, '2026-27').where(
          (player) => query.isEmpty || player.player.toLowerCase().contains(query),
        );

    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => searches[team] = value),
          style: const TextStyle(color: _text),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
            hintText: 'Search roster',
          ),
        ),
        const SizedBox(height: 6),
        for (final player in players)
          Builder(
            builder: (_) {
              final kicker =
                  NbaTradeKickerReference202627.forPlayer(player.player);
              final restriction = _tradeRestrictionFor(player.player);
              final partial =
                  NbaContractStatusReference202627.partiallyGuaranteed[player.player];
              final acquired =
                  NbaTransactionHistory2026.mostRecentAcquisitionDate(player.player);
              return _assetRow(
                title: player.player,
                subtitle: [
                  if (partial != null)
                    'Protected ${_money(partial)}'
                  else if (player.guaranteed != null)
                    'Guaranteed ${_money(player.guaranteed!)}'
                  else
                    '2026-27 contract',
                  if (acquired != null) 'Acquired $acquired',
                  if (restriction != null)
                    'Trade eligible ${restriction.eligibleDate}',
                ].join(' · '),
                trailing: _money(player.salaryFor('2026-27')),
                badges: [
                  if (kicker != null)
                    _pill(_kickerLabel(kicker), _kickerColor(kicker)),
                  if (restriction != null &&
                      tradeDate.isBefore(DateTime.parse(restriction.eligibleDate)))
                    _pill('LOCKED', _red),
                  if (restriction?.hasTradeVeto == true)
                    _pill('CONSENT', _amber),
                ],
                control: IconButton(
                  tooltip: routes[player.id] != null ? 'Remove from trade' : 'Add to trade',
                  onPressed: restriction != null &&
                          tradeDate.isBefore(DateTime.parse(restriction.eligibleDate))
                      ? null
                      : () => setState(() {
                            if (routes[player.id] != null) {
                              routes.remove(player.id);
                            } else {
                              final destination = _defaultDestination(team);
                              if (destination != null) routes[player.id] = destination;
                            }
                          }),
                  icon: Icon(
                    routes[player.id] != null
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: routes[player.id] != null ? _green : _cyan,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _draftTab(String team) {
    var assets = draftRepository.forTeam(team);

    return Column(
      children: [
        for (final asset in assets)
          _assetRow(
            title: '${asset.year} · ${asset.round == 1 ? '1st' : '2nd'}',
            subtitle: asset.description,
            badges: [
              if (asset.frozen) _pill('FROZEN', _red),
              if (!asset.tradable && !asset.frozen)
                _pill('OUT / UNAVAILABLE', _muted),
              if (asset.swapRight) _pill('SWAP', _cyan),
              if (asset.conditional) _pill('CONDITIONAL', _amber),
            ],
            control: asset.tradable
                ? IconButton(
                    tooltip: routes[asset.id] != null ? 'Remove from trade' : 'Add to trade',
                    onPressed: () => setState(() {
                      if (routes[asset.id] != null) {
                        routes.remove(asset.id);
                      } else {
                        final destination = _defaultDestination(team);
                        if (destination != null) routes[asset.id] = destination;
                      }
                    }),
                    icon: Icon(
                      routes[asset.id] != null
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      color: routes[asset.id] != null ? _green : _cyan,
                    ),
                  )
                : null,
          ),
        if (assets.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'No draft rights under the current filter.',
              style: TextStyle(color: _muted),
            ),
          ),
      ],
    );
  }

  Widget _packagePanel(
    List<NbaTradeContract> players,
    List<NbaFutureDraftAsset> picks,
    TradeTeamSummary? summary,
    String team,
  ) {
    final cash = cashAmounts[team] ?? 0;
    final hasAssets = players.isNotEmpty || picks.isNotEmpty || cash > 0;
    final incoming = summary?.incomingSalary ?? 0;
    final outgoing = summary?.outgoingSalary ?? 0;
    final maxIncoming = summary?.maximumIncomingSalary ?? 0;
    final difference = incoming - maxIncoming;
    final matchingOk = !_hasTradeActivity || difference <= 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OUTGOING PACKAGE', style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 8),
          if (!hasAssets)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Select players or picks below.', style: TextStyle(color: _muted, fontSize: 11)),
            ),
          for (final player in players)
            _selectedAsset(player.player, _money(player.salaryFor('2026-27')), () => setState(() => routes.remove(player.id))),
          for (final pick in picks)
            _selectedAsset(pick.label, 'Draft asset', () => setState(() => routes.remove(pick.id))),
          if (cash > 0)
            _selectedAsset('Cash considerations', _money(cash), () => setState(() { cashAmounts.remove(team); cashDestinations.remove(team); })),
          const SizedBox(height: 8),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 9),
          Row(children: [
            Expanded(child: _metric('Sending', _money(outgoing))),
            Expanded(child: _metric('Receiving', _money(incoming))),
            Expanded(child: _metric('Max incoming', _money(maxIncoming))),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            Icon(matchingOk ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 16, color: matchingOk ? _green : _red),
            const SizedBox(width: 6),
            Expanded(child: Text(
              !_hasTradeActivity ? 'Add assets to begin salary matching.' : matchingOk ? 'Salary matching works for this team.' : _money(difference) + ' too much incoming salary.',
              style: TextStyle(color: matchingOk ? _green : _red, fontSize: 10, fontWeight: FontWeight.w800),
            )),
          ]),
        ],
      ),
    );
  }

  Widget _selectedAsset(String label, String trailing, VoidCallback remove) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(9), border: Border.all(color: _line)),
      child: Row(children: [
        const Icon(Icons.swap_horiz_rounded, color: _cyan, size: 16),
        const SizedBox(width: 7),
        Expanded(child: Text(label, style: const TextStyle(color: _text, fontWeight: FontWeight.w800))),
        Text(trailing, style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w800)),
        IconButton(visualDensity: VisualDensity.compact, tooltip: 'Remove', onPressed: remove, icon: const Icon(Icons.close_rounded, size: 16)),
      ]),
    );
  }

  Widget _metric(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 12)),
      Text(label, style: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w800)),
    ]);
  }

  String? _defaultDestination(String originTeam) => teams.where((team) => team != originTeam).firstOrNull;
  Widget _exceptionsTab(String team, double totalCap) {
    final signing =
        NbaTradeExceptionReference202627.signingExceptions[team] ??
            const <String, double>{};
    final tpes = NbaTradeExceptionReference202627.forTeam(
      team,
      asOfIso: _dateIso(tradeDate),
    );

    final dpe = NbaFrontOfficeTracker202627.dpe[team];
    final cash = NbaCashTradeReference202627.teams[team];
    final hardCap = NbaFrontOfficeTracker202627.hardCaps[team];
    final tax = NbaFrontOfficeTracker202627.luxuryTax[team];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            if (cash != null)
              _mini(_money(cash.availableToSend), 'CASH TO SEND'),
            if (cash != null)
              _mini(_money(cash.availableToReceive), 'CASH TO RECEIVE'),
            if (tax != null)
              _mini(
                _money(tax.estimatedTax),
                tax.repeater ? 'EST. TAX · REPEATER' : 'EST. TAX',
              ),
            if (hardCap != null)
              _mini(hardCap.capLevel.toUpperCase(), 'HARD CAP'),
          ],
        ),
        if (hardCap != null) ...[
          const SizedBox(height: 8),
          Text(
            [...hardCap.firstApronTriggers, ...hardCap.secondApronTriggers]
                .join(' · '),
            style: const TextStyle(color: _muted, fontSize: 9, height: 1.35),
          ),
        ],
        if (dpe != null) ...[
          const SizedBox(height: 8),
          _assetRow(
            title: 'Disabled Player Exception · ${dpe.player}',
            subtitle: 'Available acquisition mechanism; not outgoing trade salary.',
            trailing: _money(dpe.available),
            badges: [_pill('DPE', _cyan)],
          ),
        ],
        const SizedBox(height: 10),
        _cashTradeControl(team, cash),
        const SizedBox(height: 10),
        if (signing.isNotEmpty) ...[
          const Text(
            'SIGNING EXCEPTIONS',
            style: TextStyle(
              color: _cyan,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          for (final entry in signing.entries)
            _assetRow(
              title: _exceptionName(entry.key),
              subtitle: _exceptionRule(entry.key, totalCap),
              trailing: _money(entry.value),
            ),
          const SizedBox(height: 8),
        ],
        const Text(
          'TRADED PLAYER EXCEPTIONS',
          style: TextStyle(
            color: _cyan,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        if (tpes.isEmpty)
          const Text(
            'No unexpired, unused TPE is recorded for this team on the selected trade date.',
            style: TextStyle(color: _muted),
          ),
        for (final tpe in tpes)
          _assetRow(
            title: tpe.sourceTransaction,
            subtitle:
                'Expires ${tpe.expires}${tpe.note == null ? '' : ' · ${tpe.note}'}',
            trailing: _money(tpe.available),
            badges: [
              if (tpe.original != tpe.available)
                _pill('PARTIALLY USED', _amber),
              if (tpe.unusableAboveSecondApron)
                _pill('2ND APRON RESTRICTED', _red),
            ],
            control: Radio<String>(
              value: tpe.id,
              groupValue: selectedTpeByTeam[team],
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedTpeByTeam[team] = value);
                }
              },
            ),
          ),
        if (selectedTpeByTeam[team] != null)
          TextButton.icon(
            onPressed: () => setState(() => selectedTpeByTeam.remove(team)),
            icon: const Icon(Icons.close),
            label: const Text('Do not use a TPE'),
          ),
        const Text(
          'A TPE is an acquisition mechanism for the team using it; it is not transferred to another team. MLE and BAE balances are signing tools and do not count as outgoing trade salary.',
          style: TextStyle(color: _muted, fontSize: 9, height: 1.35),
        ),
      ],
    );
  }

  Widget _capTableTab(NbaTeamCapLedgerEntry? ledger, double activeFallback) {
    if (ledger == null) {
      return _assetRow(
        title: 'Active salary',
        subtitle: 'Fallback from contract roster',
        trailing: _money(activeFallback),
      );
    }
    final rows = <MapEntry<String, double>>[
      MapEntry('Active salary', ledger.active),
      MapEntry('Dead money', ledger.dead),
      MapEntry('Retained salary', ledger.retained),
      MapEntry('Cap holds', ledger.capHolds),
      MapEntry('Incomplete-roster charges', ledger.incompleteRosterCharges),
      MapEntry('Other / unresolved adjustments', ledger.otherAdjustments),
      MapEntry('TOTAL CAP ALLOCATION', ledger.totalCap),
    ];
    return Column(
      children: [
        for (final row in rows)
          _assetRow(
            title: row.key,
            subtitle: row.key == 'Other / unresolved adjustments'
                ? 'Residual accounting bucket retained explicitly rather than misclassified.'
                : '2026-27 cap ledger',
            trailing: _money(row.value),
          ),
      ],
    );
  }

  Widget _assetRow({
    required String title,
    required String subtitle,
    String? trailing,
    Widget? control,
    List<Widget> badges = const [],
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    for (final badge in badges)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: badge,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing,
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (control != null) ...[
            const SizedBox(width: 8),
            SizedBox(width: 156, child: control),
          ],
        ],
      ),
    );
  }

  TradeScenario _scenario(
    NbaTradeContractSnapshot data,
    List<NbaFutureDraftAsset> allDraftAssets,
  ) {
    final playerById = {for (final player in data.records) player.id: player};
    final draftById = {for (final asset in allDraftAssets) asset.id: asset};
    final assignments = <TradeAssignment>[];

    for (final route in routes.entries) {
      final player = playerById[route.key];
      if (player != null) {
        assignments.add(
          TradeAssignment(
            asset: TradeAsset(
              id: player.id,
              type: TradeAssetType.player,
              label: player.player,
              originTeam: player.team,
              salary: player.salaryFor('2026-27'),
              metadata: {
                'guaranteed_amount': player.guaranteed,
                'protected_amount':
                    NbaContractStatusReference202627.partiallyGuaranteed[player.player],
                'source_status': player.sourceStatus,
                'acquired_date':
                    NbaTransactionHistory2026.mostRecentAcquisitionDate(player.player),
                'trade_restricted': _isTradeRestricted(player.player),
                'no_trade': _tradeRestrictionFor(player.player)?.hasTradeVeto == true,
                'trade_kicker':
                    NbaTradeKickerReference202627.forPlayer(player.player)?.percent,
                'trade_kicker_percent':
                    NbaTradeKickerReference202627.forPlayer(player.player)?.percent,
                'trade_kicker_status':
                    NbaTradeKickerReference202627.forPlayer(player.player)?.status.name,
              },
            ),
            destinationTeam: route.value,
          ),
        );
        continue;
      }

      final draftAsset = draftById[route.key];
      if (draftAsset != null) {
        assignments.add(
          TradeAssignment(
            asset: TradeAsset(
              id: draftAsset.id,
              type: TradeAssetType.draftPick,
              label: draftAsset.label,
              originTeam: draftAsset.team,
              metadata: {
                'draft_year': draftAsset.year,
                'round': '${draftAsset.round}',
                'frozen': draftAsset.frozen,
                'swap_right': draftAsset.swapRight,
                'stepien_safe': draftAsset.stepienSafe,
                'protection': draftAsset.protection ?? '',
                'conveyance_uncertain': draftAsset.conditional,
                'source': draftAsset.source,
              },
            ),
            destinationTeam: route.value,
          ),
        );
      }
    }

    for (final team in teams) {
      final amount = cashAmounts[team] ?? 0;
      final destination = cashDestinations[team];
      if (amount > 0 &&
          destination != null &&
          destination != team &&
          teams.contains(destination)) {
        assignments.add(
          TradeAssignment(
            asset: TradeAsset(
              id: 'cash:$team',
              type: TradeAssetType.cash,
              label: 'Cash considerations',
              originTeam: team,
              metadata: {'amount': amount},
            ),
            destinationTeam: destination,
          ),
        );
      }
    }

    return TradeScenario(
      id: 'sports-terminal-complete-2026-27',
      name: '2026-27 Trade',
      operatingSeason: '2026-27',
      asOfDateIso: _dateIso(tradeDate),
      teams: List<String>.from(teams),
      assignments: assignments,
      capContexts: {
        for (final team in teams)
          team: TeamCapContext(
            team: team,
            teamSalary:
                NbaTeamSalaryPosition202627.forTeam(team)?.totalSalary ??
                    NbaTeamCapReference202627.teamSalary(
                      team,
                      data.payroll(team, '2026-27'),
                    ),
            salaryCap: _cap,
            taxLine: _tax,
            firstApron: _first,
            secondApron: _second,
            hardCappedAt: switch (
              NbaFrontOfficeTracker202627.hardCaps[team]?.capLevel
            ) {
              'first' => _first,
              'second' => _second,
              _ => null,
            },
            standardRosterPlayers: data.forTeam(team, '2026-27').length,
            cashSentThisSeason:
                NbaCashTradeReference202627.limit -
                (NbaCashTradeReference202627.teams[team]?.availableToSend ??
                    NbaCashTradeReference202627.limit),
            cashLimitThisSeason: NbaCashTradeReference202627.limit,
          ),
      },
    );
  }

  TradeValidationReport _applyTpeValidation(
    TradeValidationReport base,
    TradeScenario scenario,
  ) {
    final findings = [...base.findings];

    for (final team in teams) {
      final selectedId = selectedTpeByTeam[team];
      if (selectedId == null) continue;

      final tpe = NbaTradeExceptionReference202627.tpes
          .where((record) => record.id == selectedId)
          .firstOrNull;
      if (tpe == null) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_MISSING',
            message: '$team selected a TPE that is not in the static exception ledger.',
            severity: TradeValidationSeverity.error,
            team: team,
          ),
        );
        continue;
      }

      final expiry = DateTime.tryParse(tpe.expires);
      if (expiry != null && expiry.isBefore(tradeDate)) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_EXPIRED',
            message: '${tpe.sourceTransaction} expired ${tpe.expires}.',
            severity: TradeValidationSeverity.error,
            team: team,
          ),
        );
        continue;
      }

      final context = scenario.capContexts[team]!;
      final incomingSalary = scenario
          .incomingFor(team)
          .where((assignment) => assignment.asset.type == TradeAssetType.player)
          .fold<double>(0, (sum, assignment) => sum + assignment.asset.salary);

      if (incomingSalary <= 0) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_UNUSED',
            message:
                '$team selected ${_money(tpe.available)} TPE but is not receiving player salary.',
            severity: TradeValidationSeverity.warning,
            team: team,
          ),
        );
        continue;
      }

      if (context.aboveSecondApron ||
          scenario.postTradeSalary(team) > context.secondApron) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_APRON',
            message:
                '$team cannot use the selected TPE under the modeled second-apron restriction.',
            severity: TradeValidationSeverity.error,
            team: team,
          ),
        );
        continue;
      }

      if (incomingSalary > tpe.available + 100000) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_AMOUNT',
            message:
                '$team receives ${_money(incomingSalary)}, above the selected TPE capacity of ${_money(tpe.available)} plus the modeled \$100K allowance.',
            severity: TradeValidationSeverity.error,
            team: team,
          ),
        );
        continue;
      }

      findings.removeWhere(
        (finding) => finding.team == team && finding.code == 'SALARY_MATCH',
      );
      findings.add(
        TradeValidationFinding(
          code: 'TPE_OK',
          message:
              '$team can absorb ${_money(incomingSalary)} with ${tpe.sourceTransaction} (${_money(tpe.available)} available; expires ${tpe.expires}).',
          severity: TradeValidationSeverity.info,
          team: team,
        ),
      );
    }

    return TradeValidationReport(
      findings: findings,
      teamSummaries: base.teamSummaries,
    );
  }

  Widget _tradeFlow(
    NbaTradeContractSnapshot data,
    List<NbaFutureDraftAsset> draftAssets,
  ) {
    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('TRADE FLOW'),
          const SizedBox(height: 8),
          if (!_hasTradeActivity)
            const Text(
              'Route a player or draft right, or add cash considerations, to begin.',
              style: TextStyle(color: _muted),
            )
          else
            for (final team in teams)
              Builder(
                builder: (_) {
                  final sent = <String>[];
                  final received = <String>[];
                  for (final player in data.records) {
                    if (player.team == team && routes[player.id] != null) {
                      sent.add('${player.player} → ${routes[player.id]}');
                    }
                    if (routes[player.id] == team) received.add(player.player);
                  }
                  for (final asset in draftAssets) {
                    if (asset.team == team && routes[asset.id] != null) {
                      sent.add('${asset.label} → ${routes[asset.id]}');
                    }
                    if (routes[asset.id] == team) received.add(asset.label);
                  }
                  final cashOut = cashAmounts[team] ?? 0;
                  final cashDestination = cashDestinations[team];
                  if (cashOut > 0 && cashDestination != null) {
                    sent.add('${_money(cashOut)} cash → $cashDestination');
                  }
                  for (final origin in teams) {
                    if (cashDestinations[origin] == team &&
                        (cashAmounts[origin] ?? 0) > 0) {
                      received.add('${_money(cashAmounts[origin]!)} cash');
                    }
                  }
                  if (sent.isEmpty && received.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final selectedTpe = selectedTpeByTeam[team] == null
                      ? null
                      : NbaTradeExceptionReference202627.tpes
                          .where(
                            (record) => record.id == selectedTpeByTeam[team],
                          )
                          .firstOrNull;
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _panel2,
                      border: Border.all(color: _line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team,
                          style: const TextStyle(
                            color: _text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Sends: ${sent.join(' • ')}',
                          style: const TextStyle(color: _red, fontSize: 10),
                        ),
                        Text(
                          'Receives: ${received.join(' • ')}',
                          style: const TextStyle(color: _green, fontSize: 10),
                        ),
                        if (selectedTpe != null)
                          Text(
                            'Uses TPE: ${selectedTpe.sourceTransaction}',
                            style: const TextStyle(color: _cyan, fontSize: 10),
                          ),
                      ],
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _tradeResult(TradeValidationReport report) {
    if (!_hasTradeActivity) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: _cyan),
            SizedBox(width: 10),
            Text(
              'Select assets above to start building a trade.',
              style: TextStyle(color: _text, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }
    final errors = report.findings.where((finding) => finding.severity == TradeValidationSeverity.error).toList();
    final warnings = report.findings.where((finding) => finding.severity == TradeValidationSeverity.warning).toList();
    final ok = errors.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (ok ? _green : _red).withValues(alpha: .08),
        border: Border.all(color: (ok ? _green : _red).withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: ok ? _green : _red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Trade works' : 'Trade does not work',
                  style: TextStyle(color: ok ? _green : _red, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  ok
                      ? (warnings.isEmpty
                          ? 'Salary matching and modeled CBA checks pass.'
                          : 'The trade passes with ' + warnings.length.toString() + ' item(s) to review.')
                      : errors.first.message,
                  style: const TextStyle(color: _text, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _validation(TradeValidationReport report) {
    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _section('CBA / STRUCTURAL VALIDATION')),
              _pill(
                report.isValid ? 'PASS' : '${report.errorCount} ERRORS',
                report.isValid ? _green : _red,
              ),
              const SizedBox(width: 6),
              _pill(
                '${report.warningCount} WARNINGS',
                report.warningCount == 0 ? _green : _amber,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final finding in report.findings)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${finding.code}: ${finding.message}',
                style: TextStyle(
                  color: finding.severity == TradeValidationSeverity.error
                      ? _red
                      : finding.severity == TradeValidationSeverity.warning
                          ? _amber
                          : _muted,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _financials(TradeValidationReport report) {
    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('POST-TRADE FINANCIALS'),
          const SizedBox(height: 8),
          for (final entry in report.teamSummaries.entries)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _panel2,
                border: Border.all(color: _line),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _mini(entry.key, 'TEAM'),
                  _mini(_money(entry.value.outgoingSalary), 'MATCH OUT'),
                  _mini(_money(entry.value.incomingSalary), 'MATCH IN'),
                  _mini(
                    _money(entry.value.maximumIncomingSalary),
                    'BASE MAX IN',
                  ),
                  _mini(_money(entry.value.postTradeSalary), 'POST CAP'),
                  if (entry.value.cashSent > 0)
                    _mini(_money(entry.value.cashSent), 'CASH SENT'),
                  _mini('${entry.value.projectedRosterPlayers}', 'ROSTER'),
                  _mini(entry.value.apronStatus.toUpperCase(), 'STATUS'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sourceNotes() {
    return _panelBox(
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SOURCE / ACCOUNTING NOTES',
            style: TextStyle(
              color: _cyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .9,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Sports Terminal uses the frozen 2026-27 front-office dataset as its transaction authority: salary sheets, guarantees, trade eligibility, kickers, draft rights, TPE/DPE balances, signing exceptions, hard-cap triggers, cash limits and tax context. The Trade Machine makes its determination from those static records and the selected transaction date; no live API calls are used.',
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ),
    );
  }

  void _repairTeams(List<String> allTeams) {
    final valid = teams.where(allTeams.contains).toList();
    for (final fallback in const ['BOS', 'PHI']) {
      if (valid.length >= 2) break;
      if (allTeams.contains(fallback) && !valid.contains(fallback)) {
        valid.add(fallback);
      }
    }
    if (valid.length >= 2 && valid.join('|') != teams.join('|')) {
      teams = valid;
    }
  }

  void _repairSelections(
    NbaTradeContractSnapshot data,
    List<NbaFutureDraftAsset> draftAssets,
  ) {
    final validIds = <String>{
      ...data.records.map((player) => player.id),
      ...draftAssets.map((asset) => asset.id),
    };
    routes.removeWhere(
      (assetId, destination) =>
          !validIds.contains(assetId) || !teams.contains(destination),
    );
    selectedTpeByTeam.removeWhere((team, _) => !teams.contains(team));
    cashAmounts.removeWhere((team, _) => !teams.contains(team));
    cashDestinations.removeWhere(
      (team, destination) =>
          !teams.contains(team) ||
          !teams.contains(destination) ||
          team == destination,
    );
  }

  bool get _hasTradeActivity =>
      routes.isNotEmpty ||
      cashAmounts.values.any((amount) => amount > 0);

  NbaTradeEligibilityRestriction? _tradeRestrictionFor(String player) {
    for (final item in NbaContractStatusReference202627.january15) {
      if (item.player == player) return item;
    }
    return null;
  }

  bool _isTradeRestricted(String player) {
    final restriction = _tradeRestrictionFor(player);
    if (restriction == null) return false;
    return tradeDate.isBefore(DateTime.parse(restriction.eligibleDate));
  }

  Widget _cashTradeControl(
    String team,
    NbaCashTradeAvailability? availability,
  ) {
    final available = availability?.availableToSend ?? 0;
    final destination = cashDestinations[team];
    final amount = (cashAmounts[team] ?? 0).clamp(0, available).toDouble();
    final destinations = teams.where((item) => item != team).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _panel2,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CASH CONSIDERATIONS',
            style: TextStyle(
              color: _cyan,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: destinations.contains(destination) ? destination : null,
                  hint: const Text('Send cash to…'),
                  isDense: true,
                  items: [
                    for (final item in destinations)
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (value) => setState(() {
                    if (value == null) {
                      cashDestinations.remove(team);
                    } else {
                      cashDestinations[team] = value;
                    }
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _money(amount),
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: amount,
            min: 0,
            max: available <= 0 ? 1 : available,
            divisions: available <= 0 ? null : 100,
            label: _money(amount),
            onChanged: available <= 0
                ? null
                : (value) => setState(() => cashAmounts[team] = value),
          ),
          Text(
            availability?.sendRestrictedAboveSecondApron == true
                ? 'Current source marks this team ineligible to send cash while above the second apron.'
                : 'Remaining annual send capacity: ${_money(available)}.',
            style: const TextStyle(color: _muted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

Widget _panelBox(Widget child) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _panel,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

Widget _section(String text) {
  return Text(
    text,
    style: const TextStyle(
      color: _cyan,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: .9,
    ),
  );
}

Widget _pill(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: _panel2,
      border: Border.all(color: color.withValues(alpha: .55)),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 8,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

Widget _mini(String value, String label) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: _text,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
      Text(
        label,
        style: const TextStyle(
          color: _muted,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
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

String _tier(double payroll) {
  if (payroll > _second) return '2ND APRON';
  if (payroll > _first) return '1ST APRON';
  if (payroll > _tax) return 'TAX';
  if (payroll > _cap) return 'OVER CAP';
  return 'CAP SPACE';
}

Color _tierColor(double payroll) {
  if (payroll > _second) return _red;
  if (payroll > _tax) return _amber;
  if (payroll > _cap) return _blue;
  return _green;
}

String _dateIso(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _displayDate(DateTime date) {
  return '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.year}';
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

String _exceptionRule(String key, double teamCap) {
  return switch (key) {
    'room_mle' => NbaMleRules202627.roomRule,
    'non_tax_mle' => NbaMleRules202627.nonTaxpayerRule,
    'tax_mle' => NbaMleRules202627.taxpayerRule,
    'bae' => 'Bi-Annual Exception remaining balance.',
    _ => 'Remaining signing-exception balance.',
  };
}


String _kickerLabel(NbaTradeKickerRecord record) {
  return switch (record.status) {
    NbaTradeKickerStatus.active =>
      'KICKER ${record.percent.toStringAsFixed(record.percent % 1 == 0 ? 0 : 2)}%',
    NbaTradeKickerStatus.voidedAtMaxSalary => 'KICKER VOID @ MAX',
    NbaTradeKickerStatus.futureExtension => 'FUTURE KICKER',
    NbaTradeKickerStatus.waivedOnTrade => 'KICKER WAIVED',
  };
}

Color _kickerColor(NbaTradeKickerRecord record) {
  return switch (record.status) {
    NbaTradeKickerStatus.active => _amber,
    NbaTradeKickerStatus.voidedAtMaxSalary => _muted,
    NbaTradeKickerStatus.futureExtension => _cyan,
    NbaTradeKickerStatus.waivedOnTrade => _muted,
  };
}
