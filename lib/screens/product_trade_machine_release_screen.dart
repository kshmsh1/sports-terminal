import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/front_office_registry_service.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import '../services/trade_machine_engine.dart';

const _rtBg = Color(0xFF090D12);
const _rtPanel = Color(0xFF101720);
const _rtPanel2 = Color(0xFF16202B);
const _rtLine = Color(0xFF293848);
const _rtFg = Color(0xFFE9EEF5);
const _rtMuted = Color(0xFF8D9AAA);
const _rtBlue = Color(0xFF66ABFF);
const _rtGreen = Color(0xFF6DD2A0);
const _rtAmber = Color(0xFFE5BC6A);
const _rtRed = Color(0xFFEA7A7A);

class ProductTradeMachineReleaseScreen extends StatefulWidget {
  const ProductTradeMachineReleaseScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<ProductTradeMachineReleaseScreen> createState() =>
      _ProductTradeMachineReleaseScreenState();
}

class _ProductTradeMachineReleaseScreenState
    extends State<ProductTradeMachineReleaseScreen> {
  final registry = const FrontOfficeRegistryService();
  final store = const ProductLocalStore();
  final engine = const TradeMachineEngine();
  final searchController = TextEditingController();
  final scenarioController = TextEditingController(text: '2026-27 Trade');

  late Future<NbaTerminalSeedSnapshot> seedFuture;
  late Future<FrontOfficeRegistrySnapshot> registryFuture;
  String season = '2026-27';
  String search = '';
  List<String> teams = ['BOS', 'PHI'];
  Map<String, String> routes = {};
  Map<String, String> tabs = {};
  Map<String, double> cashAmounts = {};
  bool routedOnly = false;

  @override
  void initState() {
    super.initState();
    seedFuture = const NbaTerminalSeedRepository().load();
    registryFuture = registry.load(session: widget.session, season: season);
    searchController.addListener(() {
      final next = searchController.text.trim().toLowerCase();
      if (next != search && mounted) setState(() => search = next);
    });
    _restore();
  }

  @override
  void dispose() {
    searchController.dispose();
    scenarioController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final saved = await store.loadStringMap(ProductLocalStore.tradeMachineStateKey);
    if (!mounted || saved.isEmpty) return;
    final savedTeams = (saved['teams'] ?? '')
        .split('|')
        .where((item) => item.isNotEmpty)
        .take(5)
        .toList();
    setState(() {
      if (savedTeams.length >= 2) teams = savedTeams;
      final savedSeason = saved['year'];
      if (const {'2024-25', '2025-26', '2026-27'}.contains(savedSeason)) {
        season = savedSeason!;
      }
      scenarioController.text = saved['name'] ?? scenarioController.text;
      routes = _decodeMap(saved['destinations']);
      tabs = _decodeMap(saved['releaseTabs']);
      cashAmounts = _decodeDoubleMap(saved['cashAmounts']);
      routedOnly = saved['selectedOnly'] == 'true';
      registryFuture = registry.load(session: widget.session, season: season);
    });
  }

  Future<void> _save({bool announce = false}) async {
    await store.saveStringMap(ProductLocalStore.tradeMachineStateKey, {
      'year': season,
      'teams': teams.join('|'),
      'name': scenarioController.text.trim(),
      'destinations': _encodeMap(routes),
      'releaseTabs': _encodeMap(tabs),
      'cashAmounts': _encodeDoubleMap(cashAmounts),
      'selectedOnly': '$routedOnly',
    });
    if (announce && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trade scenario saved.')),
      );
    }
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

  Future<void> _addTeam(String team) async {
    if (teams.length >= 5 || teams.contains(team)) return;
    setState(() => teams = [...teams, team]);
    await _save();
  }

  Future<void> _removeTeam(String team) async {
    if (teams.length <= 2) return;
    setState(() {
      teams = teams.where((item) => item != team).toList();
      routes.removeWhere(
        (assetId, destination) => assetId.startsWith('$team:') || destination == team,
      );
      tabs.remove(team);
      cashAmounts.remove(team);
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

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _rtBg,
        child: FutureBuilder<NbaTerminalSeedSnapshot>(
          future: seedFuture,
          builder: (context, seedSnapshot) {
            if (seedSnapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 420,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (seedSnapshot.hasError || seedSnapshot.data == null) {
              return _ReleaseCard(
                child: Text(
                  'NBA roster data unavailable: ${seedSnapshot.error}',
                  style: const TextStyle(color: _rtMuted),
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
                final catalog = _ReleaseCatalog.build(
                  seed: seed,
                  registry: frontOffice,
                  teams: teams,
                  season: season,
                  cashAmounts: cashAmounts,
                );
                routes.removeWhere(
                  (id, destination) =>
                      !catalog.byId.containsKey(id) || !teams.contains(destination),
                );
                final scenario = _scenario(catalog);
                final report = engine.validate(scenario);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReleaseHeader(
                      season: season,
                      teamCount: teams.length,
                      routedCount: routes.length,
                      frontOffice: frontOffice,
                      report: report,
                    ),
                    const SizedBox(height: 12),
                    _ReleaseControls(
                      season: season,
                      scenarioController: scenarioController,
                      searchController: searchController,
                      routedOnly: routedOnly,
                      onSeason: _setSeason,
                      onRoutedOnly: (value) {
                        setState(() => routedOnly = value);
                        _save();
                      },
                      onRefresh: () => setState(() {
                        registryFuture = registry.load(
                          session: widget.session,
                          season: season,
                        );
                      }),
                      onSave: () => _save(announce: true),
                      onClear: () {
                        setState(() {
                          routes.clear();
                          cashAmounts.clear();
                        });
                        _save();
                      },
                    ),
                    const SizedBox(height: 12),
                    _ReleaseTeamPicker(
                      allTeams: allTeams,
                      teams: teams,
                      onAdd: _addTeam,
                      onRemove: _removeTeam,
                    ),
                    const SizedBox(height: 12),
                    _TradeFlow(
                      routes: routes,
                      catalog: catalog,
                      report: report,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1450
                            ? 3
                            : constraints.maxWidth >= 900
                                ? 2
                                : 1;
                        final width = columns == 1
                            ? constraints.maxWidth
                            : (constraints.maxWidth - (columns - 1) * 12) / columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final team in teams)
                              SizedBox(
                                width: width,
                                child: _ReleaseTeamBoard(
                                  team: team,
                                  teams: teams,
                                  catalog: catalog,
                                  activeTab: tabs[team] ?? 'Players',
                                  search: search,
                                  routedOnly: routedOnly,
                                  routes: routes,
                                  onTab: (value) {
                                    setState(() => tabs[team] = value);
                                    _save();
                                  },
                                  onRoute: _route,
                                  onCashAmount: (value) {
                                    setState(() => cashAmounts[team] = value);
                                    _save();
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _ReleaseValidation(report: report),
                    const SizedBox(height: 12),
                    _ReleaseDataBoundary(frontOffice: frontOffice),
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

  TradeScenario _scenario(_ReleaseCatalog catalog) {
    final assignments = <TradeAssignment>[];
    for (final entry in routes.entries) {
      final item = catalog.byId[entry.key];
      if (item == null || !teams.contains(entry.value) || !item.routeable) continue;
      assignments.add(
        TradeAssignment(asset: item.asset, destinationTeam: entry.value),
      );
    }
    return TradeScenario(
      id: 'sports-terminal-release-trade',
      name: scenarioController.text.trim().isEmpty
          ? 'Untitled trade scenario'
          : scenarioController.text.trim(),
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

class _ReleaseCatalog {
  const _ReleaseCatalog({
    required this.byTeam,
    required this.byId,
    required this.positions,
    required this.season,
  });

  final Map<String, List<_ReleaseAsset>> byTeam;
  final Map<String, _ReleaseAsset> byId;
  final Map<String, Map<String, dynamic>> positions;
  final String season;

  factory _ReleaseCatalog.build({
    required NbaTerminalSeedSnapshot seed,
    required FrontOfficeRegistrySnapshot registry,
    required List<String> teams,
    required String season,
    required Map<String, double> cashAmounts,
  }) {
    final byTeam = {for (final team in teams) team: <_ReleaseAsset>[]};
    final byId = <String, _ReleaseAsset>{};
    final positions = <String, Map<String, dynamic>>{};

    void add(String team, _ReleaseAsset item) {
      if (!byTeam.containsKey(team)) return;
      byTeam[team]!.add(item);
      byId[item.asset.id] = item;
    }

    for (final wrapper in registry.teamPositions) {
      final record = _record(wrapper);
      final team = _team(record['team_id'] ?? wrapper['team_id']);
      if (teams.contains(team)) {
        positions[team] = {
          ...record,
          '_source_status': wrapper['source_status'] ??
              record['source_status'] ??
              'modeled',
        };
      }
    }

    final contracts = <String, Map<String, dynamic>>{};
    final registryContractsByTeam = <String, List<Map<String, dynamic>>>{};
    for (final wrapper in registry.contracts) {
      final record = _record(wrapper);
      final team = _team(record['team_id'] ?? wrapper['team_id']);
      final playerId = '${record['player_id'] ?? wrapper['player_id'] ?? ''}';
      final playerName = '${record['player_name'] ?? ''}'.trim();
      if (!teams.contains(team) || playerId.isEmpty) continue;
      final materialized = <String, dynamic>{
        ...record,
        '_source_status': wrapper['source_status'] ??
            record['source_status'] ??
            'modeled',
      };
      contracts['$team:$playerId'] = materialized;
      if (playerName.isNotEmpty) {
        contracts['$team:name:${_nameKey(playerName)}'] = materialized;
      }
      registryContractsByTeam.putIfAbsent(team, () => []).add(materialized);
    }

    _ReleaseAsset playerAsset({
      required String team,
      required String playerId,
      required String label,
      required Map<String, dynamic>? contract,
      required double fallbackSalary,
    }) {
      final year = _contractYear(contract, season);
      final salary = year.salary ?? fallbackSalary;
      final restriction = _tradeRestriction(contract);
      final noTrade = contract?['no_trade_clause'] == true;
      final twoWay = contract?['two_way'] == true || year.twoWay;
      final bird = '${contract?['bird_rights'] ?? 'unknown'}';
      final sourceStatus = '${contract?['_source_status'] ?? 'modeled'}';
      final contractMetadata = contract == null
          ? <String, dynamic>{}
          : _metadata(contract);
      final remainingGuaranteed =
          _positive(contractMetadata['remaining_guaranteed_total']);
      final metadata = <String, dynamic>{
        ...contractMetadata,
        'source_status': sourceStatus,
        'source_label': contract?['source_label'] ?? '',
        'contract_type': contract?['contract_type'] ?? 'standard',
        'contract_years': contract?['years'] ?? const [],
        'no_trade': noTrade,
        'trade_restricted': restriction.isNotEmpty,
        'trade_restricted_until': contract?['trade_restricted_until'] ??
            contract?['recently_signed_until'] ??
            '',
        'trade_bonus': _number(contract?['trade_bonus_percent']),
        'two_way': twoWay,
        'bird_rights': bird,
        if (year.guaranteed != null) 'guaranteed_amount': year.guaranteed,
        if (remainingGuaranteed != null)
          'remaining_guaranteed_total': remainingGuaranteed,
        'option_type': year.option,
      };
      return _ReleaseAsset(
        category: 'Players',
        playerId: playerId,
        routeable: restriction.isEmpty,
        status: restriction.isNotEmpty
            ? 'RESTRICTED'
            : noTrade
                ? 'CONSENT'
                : 'TRADEABLE',
        sourceStatus: sourceStatus,
        asset: TradeAsset(
          id: '$team:player:$playerId',
          type: TradeAssetType.player,
          label: label,
          originTeam: team,
          salary: salary,
          metadata: metadata,
        ),
        detail: [
          _money(salary),
          twoWay ? 'two-way' : '${contract?['contract_type'] ?? 'standard'}',
          _option(year.option),
          if (year.guaranteed != null) '${_money(year.guaranteed!)} guaranteed this year',
          if (remainingGuaranteed != null)
            '${_money(remainingGuaranteed)} remaining guaranteed total',
          if (bird != 'unknown' && bird.isNotEmpty) '$bird Bird rights',
          if (noTrade) 'player consent required',
          if (restriction.isNotEmpty) restriction,
        ].join(' · '),
      );
    }

    for (final team in teams) {
      final seenIds = <String>{};
      final seenNames = <String>{};
      for (final row in seed.playerSeasonTotals) {
        if (!_textValue(row['team_ids']).contains(team)) continue;
        final playerId = _textValue(row['player_id']);
        if (playerId == '—' || !seenIds.add(playerId)) continue;
        final label = _textValue(row['player_label']);
        final nameKey = _nameKey(label);
        final contract = contracts['$team:$playerId'] ??
            contracts['$team:name:$nameKey'];
        seenNames.add(nameKey);
        add(
          team,
          playerAsset(
            team: team,
            playerId: playerId,
            label: label,
            contract: contract,
            fallbackSalary: _proxySalary(row),
          ),
        );
      }

      for (final contract
          in registryContractsByTeam[team] ?? const <Map<String, dynamic>>[]) {
        final label = '${contract['player_name'] ?? ''}'.trim();
        final playerId = '${contract['player_id'] ?? ''}'.trim();
        final nameKey = _nameKey(label);
        if (playerId.isEmpty || label.isEmpty || seenNames.contains(nameKey)) {
          continue;
        }
        final year = _contractYear(contract, season);
        if (year.salary == null) continue;
        seenNames.add(nameKey);
        add(
          team,
          playerAsset(
            team: team,
            playerId: playerId,
            label: label,
            contract: contract,
            fallbackSalary: year.salary!,
          ),
        );
      }
    }

    for (final wrapper in registry.draftAssets) {
      final record = _record(wrapper);
      final team = _team(record['current_team_id'] ?? wrapper['team_id']);
      if (!teams.contains(team)) continue;
      final kind = '${record['asset_type'] ?? 'pick'}'.toLowerCase();
      final year = _integer(record['draft_year']);
      final round = _integer(record['round']);
      final isRights = kind.contains('right');
      final isSwap = kind.contains('swap');
      final frozen = record['frozen'] == true || record['trade_frozen'] == true;
      final stepienConflict = round == 1 && record['stepien_eligible'] == false;
      final routeable = record['tradeable'] != false && !frozen && !stepienConflict;
      final protection = _protection(record);
      final labelText = '${record['description'] ?? ''}'.trim();
      final label = labelText.isNotEmpty
          ? labelText
          : isRights
              ? '$team draft rights'
              : '$team $year R$round ${isSwap ? 'swap' : 'pick'}';
      final sourceStatus = '${wrapper['source_status'] ?? record['source_status'] ?? 'modeled'}';
      final metadata = <String, dynamic>{
        ..._metadata(record),
        'round': '$round',
        'draft_year': year,
        'years_out': year > 0 ? year - 2026 : null,
        'stepien_conflict': stepienConflict,
        'frozen': frozen,
        'swap_right': isSwap,
        'protection': protection,
        'conveyance_uncertain': record['encumbered'] == true ||
            (record['conveyance_chain'] is List &&
                (record['conveyance_chain'] as List).isNotEmpty),
        'source_status': sourceStatus,
      };
      add(
        team,
        _ReleaseAsset(
          category: isRights ? 'Draft Rights' : 'Draft',
          routeable: routeable,
          status: routeable ? 'TRADEABLE' : 'RESTRICTED',
          sourceStatus: sourceStatus,
          asset: TradeAsset(
            id: '$team:draft:${wrapper['id'] ?? record['id'] ?? '$year-$round-$kind'}',
            type: isRights ? TradeAssetType.draftRights : TradeAssetType.draftPick,
            label: label,
            originTeam: team,
            metadata: metadata,
          ),
          detail: [
            if (year > 0) '$year R$round',
            if (isSwap) 'swap right',
            if (protection.isNotEmpty) protection,
            if (stepienConflict) 'Stepien conflict',
            if (frozen) 'frozen',
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
      ].where((value) => value != null).join(' ').toLowerCase();
      if (!descriptor.contains('draft right')) continue;
      final sourceStatus = '${wrapper['source_status'] ?? record['source_status'] ?? 'modeled'}';
      final label = '${record['description'] ?? record['label'] ?? 'Draft rights'}';
      add(
        team,
        _ReleaseAsset(
          category: 'Draft Rights',
          routeable: record['tradeable'] != false,
          status: record['tradeable'] == false ? 'RESTRICTED' : 'TRADEABLE',
          sourceStatus: sourceStatus,
          asset: TradeAsset(
            id: '$team:rights:${wrapper['id'] ?? record['id'] ?? byId.length}',
            type: TradeAssetType.draftRights,
            label: label,
            originTeam: team,
            metadata: {
              ..._metadata(record),
              'source_status': sourceStatus,
            },
          ),
          detail: descriptor,
        ),
      );
    }

    for (final team in teams) {
      final position = positions[team];
      final exceptions = position?['exceptions'];
      if (exceptions is List) {
        for (var index = 0; index < exceptions.length; index++) {
          final raw = exceptions[index];
          if (raw is! Map) continue;
          final amount = _number(raw['amount']);
          final expires = '${raw['expires_on'] ?? raw['expires_at'] ?? 'unknown'}';
          add(
            team,
            _ReleaseAsset(
              category: 'Exceptions',
              routeable: false,
              status: 'TEAM MECHANISM',
              sourceStatus: '${position?['_source_status'] ?? 'modeled'}',
              asset: TradeAsset(
                id: '$team:exception:$index',
                type: TradeAssetType.tradeException,
                label: '${raw['name'] ?? 'Trade exception'}',
                originTeam: team,
                salary: amount,
                metadata: {
                  'amount': amount,
                  'expires_at': expires,
                  'hard_cap_trigger': raw['hard_cap_trigger'] ?? '',
                  'source_status': position?['_source_status'] ?? 'modeled',
                },
              ),
              detail: '${_money(amount)} available · expires $expires · receiving mechanism, not a transferable asset',
            ),
          );
        }
      }

      final cash = cashAmounts[team] ?? 1000000;
      add(
        team,
        _ReleaseAsset(
          category: 'Cash',
          routeable: cash > 0,
          status: 'TRADEABLE',
          sourceStatus: 'scenario',
          asset: TradeAsset(
            id: '$team:cash',
            type: TradeAssetType.cash,
            label: '$team cash considerations',
            originTeam: team,
            metadata: {'amount': cash, 'source_status': 'scenario'},
          ),
          detail: '${_money(cash)} scenario amount · annual CBA cash limit checked when team ledger data is available',
        ),
      );
    }

    return _ReleaseCatalog(
      byTeam: byTeam,
      byId: byId,
      positions: positions,
      season: season,
    );
  }

  TeamCapContext capContext(String team) {
    final position = positions[team];
    final levels = _levels(season);
    if (position == null) {
      final active = byTeam[team]!
          .where((item) => item.asset.type == TradeAssetType.player)
          .fold<double>(0, (sum, item) => sum + item.asset.salary);
      return TeamCapContext(
        team: team,
        teamSalary: active,
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
    return TeamCapContext(
      team: team,
      teamSalary: _number(position['active_salary']) +
          _number(position['cap_holds']) +
          _number(position['dead_money']) +
          _number(position['incomplete_roster_charges']),
      salaryCap: _positive(position['salary_cap']) ?? levels.cap,
      taxLine: _positive(position['luxury_tax']) ?? levels.tax,
      firstApron: _positive(position['first_apron']) ?? levels.first,
      secondApron: _positive(position['second_apron']) ?? levels.second,
      hardCappedAt: _positive(position['hard_cap']),
      cashSentThisSeason: _number(position['cash_sent']),
      cashLimitThisSeason: _positive(position['cash_limit']) ?? double.infinity,
      standardRosterPlayers: byTeam[team]!
          .where((item) =>
              item.asset.type == TradeAssetType.player &&
              item.asset.metadata['two_way'] != true)
          .length,
    );
  }
}

class _ReleaseAsset {
  const _ReleaseAsset({
    required this.category,
    required this.asset,
    required this.detail,
    required this.status,
    required this.sourceStatus,
    required this.routeable,
    this.playerId = '',
  });

  final String category;
  final TradeAsset asset;
  final String detail;
  final String status;
  final String sourceStatus;
  final bool routeable;
  final String playerId;
}

class _ReleaseHeader extends StatelessWidget {
  const _ReleaseHeader({
    required this.season,
    required this.teamCount,
    required this.routedCount,
    required this.frontOffice,
    required this.report,
  });

  final String season;
  final int teamCount;
  final int routedCount;
  final FrontOfficeRegistrySnapshot frontOffice;
  final TradeValidationReport report;

  @override
  Widget build(BuildContext context) => _ReleaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NBA / TRADE MACHINE',
              style: TextStyle(color: _rtBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
            ),
            const SizedBox(height: 7),
            const Text(
              '2026-27 front-office transaction workbench',
              style: TextStyle(color: _rtFg, fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            const Text(
              'Build two- through five-team trades with contracts, picks, swaps, draft rights and cash. Inspect Bird status, guarantees, options, two-way designation, trade restrictions, exceptions and source quality without pretending team mechanisms such as TPEs are transferable assets.',
              style: TextStyle(color: _rtMuted, height: 1.5),
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _Badge('$season CBA', _rtBlue),
                _Badge('$teamCount TEAMS', _rtBlue),
                _Badge('$routedCount ROUTED', routedCount == 0 ? _rtMuted : _rtAmber),
                _Badge('${frontOffice.contracts.length} CONTRACTS', frontOffice.contracts.isEmpty ? _rtAmber : _rtGreen),
                _Badge('${frontOffice.draftAssets.length} DRAFT ASSETS', frontOffice.draftAssets.isEmpty ? _rtAmber : _rtGreen),
                _Badge('${report.errorCount} ERRORS', report.errorCount == 0 ? _rtGreen : _rtRed),
              ],
            ),
          ],
        ),
      );
}

class _ReleaseControls extends StatelessWidget {
  const _ReleaseControls({
    required this.season,
    required this.scenarioController,
    required this.searchController,
    required this.routedOnly,
    required this.onSeason,
    required this.onRoutedOnly,
    required this.onRefresh,
    required this.onSave,
    required this.onClear,
  });

  final String season;
  final TextEditingController scenarioController;
  final TextEditingController searchController;
  final bool routedOnly;
  final ValueChanged<String> onSeason;
  final ValueChanged<bool> onRoutedOnly;
  final VoidCallback onRefresh;
  final VoidCallback onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => _ReleaseCard(
        child: Wrap(
          spacing: 9,
          runSpacing: 9,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 250,
              child: TextField(
                controller: scenarioController,
                decoration: const InputDecoration(labelText: 'Scenario', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            SizedBox(
              width: 260,
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search players / assets', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            SizedBox(
              width: 135,
              child: DropdownButtonFormField<String>(
                initialValue: season,
                decoration: const InputDecoration(labelText: 'Season', border: OutlineInputBorder(), isDense: true),
                items: [for (final value in const ['2024-25', '2025-26', '2026-27']) DropdownMenuItem(value: value, child: Text(value))],
                onChanged: (value) {
                  if (value != null) onSeason(value);
                },
              ),
            ),
            FilterChip(label: const Text('Routed only'), selected: routedOnly, onSelected: onRoutedOnly),
            FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.save), label: const Text('Save')),
            OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.sync), label: const Text('Refresh')),
            OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.clear_all), label: const Text('Clear')),
          ],
        ),
      );
}

class _ReleaseTeamPicker extends StatefulWidget {
  const _ReleaseTeamPicker({required this.allTeams, required this.teams, required this.onAdd, required this.onRemove});
  final List<String> allTeams;
  final List<String> teams;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_ReleaseTeamPicker> createState() => _ReleaseTeamPickerState();
}

class _ReleaseTeamPickerState extends State<_ReleaseTeamPicker> {
  String? pending;

  @override
  Widget build(BuildContext context) {
    final available = widget.allTeams.where((team) => !widget.teams.contains(team)).toList();
    if (pending != null && !available.contains(pending)) pending = null;
    return _ReleaseCard(
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _SectionLabel('PARTICIPATING TEAMS'),
          for (final team in widget.teams)
            InputChip(
              label: Text(team),
              onDeleted: widget.teams.length > 2 ? () => widget.onRemove(team) : null,
            ),
          if (widget.teams.length < 5 && available.isNotEmpty)
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: pending,
                hint: const Text('Add team'),
                items: [for (final team in available) DropdownMenuItem(value: team, child: Text(team))],
                onChanged: (value) => setState(() => pending = value),
              ),
            ),
          if (widget.teams.length < 5)
            FilledButton(
              onPressed: pending == null
                  ? null
                  : () {
                      widget.onAdd(pending!);
                      setState(() => pending = null);
                    },
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }
}

class _ReleaseTeamBoard extends StatelessWidget {
  const _ReleaseTeamBoard({
    required this.team,
    required this.teams,
    required this.catalog,
    required this.activeTab,
    required this.search,
    required this.routedOnly,
    required this.routes,
    required this.onTab,
    required this.onRoute,
    required this.onCashAmount,
  });

  final String team;
  final List<String> teams;
  final _ReleaseCatalog catalog;
  final String activeTab;
  final String search;
  final bool routedOnly;
  final Map<String, String> routes;
  final ValueChanged<String> onTab;
  final Future<void> Function(String, String?) onRoute;
  final ValueChanged<double> onCashAmount;

  @override
  Widget build(BuildContext context) {
    final cap = catalog.capContext(team);
    var items = catalog.byTeam[team]!.where((item) => item.category == activeTab).toList();
    if (search.isNotEmpty) {
      items = items.where((item) {
        final haystack = '${item.asset.label} ${item.detail} ${item.asset.metadata.values.join(' ')}'.toLowerCase();
        return haystack.contains(search);
      }).toList();
    }
    if (routedOnly) items = items.where((item) => routes.containsKey(item.asset.id)).toList();
    return _ReleaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(team, style: const TextStyle(color: _rtFg, fontSize: 21, fontWeight: FontWeight.w900))),
              _Badge(_apronLabel(cap), _apronColor(cap)),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 13,
            runSpacing: 7,
            children: [
              _Metric(_money(cap.teamSalary), 'TEAM SALARY'),
              _Metric(_money(cap.salaryCap), 'CAP'),
              _Metric(_money(cap.firstApron), '1ST APRON'),
              _Metric(_money(cap.secondApron), '2ND APRON'),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final tab in const ['Players', 'Draft', 'Draft Rights', 'Exceptions', 'Cash'])
                ChoiceChip(label: Text(tab), selected: activeTab == tab, onSelected: (_) => onTab(tab)),
            ],
          ),
          if (activeTab == 'Cash') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final amount in const [500000.0, 1000000.0, 2500000.0, 5000000.0])
                  ActionChip(label: Text(_money(amount)), onPressed: () => onCashAmount(amount)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No records match this category/filter.', style: TextStyle(color: _rtMuted)),
            ),
          for (final item in items)
            _ReleaseAssetRow(
              item: item,
              destinations: teams.where((value) => value != team).toList(),
              destination: routes[item.asset.id],
              onRoute: (value) => onRoute(item.asset.id, value),
            ),
        ],
      ),
    );
  }
}

class _ReleaseAssetRow extends StatelessWidget {
  const _ReleaseAssetRow({required this.item, required this.destinations, required this.destination, required this.onRoute});
  final _ReleaseAsset item;
  final List<String> destinations;
  final String? destination;
  final ValueChanged<String?> onRoute;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _showDetails(context, item),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _rtLine))),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.asset.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _rtFg, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(item.detail, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _rtMuted, fontSize: 10, height: 1.35)),
                ],
              );
              final controls = Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Badge(item.status, item.routeable ? _rtGreen : item.status == 'TEAM MECHANISM' ? _rtBlue : _rtRed),
                  _Badge(item.sourceStatus.toUpperCase(), item.sourceStatus == 'verified' ? _rtGreen : item.sourceStatus == 'scenario' ? _rtBlue : _rtAmber),
                  if (item.asset.salary > 0) Text(_money(item.asset.salary), style: const TextStyle(color: _rtFg, fontWeight: FontWeight.w900)),
                  if (item.routeable)
                    SizedBox(
                      width: 112,
                      child: DropdownButtonFormField<String>(
                        initialValue: destinations.contains(destination) ? destination : null,
                        hint: const Text('Send to'),
                        isDense: true,
                        items: [for (final team in destinations) DropdownMenuItem(value: team, child: Text(team))],
                        onChanged: onRoute,
                      ),
                    ),
                ],
              );
              if (constraints.maxWidth < 570) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, const SizedBox(height: 7), controls]);
              }
              return Row(children: [Expanded(child: identity), const SizedBox(width: 8), controls]);
            },
          ),
        ),
      );
}

class _TradeFlow extends StatelessWidget {
  const _TradeFlow({required this.routes, required this.catalog, required this.report});
  final Map<String, String> routes;
  final _ReleaseCatalog catalog;
  final TradeValidationReport report;

  @override
  Widget build(BuildContext context) => _ReleaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: _SectionLabel('LIVE TRANSACTION FLOW')),
              _Badge(report.isValid ? 'STRUCTURALLY VALID' : 'BLOCKED', report.isValid ? _rtGreen : _rtRed),
            ]),
            const SizedBox(height: 8),
            if (routes.isEmpty)
              const Text('Route a player, draft asset, draft right or cash item to begin.', style: TextStyle(color: _rtMuted)),
            if (routes.isNotEmpty)
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final route in routes.entries)
                    if (catalog.byId[route.key] != null)
                      Chip(label: Text('${catalog.byId[route.key]!.asset.originTeam} → ${route.value}: ${catalog.byId[route.key]!.asset.label}')),
                ],
              ),
          ],
        ),
      );
}

class _ReleaseValidation extends StatelessWidget {
  const _ReleaseValidation({required this.report});
  final TradeValidationReport report;

  @override
  Widget build(BuildContext context) => _ReleaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: _SectionLabel('CBA / STRUCTURAL VALIDATION')),
              _Badge('${report.errorCount} ERRORS', report.errorCount == 0 ? _rtGreen : _rtRed),
              const SizedBox(width: 5),
              _Badge('${report.warningCount} WARNINGS', report.warningCount == 0 ? _rtGreen : _rtAmber),
            ]),
            const SizedBox(height: 8),
            for (final entry in report.teamSummaries.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: _rtPanel2, border: Border.all(color: _rtLine)),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    _Metric(entry.key, 'TEAM'),
                    _Metric(_money(entry.value.outgoingSalary), 'MATCH OUT'),
                    _Metric(_money(entry.value.incomingSalary), 'MATCH IN'),
                    _Metric(_money(entry.value.maximumIncomingSalary), 'MAX IN'),
                    _Metric(_money(entry.value.postTradeSalary), 'POST SALARY'),
                    _Metric('${entry.value.projectedRosterPlayers}', 'STD ROSTER'),
                    _Metric(entry.value.apronStatus.toUpperCase(), 'STATUS'),
                  ],
                ),
              ),
            for (final finding in report.findings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 8, color: finding.severity == TradeValidationSeverity.error ? _rtRed : finding.severity == TradeValidationSeverity.warning ? _rtAmber : _rtBlue),
                    const SizedBox(width: 7),
                    Expanded(child: Text('${finding.code}: ${finding.message}', style: const TextStyle(color: _rtMuted, height: 1.4))),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _ReleaseDataBoundary extends StatelessWidget {
  const _ReleaseDataBoundary({required this.frontOffice});
  final FrontOfficeRegistrySnapshot frontOffice;

  @override
  Widget build(BuildContext context) => _ReleaseCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel('EXECUTION DATA BOUNDARY'),
            const SizedBox(height: 7),
            Text(
              frontOffice.remoteAvailable
                  ? 'Connected registry values retain verified / uploaded / modeled source status. The user-supplied 2026-27 salary snapshot is treated as uploaded evidence. A structurally valid result is execution-grade only when the relevant contract clauses, Apron Team Salary, draft ownership/protections, cash ledger and exception balances are authoritative.'
                  : 'The registry is offline or incomplete. The interface remains usable for modeling, but modeled salary proxies and placeholder records are not represented as league-confirmed facts.',
              style: const TextStyle(color: _rtMuted, height: 1.45),
            ),
          ],
        ),
      );
}

void _showDetails(BuildContext context, _ReleaseAsset item) {
  final metadata = item.asset.metadata.entries
      .where((entry) => '${entry.value}'.trim().isNotEmpty && entry.value != false)
      .toList();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _rtPanel,
    builder: (context) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .7,
        maxChildSize: .92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(item.asset.label, style: const TextStyle(color: _rtFg, fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(item.detail, style: const TextStyle(color: _rtMuted, height: 1.45)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              _Badge(item.status, item.routeable ? _rtGreen : item.status == 'TEAM MECHANISM' ? _rtBlue : _rtRed),
              _Badge(item.sourceStatus.toUpperCase(), item.sourceStatus == 'verified' ? _rtGreen : _rtAmber),
              if (item.asset.salary > 0) _Badge(_money(item.asset.salary), _rtBlue),
            ]),
            const SizedBox(height: 16),
            const _SectionLabel('CONTRACT / ASSET METADATA'),
            const SizedBox(height: 7),
            for (final entry in metadata)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _rtLine))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 175, child: Text(entry.key.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: _rtMuted, fontSize: 10, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('${entry.value}', style: const TextStyle(color: _rtFg))),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _rtPanel,
          border: Border.all(color: _rtLine),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(value, style: const TextStyle(color: _rtBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8));
}

class _Badge extends StatelessWidget {
  const _Badge(this.value, this.color);
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: _rtPanel2,
          border: Border.all(color: color.withValues(alpha: .55)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(value, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
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
          Text(value, style: const TextStyle(color: _rtFg, fontSize: 12, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: _rtMuted, fontSize: 8, fontWeight: FontWeight.w800)),
        ],
      );
}

({double? salary, double? guaranteed, String option, bool twoWay}) _contractYear(
    Map<String, dynamic>? contract, String season) {
  if (contract == null || contract['years'] is! List) {
    return (salary: null, guaranteed: null, option: 'none', twoWay: false);
  }
  for (final raw in contract['years'] as List) {
    if (raw is! Map || '${raw['season'] ?? ''}' != season) continue;
    return (
      salary: _positive(raw['cap_charge_override']) ??
          _positive(raw['salary']) ??
          _positive(raw['cap_hit']),
      guaranteed: _positive(raw['guaranteed_amount']),
      option: '${raw['option_type'] ?? 'none'}',
      twoWay: raw['two_way'] == true || '${raw['option_type'] ?? ''}' == 'two_way',
    );
  }
  return (salary: null, guaranteed: null, option: 'none', twoWay: false);
}

String _tradeRestriction(Map<String, dynamic>? contract) {
  if (contract == null) return '';
  final metadata = _metadata(contract);
  if (contract['trade_eligible'] == false || metadata['tradeable'] == false) {
    return '${contract['restriction_reason'] ?? metadata['restriction_reason'] ?? contract['trade_restriction'] ?? 'not currently trade eligible'}';
  }
  if (contract['trade_restricted'] == true || metadata['trade_restricted'] == true) {
    return '${contract['restriction_reason'] ?? metadata['restriction_reason'] ?? contract['trade_restriction'] ?? 'trade restricted'}';
  }
  final value = '${contract['trade_restriction'] ?? contract['restriction_reason'] ?? metadata['restriction_reason'] ?? ''}'.trim();
  return value;
}

String _protection(Map<String, dynamic> record) {
  final raw = record['protections'];
  if (raw is! List) return '${record['protection'] ?? ''}'.trim();
  return raw
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
      .map((row) => _textValue(row['team_id']))
      .where((item) => item != '—')
      .toSet()
      .toList()
    ..sort();
  return values;
}

double _proxySalary(Map<String, dynamic> row) {
  final ppg = _number(row['points_per_game']);
  final mpg = _number(row['minutes_per_game']);
  final value = 2100000 + ppg * 1200000 + mpg * 220000;
  return value < 2100000 ? 2100000 : value;
}

({double cap, double tax, double first, double second}) _levels(String season) =>
    switch (season) {
      '2024-25' => (cap: 140588000, tax: 170814000, first: 178132000, second: 188931000),
      '2025-26' => (cap: 154647000, tax: 187895000, first: 195945000, second: 207824000),
      _ => (cap: 164961000, tax: 200428000, first: 209015000, second: 221686000),
    };

String _option(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  return normalized == 'none' || normalized.isEmpty ? 'standard year' : '$normalized year';
}

String _nameKey(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

String _team(Object? value) => '${value ?? ''}'.trim().toUpperCase();
String _textValue(Object? value) {
  final result = '${value ?? ''}'.trim();
  return result.isEmpty ? '—' : result;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.replaceAll(',', '').replaceAll('%', '')) ?? 0;
}

double? _positive(Object? value) {
  final parsed = _number(value);
  return parsed > 0 ? parsed : null;
}

int _integer(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  final amount = value.abs();
  if (amount >= 1000000) return '$sign\$${(amount / 1000000).toStringAsFixed(2)}M';
  if (amount >= 1000) return '$sign\$${(amount / 1000).toStringAsFixed(0)}K';
  return '$sign\$${amount.toStringAsFixed(0)}';
}

String _apronLabel(TeamCapContext context) => context.aboveSecondApron
    ? 'SECOND APRON'
    : context.aboveFirstApron
        ? 'FIRST APRON'
        : context.aboveTax
            ? 'TAX'
            : context.teamSalary > context.salaryCap
                ? 'OVER CAP'
                : 'CAP ROOM';

Color _apronColor(TeamCapContext context) => context.aboveSecondApron
    ? _rtRed
    : context.aboveFirstApron
        ? _rtAmber
        : context.aboveTax
            ? _rtAmber
            : _rtGreen;

String _encodeMap(Map<String, String> values) => values.entries
    .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
    .join('&');

Map<String, String> _decodeMap(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final result = <String, String>{};
  for (final pair in raw.split('&')) {
    final index = pair.indexOf('=');
    if (index <= 0) continue;
    result[Uri.decodeComponent(pair.substring(0, index))] =
        Uri.decodeComponent(pair.substring(index + 1));
  }
  return result;
}

String _encodeDoubleMap(Map<String, double> values) => values.entries
    .map((entry) => '${Uri.encodeComponent(entry.key)}=${entry.value}')
    .join('&');

Map<String, double> _decodeDoubleMap(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  final result = <String, double>{};
  for (final pair in raw.split('&')) {
    final index = pair.indexOf('=');
    if (index <= 0) continue;
    final value = double.tryParse(pair.substring(index + 1));
    if (value != null) result[Uri.decodeComponent(pair.substring(0, index))] = value;
  }
  return result;
}
