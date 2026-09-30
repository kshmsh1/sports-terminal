import 'package:flutter/material.dart';

import '../services/nba_complete_draft_asset_repository.dart';
import '../services/nba_contract_status_reference_2026.dart';
import '../services/nba_front_office_tracker_2026.dart';
import '../services/nba_league_environment_2026.dart';
import '../services/nba_team_cap_reference_2026.dart';
import '../services/nba_team_salary_position_2026.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_trade_exception_reference_2026.dart';
import '../services/nba_trade_kicker_reference_2026.dart';
import '../services/nba_trade_machine_reference_2026.dart';
import '../services/nba_transaction_history_2026.dart';
import '../services/nba_two_way_contract_reference_2026.dart';
import '../services/trade_machine_engine.dart';

const _bg = Color(0xFF08111D);
const _panel = Color(0xFF0D1927);
const _panel2 = Color(0xFF122235);
const _panel3 = Color(0xFF172A3F);
const _line = Color(0xFF20364D);
const _text = Color(0xFFF4F7FB);
const _muted = Color(0xFF91A2B5);
const _blue = Color(0xFF62A9FF);
const _cyan = Color(0xFF58D6D1);
const _green = Color(0xFF65D19E);
const _amber = Color(0xFFF2C66D);
const _red = Color(0xFFFF7C83);

const _cap = NbaLeagueEnvironment202627.salaryCap;
const _tax = NbaLeagueEnvironment202627.luxuryTax;
const _first = NbaLeagueEnvironment202627.firstApron;
const _second = NbaLeagueEnvironment202627.secondApron;

enum _TradeView { teamPicker, builder, recentTrades }
enum _AssetTab { roster, draftPicks, draftRights, cash, freeAgents }

class ProductTradeMachineWorkbenchScreen extends StatefulWidget {
  const ProductTradeMachineWorkbenchScreen({super.key});

  @override
  State<ProductTradeMachineWorkbenchScreen> createState() =>
      _ProductTradeMachineWorkbenchScreenState();
}

class _ProductTradeMachineWorkbenchScreenState
    extends State<ProductTradeMachineWorkbenchScreen> {
  final contractRepository = const NbaTradeContractRepository();
  final draftRepository = const NbaCompleteDraftAssetRepository();
  final engine = const TradeMachineEngine();

  late final Future<NbaTradeContractSnapshot> future = contractRepository.load();

  _TradeView view = _TradeView.teamPicker;
  _AssetTab assetTab = _AssetTab.roster;
  String conference = 'All';
  final List<String> teams = <String>[];
  String? activeTeam;

  final Map<String, String> routes = <String, String>{};
  final Map<String, String> searches = <String, String>{};
  final Map<String, String> selectedTpeByTeam = <String, String>{};
  final Map<String, double> cashAmounts = <String, double>{};
  final Map<String, String> cashDestinations = <String, String>{};
  final Map<String, double> freeAgentSalaries = <String, double>{};
  final Set<String> renouncedFreeAgentHolds = <String>{};

  DateTime tradeDate = DateTime(2026, 9, 30);
  bool restrictionsOn = true;
  bool deadlineMode = false;
  bool routedOnly = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTradeContractSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            color: _bg,
            constraints: const BoxConstraints(minHeight: 580),
            alignment: Alignment.center,
            child: snapshot.hasError
                ? Text(
                    'Unable to load 2026-27 trade data: ' +
                        (snapshot.error?.toString() ?? 'unknown error'),
                    style: const TextStyle(color: _red),
                  )
                : const CircularProgressIndicator(),
          );
        }

        final data = snapshot.data!;
        final draftAssets = draftRepository.all();
        _repairTeamSelection(data.teams);
        final scenario = _scenario(data, draftAssets);
        final report = _applyTpeValidation(engine.validate(scenario), scenario);

        return Container(
          width: double.infinity,
          color: _bg,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: switch (view) {
            _TradeView.teamPicker => _teamPicker(data),
            _TradeView.recentTrades => _recentTrades(data),
            _TradeView.builder => _builder(
                data,
                draftAssets,
                scenario,
                report,
              ),
          },
        );
      },
    );
  }

  Widget _teamPicker(NbaTradeContractSnapshot data) {
    final filtered = NbaTradeMachineReference202627.teams
        .where((team) => conference == 'All' || team.conference == conference)
        .toList();
    return Column(
      key: const ValueKey('trade-team-picker'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHero(
          'SPORTS TERMINAL / FRONT OFFICE',
          'NBA Trade Machine',
          'Choose 2–5 teams, route players and draft assets, model cash or sign-and-trades, and validate each club against the 2026-27 CBA environment.',
        ),
        const SizedBox(height: 14),
        _panelBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _Section('BUILD A TRADE')),
                  SegmentedButton<_TradeView>(
                    segments: const [
                      ButtonSegment(
                        value: _TradeView.teamPicker,
                        label: Text('Build a Trade'),
                        icon: Icon(Icons.swap_horiz_rounded, size: 17),
                      ),
                      ButtonSegment(
                        value: _TradeView.recentTrades,
                        label: Text('Recent Trades'),
                        icon: Icon(Icons.history_rounded, size: 17),
                      ),
                    ],
                    selected: const {_TradeView.teamPicker},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) {
                      setState(() => view = values.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 9),
              const Text(
                'Select at least two teams. Add a third, fourth or fifth club for multi-team constructions.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in const ['All', 'East', 'West'])
                    ChoiceChip(
                      label: Text(item == 'All' ? 'All teams' : item),
                      selected: conference == item,
                      onSelected: (_) => setState(() => conference = item),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1320
                      ? 5
                      : constraints.maxWidth >= 980
                          ? 4
                          : constraints.maxWidth >= 680
                              ? 3
                              : 2;
                  final width =
                      (constraints.maxWidth - ((columns - 1) * 10)) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final team in filtered)
                        SizedBox(
                          width: width,
                          child: _teamSelectionCard(data, team),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      teams.isEmpty
                          ? 'No teams selected'
                          : teams.length.toString() +
                              ' selected · ' +
                              teams.join(' / '),
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: teams.length >= 2
                        ? () {
                            setState(() {
                              activeTeam ??= teams.first;
                              view = _TradeView.builder;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Build Trade'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teamSelectionCard(
    NbaTradeContractSnapshot data,
    NbaTradeMachineTeam team,
  ) {
    final selected = teams.contains(team.id);
    final salary = _teamSalary(data, team.id);
    final hardCap =
        NbaFrontOfficeTracker202627.hardCaps[_referenceTeam(team.id)];
    return InkWell(
      onTap: () {
        setState(() {
          if (selected) {
            teams.remove(team.id);
            if (activeTeam == team.id) {
              activeTeam = teams.isEmpty ? null : teams.first;
            }
          } else if (teams.length < 5) {
            teams.add(team.id);
            activeTeam ??= team.id;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? _panel3 : _panel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _blue : _line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            _teamBadge(team.id, selected ? _blue : _cyan),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _money(salary) + ' · ' + _tier(salary),
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                  if (hardCap != null)
                    Text(
                      hardCap.capLevel.toUpperCase() + ' APRON HARD CAP',
                      style: const TextStyle(
                        color: _amber,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.add_circle_outline,
              color: selected ? _green : _muted,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentTrades(NbaTradeContractSnapshot data) {
    return Column(
      key: const ValueKey('trade-recent-trades'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHero(
          'SPORTS TERMINAL / FRONT OFFICE',
          'Recent NBA Trades',
          'Use the 2026 transaction ledger as a starting point, then modify the participating teams and assets in the Trade Machine.',
        ),
        const SizedBox(height: 14),
        _panelBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _Section('RECENT TRADES')),
                  SegmentedButton<_TradeView>(
                    segments: const [
                      ButtonSegment(
                        value: _TradeView.teamPicker,
                        label: Text('Build a Trade'),
                        icon: Icon(Icons.swap_horiz_rounded, size: 17),
                      ),
                      ButtonSegment(
                        value: _TradeView.recentTrades,
                        label: Text('Recent Trades'),
                        icon: Icon(Icons.history_rounded, size: 17),
                      ),
                    ],
                    selected: const {_TradeView.recentTrades},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) =>
                        setState(() => view = values.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final event in NbaTransactionHistory2026.trades)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _panel2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 88,
                        child: Text(
                          event.date,
                          style: const TextStyle(
                            color: _cyan,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.summary,
                              style: const TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              event.type.name + ' · ' + event.teams.join(' / '),
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: event.teams.length >= 2
                            ? () => _loadRecentTradeTeams(event.teams, data)
                            : null,
                        child: const Text('Load teams'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _loadRecentTradeTeams(
    List<String> eventTeams,
    NbaTradeContractSnapshot data,
  ) {
    final normalized = eventTeams
        .map(_uiTeam)
        .where(data.teams.contains)
        .toSet()
        .take(5)
        .toList();
    if (normalized.length < 2) return;
    setState(() {
      _clearScenario();
      teams
        ..clear()
        ..addAll(normalized);
      activeTeam = teams.first;
      view = _TradeView.builder;
    });
  }

  Widget _builder(
    NbaTradeContractSnapshot data,
    List<NbaFutureDraftAsset> draftAssets,
    TradeScenario scenario,
    TradeValidationReport report,
  ) {
    final active = activeTeam != null && teams.contains(activeTeam)
        ? activeTeam!
        : teams.first;
    final activity = _tradeActivity(scenario);
    return Column(
      key: const ValueKey('trade-builder'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _builderHeader(data, scenario, report, activity),
        const SizedBox(height: 12),
        _teamTabs(data, active),
        const SizedBox(height: 12),
        _teamFinancialStrip(data, active),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final browser = _assetBrowser(data, draftAssets, active);
            final acquire = _acquireColumn(scenario, report);
            if (constraints.maxWidth < 1120) {
              return Column(
                children: [
                  browser,
                  const SizedBox(height: 12),
                  acquire,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 13, child: browser),
                const SizedBox(width: 12),
                Expanded(flex: 9, child: acquire),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _validation(report, scenario),
        const SizedBox(height: 12),
        _financials(report),
        const SizedBox(height: 12),
        _sourceNotes(data),
      ],
    );
  }

  Widget _builderHeader(
    NbaTradeContractSnapshot data,
    TradeScenario scenario,
    TradeValidationReport report,
    Map<String, _TeamFlowState> activity,
  ) {
    final anyActivity = scenario.assignments.isNotEmpty;
    final anyIncomplete = activity.values.any((item) => item.oneSided);
    final label = !anyActivity
        ? 'START BUILDING'
        : anyIncomplete
            ? 'INCOMPLETE TRADE'
            : !report.isValid
                ? 'TRADE FAILS'
                : report.requiresReview
                    ? 'PASS · REVIEW'
                    : 'TRADE PASSES';
    final color = !anyActivity
        ? _muted
        : anyIncomplete
            ? _amber
            : !report.isValid
                ? _red
                : report.requiresReview
                    ? _amber
                    : _green;

    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Choose teams',
                onPressed: () => setState(() => view = _TradeView.teamPicker),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 2),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPORTS TERMINAL / FRONT OFFICE',
                      style: TextStyle(
                        color: _cyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'NBA Trade Machine',
                      style: TextStyle(
                        color: _text,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _pill(label, color),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Restrictions On'),
                    icon: Icon(Icons.lock_outline_rounded, size: 15),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Restrictions Off'),
                    icon: Icon(Icons.lock_open_rounded, size: 15),
                  ),
                ],
                selected: {restrictionsOn},
                showSelectedIcon: false,
                onSelectionChanged: (values) =>
                    setState(() => restrictionsOn = values.first),
              ),
              FilterChip(
                avatar: const Icon(Icons.timer_outlined, size: 15),
                label: const Text('Deadline Trade'),
                selected: deadlineMode,
                onSelected: (value) {
                  setState(() {
                    deadlineMode = value;
                    if (value) tradeDate = DateTime(2027, 2, 5);
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_today_rounded, size: 15),
                label: Text(_displayDate(tradeDate)),
                onPressed: () => _pickDate(context),
              ),
              FilterChip(
                label: const Text('Routed only'),
                selected: routedOnly,
                onSelected: (value) => setState(() => routedOnly = value),
              ),
              ActionChip(
                avatar: const Icon(Icons.restart_alt_rounded, size: 15),
                label: const Text('Reset trade'),
                onPressed: () => setState(_clearAssetsOnly),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            restrictionsOn
                ? 'Trade-timing, same-season reacquisition, hard-cap, apron, draft and cash restrictions are enforced for ' +
                    _dateIso(tradeDate) +
                    '.'
                : 'Restriction mode is OFF for exploration. Salary math still runs, but date/reacquisition gating is deliberately disabled.',
            style: TextStyle(
              color: restrictionsOn ? _muted : _amber,
              fontSize: 10,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: tradeDate,
      firstDate: DateTime(2026, 7, 1),
      lastDate: DateTime(2033, 6, 30),
    );
    if (picked != null && mounted) {
      setState(() {
        tradeDate = picked;
        deadlineMode = false;
      });
    }
  }

  Widget _teamTabs(NbaTradeContractSnapshot data, String active) {
    final available = data.teams.where((team) => !teams.contains(team)).toList();
    return _panelBox(
      Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final team in teams)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: InputChip(
                        avatar: _teamBadge(
                          team,
                          team == active ? _blue : _cyan,
                        ),
                        label: Text(
                          NbaTradeMachineReference202627
                                  .team(team)
                                  ?.displayName ??
                              team,
                        ),
                        selected: team == active,
                        onPressed: () => setState(() => activeTeam = team),
                        onDeleted: teams.length > 2
                            ? () => setState(() => _removeTeam(team))
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (teams.length < 5)
            PopupMenuButton<String>(
              tooltip: 'Add team',
              onSelected: (team) {
                setState(() {
                  teams.add(team);
                  activeTeam = team;
                });
              },
              itemBuilder: (_) => [
                for (final team in available)
                  PopupMenuItem(
                    value: team,
                    child: Text(
                      NbaTradeMachineReference202627
                              .team(team)
                              ?.displayName ??
                          team,
                    ),
                  ),
              ],
              child: const Chip(
                avatar: Icon(Icons.add_rounded, size: 16),
                label: Text('Add team'),
              ),
            ),
        ],
      ),
    );
  }

  void _removeTeam(String team) {
    if (teams.length <= 2) return;
    teams.remove(team);
    routes.removeWhere(
      (id, destination) =>
          destination == team ||
          id.startsWith(team + ':') ||
          id.startsWith(team + '-'),
    );
    selectedTpeByTeam.remove(team);
    cashAmounts.remove(team);
    cashDestinations.remove(team);
    cashDestinations.removeWhere((_, destination) => destination == team);
    if (activeTeam == team) activeTeam = teams.first;
  }

  Widget _teamFinancialStrip(NbaTradeContractSnapshot data, String team) {
    final salary = _teamSalary(data, team);
    final ref = _referenceTeam(team);
    final tax = NbaFrontOfficeTracker202627.luxuryTax[ref];
    final hardCap = NbaFrontOfficeTracker202627.hardCaps[ref];
    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _teamBadge(team, _blue),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  NbaTradeMachineReference202627.team(team)?.displayName ?? team,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _pill(_tier(salary), _tierColor(salary)),
              if (hardCap != null) ...[
                const SizedBox(width: 6),
                _pill(
                  hardCap.capLevel.toUpperCase() + ' APRON HARD CAP',
                  _amber,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _mini(_tier(salary), 'OPERATING AS'),
              _mini(_signed(_cap - salary), 'CAP SPACE'),
              _mini(_signed(_first - salary), '1ST APRON SPACE'),
              _mini(_signed(_second - salary), '2ND APRON SPACE'),
              _mini(_signed(_tax - salary), 'TAX SPACE'),
              if (tax != null)
                _mini(
                  _money(tax.estimatedTax),
                  tax.repeater ? 'EST. TAX · REPEATER' : 'EST. TAX',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _assetBrowser(
    NbaTradeContractSnapshot data,
    List<NbaFutureDraftAsset> draftAssets,
    String team,
  ) {
    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _Section('ASSETS · $team')),
              const Text(
                'Route assets to another participating team.',
                style: TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_AssetTab>(
              segments: const [
                ButtonSegment(
                  value: _AssetTab.roster,
                  label: Text('Active Roster'),
                  icon: Icon(Icons.person_rounded, size: 15),
                ),
                ButtonSegment(
                  value: _AssetTab.draftPicks,
                  label: Text('Draft Picks'),
                  icon: Icon(Icons.sports_basketball_rounded, size: 15),
                ),
                ButtonSegment(
                  value: _AssetTab.draftRights,
                  label: Text('Draft Rights'),
                  icon: Icon(Icons.account_tree_rounded, size: 15),
                ),
                ButtonSegment(
                  value: _AssetTab.cash,
                  label: Text('Cash'),
                  icon: Icon(Icons.payments_outlined, size: 15),
                ),
                ButtonSegment(
                  value: _AssetTab.freeAgents,
                  label: Text('Free Agents'),
                  icon: Icon(Icons.person_add_alt_1_rounded, size: 15),
                ),
              ],
              selected: {assetTab},
              showSelectedIcon: false,
              onSelectionChanged: (values) =>
                  setState(() => assetTab = values.first),
            ),
          ),
          const SizedBox(height: 10),
          switch (assetTab) {
            _AssetTab.roster => _rosterTab(data, team),
            _AssetTab.draftPicks => _draftPicksTab(team, draftAssets),
            _AssetTab.draftRights => _draftRightsTab(team, draftAssets),
            _AssetTab.cash => _cashTab(team),
            _AssetTab.freeAgents => _freeAgentsTab(team),
          },
        ],
      ),
    );
  }

  Widget _rosterTab(NbaTradeContractSnapshot data, String team) {
    final query = (searches[team] ?? '').trim().toLowerCase();
    var players = data
        .forTeam(team, '2026-27')
        .where(
          (player) =>
              query.isEmpty || player.player.toLowerCase().contains(query),
        )
        .toList();
    if (routedOnly) {
      players =
          players.where((player) => routes.containsKey(player.id)).toList();
    }
    return Column(
      children: [
        TextField(
          onChanged: (value) => setState(() => searches[team] = value),
          style: const TextStyle(color: _text),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search active roster',
          ),
        ),
        const SizedBox(height: 8),
        _tableHeader(
          const [
            _HeaderCell('PLAYER', 4),
            _HeaderCell('2026-27 CAP HIT', 2),
            _HeaderCell('CONTRACT', 2),
            _HeaderCell('FLAGS', 3),
            _HeaderCell('TRADE', 2),
          ],
        ),
        for (final player in players) _playerRow(player, team),
        if (players.isEmpty)
          _emptyState('No active-roster players match the current filter.'),
      ],
    );
  }

  Widget _playerRow(NbaTradeContract player, String team) {
    final restrictionDate = _playerEligibleDate(player.player, team);
    final locked = restrictionDate != null &&
        tradeDate.isBefore(DateTime.parse(restrictionDate));
    final kicker = NbaTradeKickerReference202627.forPlayer(player.player);
    final partial =
        NbaContractStatusReference202627.partiallyGuaranteed[player.player];
    final acquired =
        NbaTransactionHistory2026.mostRecentAcquisitionDate(player.player);
    final twoWay = _isTwoWay(player.player, team);
    final display =
        NbaTradeMachineReference202627.contractDisplay[player.player];
    final reacquire = <NbaTradeMachineReacquisitionRestriction>[];
    for (final destination in teams) {
      if (destination == team) continue;
      final item = NbaTradeMachineReference202627.reacquisition(
        player.player,
        team,
        destination,
      );
      if (item != null) reacquire.add(item);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.player,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (acquired != null)
                  Text(
                    'Acquired $acquired',
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _money(player.salaryFor('2026-27')),
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              display?.summary ?? 'Term detail not loaded',
              style: TextStyle(
                color: display == null ? _muted : _text,
                fontSize: 10,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (locked) _pill('ELIGIBLE ' + restrictionDate, _red),
                for (final item in reacquire)
                  _pill(item.blockedTeam + ' CANNOT REACQUIRE', _red),
                if (kicker != null)
                  _pill(_kickerLabel(kicker), _kickerColor(kicker)),
                if (partial != null)
                  _pill('PARTIAL ' + _money(partial), _amber),
                if (twoWay) _pill('TWO-WAY', _cyan),
                if (_hasTradeVeto(player.player, team))
                  _pill('CONSENT', _amber),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _routeMenu(
              assetId: player.id,
              originTeam: team,
              player: player.player,
              globallyLocked: restrictionsOn && locked,
            ),
          ),
        ],
      ),
    );
  }

  Widget _draftPicksTab(
    String team,
    List<NbaFutureDraftAsset> allDraftAssets,
  ) {
    var assets = allDraftAssets
        .where((asset) => asset.team == _referenceTeam(team))
        .where((asset) => !_isDraftRight(asset))
        .toList()
      ..sort(_draftSort);
    if (routedOnly) {
      assets = assets.where((asset) => routes.containsKey(asset.id)).toList();
    }
    return Column(
      children: [
        _tableHeader(
          const [
            _HeaderCell('PICK', 3),
            _HeaderCell('OWNERSHIP / TERMS', 6),
            _HeaderCell('TRADE', 2),
          ],
        ),
        for (final asset in assets) _draftRow(asset, team),
        if (assets.isEmpty)
          _emptyState('No clean draft-pick assets under the current filter.'),
      ],
    );
  }

  Widget _draftRightsTab(
    String team,
    List<NbaFutureDraftAsset> allDraftAssets,
  ) {
    var assets = allDraftAssets
        .where((asset) => asset.team == _referenceTeam(team))
        .where(_isDraftRight)
        .toList()
      ..sort(_draftSort);
    if (routedOnly) {
      assets = assets.where((asset) => routes.containsKey(asset.id)).toList();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conditional interests, swaps, protected obligations and frozen/unavailable picks stay explicit instead of being flattened into fake clean picks.',
          style: TextStyle(color: _muted, fontSize: 10, height: 1.35),
        ),
        const SizedBox(height: 8),
        _tableHeader(
          const [
            _HeaderCell('DRAFT RIGHT', 3),
            _HeaderCell('CONVEYANCE / PROTECTION', 6),
            _HeaderCell('TRADE', 2),
          ],
        ),
        for (final asset in assets) _draftRow(asset, team),
        if (assets.isEmpty)
          _emptyState('No conditional draft rights are recorded for this team.'),
      ],
    );
  }

  Widget _draftRow(NbaFutureDraftAsset asset, String uiTeam) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              asset.label,
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.description,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    if (asset.protection != null)
                      _pill(asset.protection!, _amber),
                    if (asset.swapRight) _pill('SWAP', _cyan),
                    if (asset.conditional) _pill('CONDITIONAL', _amber),
                    if (asset.frozen) _pill('FROZEN', _red),
                    if (!asset.tradable && !asset.frozen)
                      _pill('OUT / UNAVAILABLE', _muted),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: asset.tradable
                ? _routeMenu(assetId: asset.id, originTeam: uiTeam)
                : const Text(
                    'Unavailable',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cashTab(String team) {
    final ref = _referenceTeam(team);
    final availability = NbaCashTradeReference202627.teams[ref];
    final available = availability?.availableToSend ?? 0;
    final amount = (cashAmounts[team] ?? 0).clamp(0, available).toDouble();
    final destination = cashDestinations[team];
    final destinations = teams.where((item) => item != team).toList();
    final tpes = NbaTradeExceptionReference202627.forTeam(
      ref,
      asOfIso: _dateIso(tradeDate),
    );
    final signing =
        NbaTradeExceptionReference202627.signingExceptions[ref] ??
            const <String, double>{};
    final dpe = NbaFrontOfficeTracker202627.dpe[ref];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Subsection('CASH CONSIDERATIONS'),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: _panel2,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value:
                          destinations.contains(destination) ? destination : null,
                      isDense: true,
                      hint: const Text('Send cash to…'),
                      items: [
                        for (final item in destinations)
                          DropdownMenuItem(
                            value: item,
                            child: Text(
                              NbaTradeMachineReference202627.team(item)?.name ??
                                  item,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          if (value == null) {
                            cashDestinations.remove(team);
                          } else {
                            cashDestinations[team] = value;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _money(amount),
                    style: const TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Slider(
                value: amount,
                min: 0,
                max: available > 0 ? available : 1,
                divisions: available > 0 ? 100 : null,
                onChanged: available > 0
                    ? (value) => setState(() => cashAmounts[team] = value)
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Annual send capacity remaining: ' +
                      _money(available) +
                      (availability?.sendRestrictedAboveSecondApron == true
                          ? ' · Source flags second-apron sending restriction.'
                          : ''),
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _Subsection('TRADED PLAYER EXCEPTIONS'),
        const SizedBox(height: 6),
        if (tpes.isEmpty)
          const Text(
            'No unexpired TPE is recorded for the selected trade date.',
            style: TextStyle(color: _muted),
          ),
        for (final tpe in tpes)
          _compactChoiceRow(
            tpe.sourceTransaction,
            _money(tpe.available) + ' available · expires ' + tpe.expires,
            selectedTpeByTeam[team] == tpe.id,
            () => setState(() {
              if (selectedTpeByTeam[team] == tpe.id) {
                selectedTpeByTeam.remove(team);
              } else {
                selectedTpeByTeam[team] = tpe.id;
              }
            }),
          ),
        const SizedBox(height: 12),
        const _Subsection('SIGNING / OTHER EXCEPTIONS'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in signing.entries)
              _pill(
                _exceptionName(item.key) + ' ' + _money(item.value),
                _cyan,
              ),
            if (dpe != null)
              _pill(
                'DPE ' + dpe.player + ' · ' + _money(dpe.available),
                _amber,
              ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'MLE/BAE/DPE amounts are context, not outgoing salary. A selected TPE can absorb eligible incoming player salary when exception and apron rules allow it.',
          style: TextStyle(color: _muted, fontSize: 10, height: 1.35),
        ),
      ],
    );
  }

  Widget _freeAgentsTab(String team) {
    final rights = NbaTradeMachineReference202627.freeAgentsFor(team);
    final renounced = renouncedFreeAgentHolds.contains(team);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _Subsection('FREE AGENT RIGHTS')),
            TextButton.icon(
              onPressed: rights.isEmpty
                  ? null
                  : () {
                      setState(() {
                        if (renounced) {
                          renouncedFreeAgentHolds.remove(team);
                        } else {
                          renouncedFreeAgentHolds.add(team);
                          for (final right in rights) {
                            routes.remove(right.id);
                          }
                        }
                      });
                    },
              icon: Icon(
                renounced ? Icons.undo_rounded : Icons.delete_outline_rounded,
                size: 16,
              ),
              label: Text(renounced ? 'Restore holds' : 'Renounce all holds'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (rights.isEmpty)
          _emptyState(
            'No source-backed free-agent rights for $team were present in the supplied Trade Machine recording. Sports Terminal will not invent them.',
          ),
        if (renounced)
          _emptyState(
            'All source-backed $team free-agent holds are currently renounced in this scenario.',
          ),
        if (!renounced && rights.isNotEmpty) ...[
          _tableHeader(
            const [
              _HeaderCell('PLAYER', 3),
              _HeaderCell('CAP HOLD', 2),
              _HeaderCell('RIGHTS', 3),
              _HeaderCell('S&T FIRST-YEAR SALARY', 3),
              _HeaderCell('TRADE', 2),
            ],
          ),
          for (final right in rights) _freeAgentRow(right),
        ],
      ],
    );
  }

  Widget _freeAgentRow(NbaTradeMachineFreeAgentRight right) {
    final salary = (freeAgentSalaries[right.id] ?? right.defaultFirstYearSalary)
        .clamp(
          right.minimumFirstYearSalary,
          right.maximumFirstYearSalary,
        )
        .toDouble();
    final flexible =
        right.maximumFirstYearSalary > right.minimumFirstYearSalary + .01;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              right.player,
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _money(right.capHold),
              style: const TextStyle(color: _text),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              right.rights,
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ),
          Expanded(
            flex: 3,
            child: right.supportsSignAndTrade
                ? flexible
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _money(salary),
                            style: const TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Slider(
                            value: salary,
                            min: right.minimumFirstYearSalary,
                            max: right.maximumFirstYearSalary,
                            divisions: 100,
                            onChanged: (value) => setState(
                              () => freeAgentSalaries[right.id] = value,
                            ),
                          ),
                          Text(
                            _money(right.minimumFirstYearSalary) +
                                ' – ' +
                                _money(right.maximumFirstYearSalary),
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _money(salary),
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                : const Text(
                    'Two-way right · S&T disabled',
                    style: TextStyle(color: _muted, fontSize: 9),
                  ),
          ),
          Expanded(
            flex: 2,
            child: right.supportsSignAndTrade
                ? _routeMenu(assetId: right.id, originTeam: right.team)
                : const Text(
                    'Unavailable',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: _muted, fontSize: 9),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _routeMenu({
    required String assetId,
    required String originTeam,
    String? player,
    bool globallyLocked = false,
  }) {
    final destinations = teams.where((team) => team != originTeam).toList();
    final current = destinations.contains(routes[assetId])
        ? routes[assetId]
        : null;
    return DropdownButtonFormField<String>(
      value: current,
      isDense: true,
      isExpanded: true,
      hint: Text(
        globallyLocked ? 'Restricted' : 'Route to…',
        overflow: TextOverflow.ellipsis,
      ),
      items: [
        for (final destination in destinations)
          DropdownMenuItem(
            value: destination,
            enabled: !globallyLocked &&
                !(restrictionsOn &&
                    player != null &&
                    NbaTradeMachineReference202627.reacquisition(
                          player,
                          originTeam,
                          destination,
                        ) !=
                        null),
            child: Text(
              player != null &&
                      restrictionsOn &&
                      NbaTradeMachineReference202627.reacquisition(
                            player,
                            originTeam,
                            destination,
                          ) !=
                          null
                  ? destination + ' · restricted'
                  : destination,
            ),
          ),
      ],
      onChanged: globallyLocked
          ? null
          : (value) {
              setState(() {
                if (value == null) {
                  routes.remove(assetId);
                } else {
                  routes[assetId] = value;
                }
              });
            },
    );
  }

  Widget _acquireColumn(
    TradeScenario scenario,
    TradeValidationReport report,
  ) {
    final flow = _tradeActivity(scenario);
    final anyActivity = scenario.assignments.isNotEmpty;
    final incomplete = flow.values.any((state) => state.oneSided);
    final globalLabel = !anyActivity
        ? 'Select assets to begin'
        : incomplete
            ? 'Trade incomplete'
            : report.isValid
                ? 'CBA structure passes'
                : 'Trade fails validation';
    final globalColor = !anyActivity
        ? _muted
        : incomplete
            ? _amber
            : report.isValid
                ? _green
                : _red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelBox(
          Row(
            children: [
              const Expanded(child: _Section('TEAM ACQUIRE')),
              _pill(globalLabel.toUpperCase(), globalColor),
            ],
          ),
        ),
        const SizedBox(height: 9),
        for (final team in teams) ...[
          _acquireCard(team, scenario, report, flow[team]!),
          const SizedBox(height: 9),
        ],
      ],
    );
  }

  Widget _acquireCard(
    String team,
    TradeScenario scenario,
    TradeValidationReport report,
    _TeamFlowState flow,
  ) {
    final incoming = scenario.incomingFor(team).toList();
    final outgoing = scenario.outgoingFor(team).toList();
    final findings = report.findings
        .where((item) => item.team == team)
        .where((item) => item.code != 'NO_ACTIVITY')
        .toList();
    final errors = findings
        .where((item) => item.severity == TradeValidationSeverity.error)
        .toList();
    final warnings = findings
        .where(
          (item) =>
              item.severity == TradeValidationSeverity.warning &&
              item.code != 'ROSTER_MAX' &&
              item.code != 'ROSTER_MIN',
        )
        .toList();

    String status;
    Color color;
    if (!flow.hasActivity) {
      status = 'WAITING';
      color = _muted;
    } else if (errors.isNotEmpty) {
      status = 'FAIL';
      color = _red;
    } else if (flow.oneSided) {
      status = 'INCOMPLETE';
      color = _amber;
    } else if (warnings.isNotEmpty) {
      status = 'REVIEW';
      color = _amber;
    } else {
      status = 'PASS';
      color = _green;
    }

    final summary = report.teamSummaries[team];
    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _teamBadge(team, color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (NbaTradeMachineReference202627.team(team)?.name ?? team) +
                      ' Acquire',
                  style: const TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _pill(status, color),
            ],
          ),
          const SizedBox(height: 8),
          if (incoming.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _panel2,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _line),
              ),
              child: const Text(
                'No incoming assets yet.',
                style: TextStyle(color: _muted),
              ),
            ),
          for (final assignment in incoming)
            _incomingAssetRow(assignment),
          if (outgoing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Sends: ' +
                  outgoing.map((item) => item.asset.label).join(' · '),
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
          ],
          if (summary != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 7,
              children: [
                _mini(_money(summary.outgoingSalary), 'MATCH OUT'),
                _mini(_money(summary.incomingSalary), 'MATCH IN'),
                _mini(_money(summary.maximumIncomingSalary), 'MAX IN'),
                _mini(
                  _money(summary.postTradeSalary),
                  'POST-TRADE SALARY',
                ),
              ],
            ),
          ],
          if (flow.oneSided) ...[
            const SizedBox(height: 8),
            const Text(
              'This team only sends or only receives consideration. Add the other side before treating the trade as complete.',
              style: TextStyle(color: _amber, fontSize: 9, height: 1.3),
            ),
          ],
          if (errors.isNotEmpty || warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final finding in <TradeValidationFinding>[
              ...errors,
              ...warnings,
            ].take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ' + finding.message,
                  style: TextStyle(
                    color: finding.severity == TradeValidationSeverity.error
                        ? _red
                        : _amber,
                    fontSize: 9,
                    height: 1.25,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _incomingAssetRow(TradeAssignment assignment) {
    final asset = assignment.asset;
    final salary = asset.type == TradeAssetType.player && asset.salary > 0
        ? _money(asset.salary)
        : asset.type == TradeAssetType.cash
            ? _money(_cashAmount(asset))
            : '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _panel2,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(
            switch (asset.type) {
              TradeAssetType.player => Icons.person_rounded,
              TradeAssetType.draftPick ||
              TradeAssetType.draftRights =>
                Icons.sports_basketball_rounded,
              TradeAssetType.cash => Icons.payments_outlined,
              _ => Icons.swap_horiz_rounded,
            },
            color: _cyan,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.label,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'From ' +
                      asset.originTeam +
                      (asset.metadata['sign_and_trade'] == true
                          ? ' · sign-and-trade'
                          : ''),
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
              ],
            ),
          ),
          if (salary.isNotEmpty)
            Text(
              salary,
              style: const TextStyle(
                color: _text,
                fontWeight: FontWeight.w900,
              ),
            ),
          IconButton(
            tooltip: 'Remove asset',
            onPressed: () => setState(() {
              if (asset.type == TradeAssetType.cash) {
                cashAmounts[asset.originTeam] = 0;
                cashDestinations.remove(asset.originTeam);
              } else {
                routes.remove(asset.id);
              }
            }),
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
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
    final rightsById = {
      for (final right in NbaTradeMachineReference202627.freeAgentRights)
        right.id: right,
    };
    final assignments = <TradeAssignment>[];

    for (final route in routes.entries) {
      final player = playerById[route.key];
      if (player != null) {
        final restrictionDate = _playerEligibleDate(
          player.player,
          player.team,
        );
        final reacquire = NbaTradeMachineReference202627.reacquisition(
          player.player,
          player.team,
          route.value,
        );
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
                    NbaContractStatusReference202627.partiallyGuaranteed[
                        player.player],
                'source_status': player.sourceStatus,
                'acquired_date':
                    NbaTransactionHistory2026.mostRecentAcquisitionDate(
                  player.player,
                ),
                if (restrictionsOn && restrictionDate != null)
                  'trade_restricted_until': restrictionDate,
                if (restrictionsOn && reacquire != null)
                  'cannot_reacquire_teams': [reacquire.blockedTeam],
                if (restrictionsOn && reacquire != null)
                  'reacquire_eligible_date': reacquire.eligibleDate,
                'no_trade': _hasTradeVeto(player.player, player.team),
                'two_way': _isTwoWay(player.player, player.team),
                'trade_kicker':
                    NbaTradeKickerReference202627.forPlayer(player.player)
                        ?.percent,
                'trade_kicker_percent':
                    NbaTradeKickerReference202627.forPlayer(player.player)
                        ?.percent,
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
              type: _isDraftRight(draftAsset)
                  ? TradeAssetType.draftRights
                  : TradeAssetType.draftPick,
              label: draftAsset.label,
              originTeam: _uiTeam(draftAsset.team),
              metadata: {
                'draft_year': draftAsset.year,
                'round': draftAsset.round.toString(),
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
        continue;
      }

      final right = rightsById[route.key];
      if (right != null && right.supportsSignAndTrade) {
        final salary = (freeAgentSalaries[right.id] ??
                right.defaultFirstYearSalary)
            .clamp(
              right.minimumFirstYearSalary,
              right.maximumFirstYearSalary,
            )
            .toDouble();
        assignments.add(
          TradeAssignment(
            asset: TradeAsset(
              id: right.id,
              type: TradeAssetType.player,
              label: right.player,
              originTeam: right.team,
              salary: salary,
              metadata: {
                'sign_and_trade': true,
                'free_agent_rights': true,
                'rights': right.rights,
                'cap_hold': right.capHold,
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
      id: 'sports-terminal-2026-27-workbench',
      name: '2026-27 Trade',
      operatingSeason: '2026-27',
      asOfDateIso: _dateIso(tradeDate),
      teams: List<String>.from(teams),
      assignments: assignments,
      capContexts: {
        for (final team in teams)
          team: TeamCapContext(
            team: team,
            teamSalary: _teamSalary(data, team),
            salaryCap: _cap,
            taxLine: _tax,
            firstApron: _first,
            secondApron: _second,
            hardCappedAt: switch (
              NbaFrontOfficeTracker202627
                  .hardCaps[_referenceTeam(team)]
                  ?.capLevel
            ) {
              'first' => _first,
              'second' => _second,
              _ => null,
            },
            standardRosterPlayers: _standardRosterCount(data, team),
            minimumStandardRosterPlayers: 14,
            cashSentThisSeason: NbaCashTradeReference202627.limit -
                (NbaCashTradeReference202627
                        .teams[_referenceTeam(team)]
                        ?.availableToSend ??
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
      NbaTradeExceptionRecord? tpe;
      for (final item in NbaTradeExceptionReference202627.tpes) {
        if (item.id == selectedId) {
          tpe = item;
          break;
        }
      }
      if (tpe == null) continue;

      final incomingSalary = scenario
          .incomingFor(team)
          .where((assignment) => assignment.asset.type == TradeAssetType.player)
          .fold<double>(
            0,
            (sum, assignment) => sum + assignment.asset.salary,
          );
      final context = scenario.capContexts[team]!;
      final expiry = DateTime.tryParse(tpe.expires);

      if (expiry != null && expiry.isBefore(tradeDate)) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_EXPIRED',
            message: tpe.sourceTransaction + ' expired ' + tpe.expires + '.',
            severity: TradeValidationSeverity.error,
            team: team,
          ),
        );
      } else if (incomingSalary <= 0) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_UNUSED',
            message: team +
                ' selected ' +
                _money(tpe.available) +
                ' TPE but is not receiving player salary.',
            severity: TradeValidationSeverity.warning,
            team: team,
          ),
        );
      } else if (context.aboveSecondApron ||
          scenario.postTradeSalary(team) > context.secondApron) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_APRON',
            message: team +
                ' cannot use the selected TPE while above the modeled second-apron boundary.',
            severity: TradeValidationSeverity.error,
            team: team,
          ),
        );
      } else if (incomingSalary > tpe.available + 100000) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_AMOUNT',
            message: team +
                ' receives ' +
                _money(incomingSalary) +
                ', above the selected TPE capacity of ' +
                _money(tpe.available) +
                ' plus the modeled \$100K allowance.',
            severity: TradeValidationSeverity.error,
            team: team,
          ),
        );
      } else {
        findings.removeWhere(
          (finding) =>
              finding.team == team && finding.code == 'SALARY_MATCH',
        );
        findings.add(
          TradeValidationFinding(
            code: 'TPE_OK',
            message: team +
                ' can absorb ' +
                _money(incomingSalary) +
                ' with ' +
                tpe.sourceTransaction +
                ' (' +
                _money(tpe.available) +
                ' available).',
            severity: TradeValidationSeverity.info,
            team: team,
          ),
        );
      }
    }

    return TradeValidationReport(
      findings: findings,
      teamSummaries: base.teamSummaries,
    );
  }

  Widget _validation(
    TradeValidationReport report,
    TradeScenario scenario,
  ) {
    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _Section('CBA / STRUCTURAL VALIDATION')),
              _pill(
                report.isValid
                    ? 'NO HARD ERRORS'
                    : report.errorCount.toString() + ' ERRORS',
                report.isValid ? _green : _red,
              ),
              const SizedBox(width: 6),
              _pill(
                report.warningCount.toString() + ' WARNINGS',
                report.warningCount == 0 ? _green : _amber,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (scenario.assignments.isEmpty)
            const Text(
              'Route assets to begin validation.',
              style: TextStyle(color: _muted),
            )
          else
            for (final finding in report.findings)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  finding.code + ': ' + finding.message,
                  style: TextStyle(
                    color: finding.severity == TradeValidationSeverity.error
                        ? _red
                        : finding.severity ==
                                TradeValidationSeverity.warning
                            ? _amber
                            : _muted,
                    fontSize: 10,
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
          const _Section('POST-TRADE FINANCIALS'),
          const SizedBox(height: 8),
          for (final team in teams)
            if (report.teamSummaries[team] != null)
              _financialTeamRow(
                team,
                report.teamSummaries[team]!,
              ),
        ],
      ),
    );
  }

  Widget _financialTeamRow(String team, TeamTradeSummary summary) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _panel2,
        border: Border.all(color: _line),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 8,
        children: [
          _mini(team, 'TEAM'),
          _mini(_money(summary.outgoingSalary), 'MATCH OUT'),
          _mini(_money(summary.incomingSalary), 'MATCH IN'),
          _mini(_money(summary.maximumIncomingSalary), 'MAX INCOMING'),
          _mini(_money(summary.postTradeSalary), 'POST-TRADE SALARY'),
          if (summary.cashSent > 0)
            _mini(_money(summary.cashSent), 'CASH SENT'),
          _mini(summary.projectedRosterPlayers.toString(), 'STANDARD ROSTER'),
          _mini(summary.apronStatus.toUpperCase(), 'POST-TRADE STATUS'),
        ],
      ),
    );
  }

  Widget _sourceNotes(NbaTradeContractSnapshot data) {
    return _panelBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Section('SOURCE / RULE BOUNDARY'),
          const SizedBox(height: 7),
          Text(
            'Player salary authority: ' +
                data.sourceNote +
                ' The screen-recording pass adds source-backed contract-option labels, reacquisition flags and the demonstrated Boston free-agent rights without inventing unsupported rights for other clubs.',
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.4),
          ),
          const SizedBox(height: 5),
          const Text(
            'Draft interests preserve protections, swaps and conveyance uncertainty. CBA validation covers salary matching, hard caps, apron rules, trade timing, same-season reacquisition, sign-and-trades, BYC/poison-pill metadata when supplied, cash limits, TPEs and Stepien review. Restriction-off mode is an explicit what-if override, not a statement that a live transaction is executable.',
            style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
          ),
        ],
      ),
    );
  }

  String? _playerEligibleDate(String player, String team) {
    final recorded =
        NbaTradeMachineReference202627.timingEligibleDate(player, team);
    if (recorded != null) return recorded;
    for (final item in NbaContractStatusReference202627.january15) {
      if (item.player == player && _uiTeam(item.team) == team) {
        return item.eligibleDate;
      }
    }
    return null;
  }

  bool _hasTradeVeto(String player, String team) {
    for (final item in NbaContractStatusReference202627.january15) {
      if (item.player == player &&
          _uiTeam(item.team) == team &&
          item.hasTradeVeto) {
        return true;
      }
    }
    return false;
  }

  bool _isTwoWay(String player, String team) {
    return NbaTwoWayContractReference202627.forTeam(_referenceTeam(team))
        .any((item) => item.player == player);
  }

  int _standardRosterCount(NbaTradeContractSnapshot data, String team) {
    return data
        .forTeam(team, '2026-27')
        .where((item) => !_isTwoWay(item.player, team))
        .length;
  }

  double _teamSalary(NbaTradeContractSnapshot data, String team) {
    final salaryTeam = NbaTradeMachineReference202627.salaryKey(team);
    final salaryPosition = NbaTeamSalaryPosition202627.forTeam(salaryTeam);
    final ledger = NbaTeamCapReference202627.forTeam(_referenceTeam(team));
    return salaryPosition?.totalSalary ??
        ledger?.totalCap ??
        data.payroll(team, '2026-27');
  }

  Map<String, _TeamFlowState> _tradeActivity(TradeScenario scenario) {
    return {
      for (final team in teams)
        team: _TeamFlowState(
          incoming: scenario.incomingFor(team).length,
          outgoing: scenario.outgoingFor(team).length,
        ),
    };
  }

  void _repairTeamSelection(List<String> available) {
    teams.removeWhere((team) => !available.contains(team));
    if (activeTeam != null && !teams.contains(activeTeam)) {
      activeTeam = teams.isEmpty ? null : teams.first;
    }
    routes.removeWhere((_, destination) => !teams.contains(destination));
  }

  void _clearScenario() {
    routes.clear();
    selectedTpeByTeam.clear();
    cashAmounts.clear();
    cashDestinations.clear();
    searches.clear();
    freeAgentSalaries.clear();
    renouncedFreeAgentHolds.clear();
    routedOnly = false;
  }

  void _clearAssetsOnly() {
    _clearScenario();
    assetTab = _AssetTab.roster;
  }
}

class _TeamFlowState {
  const _TeamFlowState({required this.incoming, required this.outgoing});

  final int incoming;
  final int outgoing;

  bool get hasActivity => incoming > 0 || outgoing > 0;
  bool get oneSided => hasActivity && (incoming == 0 || outgoing == 0);
}

class _HeaderCell {
  const _HeaderCell(this.label, this.flex);
  final String label;
  final int flex;
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _cyan,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .9,
        ),
      );
}

class _Subsection extends StatelessWidget {
  const _Subsection(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _text,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      );
}

Widget _pageHero(String eyebrow, String title, String description) {
  return _panelBox(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: _cyan,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: _text,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: const TextStyle(color: _muted, height: 1.4),
        ),
      ],
    ),
  );
}

Widget _tableHeader(List<_HeaderCell> cells) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        for (final cell in cells)
          Expanded(
            flex: cell.flex,
            child: Text(
              cell.label,
              style: const TextStyle(
                color: _muted,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _compactChoiceRow(
  String title,
  String subtitle,
  bool selected,
  VoidCallback onTap,
) {
  return InkWell(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? _cyan : _muted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _emptyState(String text) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _panel2,
      border: Border.all(color: _line),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(text, style: const TextStyle(color: _muted)),
  );
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

Widget _teamBadge(String team, Color color) {
  return Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _panel2,
      border: Border.all(color: color),
    ),
    child: Text(
      team,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: 8,
      ),
    ),
  );
}

bool _isDraftRight(NbaFutureDraftAsset asset) =>
    asset.conditional ||
    asset.swapRight ||
    asset.frozen ||
    !asset.tradable ||
    asset.label.toLowerCase().contains('interest') ||
    asset.description.toLowerCase().contains('right');

int _draftSort(NbaFutureDraftAsset a, NbaFutureDraftAsset b) {
  final byYear = a.year.compareTo(b.year);
  if (byYear != 0) return byYear;
  final byRound = a.round.compareTo(b.round);
  if (byRound != 0) return byRound;
  return a.label.compareTo(b.label);
}

String _referenceTeam(String team) =>
    NbaTradeMachineReference202627.leagueKey(team);

String _uiTeam(String team) => switch (team) {
      'BKN' => 'BRK',
      'CHA' => 'CHO',
      _ => team,
    };

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  if (amount >= 1000000) {
    return sign + r'$' + (amount / 1000000).toStringAsFixed(2) + 'M';
  }
  if (amount >= 1000) {
    return sign + r'$' + (amount / 1000).toStringAsFixed(0) + 'K';
  }
  return sign + r'$' + amount.toStringAsFixed(0);
}

String _signed(double value) =>
    value >= 0 ? '+' + _money(value) : _money(value);

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

String _dateIso(DateTime date) =>
    date.year.toString().padLeft(4, '0') +
    '-' +
    date.month.toString().padLeft(2, '0') +
    '-' +
    date.day.toString().padLeft(2, '0');

String _displayDate(DateTime date) =>
    date.month.toString().padLeft(2, '0') +
    '/' +
    date.day.toString().padLeft(2, '0') +
    '/' +
    date.year.toString();

String _exceptionName(String key) => switch (key) {
      'room_mle' => 'Room MLE',
      'non_tax_mle' => 'Non-Taxpayer MLE',
      'tax_mle' => 'Taxpayer MLE',
      'bae' => 'Bi-Annual Exception',
      _ => key,
    };

String _kickerLabel(NbaTradeKickerRecord record) => switch (record.status) {
      NbaTradeKickerStatus.active =>
        'KICKER ' +
            record.percent.toStringAsFixed(record.percent % 1 == 0 ? 0 : 2) +
            '%',
      NbaTradeKickerStatus.voidedAtMaxSalary => 'KICKER VOID @ MAX',
      NbaTradeKickerStatus.futureExtension => 'FUTURE KICKER',
      NbaTradeKickerStatus.waivedOnTrade => 'KICKER WAIVED',
    };

Color _kickerColor(NbaTradeKickerRecord record) => switch (record.status) {
      NbaTradeKickerStatus.active => _amber,
      NbaTradeKickerStatus.voidedAtMaxSalary => _muted,
      NbaTradeKickerStatus.futureExtension => _cyan,
      NbaTradeKickerStatus.waivedOnTrade => _muted,
    };

double _cashAmount(TradeAsset asset) {
  final value = asset.metadata['amount'];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? asset.salary;
}
