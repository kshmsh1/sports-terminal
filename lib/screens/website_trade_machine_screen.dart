import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/front_office_registry_service.dart';
import '../services/nba_stats_workstation_engine.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/trade_machine_engine.dart';
import '../services/website_nba_api_service.dart';
import 'website_nba_entity_pages.dart';

class WebsiteTradeMachineScreen extends StatefulWidget {
  const WebsiteTradeMachineScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<WebsiteTradeMachineScreen> createState() => _WebsiteTradeMachineScreenState();
}

class _WebsiteTradeMachineScreenState extends State<WebsiteTradeMachineScreen> {
  final _api = const WebsiteNbaApiService();
  final _frontOffice = const FrontOfficeRegistryService();
  final _engine = const TradeMachineEngine();
  final _stats = const NbaStatsWorkstationEngine();

  late Future<_TradePageData> _future;
  final List<String> _teams = [];
  final Map<String, String> _playerRoutes = {};
  final Map<String, String> _pickRoutes = {};
  final Map<String, double> _salaryOverrides = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TradePageData> _load() async {
    final seed = await _api.seasonSnapshot('2025-26', seasonType: 'regular');
    final registry = await _frontOffice.load(session: widget.session, season: '2025-26');
    final data = _TradePageData(seed: seed, registry: registry);
    if (_teams.isEmpty) {
      final available = _teamAbbreviations(seed);
      for (final preferred in const ['BOS', 'NYK', 'LAL', 'OKC']) {
        if (_teams.length >= 2) break;
        if (available.contains(preferred)) _teams.add(preferred);
      }
      for (final team in available) {
        if (_teams.length >= 2) break;
        if (!_teams.contains(team)) _teams.add(team);
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TradePageData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(height: 340, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || snapshot.data == null) {
          return _TradeError(error: snapshot.error, onRetry: () => setState(() => _future = _load()));
        }
        return _buildMachine(context, snapshot.data!);
      },
    );
  }

  Widget _buildMachine(BuildContext context, _TradePageData data) {
    final colors = Theme.of(context).colorScheme;
    final allTeams = _teamAbbreviations(data.seed);
    final playerRows = _stats.buildRows(
      data.seed,
      basis: NbaStatsBasis.perGame,
      seasonType: NbaStatsSeasonType.regular,
    );
    final rosterByTeam = _stats.groupByTeam(playerRows);
    final scenario = _scenario(data, rosterByTeam);
    final report = _engine.validate(scenario);
    final missingSalary = scenario.assignments
        .where((item) => item.asset.type == TradeAssetType.player && item.asset.salary <= 0)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NBA Trade Machine', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 8),
        Text(
          'Build a multi-team transaction, route players and draft assets, enter or use registered salaries, and run the existing CBA validation engine.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final team in _teams)
                  InputChip(
                    label: Text(team),
                    avatar: const Icon(Icons.groups_rounded, size: 18),
                    onDeleted: _teams.length <= 2
                        ? null
                        : () => setState(() {
                              _teams.remove(team);
                              _playerRoutes.removeWhere((_, destination) => destination == team);
                              _pickRoutes.removeWhere((_, destination) => destination == team);
                            }),
                  ),
                if (_teams.length < 5)
                  PopupMenuButton<String>(
                    tooltip: 'Add team',
                    onSelected: (team) => setState(() => _teams.add(team)),
                    itemBuilder: (_) => [
                      for (final team in allTeams.where((team) => !_teams.contains(team)))
                        PopupMenuItem(value: team, child: Text(team)),
                    ],
                    child: const Chip(avatar: Icon(Icons.add_rounded, size: 18), label: Text('Add team')),
                  ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _playerRoutes.clear();
                    _pickRoutes.clear();
                    _salaryOverrides.clear();
                  }),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset trade'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 1050
                ? (constraints.maxWidth - 16 * (_teams.length - 1)) / _teams.length.clamp(2, 3)
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final team in _teams)
                  SizedBox(
                    width: width.clamp(330, constraints.maxWidth),
                    child: _TeamTradeCard(
                      session: widget.session,
                      team: team,
                      teams: _teams,
                      players: rosterByTeam[team] ?? const [],
                      contracts: data.registry.contracts,
                      draftAssets: _teamDraftAssets(data.registry, team),
                      routes: _playerRoutes,
                      pickRoutes: _pickRoutes,
                      overrides: _salaryOverrides,
                      onRoutePlayer: (playerId, destination) => setState(() {
                        if (destination == null) {
                          _playerRoutes.remove(playerId);
                        } else {
                          _playerRoutes[playerId] = destination;
                        }
                      }),
                      onRoutePick: (assetId, destination) => setState(() {
                        if (destination == null) {
                          _pickRoutes.remove(assetId);
                        } else {
                          _pickRoutes[assetId] = destination;
                        }
                      }),
                      onSalary: (playerId, salary) => setState(() {
                        if (salary == null || salary <= 0) {
                          _salaryOverrides.remove(playerId);
                        } else {
                          _salaryOverrides[playerId] = salary;
                        }
                      }),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _ValidationSummary(report: report, missingSalary: missingSalary, registryAvailable: data.registry.remoteAvailable),
      ],
    );
  }

  TradeScenario _scenario(
    _TradePageData data,
    Map<String, List<NbaStatsRow>> rosterByTeam,
  ) {
    final assignments = <TradeAssignment>[];
    for (final team in _teams) {
      for (final row in rosterByTeam[team] ?? const <NbaStatsRow>[]) {
        final destination = _playerRoutes[row.playerId];
        if (destination == null || !_teams.contains(destination) || destination == team) continue;
        final registeredSalary = _contractSalary(data.registry.contracts, row.playerId, row.player, team);
        final salary = _salaryOverrides[row.playerId] ?? registeredSalary ?? 0;
        assignments.add(
          TradeAssignment(
            asset: TradeAsset(
              id: 'player:${row.playerId}',
              type: TradeAssetType.player,
              label: row.player,
              originTeam: team,
              salary: salary,
              metadata: {
                'player_id': row.playerId,
                'salary_source': _salaryOverrides.containsKey(row.playerId)
                    ? 'user-entered'
                    : registeredSalary != null
                        ? 'front-office-registry'
                        : 'missing',
              },
            ),
            destinationTeam: destination,
          ),
        );
      }
      for (final wrapper in _teamDraftAssets(data.registry, team)) {
        final id = wrapper['id']?.toString() ?? '';
        final destination = _pickRoutes[id];
        if (id.isEmpty || destination == null || destination == team) continue;
        final record = _map(wrapper['record']);
        assignments.add(
          TradeAssignment(
            asset: TradeAsset(
              id: 'pick:$id',
              type: TradeAssetType.draftPick,
              label: _pickLabel(record),
              originTeam: team,
              metadata: record,
            ),
            destinationTeam: destination,
          ),
        );
      }
    }
    return TradeScenario(
      id: 'website-trade-machine',
      name: 'NBA Trade Machine scenario',
      operatingSeason: '2025-26',
      teams: List<String>.from(_teams),
      assignments: assignments,
      capContexts: {
        for (final team in _teams) team: _capContext(data.registry, team),
      },
      asOfDateIso: DateTime.now().toUtc().toIso8601String(),
    );
  }
}

class _TeamTradeCard extends StatelessWidget {
  const _TeamTradeCard({
    required this.session,
    required this.team,
    required this.teams,
    required this.players,
    required this.contracts,
    required this.draftAssets,
    required this.routes,
    required this.pickRoutes,
    required this.overrides,
    required this.onRoutePlayer,
    required this.onRoutePick,
    required this.onSalary,
  });

  final AppSession session;
  final String team;
  final List<String> teams;
  final List<NbaStatsRow> players;
  final List<Map<String, dynamic>> contracts;
  final List<Map<String, dynamic>> draftAssets;
  final Map<String, String> routes;
  final Map<String, String> pickRoutes;
  final Map<String, double> overrides;
  final void Function(String, String?) onRoutePlayer;
  final void Function(String, String?) onRoutePick;
  final void Function(String, double?) onSalary;

  @override
  Widget build(BuildContext context) {
    final sorted = [...players]
      ..sort((a, b) => (b.value('min') ?? 0).compareTo(a.value('min') ?? 0));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(team.substring(0, 1))),
                const SizedBox(width: 10),
                Expanded(child: Text(team, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900))),
              ],
            ),
            const SizedBox(height: 16),
            Text('Players', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final row in sorted.take(18))
              _PlayerTradeRow(
                session: session,
                team: team,
                teams: teams,
                row: row,
                registeredSalary: _contractSalary(contracts, row.playerId, row.player, team),
                overrideSalary: overrides[row.playerId],
                destination: routes[row.playerId],
                onRoute: (destination) => onRoutePlayer(row.playerId, destination),
                onSalary: (salary) => onSalary(row.playerId, salary),
              ),
            if (draftAssets.isNotEmpty) ...[
              const Divider(height: 26),
              Text('Draft assets', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              for (final wrapper in draftAssets.take(12))
                _AssetTradeRow(
                  label: _pickLabel(_map(wrapper['record'])),
                  team: team,
                  teams: teams,
                  destination: pickRoutes[wrapper['id']?.toString() ?? ''],
                  onRoute: (destination) => onRoutePick(wrapper['id']?.toString() ?? '', destination),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerTradeRow extends StatefulWidget {
  const _PlayerTradeRow({
    required this.session,
    required this.team,
    required this.teams,
    required this.row,
    required this.registeredSalary,
    required this.overrideSalary,
    required this.destination,
    required this.onRoute,
    required this.onSalary,
  });

  final AppSession session;
  final String team;
  final List<String> teams;
  final NbaStatsRow row;
  final double? registeredSalary;
  final double? overrideSalary;
  final String? destination;
  final ValueChanged<String?> onRoute;
  final ValueChanged<double?> onSalary;

  @override
  State<_PlayerTradeRow> createState() => _PlayerTradeRowState();
}

class _PlayerTradeRowState extends State<_PlayerTradeRow> {
  late final TextEditingController salary;

  @override
  void initState() {
    super.initState();
    final value = widget.overrideSalary ?? widget.registeredSalary;
    salary = TextEditingController(text: value == null || value <= 0 ? '' : (value / 1000000).toStringAsFixed(2));
  }

  @override
  void dispose() {
    salary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: InkWell(
              onTap: () => openWebsiteNbaPlayerPage(
                context,
                session: widget.session,
                playerKey: widget.row.playerId,
                playerName: widget.row.player,
              ),
              child: Text(widget.row.player, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 82,
            child: TextField(
              controller: salary,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '\$M', isDense: true),
              onChanged: (value) {
                final millions = double.tryParse(value.trim());
                widget.onSalary(millions == null ? null : millions * 1000000);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: DropdownButtonFormField<String>(
              initialValue: widget.destination,
              decoration: const InputDecoration(labelText: 'To', isDense: true),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Keep')),
                for (final target in widget.teams.where((value) => value != widget.team))
                  DropdownMenuItem(value: target, child: Text(target)),
              ],
              onChanged: widget.onRoute,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetTradeRow extends StatelessWidget {
  const _AssetTradeRow({required this.label, required this.team, required this.teams, required this.destination, required this.onRoute});
  final String label;
  final String team;
  final List<String> teams;
  final String? destination;
  final ValueChanged<String?> onRoute;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: DropdownButtonFormField<String>(
                initialValue: destination,
                decoration: const InputDecoration(labelText: 'To', isDense: true),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Keep')),
                  for (final target in teams.where((value) => value != team)) DropdownMenuItem(value: target, child: Text(target)),
                ],
                onChanged: onRoute,
              ),
            ),
          ],
        ),
      );
}

class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({required this.report, required this.missingSalary, required this.registryAvailable});
  final TradeValidationReport report;
  final int missingSalary;
  final bool registryAvailable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ready = report.isValid && missingSalary == 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ready ? Icons.check_circle_outline_rounded : Icons.rule_rounded, color: ready ? colors.primary : colors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ready ? 'Trade passes modeled structural checks' : 'Trade needs review',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                Text('${report.errorCount} errors · ${report.warningCount} warnings'),
              ],
            ),
            if (missingSalary > 0) ...[
              const SizedBox(height: 12),
              Text('$missingSalary routed player${missingSalary == 1 ? '' : 's'} still need a salary. Enter the salary in millions before treating salary matching as meaningful.', style: TextStyle(color: colors.error)),
            ],
            if (!registryAvailable) ...[
              const SizedBox(height: 10),
              const Text('The shared front-office registry is unavailable, so contract/cap facts may rely on local cached records or user-entered values.'),
            ],
            const SizedBox(height: 16),
            for (final team in report.teamSummaries.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${team.team}: outgoing ${_money(team.outgoingSalary)} · incoming ${_money(team.incomingSalary)} · post-trade ${_money(team.postTradeSalary)} · ${team.apronStatus}'),
              ),
            if (report.findings.isNotEmpty) const Divider(height: 24),
            for (final finding in report.findings.take(30))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      finding.severity == TradeValidationSeverity.error
                          ? Icons.error_outline_rounded
                          : finding.severity == TradeValidationSeverity.warning
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(finding.message)),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Text(
              'This engine evaluates modeled CBA structure, salary matching, apron/hard-cap constraints and asset rules. Final execution still requires authoritative current contracts, team cap positions, transaction dates, exceptions, pick protections and league confirmation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeError extends StatelessWidget {
  const _TradeError({required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trade Machine data unavailable', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('The Trade Machine needs the current canonical NBA roster plus front-office contract/cap records. ${error ?? ''}'),
              const SizedBox(height: 18),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _TradePageData {
  const _TradePageData({required this.seed, required this.registry});
  final NbaTerminalSeedSnapshot seed;
  final FrontOfficeRegistrySnapshot registry;
}

List<String> _teamAbbreviations(NbaTerminalSeedSnapshot seed) {
  final values = <String>{};
  for (final row in seed.teams) {
    final abbreviation = (row['team_abbreviation'] ?? row['abbreviation'] ?? '').toString().trim().toUpperCase();
    if (abbreviation.isNotEmpty) values.add(abbreviation);
  }
  final result = values.toList()..sort();
  return result;
}

List<Map<String, dynamic>> _teamDraftAssets(FrontOfficeRegistrySnapshot registry, String team) {
  return registry.draftAssets.where((wrapper) {
    final record = _map(wrapper['record']);
    return (record['current_team_id'] ?? record['team_id'] ?? '').toString().toUpperCase() == team;
  }).toList();
}

double? _contractSalary(
  List<Map<String, dynamic>> contracts,
  String playerId,
  String playerName,
  String team,
) {
  for (final wrapper in contracts) {
    final record = _map(wrapper['record']);
    final idMatch = (record['player_id'] ?? '').toString() == playerId;
    final nameMatch = (record['player_name'] ?? '').toString().toLowerCase() == playerName.toLowerCase();
    final teamMatch = (record['team_id'] ?? '').toString().toUpperCase() == team;
    if ((!idMatch && !nameMatch) || !teamMatch) continue;
    for (final year in _maps(record['years'])) {
      if ((year['season'] ?? '').toString() != '2025-26') continue;
      final salary = _num(year['salary']);
      if (salary != null && salary > 0) return salary;
    }
  }
  return null;
}

TeamCapContext _capContext(FrontOfficeRegistrySnapshot registry, String team) {
  Map<String, dynamic>? record;
  for (final wrapper in registry.teamPositions) {
    final candidate = _map(wrapper['record']);
    if ((candidate['team_id'] ?? '').toString().toUpperCase() == team && (candidate['season'] ?? '').toString() == '2025-26') {
      record = candidate;
      break;
    }
  }
  final salaries = registry.contracts.fold<double>(0, (sum, wrapper) {
    final contract = _map(wrapper['record']);
    if ((contract['team_id'] ?? '').toString().toUpperCase() != team) return sum;
    for (final year in _maps(contract['years'])) {
      if ((year['season'] ?? '').toString() == '2025-26') return sum + (_num(year['salary']) ?? 0);
    }
    return sum;
  });
  return TeamCapContext(
    team: team,
    teamSalary: _num(record?['active_salary']) ?? salaries,
    salaryCap: _num(record?['salary_cap']) ?? 154647000,
    taxLine: _num(record?['luxury_tax']) ?? 187895000,
    firstApron: _num(record?['first_apron']) ?? 195945000,
    secondApron: _num(record?['second_apron']) ?? 207824000,
    hardCappedAt: (_num(record?['hard_cap']) ?? 0) > 0 ? _num(record?['hard_cap']) : null,
  );
}

String _pickLabel(Map<String, dynamic> record) {
  final year = (record['draft_year'] ?? '').toString();
  final round = (record['round'] ?? '').toString();
  final original = (record['original_team_id'] ?? record['original_team'] ?? '').toString();
  final protection = (record['protection'] ?? record['protection_text'] ?? '').toString();
  return [
    if (year.isNotEmpty) year,
    if (round.isNotEmpty) 'Round $round',
    if (original.isNotEmpty) 'via $original',
    if (protection.isNotEmpty) protection,
  ].join(' · ');
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) _map(item)];
}

double? _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _money(double value) {
  if (!value.isFinite) return '—';
  return '\$${(value / 1000000).toStringAsFixed(1)}M';
}
