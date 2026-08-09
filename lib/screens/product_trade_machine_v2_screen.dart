import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/front_office_registry_service.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import '../services/trade_machine_engine.dart';
import 'product_nba_public_pages_screen.dart';

const _tBg = Color(0xFF090D12);
const _tPanel = Color(0xFF0F151C);
const _tPanel2 = Color(0xFF141C25);
const _tLine = Color(0xFF263342);
const _tText = Color(0xFFE8EDF3);
const _tMuted = Color(0xFF8895A5);
const _tBlue = Color(0xFF63A9FF);
const _tGreen = Color(0xFF69C99A);
const _tAmber = Color(0xFFE2B866);
const _tRed = Color(0xFFE87979);

class ProductTradeMachineV2Screen extends StatefulWidget {
  const ProductTradeMachineV2Screen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProductTradeMachineV2Screen> createState() =>
      _ProductTradeMachineV2ScreenState();
}

class _ProductTradeMachineV2ScreenState
    extends State<ProductTradeMachineV2Screen> {
  final ProductLocalStore store = const ProductLocalStore();
  final FrontOfficeRegistryService registry = const FrontOfficeRegistryService();
  final TradeMachineEngine engine = const TradeMachineEngine();
  final TextEditingController nameController =
      TextEditingController(text: 'Untitled trade scenario');

  late Future<NbaTerminalSeedSnapshot> seedFuture;
  late Future<FrontOfficeRegistrySnapshot> registryFuture;
  String season = '2026-27';
  List<String> teams = ['BOS', 'PHI'];
  Map<String, String> routes = {};
  Map<String, String> teamTabs = {};
  bool routedOnly = false;

  @override
  void initState() {
    super.initState();
    seedFuture = const NbaTerminalSeedRepository().load();
    registryFuture = registry.load(session: widget.session, season: season);
    _restore();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final saved = await store.loadStringMap(ProductLocalStore.tradeMachineStateKey);
    if (!mounted || saved.isEmpty) return;
    final restoredTeams = saved['teams'] ?? ''
        .split('|')
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList();
    final restoredSeason = saved['year'] ?? season;
    setState(() {
      season = const {'2024-25', '2025-26', '2026-27'}.contains(restoredSeason)
          ? restoredSeason
          : '2026-27';
      if (restoredTeams.length >= 2) teams = restoredTeams;
      nameController.text = saved['name'] ?? nameController.text;
      routes = _decode(saved['destinations']);
      teamTabs = _decode(saved['tabs']);
      routedOnly = saved['selectedOnly'] == 'true';
      registryFuture = registry.load(session: widget.session, season: season);
    });
  }

  Future<void> _save({bool announce = false}) async {
    await store.saveStringMap(ProductLocalStore.tradeMachineStateKey, {
      'year': season,
      'teams': teams.join('|'),
      'name': nameController.text.trim(),
      'destinations': _encode(routes),
      'tabs': _encode(teamTabs),
      'selectedOnly': '$routedOnly',
    });
    if (announce && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trade scenario saved.')),
      );
    }
  }

  void _reloadRegistry() {
    setState(() {
      registryFuture = registry.load(session: widget.session, season: season);
    });
  }

  Future<void> _setSeason(String value) async {
    if (value == season) return;
    setState(() {
      season = value;
      routes.clear();
      registryFuture = registry.load(session: widget.session, season: season);
    });
    await _save();
  }

  Future<void> _route(String assetId, String? destination) async {
    setState(() {
      if (destination == null || destination.isEmpty) {
        routes.remove(assetId);
      } else {
        routes[assetId] = destination;
      }
    });
    await _save();
  }

  Future<void> _addTeam(String team) async {
    if (teams.contains(team) || teams.length >= 5) return;
    setState(() => teams = [...teams, team]);
    await _save();
  }

  Future<void> _removeTeam(String team) async {
    if (teams.length <= 2) return;
    setState(() {
      teams = teams.where((item) => item != team).toList();
      routes.removeWhere((asset, destination) =>
          asset.startsWith('$team:') || destination == team);
      teamTabs.remove(team);
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _tBg,
        child: FutureBuilder<NbaTerminalSeedSnapshot>(
          future: seedFuture,
          builder: (context, seedSnapshot) {
            if (seedSnapshot.connectionState != ConnectionState.done) {
              return const _TradePanel(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (seedSnapshot.hasError || seedSnapshot.data == null) {
              return _TradePanel(
                child: Text(
                  'NBA player data unavailable: ${seedSnapshot.error}',
                  style: const TextStyle(color: _tMuted),
                ),
              );
            }
            final seed = seedSnapshot.data!;
            final allTeams = _teamIds(seed);
            _repairTeams(allTeams);
            return FutureBuilder<FrontOfficeRegistrySnapshot>(
              future: registryFuture,
              builder: (context, registrySnapshot) {
                final frontOffice = registrySnapshot.data ??
                    const FrontOfficeRegistrySnapshot(
                      contracts: [],
                      teamPositions: [],
                      draftAssets: [],
                      ledger: [],
                      remoteAvailable: false,
                    );
                final catalog = _TradeCatalog.build(
                  seed: seed,
                  registry: frontOffice,
                  teams: teams,
                  season: season,
                );
                routes.removeWhere((assetId, destination) =>
                    !catalog.byId.containsKey(assetId) ||
                    !teams.contains(destination));
                final scenario = _scenario(catalog);
                final report = engine.validate(scenario);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TradeHero(
                      season: season,
                      teamCount: teams.length,
                      assetCount: scenario.assignments.length,
                      registry: frontOffice,
                    ),
                    const SizedBox(height: 12),
                    _ScenarioBar(
                      controller: nameController,
                      season: season,
                      routedOnly: routedOnly,
                      onSeason: _setSeason,
                      onRoutedOnly: (value) {
                        setState(() => routedOnly = value);
                        _save();
                      },
                      onSave: () => _save(announce: true),
                      onRefresh: _reloadRegistry,
                      onReset: () {
                        setState(() {
                          routes.clear();
                          teamTabs.clear();
                          routedOnly = false;
                          nameController.text = 'Untitled trade scenario';
                        });
                        _save();
                      },
                    ),
                    const SizedBox(height: 12),
                    _TeamPicker(
                      allTeams: allTeams,
                      teams: teams,
                      onAdd: _addTeam,
                      onRemove: _removeTeam,
                      onOpenTeam: (team) => openNbaTeamPage(context, team, team),
                    ),
                    const SizedBox(height: 12),
                    for (final team in teams) ...[
                      _TeamTradeBoard(
                        team: team,
                        teams: teams,
                        catalog: catalog,
                        activeTab: teamTabs[team] ?? 'Players',
                        routedOnly: routedOnly,
                        routes: routes,
                        context: scenario.capContexts[team],
                        onTab: (value) {
                          setState(() => teamTabs[team] = value);
                          _save();
                        },
                        onRoute: _route,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ValidationWorkbench(report: report),
                    const SizedBox(height: 12),
                    _FinancialSummary(report: report, scenario: scenario),
                    const SizedBox(height: 12),
                    _TradePanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _TradeSection('SOURCE & RULE BOUNDARY'),
                          const SizedBox(height: 7),
                          Text(
                            frontOffice.remoteAvailable
                                ? 'Contract, team-position and draft-asset rows are read from the Sports Terminal front-office registry when present. Every record keeps its source_status, and missing player contracts fall back to a clearly modeled salary proxy rather than pretending the number is verified.'
                                : 'The front-office registry is offline or empty, so this scenario is using modeled player salary fallbacks and draft placeholders. Salary matching can be explored, but execution-grade approval requires verified contract, team-position, exception and pick records.',
                            style: const TextStyle(color: _tMuted, height: 1.5),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'The rule engine flags apron restrictions, salary matching, hard caps, sign-and-trades, BYC, poison-pill salary, no-trade rights, trade timing, cash limits, exceptions, two-way contracts, pick protections/swaps, conveyance uncertainty, frozen picks and Stepien continuity. A green structural result is not a substitute for league confirmation on a live transaction.',
                            style: TextStyle(color: _tMuted, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      );

  void _repairTeams(List<String> allTeams) {
    final valid = teams.where(allTeams.contains).toList();
    for (final fallback in const ['BOS', 'PHI']) {
      if (valid.length >= 2) break;
      if (allTeams.contains(fallback) && !valid.contains(fallback)) valid.add(fallback);
    }
    for (final team in allTeams) {
      if (valid.length >= 2) break;
      if (!valid.contains(team)) valid.add(team);
    }
    if (valid.join('|') != teams.join('|')) teams = valid.take(5).toList();
  }

  TradeScenario _scenario(_TradeCatalog catalog) {
    final assignments = <TradeAssignment>[];
    for (final route in routes.entries) {
      final asset = catalog.byId[route.key];
      if (asset == null || !teams.contains(route.value)) continue;
      assignments.add(
        TradeAssignment(asset: asset.asset, destinationTeam: route.value),
      );
    }
    return TradeScenario(
      id: 'sports-terminal-trade-v2',
      name: nameController.text.trim().isEmpty
          ? 'Untitled trade scenario'
          : nameController.text.trim(),
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

class _TradeCatalog {
  const _TradeCatalog({
    required this.byTeam,
    required this.byId,
    required this.positions,
    required this.season,
  });

  final Map<String, List<_TradeAssetView>> byTeam;
  final Map<String, _TradeAssetView> byId;
  final Map<String, Map<String, dynamic>> positions;
  final String season;

  factory _TradeCatalog.build({
    required NbaTerminalSeedSnapshot seed,
    required FrontOfficeRegistrySnapshot registry,
    required List<String> teams,
    required String season,
  }) {
    final byTeam = <String, List<_TradeAssetView>>{
      for (final team in teams) team: [],
    };
    final byId = <String, _TradeAssetView>{};
    final positions = <String, Map<String, dynamic>>{};

    for (final wrapper in registry.teamPositions) {
      final record = _record(wrapper);
      final team = '${record['team_id'] ?? wrapper['team_id'] ?? ''}'.toUpperCase();
      if (teams.contains(team)) positions[team] = record;
    }

    final contractsByPlayer = <String, Map<String, dynamic>>{};
    for (final wrapper in registry.contracts) {
      final record = _record(wrapper);
      final team = '${record['team_id'] ?? wrapper['team_id'] ?? ''}'.toUpperCase();
      final playerId = '${record['player_id'] ?? wrapper['player_id'] ?? ''}';
      if (teams.contains(team) && playerId.isNotEmpty) {
        contractsByPlayer['$team:$playerId'] = {
          ...record,
          '_source_status': wrapper['source_status'] ?? record['source_status'] ?? 'modeled',
        };
      }
    }

    for (final team in teams) {
      final rows = seed.playerSeasonTotals
          .where((row) => _text(row['team_ids']).contains(team))
          .toList();
      final seen = <String>{};
      for (final row in rows) {
        final playerId = _text(row['player_id']);
        if (playerId == '—' || !seen.add(playerId)) continue;
        final contract = contractsByPlayer['$team:$playerId'];
        final salaryInfo = _contractSalary(contract, season);
        final salary = salaryInfo.$1 ?? _proxySalary(row);
        final metadata = <String, dynamic>{
          if (contract != null) ..._metadata(contract),
          'source_status': contract?['_source_status'] ?? 'modeled',
          'source_label': contract?['source_label'] ?? '',
          'no_trade': contract?['no_trade_clause'] == true,
          'trade_bonus': _num(contract?['trade_bonus_percent']),
          'two_way': contract?['two_way'] == true,
          if (salaryInfo.$2 != null) 'guaranteed_amount': salaryInfo.$2,
        };
        final view = _TradeAssetView(
          category: 'Players',
          asset: TradeAsset(
            id: '$team:player:$playerId',
            type: TradeAssetType.player,
            label: _text(row['player_label']),
            originTeam: team,
            salary: salary,
            metadata: metadata,
          ),
          detail: contract == null
              ? '${_perGame(row, 'points', 'points_per_game').toStringAsFixed(1)} PPG · modeled salary proxy'
              : '${contract['_source_status'] ?? 'modeled'} contract · ${_optionLabel(salaryInfo.$3)}',
          sourceStatus: '${contract?['_source_status'] ?? 'modeled'}',
          playerId: playerId,
        );
        byTeam[team]!.add(view);
        byId[view.asset.id] = view;
      }
    }

    for (final wrapper in registry.draftAssets) {
      final record = _record(wrapper);
      final team = '${record['current_team_id'] ?? wrapper['team_id'] ?? ''}'.toUpperCase();
      if (!teams.contains(team)) continue;
      final year = _int(record['draft_year']);
      final round = _int(record['round']);
      final protectionRows = record['protections'] is List ? record['protections'] as List : const [];
      final protection = protectionRows
          .whereType<Map>()
          .map((item) => '${item['year'] ?? ''}: ${item['condition'] ?? ''}')
          .where((item) => !item.endsWith(': '))
          .join(' → ');
      final assetType = '${record['asset_type'] ?? 'pick'}';
      final description = '${record['description'] ?? ''}'.trim();
      final metadata = <String, dynamic>{
        ..._metadata(record),
        'round': '$round',
        'draft_year': year,
        'years_out': year == 0 ? null : year - 2026,
        'stepien_conflict': round == 1 && record['stepien_eligible'] == false,
        'protection': protection,
        'swap_right': assetType == 'swap',
        'conveyance_uncertain': record['encumbered'] == true ||
            (record['conveyance_chain'] is List && (record['conveyance_chain'] as List).isNotEmpty),
        'source_status': wrapper['source_status'] ?? record['source_status'] ?? 'modeled',
      };
      final label = description.isNotEmpty
          ? description
          : '$year Round $round ${assetType == 'swap' ? 'swap' : 'pick'}';
      final view = _TradeAssetView(
        category: 'Draft',
        asset: TradeAsset(
          id: '$team:draft:${wrapper['id'] ?? record['id'] ?? '$year-$round'}',
          type: TradeAssetType.draftPick,
          label: label,
          originTeam: team,
          metadata: metadata,
        ),
        detail: [
          '${wrapper['source_status'] ?? record['source_status'] ?? 'modeled'}',
          if (protection.isNotEmpty) protection,
          if ('${record['swap_terms'] ?? ''}'.isNotEmpty) '${record['swap_terms']}',
        ].join(' · '),
        sourceStatus: '${wrapper['source_status'] ?? record['source_status'] ?? 'modeled'}',
      );
      byTeam[team]!.add(view);
      byId[view.asset.id] = view;
    }

    for (final team in teams) {
      if (!byTeam[team]!.any((item) => item.category == 'Draft')) {
        for (final year in [2027, 2028, 2029]) {
          final view = _TradeAssetView(
            category: 'Draft',
            asset: TradeAsset(
              id: '$team:modeled-first-$year',
              type: TradeAssetType.draftPick,
              label: '$team $year first-round control (modeled)',
              originTeam: team,
              metadata: {
                'round': '1',
                'draft_year': year,
                'years_out': year - 2026,
                'source_status': 'modeled',
              },
            ),
            detail: 'Placeholder draft-control slot · ownership/protection source pending',
            sourceStatus: 'modeled',
          );
          byTeam[team]!.add(view);
          byId[view.asset.id] = view;
        }
      }

      final position = positions[team];
      final exceptions = position?['exceptions'];
      if (exceptions is List) {
        for (var index = 0; index < exceptions.length; index++) {
          final raw = exceptions[index];
          if (raw is! Map) continue;
          final amount = _num(raw['amount']);
          final label = '${raw['name'] ?? 'Trade exception'}';
          final view = _TradeAssetView(
            category: 'Exceptions',
            asset: TradeAsset(
              id: '$team:exception:$index:$label',
              type: TradeAssetType.tradeException,
              label: label,
              originTeam: team,
              salary: amount,
              metadata: {
                'amount': amount,
                'expires_at': raw['expires_on'] ?? '',
                'hard_cap_trigger': raw['hard_cap_trigger'] ?? '',
                'source_status': position?['source_status'] ?? 'modeled',
              },
            ),
            detail: '${_money(amount)} available · expires ${raw['expires_on'] ?? 'unknown'}',
            sourceStatus: '${position?['source_status'] ?? 'modeled'}',
          );
          byTeam[team]!.add(view);
          byId[view.asset.id] = view;
        }
      }
      final cash = _TradeAssetView(
        category: 'Exceptions',
        asset: TradeAsset(
          id: '$team:cash:1m',
          type: TradeAssetType.cash,
          label: '$team cash considerations',
          originTeam: team,
          metadata: const {'amount': 1000000, 'source_status': 'modeled'},
        ),
        detail: '\$1.00M scenario amount · annual limit checked when team-position data supplies it',
        sourceStatus: 'modeled',
      );
      byTeam[team]!.add(cash);
      byId[cash.asset.id] = cash;
    }

    return _TradeCatalog(
      byTeam: byTeam,
      byId: byId,
      positions: positions,
      season: season,
    );
  }

  TeamCapContext capContext(String team) {
    final position = positions[team];
    final official = _officialThresholds(season);
    if (position == null) {
      final rosterSalary = byTeam[team]!
          .where((item) => item.asset.type == TradeAssetType.player)
          .fold<double>(0, (sum, item) => sum + item.asset.salary);
      return TeamCapContext(
        team: team,
        teamSalary: rosterSalary,
        salaryCap: official.salaryCap,
        taxLine: official.taxLine,
        firstApron: official.firstApron,
        secondApron: official.secondApron,
        standardRosterPlayers: byTeam[team]!
            .where((item) => item.asset.type == TradeAssetType.player && item.asset.metadata['two_way'] != true)
            .length,
      );
    }
    final active = _num(position['active_salary']);
    final capHolds = _num(position['cap_holds']);
    final dead = _num(position['dead_money']);
    final incomplete = _num(position['incomplete_roster_charges']);
    return TeamCapContext(
      team: team,
      teamSalary: active + capHolds + dead + incomplete,
      salaryCap: _positive(position['salary_cap']) ?? official.salaryCap,
      taxLine: _positive(position['luxury_tax']) ?? official.taxLine,
      firstApron: _positive(position['first_apron']) ?? official.firstApron,
      secondApron: _positive(position['second_apron']) ?? official.secondApron,
      hardCappedAt: _positive(position['hard_cap']),
      standardRosterPlayers: byTeam[team]!
          .where((item) => item.asset.type == TradeAssetType.player && item.asset.metadata['two_way'] != true)
          .length,
      cashSentThisSeason: _num(position['cash_sent']),
      cashLimitThisSeason: _positive(position['cash_limit']) ?? double.infinity,
    );
  }
}

class _TradeAssetView {
  const _TradeAssetView({
    required this.category,
    required this.asset,
    required this.detail,
    required this.sourceStatus,
    this.playerId = '',
  });

  final String category;
  final TradeAsset asset;
  final String detail;
  final String sourceStatus;
  final String playerId;
}

class _TradeHero extends StatelessWidget {
  const _TradeHero({
    required this.season,
    required this.teamCount,
    required this.assetCount,
    required this.registry,
  });

  final String season;
  final int teamCount;
  final int assetCount;
  final FrontOfficeRegistrySnapshot registry;

  @override
  Widget build(BuildContext context) => _TradePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NBA / TRADE MACHINE V2',
              style: TextStyle(color: _tBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            const SizedBox(height: 7),
            const Text(
              'Build the transaction, then interrogate the rule stack',
              style: TextStyle(color: _tText, fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            const Text(
              'Route players, draft assets, cash and exceptions across two to five teams. Matching salary is sender/receiver aware; cap/apron thresholds are season-specific; source quality stays visible; and every warning remains attached to the scenario instead of disappearing behind a single “trade works” badge.',
              style: TextStyle(color: _tMuted, height: 1.5),
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Status('$season CBA', _tBlue),
                _Status('$teamCount TEAMS', _tBlue),
                _Status('$assetCount ROUTED', _tAmber),
                _Status('${registry.contracts.length} CONTRACTS', registry.contracts.isEmpty ? _tAmber : _tGreen),
                _Status('${registry.draftAssets.length} DRAFT ASSETS', registry.draftAssets.isEmpty ? _tAmber : _tGreen),
                _Status(registry.remoteAvailable ? 'REGISTRY CONNECTED' : 'LOCAL / MODELED', registry.remoteAvailable ? _tGreen : _tAmber),
              ],
            ),
          ],
        ),
      );
}

class _ScenarioBar extends StatelessWidget {
  const _ScenarioBar({
    required this.controller,
    required this.season,
    required this.routedOnly,
    required this.onSeason,
    required this.onRoutedOnly,
    required this.onSave,
    required this.onRefresh,
    required this.onReset,
  });

  final TextEditingController controller;
  final String season;
  final bool routedOnly;
  final ValueChanged<String> onSeason;
  final ValueChanged<bool> onRoutedOnly;
  final VoidCallback onSave;
  final VoidCallback onRefresh;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => _TradePanel(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: controller,
                style: const TextStyle(color: _tText),
                decoration: const InputDecoration(labelText: 'Scenario name', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: season,
                decoration: const InputDecoration(labelText: 'Season', border: OutlineInputBorder(), isDense: true),
                items: [
                  for (final item in const ['2024-25', '2025-26', '2026-27'])
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) {
                  if (value != null) onSeason(value);
                },
              ),
            ),
            FilterChip(label: const Text('Routed assets only'), selected: routedOnly, onSelected: onRoutedOnly),
            FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.save_rounded), label: const Text('Save')),
            OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.sync_rounded), label: const Text('Refresh registry')),
            OutlinedButton.icon(onPressed: onReset, icon: const Icon(Icons.restart_alt_rounded), label: const Text('Reset')),
          ],
        ),
      );
}

class _TeamPicker extends StatefulWidget {
  const _TeamPicker({required this.allTeams, required this.teams, required this.onAdd, required this.onRemove, required this.onOpenTeam});
  final List<String> allTeams;
  final List<String> teams;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onOpenTeam;
  @override
  State<_TeamPicker> createState() => _TeamPickerState();
}

class _TeamPickerState extends State<_TeamPicker> {
  String? pending;
  @override
  Widget build(BuildContext context) {
    final available = widget.allTeams.where((item) => !widget.teams.contains(item)).toList();
    if (pending != null && !available.contains(pending)) pending = null;
    return _TradePanel(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _TradeSection('PARTICIPATING TEAMS'),
          for (final team in widget.teams)
            InputChip(
              avatar: const Icon(Icons.sports_basketball_rounded, size: 15),
              label: InkWell(onTap: () => widget.onOpenTeam(team), child: Text(team)),
              onDeleted: widget.teams.length > 2 ? () => widget.onRemove(team) : null,
            ),
          if (widget.teams.length < 5 && available.isNotEmpty)
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                initialValue: pending,
                hint: const Text('Add team'),
                isDense: true,
                items: [for (final team in available) DropdownMenuItem(value: team, child: Text(team))],
                onChanged: (value) => setState(() => pending = value),
              ),
            ),
          if (widget.teams.length < 5)
            FilledButton(
              onPressed: pending == null ? null : () { widget.onAdd(pending!); setState(() => pending = null); },
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }
}

class _TeamTradeBoard extends StatelessWidget {
  const _TeamTradeBoard({
    required this.team,
    required this.teams,
    required this.catalog,
    required this.activeTab,
    required this.routedOnly,
    required this.routes,
    required this.context,
    required this.onTab,
    required this.onRoute,
  });
  final String team;
  final List<String> teams;
  final _TradeCatalog catalog;
  final String activeTab;
  final bool routedOnly;
  final Map<String, String> routes;
  final TeamCapContext? context;
  final ValueChanged<String> onTab;
  final Future<void> Function(String, String?) onRoute;

  @override
  Widget build(BuildContext context) {
    var assets = catalog.byTeam[team] ?? const <_TradeAssetView>[];
    assets = assets.where((item) => item.category == activeTab).toList();
    if (routedOnly) assets = assets.where((item) => routes.containsKey(item.asset.id)).toList();
    return _TradePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => openNbaTeamPage(context, team, team),
                  child: Text('$team TRANSACTION BOARD', style: const TextStyle(color: _tText, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: _tBlue)),
                ),
              ),
              if (this.context != null) _Status(_apron(this.context!), _apronColor(this.context!)),
            ],
          ),
          if (this.context != null) ...[
            const SizedBox(height: 8),
            _CapStrip(context: this.context!),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final item in const ['Players', 'Draft', 'Exceptions'])
                ChoiceChip(label: Text(item), selected: activeTab == item, onSelected: (_) => onTab(item)),
            ],
          ),
          const SizedBox(height: 8),
          if (assets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('No assets in this category for the active source/filter.', style: TextStyle(color: _tMuted)),
            ),
          for (final view in assets)
            _AssetRouteRow(
              view: view,
              destinations: teams.where((item) => item != team).toList(),
              destination: routes[view.asset.id],
              onChanged: (value) => onRoute(view.asset.id, value),
            ),
        ],
      ),
    );
  }
}

class _AssetRouteRow extends StatelessWidget {
  const _AssetRouteRow({required this.view, required this.destinations, required this.destination, required this.onChanged});
  final _TradeAssetView view;
  final List<String> destinations;
  final String? destination;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _tLine))),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                view.playerId.isEmpty
                    ? Text(view.asset.label, style: const TextStyle(color: _tText, fontWeight: FontWeight.w900))
                    : InkWell(
                        onTap: () => openNbaPlayerPage(context, view.playerId, view.asset.label),
                        child: Text(view.asset.label, style: const TextStyle(color: _tBlue, fontWeight: FontWeight.w900, decoration: TextDecoration.underline, decorationColor: _tBlue)),
                      ),
                const SizedBox(height: 3),
                Text(view.detail, style: const TextStyle(color: _tMuted, fontSize: 10, height: 1.35)),
              ],
            );
            final source = _Status(view.sourceStatus.toUpperCase(), view.sourceStatus == 'verified' ? _tGreen : view.sourceStatus == 'uploaded' ? _tBlue : _tAmber);
            final value = view.asset.type == TradeAssetType.player ? _money(view.asset.salary) : view.asset.type == TradeAssetType.cash ? _money(_num(view.asset.metadata['amount'])) : view.asset.type == TradeAssetType.tradeException ? _money(_num(view.asset.metadata['amount'])) : '';
            final selector = SizedBox(
              width: 145,
              child: DropdownButtonFormField<String>(
                initialValue: destinations.contains(destination) ? destination : null,
                hint: const Text('Route to…'),
                isDense: true,
                items: [for (final team in destinations) DropdownMenuItem(value: team, child: Text(team))],
                onChanged: onChanged,
              ),
            );
            if (constraints.maxWidth < 720) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, const SizedBox(height: 6), Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [source, if (value.isNotEmpty) Text(value, style: const TextStyle(color: _tText, fontWeight: FontWeight.w900)), selector])]);
            }
            return Row(children: [Expanded(child: identity), const SizedBox(width: 8), source, const SizedBox(width: 10), SizedBox(width: 100, child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: _tText, fontWeight: FontWeight.w900))), const SizedBox(width: 10), selector]);
          },
        ),
      );
}

class _ValidationWorkbench extends StatelessWidget {
  const _ValidationWorkbench({required this.report});
  final TradeValidationReport report;
  @override
  Widget build(BuildContext context) {
    final errors = report.findings.where((item) => item.severity == TradeValidationSeverity.error).length;
    final warnings = report.findings.where((item) => item.severity == TradeValidationSeverity.warning).length;
    final info = report.findings.where((item) => item.severity == TradeValidationSeverity.info).length;
    return _TradePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: _TradeSection('CBA / STRUCTURAL VALIDATION')), _Status('$errors ERRORS', errors == 0 ? _tGreen : _tRed), const SizedBox(width: 6), _Status('$warnings WARNINGS', warnings == 0 ? _tGreen : _tAmber), const SizedBox(width: 6), _Status('$info INFO', _tBlue)]),
        const SizedBox(height: 8),
        if (report.findings.isEmpty) const Text('No structural findings yet. Add routed assets to test the transaction.', style: TextStyle(color: _tMuted)),
        for (final finding in report.findings)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.circle, size: 8, color: finding.severity == TradeValidationSeverity.error ? _tRed : finding.severity == TradeValidationSeverity.warning ? _tAmber : _tBlue),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(finding.code, style: const TextStyle(color: _tText, fontSize: 10, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(finding.message, style: const TextStyle(color: _tMuted, height: 1.4))])),
            ]),
          ),
      ]),
    );
  }
}

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({required this.report, required this.scenario});
  final TradeValidationReport report;
  final TradeScenario scenario;
  @override
  Widget build(BuildContext context) => _TradePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _TradeSection('POST-TRADE TEAM SUMMARY'),
          const SizedBox(height: 8),
          for (final entry in report.teamSummaries.entries)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _tPanel2, border: Border.all(color: _tLine)),
              child: Wrap(spacing: 18, runSpacing: 8, children: [
                _MiniMetric(entry.key, 'TEAM'),
                _MiniMetric(_money(entry.value.outgoingSalary), 'MATCH OUT'),
                _MiniMetric(_money(entry.value.incomingSalary), 'MATCH IN'),
                _MiniMetric(_money(entry.value.postTradeSalary), 'POST SALARY'),
                _MiniMetric('${entry.value.projectedRosterPlayers}', 'STD ROSTER'),
                _MiniMetric(entry.value.apronStatus.toUpperCase(), 'CAP STATUS'),
                if (entry.value.cashSent > 0) _MiniMetric(_money(entry.value.cashSent), 'CASH SENT'),
              ]),
            ),
        ]),
      );
}

class _CapStrip extends StatelessWidget {
  const _CapStrip({required this.context});
  final TeamCapContext context;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _MiniMetric(_money(this.context.teamSalary), 'TEAM SALARY'),
          _MiniMetric(_money(this.context.salaryCap), 'CAP'),
          _MiniMetric(_money(this.context.taxLine), 'TAX'),
          _MiniMetric(_money(this.context.firstApron), '1ST APRON'),
          _MiniMetric(_money(this.context.secondApron), '2ND APRON'),
        ],
      );
}

class _TradePanel extends StatelessWidget {
  const _TradePanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _tPanel, border: Border.all(color: _tLine)), child: child);
}

class _TradeSection extends StatelessWidget {
  const _TradeSection(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: _tBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8));
}

class _Status extends StatelessWidget {
  const _Status(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: _tPanel2, border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)), child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)));
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: _tText, fontSize: 12, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: _tMuted, fontSize: 8, fontWeight: FontWeight.w800))]);
}

({double salaryCap, double taxLine, double firstApron, double secondApron}) _officialThresholds(String season) => switch (season) {
      '2024-25' => (salaryCap: 140588000, taxLine: 170814000, firstApron: 178132000, secondApron: 188931000),
      '2025-26' => (salaryCap: 154647000, taxLine: 187895000, firstApron: 195945000, secondApron: 207824000),
      _ => (salaryCap: 164961000, taxLine: 200428000, firstApron: 209015000, secondApron: 221686000),
    };

Map<String, dynamic> _record(Map<String, dynamic> wrapper) {
  final value = wrapper['record'];
  return value is Map ? value.map((key, item) => MapEntry(key.toString(), item)) : wrapper;
}

Map<String, dynamic> _metadata(Map<String, dynamic> record) {
  final value = record['metadata'];
  return value is Map ? value.map((key, item) => MapEntry(key.toString(), item)) : <String, dynamic>{};
}

(double?, double?, String?) _contractSalary(Map<String, dynamic>? contract, String season) {
  if (contract == null || contract['years'] is! List) return (null, null, null);
  for (final raw in contract['years'] as List) {
    if (raw is! Map || '${raw['season'] ?? ''}' != season) continue;
    final salary = _positive(raw['cap_charge_override']) ?? _num(raw['salary']) + _num(raw['likely_incentives']) + _num(raw['dead_money']);
    return (salary, _positive(raw['guaranteed_amount']), '${raw['option_type'] ?? 'none'}');
  }
  return (null, null, null);
}

String _optionLabel(String? value) {
  final text = (value ?? 'none').replaceAll('_', ' ');
  return text == 'none' ? 'standard year' : '$text year';
}

List<String> _teamIds(NbaTerminalSeedSnapshot data) {
  final values = data.teamRecords.map((row) => _text(row['team_id'])).where((item) => item != '—').toSet().toList()..sort();
  return values;
}

double _proxySalary(Map<String, dynamic> row) {
  final ppg = _perGame(row, 'points', 'points_per_game');
  final mpg = _perGame(row, 'minutes', 'minutes_per_game');
  final bpm = _num(row['avg_bpm']);
  final value = 2100000 + ppg * 1200000 + mpg * 220000 + (bpm > 0 ? bpm * 900000 : 0);
  return value < 2100000 ? 2100000 : value;
}

double _perGame(Map<String, dynamic> row, String totalKey, String perGameKey) {
  final direct = _nullable(row[perGameKey]);
  if (direct != null) return direct;
  final games = _nullable(row['games']);
  final total = _nullable(row[totalKey]);
  if (games == null || games <= 0 || total == null) return 0;
  return total / games;
}

double _num(Object? value) => _nullable(value) ?? 0;
double? _positive(Object? value) { final number = _nullable(value); return number != null && number > 0 ? number : null; }
double? _nullable(Object? value) { if (value is num) return value.toDouble(); return double.tryParse('${value ?? ''}'.replaceAll(',', '').replaceAll('%', '')); }
int _int(Object? value) { if (value is num) return value.toInt(); return int.tryParse('${value ?? ''}') ?? 0; }
String _text(Object? value) { final text = '${value ?? ''}'.trim(); return text.isEmpty ? '—' : text; }
String _money(double value) { final sign = value < 0 ? '-' : ''; final amount = value.abs(); if (amount >= 1000000) return '$sign\$${(amount / 1000000).toStringAsFixed(2)}M'; if (amount >= 1000) return '$sign\$${(amount / 1000).toStringAsFixed(0)}K'; return '$sign\$${amount.toStringAsFixed(0)}'; }
String _apron(TeamCapContext context) => context.aboveSecondApron ? 'SECOND APRON' : context.aboveFirstApron ? 'FIRST APRON' : context.aboveTax ? 'TAX' : context.teamSalary > context.salaryCap ? 'OVER CAP' : 'CAP ROOM';
Color _apronColor(TeamCapContext context) => context.aboveSecondApron ? _tRed : context.aboveFirstApron ? _tAmber : context.aboveTax ? _tAmber : _tGreen;
String _encode(Map<String, String> values) => values.entries.map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}').join('&');
Map<String, String> _decode(String? raw) { if (raw == null || raw.isEmpty) return {}; final result = <String, String>{}; for (final pair in raw.split('&')) { final index = pair.indexOf('='); if (index <= 0) continue; result[Uri.decodeComponent(pair.substring(0, index))] = Uri.decodeComponent(pair.substring(index + 1)); } return result; }
