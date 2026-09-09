import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/front_office_registry_service.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/trade_machine_engine.dart';

const _bg = Color(0xFF080C12);
const _panel = Color(0xFF0F151D);
const _panel2 = Color(0xFF151E28);
const _line = Color(0xFF263444);
const _text = Color(0xFFE9EEF5);
const _muted = Color(0xFF8B98A8);
const _blue = Color(0xFF64AAFF);
const _green = Color(0xFF6DD2A0);
const _amber = Color(0xFFE4BC6A);
const _red = Color(0xFFEB7B7B);

class ProductTradeMachineWorkbenchScreen extends StatefulWidget {
  const ProductTradeMachineWorkbenchScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProductTradeMachineWorkbenchScreen> createState() =>
      _ProductTradeMachineWorkbenchScreenState();
}

class _ProductTradeMachineWorkbenchScreenState
    extends State<ProductTradeMachineWorkbenchScreen> {
  final registry = const FrontOfficeRegistryService();
  final engine = const TradeMachineEngine();
  final searchController = TextEditingController();

  late Future<NbaTerminalSeedSnapshot> seedFuture;
  late Future<FrontOfficeRegistrySnapshot> registryFuture;
  String season = '2026-27';
  String search = '';
  bool tradeableOnly = false;
  List<String> teams = ['BOS', 'PHI'];
  final Map<String, String> routes = {};
  final Map<String, String> tabs = {};
  final Map<String, double> cashAmounts = {};

  @override
  void initState() {
    super.initState();
    seedFuture = const NbaTerminalSeedRepository().load();
    registryFuture = registry.load(session: widget.session, season: season);
    searchController.addListener(() {
      final next = searchController.text.trim().toLowerCase();
      if (next != search) setState(() => search = next);
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      registryFuture = registry.load(session: widget.session, season: season);
    });
  }

  void _setSeason(String next) {
    if (next == season) return;
    setState(() {
      season = next;
      routes.clear();
      registryFuture = registry.load(session: widget.session, season: season);
    });
  }

  void _addTeam(String team) {
    if (teams.length >= 5 || teams.contains(team)) return;
    setState(() => teams = [...teams, team]);
  }

  void _removeTeam(String team) {
    if (teams.length <= 2) return;
    setState(() {
      teams = teams.where((item) => item != team).toList();
      routes.removeWhere((assetId, destination) =>
          assetId.startsWith('$team:') || destination == team);
      tabs.remove(team);
      cashAmounts.remove(team);
    });
  }

  void _route(String assetId, String? destination) {
    setState(() {
      if (destination == null || destination.isEmpty) {
        routes.remove(assetId);
      } else {
        routes[assetId] = destination;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: FutureBuilder<NbaTerminalSeedSnapshot>(
        future: seedFuture,
        builder: (context, seedSnap) {
          if (!seedSnap.hasData) {
            return const SizedBox(
              height: 360,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final seed = seedSnap.data!;
          final allTeams = _teamIds(seed);
          _repairTeams(allTeams);
          return FutureBuilder<FrontOfficeRegistrySnapshot>(
            future: registryFuture,
            builder: (context, regSnap) {
              final snapshot = regSnap.data ??
                  const FrontOfficeRegistrySnapshot(
                    contracts: [],
                    teamPositions: [],
                    draftAssets: [],
                    ledger: [],
                    remoteAvailable: false,
                  );
              final catalog = _WorkbenchCatalog.build(
                seed: seed,
                registry: snapshot,
                teams: teams,
                season: season,
                cashAmounts: cashAmounts,
              );
              routes.removeWhere((id, destination) =>
                  !catalog.byId.containsKey(id) || !teams.contains(destination));
              final scenario = _scenario(catalog);
              final report = engine.validate(scenario);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    season: season,
                    teams: teams.length,
                    routed: routes.length,
                    snapshot: snapshot,
                    report: report,
                  ),
                  const SizedBox(height: 12),
                  _Controls(
                    season: season,
                    searchController: searchController,
                    tradeableOnly: tradeableOnly,
                    onSeason: _setSeason,
                    onTradeableOnly: (value) =>
                        setState(() => tradeableOnly = value),
                    onRefresh: _reload,
                    onClear: () => setState(() => routes.clear()),
                  ),
                  const SizedBox(height: 12),
                  _TeamSelector(
                    allTeams: allTeams,
                    teams: teams,
                    onAdd: _addTeam,
                    onRemove: _removeTeam,
                  ),
                  const SizedBox(height: 12),
                  _FlowStrip(
                    scenario: scenario,
                    routes: routes,
                    catalog: catalog,
                    report: report,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final columns = width >= 1550
                          ? (teams.length.clamp(2, 3))
                          : width >= 980
                              ? 2
                              : 1;
                      final itemWidth = columns == 1
                          ? width
                          : (width - 12 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final team in teams)
                            SizedBox(
                              width: itemWidth,
                              child: _TeamColumn(
                                team: team,
                                teams: teams,
                                catalog: catalog,
                                tab: tabs[team] ?? 'Players',
                                search: search,
                                tradeableOnly: tradeableOnly,
                                routes: routes,
                                onTab: (value) =>
                                    setState(() => tabs[team] = value),
                                onRoute: _route,
                                onCashAmount: (amount) => setState(() {
                                  cashAmounts[team] = amount;
                                }),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ValidationPanel(report: report),
                  const SizedBox(height: 12),
                  _SourceBoundary(snapshot: snapshot),
                ],
              );
            },
          );
        },
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
    for (final team in allTeams) {
      if (valid.length >= 2) break;
      if (!valid.contains(team)) valid.add(team);
    }
    teams = valid.take(5).toList();
  }

  TradeScenario _scenario(_WorkbenchCatalog catalog) {
    final assignments = <TradeAssignment>[];
    for (final route in routes.entries) {
      final view = catalog.byId[route.key];
      if (view == null || !teams.contains(route.value)) continue;
      assignments.add(
        TradeAssignment(asset: view.asset, destinationTeam: route.value),
      );
    }
    return TradeScenario(
      id: 'trade-machine-workbench',
      name: 'Interactive $season trade',
      operatingSeason: season,
      asOfDateIso: DateTime.now().toUtc().toIso8601String(),
      teams: List<String>.from(teams),
      assignments: assignments,
      capContexts: {
        for (final team in teams) team: catalog.capContext(team),
      },
    );
  }
}

class _WorkbenchCatalog {
  const _WorkbenchCatalog({
    required this.byTeam,
    required this.byId,
    required this.positions,
    required this.season,
  });

  final Map<String, List<_AssetView>> byTeam;
  final Map<String, _AssetView> byId;
  final Map<String, Map<String, dynamic>> positions;
  final String season;

  factory _WorkbenchCatalog.build({
    required NbaTerminalSeedSnapshot seed,
    required FrontOfficeRegistrySnapshot registry,
    required List<String> teams,
    required String season,
    required Map<String, double> cashAmounts,
  }) {
    final byTeam = {for (final team in teams) team: <_AssetView>[]};
    final byId = <String, _AssetView>{};
    final positions = <String, Map<String, dynamic>>{};

    void add(String team, _AssetView view) {
      if (!byTeam.containsKey(team)) return;
      byTeam[team]!.add(view);
      byId[view.asset.id] = view;
    }

    for (final wrapper in registry.teamPositions) {
      final record = _record(wrapper);
      final team = _team(record['team_id'] ?? wrapper['team_id']);
      if (teams.contains(team)) positions[team] = record;
    }

    final contracts = <String, Map<String, dynamic>>{};
    for (final wrapper in registry.contracts) {
      final record = _record(wrapper);
      final team = _team(record['team_id'] ?? wrapper['team_id']);
      final playerId = '${record['player_id'] ?? wrapper['player_id'] ?? ''}';
      if (!teams.contains(team) || playerId.isEmpty) continue;
      contracts['$team:$playerId'] = {
        ...record,
        '_source_status': wrapper['source_status'] ??
            record['source_status'] ??
            'modeled',
      };
    }

    for (final team in teams) {
      final seen = <String>{};
      for (final row in seed.playerSeasonTotals) {
        if (!_text(row['team_ids']).contains(team)) continue;
        final playerId = _text(row['player_id']);
        if (playerId == '—' || !seen.add(playerId)) continue;
        final contract = contracts['$team:$playerId'];
        final year = _contractYear(contract, season);
        final salary = year.salary ?? _proxySalary(row);
        final restriction = _restriction(contract);
        final twoWay = _bool(contract?['two_way']) || _bool(year.raw?['two_way']);
        final metadata = <String, dynamic>{
          if (contract != null) ..._metadata(contract),
          'source_status': contract?['_source_status'] ?? 'modeled',
          'two_way': twoWay,
          'no_trade': _bool(contract?['no_trade_clause']),
          'trade_restriction': restriction,
          'trade_eligible': restriction.isEmpty,
          'trade_bonus': _num(contract?['trade_bonus_percent']),
          'bird_rights': contract?['bird_rights'] ?? contract?['rights_type'] ?? '',
          'guaranteed_amount': year.guaranteed ?? 0,
          'option_type': year.optionType,
        };
        add(
          team,
          _AssetView(
            category: 'Players',
            playerId: playerId,
            sourceStatus: '${contract?['_source_status'] ?? 'modeled'}',
            tradeable: restriction.isEmpty,
            asset: TradeAsset(
              id: '$team:player:$playerId',
              type: TradeAssetType.player,
              label: _text(row['player_label']),
              originTeam: team,
              salary: salary,
              metadata: metadata,
            ),
            detail: contract == null
                ? '${_money(salary)} · modeled salary · contract source pending'
                : '${_money(salary)} · ${_option(year.optionType)} · ${twoWay ? 'two-way' : 'standard'}',
          ),
        );
      }
    }

    for (final wrapper in registry.draftAssets) {
      final record = _record(wrapper);
      final team = _team(record['current_team_id'] ?? wrapper['team_id']);
      if (!teams.contains(team)) continue;
      final kind = '${record['asset_type'] ?? 'pick'}'.toLowerCase();
      final year = _int(record['draft_year']);
      final round = _int(record['round']);
      final isRights = kind.contains('rights');
      final isSwap = kind.contains('swap');
      final tradeable = record['tradeable'] != false &&
          record['stepien_eligible'] != false &&
          record['frozen'] != true;
      final label = '${record['description'] ?? ''}'.trim().isNotEmpty
          ? '${record['description']}'
          : isRights
              ? '$team draft rights'
              : '$team $year R$round ${isSwap ? 'swap' : 'pick'}';
      final metadata = <String, dynamic>{
        ..._metadata(record),
        'draft_year': year,
        'round': '$round',
        'swap_right': isSwap,
        'stepien_conflict': record['stepien_eligible'] == false,
        'frozen_pick': record['frozen'] == true,
        'protection': _protection(record),
        'source_status': wrapper['source_status'] ??
            record['source_status'] ??
            'modeled',
      };
      add(
        team,
        _AssetView(
          category: isRights ? 'Rights & Holds' : 'Draft',
          sourceStatus: '${metadata['source_status']}',
          tradeable: tradeable,
          asset: TradeAsset(
            id: '$team:draft:${wrapper['id'] ?? record['id'] ?? '$year-$round-$kind'}',
            type: isRights ? TradeAssetType.draftRights : TradeAssetType.draftPick,
            label: label,
            originTeam: team,
            metadata: metadata,
          ),
          detail: [
            if (year > 0) '$year R$round',
            if (_protection(record).isNotEmpty) _protection(record),
            if (isSwap) 'swap right',
            if (!tradeable) 'restricted',
          ].join(' · '),
        ),
      );
    }

    for (final wrapper in registry.ledger) {
      final record = _record(wrapper);
      final team = _team(record['team_id'] ?? wrapper['team_id']);
      if (!teams.contains(team)) continue;
      final descriptor = [
        record['entry_type'],
        record['asset_type'],
        record['right_type'],
        record['kind'],
        record['description'],
      ].whereType<Object>().join(' ').toLowerCase();
      final isRights = descriptor.contains('bird') ||
          descriptor.contains('draft right') ||
          descriptor.contains('free agent right') ||
          descriptor.contains('cap hold') ||
          descriptor.contains('rights');
      if (!isRights) continue;
      final isDraftRights = descriptor.contains('draft right');
      final amount = _num(record['amount'] ?? record['cap_hold']);
      final label = '${record['description'] ?? record['label'] ?? record['right_type'] ?? 'Rights / cap hold'}';
      add(
        team,
        _AssetView(
          category: 'Rights & Holds',
          sourceStatus: '${wrapper['source_status'] ?? record['source_status'] ?? 'modeled'}',
          tradeable: record['tradeable'] != false,
          asset: TradeAsset(
            id: '$team:rights:${wrapper['id'] ?? record['id'] ?? byId.length}',
            type: isDraftRights
                ? TradeAssetType.draftRights
                : TradeAssetType.freeAgentRights,
            label: label,
            originTeam: team,
            salary: amount,
            metadata: {
              ..._metadata(record),
              'bird_rights': record['bird_rights'] ?? record['right_type'] ?? '',
              'cap_hold': amount,
              'source_status': wrapper['source_status'] ??
                  record['source_status'] ??
                  'modeled',
            },
          ),
          detail: amount > 0 ? '${_money(amount)} cap hold' : descriptor,
        ),
      );
    }

    for (final team in teams) {
      final position = positions[team];
      final exceptions = position?['exceptions'];
      if (exceptions is List) {
        for (var i = 0; i < exceptions.length; i++) {
          final raw = exceptions[i];
          if (raw is! Map) continue;
          final amount = _num(raw['amount']);
          final expires = '${raw['expires_on'] ?? raw['expires_at'] ?? 'unknown'}';
          add(
            team,
            _AssetView(
              category: 'Exceptions',
              sourceStatus: '${position?['source_status'] ?? 'modeled'}',
              tradeable: raw['usable'] != false,
              asset: TradeAsset(
                id: '$team:exception:$i',
                type: TradeAssetType.tradeException,
                label: '${raw['name'] ?? 'Trade exception'}',
                originTeam: team,
                salary: amount,
                metadata: {
                  'amount': amount,
                  'expires_at': expires,
                  'source_status': position?['source_status'] ?? 'modeled',
                },
              ),
              detail: '${_money(amount)} · expires $expires',
            ),
          );
        }
      }

      final amount = cashAmounts[team] ?? 1000000;
      add(
        team,
        _AssetView(
          category: 'Exceptions',
          sourceStatus: 'scenario',
          tradeable: true,
          asset: TradeAsset(
            id: '$team:cash',
            type: TradeAssetType.cash,
            label: '$team cash considerations',
            originTeam: team,
            metadata: {'amount': amount, 'source_status': 'scenario'},
          ),
          detail: '${_money(amount)} scenario amount · annual cash limits validated when available',
        ),
      );
    }

    return _WorkbenchCatalog(
      byTeam: byTeam,
      byId: byId,
      positions: positions,
      season: season,
    );
  }

  TeamCapContext capContext(String team) {
    final position = positions[team];
    final levels = _thresholds(season);
    if (position == null) {
      final salary = byTeam[team]!
          .where((item) => item.asset.type == TradeAssetType.player)
          .fold<double>(0, (sum, item) => sum + item.asset.salary);
      return TeamCapContext(
        team: team,
        teamSalary: salary,
        salaryCap: levels.cap,
        taxLine: levels.tax,
        firstApron: levels.first,
        secondApron: levels.second,
        standardRosterPlayers: byTeam[team]!
            .where((item) =>
                item.asset.type == TradeAssetType.player &&
                item.asset.metadata['two_way'] != true)
            .length,
      );
    }
    final active = _num(position['active_salary']);
    final holds = _num(position['cap_holds']);
    final dead = _num(position['dead_money']);
    final incomplete = _num(position['incomplete_roster_charges']);
    return TeamCapContext(
      team: team,
      teamSalary: active + holds + dead + incomplete,
      salaryCap: _positive(position['salary_cap']) ?? levels.cap,
      taxLine: _positive(position['luxury_tax']) ?? levels.tax,
      firstApron: _positive(position['first_apron']) ?? levels.first,
      secondApron: _positive(position['second_apron']) ?? levels.second,
      hardCappedAt: _positive(position['hard_cap']),
      cashSentThisSeason: _num(position['cash_sent']),
      cashLimitThisSeason:
          _positive(position['cash_limit']) ?? double.infinity,
      standardRosterPlayers: byTeam[team]!
          .where((item) =>
              item.asset.type == TradeAssetType.player &&
              item.asset.metadata['two_way'] != true)
          .length,
    );
  }
}

class _AssetView {
  const _AssetView({
    required this.category,
    required this.asset,
    required this.detail,
    required this.sourceStatus,
    required this.tradeable,
    this.playerId = '',
  });

  final String category;
  final TradeAsset asset;
  final String detail;
  final String sourceStatus;
  final bool tradeable;
  final String playerId;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.season,
    required this.teams,
    required this.routed,
    required this.snapshot,
    required this.report,
  });

  final String season;
  final int teams;
  final int routed;
  final FrontOfficeRegistrySnapshot snapshot;
  final TradeValidationReport report;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FRONT OFFICE / TRADE MACHINE',
              style: TextStyle(
                color: _blue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Build a 2–5 team transaction from the complete asset ledger',
              style: TextStyle(
                color: _text,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Inspect contracts and restrictions, route players and draft capital, include rights, holds, swaps, exceptions and cash, then watch salary matching, roster counts, apron status and rule findings update with the transaction.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _Pill('$season CBA', _blue),
                _Pill('$teams TEAMS', _blue),
                _Pill('$routed ROUTED', routed == 0 ? _muted : _amber),
                _Pill('${snapshot.contracts.length} CONTRACT RECORDS',
                    snapshot.contracts.isEmpty ? _amber : _green),
                _Pill('${snapshot.draftAssets.length} DRAFT RECORDS',
                    snapshot.draftAssets.isEmpty ? _amber : _green),
                _Pill('${report.errorCount} ERRORS',
                    report.errorCount == 0 ? _green : _red),
                _Pill('${report.warningCount} WARNINGS',
                    report.warningCount == 0 ? _green : _amber),
              ],
            ),
          ],
        ),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.season,
    required this.searchController,
    required this.tradeableOnly,
    required this.onSeason,
    required this.onTradeableOnly,
    required this.onRefresh,
    required this.onClear,
  });

  final String season;
  final TextEditingController searchController;
  final bool tradeableOnly;
  final ValueChanged<String> onSeason;
  final ValueChanged<bool> onTradeableOnly;
  final VoidCallback onRefresh;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => _Card(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: searchController,
                style: const TextStyle(color: _text),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  labelText: 'Search contracts and assets',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 145,
              child: DropdownButtonFormField<String>(
                initialValue: season,
                decoration: const InputDecoration(
                  labelText: 'Season',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final item in const ['2024-25', '2025-26', '2026-27'])
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value != null) onSeason(value);
                },
              ),
            ),
            FilterChip(
              label: const Text('Tradeable only'),
              selected: tradeableOnly,
              onSelected: onTradeableOnly,
            ),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Refresh data'),
            ),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Clear trade'),
            ),
          ],
        ),
      );
}

class _TeamSelector extends StatefulWidget {
  const _TeamSelector({
    required this.allTeams,
    required this.teams,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> allTeams;
  final List<String> teams;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_TeamSelector> createState() => _TeamSelectorState();
}

class _TeamSelectorState extends State<_TeamSelector> {
  String? pending;

  @override
  Widget build(BuildContext context) {
    final available = widget.allTeams
        .where((item) => !widget.teams.contains(item))
        .toList();
    if (pending != null && !available.contains(pending)) pending = null;
    return _Card(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _Label('PARTICIPATING TEAMS'),
          for (final team in widget.teams)
            InputChip(
              label: Text(team),
              avatar: const Icon(Icons.sports_basketball_rounded, size: 16),
              onDeleted: widget.teams.length > 2
                  ? () => widget.onRemove(team)
                  : null,
            ),
          if (widget.teams.length < 5)
            SizedBox(
              width: 165,
              child: DropdownButtonFormField<String>(
                initialValue: pending,
                hint: const Text('Add team'),
                items: [
                  for (final team in available)
                    DropdownMenuItem(value: team, child: Text(team)),
                ],
                onChanged: (value) => setState(() => pending = value),
              ),
            ),
          if (widget.teams.length < 5)
            FilledButton.icon(
              onPressed: pending == null
                  ? null
                  : () {
                      widget.onAdd(pending!);
                      setState(() => pending = null);
                    },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.team,
    required this.teams,
    required this.catalog,
    required this.tab,
    required this.search,
    required this.tradeableOnly,
    required this.routes,
    required this.onTab,
    required this.onRoute,
    required this.onCashAmount,
  });

  final String team;
  final List<String> teams;
  final _WorkbenchCatalog catalog;
  final String tab;
  final String search;
  final bool tradeableOnly;
  final Map<String, String> routes;
  final ValueChanged<String> onTab;
  final void Function(String, String?) onRoute;
  final ValueChanged<double> onCashAmount;

  @override
  Widget build(BuildContext context) {
    final cap = catalog.capContext(team);
    var assets = catalog.byTeam[team] ?? const <_AssetView>[];
    assets = assets.where((item) => item.category == tab).toList();
    if (search.isNotEmpty) {
      assets = assets.where((item) {
        final haystack = '${item.asset.label} ${item.detail} ${item.asset.metadata.values.join(' ')}'.toLowerCase();
        return haystack.contains(search);
      }).toList();
    }
    if (tradeableOnly) assets = assets.where((item) => item.tradeable).toList();
    final routed = catalog.byTeam[team]!
        .where((item) => routes.containsKey(item.asset.id))
        .toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  team,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _Pill(_apron(cap), _apronColor(cap)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _Metric(_money(cap.teamSalary), 'TEAM SALARY'),
              _Metric(_money(cap.firstApron), '1ST APRON'),
              _Metric(_money(cap.secondApron), '2ND APRON'),
              _Metric('${routed.length}', 'ROUTED OUT'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in const [
                'Players',
                'Draft',
                'Rights & Holds',
                'Exceptions'
              ])
                ChoiceChip(
                  label: Text(item),
                  selected: tab == item,
                  onSelected: (_) => onTab(item),
                ),
            ],
          ),
          if (tab == 'Exceptions') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                const Text('Cash:', style: TextStyle(color: _muted)),
                for (final amount in const [1000000.0, 2500000.0, 5000000.0])
                  ActionChip(
                    label: Text(_money(amount)),
                    onPressed: () => onCashAmount(amount),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (assets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No assets match this category and filter.',
                style: TextStyle(color: _muted),
              ),
            ),
          for (final asset in assets)
            _AssetRow(
              view: asset,
              destinations: teams.where((item) => item != team).toList(),
              destination: routes[asset.asset.id],
              onRoute: (destination) =>
                  onRoute(asset.asset.id, destination),
            ),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.view,
    required this.destinations,
    required this.destination,
    required this.onRoute,
  });

  final _AssetView view;
  final List<String> destinations;
  final String? destination;
  final ValueChanged<String?> onRoute;

  @override
  Widget build(BuildContext context) {
    final value = view.asset.salary > 0 ? _money(view.asset.salary) : '';
    return InkWell(
      onTap: () => _showAsset(context, view),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              view.tradeable ? Icons.check_circle_outline_rounded : Icons.block_rounded,
              size: 17,
              color: view.tradeable ? _green : _red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.asset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    view.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            if (value.isNotEmpty)
              SizedBox(
                width: 88,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _text, fontWeight: FontWeight.w900),
                ),
              ),
            const SizedBox(width: 7),
            _Pill(
              view.sourceStatus.toUpperCase(),
              view.sourceStatus == 'verified'
                  ? _green
                  : view.sourceStatus == 'scenario'
                      ? _blue
                      : _amber,
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 115,
              child: DropdownButtonFormField<String>(
                initialValue: destinations.contains(destination) ? destination : null,
                hint: const Text('Send to'),
                isDense: true,
                items: [
                  for (final team in destinations)
                    DropdownMenuItem(value: team, child: Text(team)),
                ],
                onChanged: view.tradeable ? onRoute : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowStrip extends StatelessWidget {
  const _FlowStrip({
    required this.scenario,
    required this.routes,
    required this.catalog,
    required this.report,
  });

  final TradeScenario scenario;
  final Map<String, String> routes;
  final _WorkbenchCatalog catalog;
  final TradeValidationReport report;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: _Label('LIVE TRANSACTION FLOW')),
                _Pill(
                  report.isValid ? 'STRUCTURALLY VALID' : 'BLOCKED',
                  report.isValid ? _green : _red,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (routes.isEmpty)
              const Text(
                'Route an asset from any team column to begin building the trade.',
                style: TextStyle(color: _muted),
              ),
            if (routes.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final route in routes.entries)
                    if (catalog.byId[route.key] != null)
                      Chip(
                        avatar: const Icon(Icons.arrow_forward_rounded, size: 15),
                        label: Text(
                          '${catalog.byId[route.key]!.asset.originTeam} → ${route.value}: ${catalog.byId[route.key]!.asset.label}',
                        ),
                      ),
                ],
              ),
          ],
        ),
      );
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.report});

  final TradeValidationReport report;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: _Label('CBA / TRANSACTION VALIDATION')),
                _Pill('${report.errorCount} ERRORS',
                    report.errorCount == 0 ? _green : _red),
                const SizedBox(width: 6),
                _Pill('${report.warningCount} WARNINGS',
                    report.warningCount == 0 ? _green : _amber),
              ],
            ),
            const SizedBox(height: 9),
            for (final summary in report.teamSummaries.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _panel2,
                  border: Border.all(color: _line),
                ),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    _Metric(summary.key, 'TEAM'),
                    _Metric(_money(summary.value.outgoingSalary), 'MATCH OUT'),
                    _Metric(_money(summary.value.incomingSalary), 'MATCH IN'),
                    _Metric(_money(summary.value.maximumIncomingSalary), 'MAX IN'),
                    _Metric(_money(summary.value.postTradeSalary), 'POST SALARY'),
                    _Metric(summary.value.apronStatus.toUpperCase(), 'STATUS'),
                  ],
                ),
              ),
            for (final finding in report.findings)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: finding.severity == TradeValidationSeverity.error
                          ? _red
                          : finding.severity == TradeValidationSeverity.warning
                              ? _amber
                              : _blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${finding.code}: ${finding.message}',
                        style: const TextStyle(color: _muted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _SourceBoundary extends StatelessWidget {
  const _SourceBoundary({required this.snapshot});

  final FrontOfficeRegistrySnapshot snapshot;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Label('DATA QUALITY / EXECUTION BOUNDARY'),
            const SizedBox(height: 7),
            Text(
              snapshot.remoteAvailable
                  ? 'Sports Terminal registry data is connected. Asset rows retain their source status; modeled rows remain visibly labeled and should not be treated as league-confirmed transaction facts.'
                  : 'The registry is offline or incomplete. The workbench exposes modeled roster salary and placeholder asset information where necessary, but it does not represent those rows as verified contract or draft ownership data.',
              style: const TextStyle(color: _muted, height: 1.45),
            ),
          ],
        ),
      );
}

void _showAsset(BuildContext context, _AssetView view) {
  final metadata = view.asset.metadata.entries
      .where((entry) => '${entry.value}'.trim().isNotEmpty && entry.value != false)
      .toList();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _panel,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        maxChildSize: .92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    view.asset.label,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _Pill(view.tradeable ? 'TRADEABLE' : 'RESTRICTED',
                    view.tradeable ? _green : _red),
              ],
            ),
            const SizedBox(height: 8),
            Text(view.detail, style: const TextStyle(color: _muted, height: 1.45)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _Metric(view.asset.originTeam, 'CURRENT TEAM'),
                _Metric(view.category.toUpperCase(), 'ASSET CLASS'),
                if (view.asset.salary > 0)
                  _Metric(_money(view.asset.salary), '2026-27 / ACTIVE VALUE'),
                _Metric(view.sourceStatus.toUpperCase(), 'SOURCE STATUS'),
              ],
            ),
            const SizedBox(height: 18),
            const _Label('CONTRACT / ASSET DETAILS'),
            const SizedBox(height: 8),
            for (final entry in metadata)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _line)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 180,
                      child: Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${entry.value}',
                        style: const TextStyle(color: _text),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: _blue,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .9,
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _panel2,
          border: Border.all(color: color.withValues(alpha: .55)),
          borderRadius: BorderRadius.circular(999),
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

class _Metric extends StatelessWidget {
  const _Metric(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(
                  color: _muted, fontSize: 8, fontWeight: FontWeight.w800)),
        ],
      );
}

({double cap, double tax, double first, double second}) _thresholds(String season) =>
    switch (season) {
      '2024-25' =>
        (cap: 140588000, tax: 170814000, first: 178132000, second: 188931000),
      '2025-26' =>
        (cap: 154647000, tax: 187895000, first: 195945000, second: 207824000),
      _ => (cap: 164961000, tax: 200428000, first: 209015000, second: 221686000),
    };

({double? salary, double? guaranteed, String optionType, Map? raw}) _contractYear(
    Map<String, dynamic>? contract, String season) {
  if (contract == null || contract['years'] is! List) {
    return (salary: null, guaranteed: null, optionType: 'standard', raw: null);
  }
  for (final raw in contract['years'] as List) {
    if (raw is! Map || '${raw['season'] ?? ''}' != season) continue;
    return (
      salary: _positive(raw['cap_charge_override']) ??
          _positive(raw['salary']) ??
          _positive(raw['cap_hit']),
      guaranteed: _positive(raw['guaranteed_amount']),
      optionType: '${raw['option_type'] ?? 'standard'}',
      raw: raw,
    );
  }
  return (salary: null, guaranteed: null, optionType: 'standard', raw: null);
}

String _restriction(Map<String, dynamic>? contract) {
  if (contract == null) return '';
  if (_bool(contract['trade_eligible']) == false && contract.containsKey('trade_eligible')) {
    return '${contract['trade_restriction'] ?? contract['restriction_reason'] ?? 'not currently trade eligible'}';
  }
  final explicit = '${contract['trade_restriction'] ?? contract['restriction_reason'] ?? ''}'.trim();
  if (explicit.isNotEmpty) return explicit;
  return '';
}

String _protection(Map<String, dynamic> record) {
  final value = record['protections'];
  if (value is! List) return '${record['protection'] ?? ''}'.trim();
  return value
      .whereType<Map>()
      .map((item) => '${item['year'] ?? ''}: ${item['condition'] ?? ''}'.trim())
      .where((item) => item != ':')
      .join(' → ');
}

Map<String, dynamic> _record(Map<String, dynamic> wrapper) {
  final value = wrapper['record'];
  return value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : wrapper;
}

Map<String, dynamic> _metadata(Map<String, dynamic> record) {
  final value = record['metadata'];
  return value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : <String, dynamic>{};
}

List<String> _teamIds(NbaTerminalSeedSnapshot data) {
  final values = data.teamRecords
      .map((row) => _text(row['team_id']))
      .where((item) => item != '—')
      .toSet()
      .toList()
    ..sort();
  return values;
}

double _proxySalary(Map<String, dynamic> row) {
  final ppg = _num(row['points_per_game']);
  final mpg = _num(row['minutes_per_game']);
  final value = 2100000 + ppg * 1200000 + mpg * 220000;
  return value < 2100000 ? 2100000 : value;
}

String _option(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  return normalized.isEmpty || normalized == 'standard'
      ? 'standard year'
      : '$normalized year';
}

String _team(Object? value) => '${value ?? ''}'.trim().toUpperCase();
String _text(Object? value) {
  final result = '${value ?? ''}'.trim();
  return result.isEmpty ? '—' : result;
}

double _num(Object? value) => _nullable(value) ?? 0;
double? _positive(Object? value) {
  final number = _nullable(value);
  return number != null && number > 0 ? number : null;
}

double? _nullable(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.replaceAll(',', '').replaceAll('%', ''));
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  final normalized = '${value ?? ''}'.toLowerCase();
  return normalized == 'true' || normalized == 'yes' || normalized == '1';
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  if (amount >= 1000000) {
    return '$sign\$${(amount / 1000000).toStringAsFixed(2)}M';
  }
  if (amount >= 1000) return '$sign\$${(amount / 1000).toStringAsFixed(0)}K';
  return '$sign\$${amount.toStringAsFixed(0)}';
}

String _apron(TeamCapContext context) => context.aboveSecondApron
    ? 'SECOND APRON'
    : context.aboveFirstApron
        ? 'FIRST APRON'
        : context.aboveTax
            ? 'TAX'
            : context.teamSalary > context.salaryCap
                ? 'OVER CAP'
                : 'CAP ROOM';

Color _apronColor(TeamCapContext context) => context.aboveSecondApron
    ? _red
    : context.aboveFirstApron
        ? _amber
        : context.aboveTax
            ? _amber
            : _green;
