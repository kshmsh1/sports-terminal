import 'package:flutter/material.dart';

import '../services/nba_complete_draft_asset_repository.dart';
import '../services/nba_contract_status_reference_2026.dart';
import '../services/nba_front_office_tracker_2026.dart';
import '../services/nba_future_draft_asset_repository.dart';
import '../services/nba_league_environment_2026.dart';
import '../services/nba_team_cap_reference_2026.dart';
import '../services/nba_team_salary_position_2026.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_trade_kicker_reference_2026.dart';
import '../services/nba_trade_supplemental_assets_2026.dart';
import '../services/nba_two_way_contract_reference_2026.dart';
import '../services/trade_machine_engine.dart';
import '../services/trade_machine_saved_trade_store.dart';

enum _TradePage { build, recent }
enum _TeamFilter { all, east, west }
enum _AssetTab { roster, draftPicks, draftRights, cash, freeAgents }
enum _RestrictionMode { on, off, deadline }

class ProductTradeMachineVideoScreen extends StatefulWidget {
  const ProductTradeMachineVideoScreen({super.key});

  @override
  State<ProductTradeMachineVideoScreen> createState() =>
      _ProductTradeMachineVideoScreenState();
}

class _ProductTradeMachineVideoScreenState
    extends State<ProductTradeMachineVideoScreen> {
  final _contracts = const NbaTradeContractRepository();
  final _drafts = const NbaCompleteDraftAssetRepository();
  final _engine = const TradeMachineEngine();
  final _savedStore = const TradeMachineSavedTradeStore();

  late final Future<NbaTradeContractSnapshot> _future = _contracts.load();

  _TradePage _page = _TradePage.build;
  _TeamFilter _teamFilter = _TeamFilter.all;
  _AssetTab _assetTab = _AssetTab.roster;
  _RestrictionMode _restrictionMode = _RestrictionMode.on;

  final List<String> _teams = [];
  String? _activeTeam;
  bool _builderActive = false;
  bool _showFinancials = false;
  String _search = '';

  final Map<String, String> _routes = {};
  final Map<String, double> _cashAmounts = {};
  final Map<String, String> _cashDestinations = {};
  final Map<String, String> _signAndTradeDestinations = {};
  final Map<String, double> _signAndTradeSalaries = {};
  final Set<String> _expandedFreeAgents = {};

  List<TradeMachineSavedTrade> _savedTrades = const [];
  String _recentSearch = '';
  String _recentTeam = 'All';

  static final DateTime _currentTradeDate = DateTime(2026, 9, 30);
  static final DateTime _modeledDeadlineDate = DateTime(2027, 2, 4);

  @override
  void initState() {
    super.initState();
    _loadSavedTrades();
  }

  Future<void> _loadSavedTrades() async {
    final rows = await _savedStore.load();
    if (mounted) setState(() => _savedTrades = rows);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTradeContractSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return _surface(
              context,
              child: Text('Unable to load Trade Machine data: ${snapshot.error}'),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final draftAssets = _drafts.all();
        _repairTeams(data.teams);
        final scenario = _builderActive
            ? _scenario(data, draftAssets)
            : null;
        final report = scenario == null ? null : _engine.validate(scenario);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            const SizedBox(height: 14),
            if (_page == _TradePage.recent)
              _recentTrades(context, data)
            else if (!_builderActive)
              _teamSelector(context, data)
            else
              _builder(context, data, draftAssets, scenario!, report!),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NBA Trade Machine',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 4),
              Text(
                '2026-27 season · build, validate, save and reload multi-team trades.',
              ),
            ],
          ),
        ),
        SegmentedButton<_TradePage>(
          segments: const [
            ButtonSegment(
              value: _TradePage.build,
              label: Text('Build a Trade'),
              icon: Icon(Icons.swap_horiz_rounded),
            ),
            ButtonSegment(
              value: _TradePage.recent,
              label: Text('Recent Trades'),
              icon: Icon(Icons.history_rounded),
            ),
          ],
          selected: {_page},
          showSelectedIcon: false,
          onSelectionChanged: (value) {
            setState(() => _page = value.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? colors.onPrimaryContainer
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _teamSelector(BuildContext context, NbaTradeContractSnapshot data) {
    final teams = data.teams.where((team) {
      final conference = _teamMeta[team]?.conference ?? '';
      return switch (_teamFilter) {
        _TeamFilter.all => true,
        _TeamFilter.east => conference == 'East',
        _TeamFilter.west => conference == 'West',
      };
    }).toList()
      ..sort((a, b) =>
          (_teamMeta[a]?.name ?? a).compareTo(_teamMeta[b]?.name ?? b));

    return _surface(
      context,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  initialValue: '2026-27',
                  decoration: const InputDecoration(
                    labelText: 'Season',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: '2026-27', child: Text('2026-27')),
                  ],
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<_TeamFilter>(
                segments: const [
                  ButtonSegment(value: _TeamFilter.all, label: Text('All teams')),
                  ButtonSegment(value: _TeamFilter.east, label: Text('East')),
                  ButtonSegment(value: _TeamFilter.west, label: Text('West')),
                ],
                selected: {_teamFilter},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _teamFilter = value.first),
              ),
              const Spacer(),
              Text(
                '${_teams.length} teams selected',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: _teams.isEmpty
                    ? null
                    : () => setState(() => _teams.clear()),
                child: const Text('Clear'),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _teams.length >= 2
                    ? () => setState(() {
                          _builderActive = true;
                          _activeTeam = _teams.first;
                          _assetTab = _AssetTab.roster;
                        })
                    : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Build a Trade'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1180
                  ? 5
                  : constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 620
                          ? 3
                          : 2;
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final team in teams)
                    SizedBox(
                      width: cardWidth,
                      child: _teamSelectCard(context, data, team),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Choose 2-5 teams. The cap-status label is based on the static 2026-27 team salary and hard-cap ledger.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamSelectCard(
    BuildContext context,
    NbaTradeContractSnapshot data,
    String team,
  ) {
    final selected = _teams.contains(team);
    final meta = _teamMeta[team] ?? _TeamMeta(team, team, '');
    final status = _operatingAs(team, data);
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: .55)
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? colors.primary : Theme.of(context).dividerColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            if (selected) {
              _teams.remove(team);
            } else if (_teams.length < 5) {
              _teams.add(team);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              _teamBadge(context, team, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_rounded : Icons.add_rounded,
                size: 18,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _builder(
    BuildContext context,
    NbaTradeContractSnapshot data,
    List<NbaFutureDraftAsset> draftAssets,
    TradeScenario scenario,
    TradeValidationReport report,
  ) {
    final team = _activeTeam ?? _teams.first;
    final effectiveDate = _effectiveTradeDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _builderToolbar(context, data, team),
        const SizedBox(height: 12),
        _teamFinancialStrip(context, data, team),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final left = _assetBrowser(context, data, draftAssets, team);
            final right = _tradeSummary(context, scenario, report, data);
            if (constraints.maxWidth < 1060) {
              return Column(
                children: [
                  left,
                  const SizedBox(height: 12),
                  right,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: left),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: right),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          _restrictionMode == _RestrictionMode.off
              ? 'Trade-timing restrictions are disabled for sandboxing. Salary matching, apron rules, pick rules and other CBA checks remain active.'
              : 'Eligibility is evaluated as of ${_dateLabel(effectiveDate)}. Timing-restricted players cannot be routed until their source-backed eligible date.',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _builderToolbar(
    BuildContext context,
    NbaTradeContractSnapshot data,
    String activeTeam,
  ) {
    final available = data.teams.where((item) => !_teams.contains(item)).toList()
      ..sort();

    return _surface(
      context,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final team in _teams)
            ChoiceChip(
              avatar: _teamBadge(context, team, size: 24),
              label: Text(_teamMeta[team]?.shortName ?? team),
              selected: activeTeam == team,
              onSelected: (_) => setState(() {
                _activeTeam = team;
                _assetTab = _AssetTab.roster;
                _search = '';
              }),
            ),
          if (_teams.length < 5)
            PopupMenuButton<String>(
              tooltip: 'Add team',
              onSelected: (team) => setState(() {
                _teams.add(team);
                _activeTeam = team;
                _repairTradeState();
              }),
              itemBuilder: (_) => [
                for (final team in available)
                  PopupMenuItem(
                    value: team,
                    child: Text('$team · ${_teamMeta[team]?.name ?? team}'),
                  ),
              ],
              child: const Chip(
                avatar: Icon(Icons.add_rounded, size: 17),
                label: Text('Add team'),
              ),
            ),
          const SizedBox(width: 10),
          SegmentedButton<_RestrictionMode>(
            segments: const [
              ButtonSegment(
                value: _RestrictionMode.on,
                label: Text('On'),
                tooltip: 'Restrictions on',
              ),
              ButtonSegment(
                value: _RestrictionMode.off,
                label: Text('Off'),
                tooltip: 'Restrictions off',
              ),
              ButtonSegment(
                value: _RestrictionMode.deadline,
                label: Text('Deadline'),
                tooltip: 'Modeled trade-deadline eligibility',
              ),
            ],
            selected: {_restrictionMode},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                setState(() => _restrictionMode = value.first),
          ),
          IconButton(
            tooltip: 'Trade research',
            onPressed: _openTradeResearch,
            icon: const Icon(Icons.manage_search_rounded),
          ),
          IconButton(
            tooltip: 'Reset trade',
            onPressed: _clearTrade,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            tooltip: 'Back to team selection',
            onPressed: () => setState(() {
              _builderActive = false;
              _activeTeam = null;
            }),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
    );
  }

  Widget _teamFinancialStrip(
    BuildContext context,
    NbaTradeContractSnapshot data,
    String team,
  ) {
    final salary = _teamSalary(team, data);
    final metrics = [
      ('Operating As', _operatingAs(team, data), null),
      ('Cap Space', _signedMoney(NbaLeagueEnvironment202627.salaryCap - salary),
          NbaLeagueEnvironment202627.salaryCap - salary),
      ('1st Apron Space',
          _signedMoney(NbaLeagueEnvironment202627.firstApron - salary),
          NbaLeagueEnvironment202627.firstApron - salary),
      ('2nd Apron Space',
          _signedMoney(NbaLeagueEnvironment202627.secondApron - salary),
          NbaLeagueEnvironment202627.secondApron - salary),
      ('Tax Space', _signedMoney(NbaLeagueEnvironment202627.luxuryTax - salary),
          NbaLeagueEnvironment202627.luxuryTax - salary),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 4 * 10) / 5
            : constraints.maxWidth >= 520
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in metrics)
              SizedBox(
                width: width,
                child: _metricCard(
                  context,
                  item.$1,
                  item.$2,
                  item.$3,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _metricCard(
    BuildContext context,
    String label,
    String value,
    double? signedValue,
  ) {
    final colors = Theme.of(context).colorScheme;
    final valueColor = signedValue == null
        ? colors.onSurface
        : signedValue >= 0
            ? const Color(0xFF4CAF7A)
            : const Color(0xFFD85B67);
    return _surface(
      context,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _assetBrowser(
    BuildContext context,
    NbaTradeContractSnapshot data,
    List<NbaFutureDraftAsset> draftAssets,
    String team,
  ) {
    return _surface(
      context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: SegmentedButton<_AssetTab>(
                segments: const [
                  ButtonSegment(value: _AssetTab.roster, label: Text('Active Roster')),
                  ButtonSegment(value: _AssetTab.draftPicks, label: Text('Draft Picks')),
                  ButtonSegment(value: _AssetTab.draftRights, label: Text('Draft Rights')),
                  ButtonSegment(value: _AssetTab.cash, label: Text('Cash')),
                  ButtonSegment(value: _AssetTab.freeAgents, label: Text('Free Agents')),
                ],
                selected: {_assetTab},
                showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() {
                  _assetTab = value.first;
                  _search = '';
                }),
              ),
            ),
          ),
          if (_assetTab == _AssetTab.roster ||
              _assetTab == _AssetTab.freeAgents) ...[
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: _assetTab == _AssetTab.roster
                      ? 'Search players...'
                      : 'Search free-agent rights...',
                  isDense: true,
                ),
              ),
            ),
          ],
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: switch (_assetTab) {
              _AssetTab.roster => _rosterTab(context, data, team),
              _AssetTab.draftPicks =>
                _draftPicksTab(context, draftAssets, team),
              _AssetTab.draftRights => _draftRightsTab(context, team),
              _AssetTab.cash => _cashTab(context, team),
              _AssetTab.freeAgents => _freeAgentsTab(context, team),
            },
          ),
        ],
      ),
    );
  }

  Widget _rosterTab(
    BuildContext context,
    NbaTradeContractSnapshot data,
    String team,
  ) {
    final query = _search.trim().toLowerCase();
    final players = data
        .forTeam(team, '2026-27')
        .where((item) =>
            query.isEmpty || item.player.toLowerCase().contains(query))
        .toList();

    return Column(
      children: [
        _tableHeader(context, const ['PLAYER', '2026-27 CAP HIT', 'CONTRACT', 'ACTION']),
        for (final player in players)
          _playerRow(context, player),
        if (players.isEmpty) _empty('No roster players match this search.'),
      ],
    );
  }

  Widget _playerRow(BuildContext context, NbaTradeContract player) {
    final restriction = _restrictionFor(player.player);
    final blocked = _playerBlocked(player.player);
    final kicker = NbaTradeKickerReference202627.forPlayer(player.player);
    final twoWay = NbaTwoWayContractReference202627.records.any(
      (item) => item.player == player.player && item.team == player.team,
    );
    final routedTo = _routes[player.id];

    return Container(
      decoration: BoxDecoration(
        color: routedTo != null
            ? const Color(0xFF2E7D32).withValues(alpha: .10)
            : blocked
                ? const Color(0xFFC62828).withValues(alpha: .08)
                : null,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 210,
            child: Row(
              children: [
                _initialAvatar(context, player.player),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.player, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Wrap(
                        spacing: 5,
                        runSpacing: 3,
                        children: [
                          if (twoWay) _tag(context, 'Two-Way'),
                          if (kicker != null) _tag(context, 'Trade Kicker'),
                          if (restriction?.hasTradeVeto == true)
                            _tag(context, 'Consent'),
                          if (blocked)
                            _tag(
                              context,
                              'Restricted until ${restriction?.eligibleDate ?? 'source date'}',
                              danger: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              _money(player.salaryFor('2026-27')),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              player.guaranteed == null
                  ? '2026-27 contract'
                  : 'Guaranteed ${_money(player.guaranteed!)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: _routeControl(
              assetId: player.id,
              originTeam: player.team,
              enabled: !blocked,
            ),
          ),
        ],
      ),
    );
  }

  Widget _draftPicksTab(
    BuildContext context,
    List<NbaFutureDraftAsset> all,
    String team,
  ) {
    final assets = all.where((item) => item.team == team).toList()
      ..sort((a, b) {
        final year = a.year.compareTo(b.year);
        return year != 0 ? year : a.round.compareTo(b.round);
      });

    return Column(
      children: [
        for (final asset in assets)
          _genericAssetRow(
            context,
            title: '${asset.year}, Round ${asset.round}: ${asset.label}',
            subtitle: asset.description,
            warning: asset.frozen || !asset.tradable,
            badges: [
              if (asset.frozen) 'Frozen',
              if (asset.conditional) 'Conditional',
              if (asset.swapRight) 'Swap',
            ],
            control: _routeControl(
              assetId: asset.id,
              originTeam: team,
              enabled: asset.tradable,
            ),
          ),
        if (assets.isEmpty) _empty('No normalized draft assets for this team.'),
      ],
    );
  }

  Widget _draftRightsTab(BuildContext context, String team) {
    final rights = NbaTradeSupplementalAssets202627.draftRightsFor(team);
    return Column(
      children: [
        for (final item in rights)
          _genericAssetRow(
            context,
            title: '${item.player} (draft rights)',
            subtitle: '${item.position} · ${item.note}',
            control: _routeControl(
              assetId: item.id,
              originTeam: team,
              enabled: true,
            ),
          ),
        if (rights.isEmpty)
          _empty(
            'No source-certified draft-rights records are installed for $team yet. The tab stays source-gated rather than inventing rights.',
          ),
      ],
    );
  }

  Widget _cashTab(BuildContext context, String team) {
    final reference = NbaCashTradeReference202627.teams[team];
    final available = reference?.availableToSend ?? 0;
    final destinations = _teams.where((item) => item != team).toList();
    final destination = _cashDestinations[team];
    final amount = (_cashAmounts[team] ?? 0).clamp(0, available).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _genericAssetRow(
          context,
          title: 'Cash considerations',
          subtitle:
              'Annual send capacity remaining: ${_money(available)} · receive capacity: ${_money(reference?.availableToReceive ?? 0)}',
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: destinations.contains(destination) ? destination : null,
          decoration: const InputDecoration(
            labelText: 'Send cash to',
            isDense: true,
          ),
          items: [
            for (final item in destinations)
              DropdownMenuItem(value: item, child: Text(_teamName(item))),
          ],
          onChanged: (value) => setState(() {
            if (value == null) {
              _cashDestinations.remove(team);
            } else {
              _cashDestinations[team] = value;
            }
          }),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: amount,
                min: 0,
                max: available <= 0 ? 1 : available,
                divisions: available <= 0 ? null : 100,
                label: _money(amount),
                onChanged: available <= 0
                    ? null
                    : (value) => setState(() => _cashAmounts[team] = value),
              ),
            ),
            SizedBox(
              width: 120,
              child: Text(
                _money(amount),
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        if (reference?.sendRestrictedAboveSecondApron == true)
          const Text(
            'Source note: cash sending is restricted while this team is above the second apron.',
            style: TextStyle(color: Color(0xFFD58B45), fontSize: 11),
          ),
      ],
    );
  }

  Widget _freeAgentsTab(BuildContext context, String team) {
    final query = _search.trim().toLowerCase();
    final rights = NbaTradeSupplementalAssets202627.freeAgentRightsFor(team)
        .where((item) =>
            query.isEmpty || item.player.toLowerCase().contains(query))
        .toList();

    return Column(
      children: [
        if (rights.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  for (final item in rights) {
                    _signAndTradeDestinations.remove(item.id);
                    _signAndTradeSalaries.remove(item.id);
                    _expandedFreeAgents.remove(item.id);
                  }
                });
              },
              child: const Text('Renounce all holds'),
            ),
          ),
        for (final item in rights) _freeAgentRow(context, item),
        if (rights.isEmpty)
          _empty(
            'No source-certified free-agent rights are installed for $team yet.',
          ),
      ],
    );
  }

  Widget _freeAgentRow(BuildContext context, NbaTradeFreeAgentRight item) {
    final expanded = _expandedFreeAgents.contains(item.id);
    final destinations = _teams.where((team) => team != item.team).toList();
    final destination = _signAndTradeDestinations[item.id];
    final min = item.signAndTradeMinimum ?? 0;
    final max = item.signAndTradeMaximum ?? min;
    final salary = (_signAndTradeSalaries[item.id] ?? min)
        .clamp(min, max <= min ? min : max)
        .toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        color: destination != null
            ? const Color(0xFF2E7D32).withValues(alpha: .10)
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _initialAvatar(context, item.player),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.player, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      '${item.position} · ${item.rights}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  _money(item.capHold),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 150,
                child: OutlinedButton.icon(
                  onPressed: item.signAndTradeReady
                      ? () => setState(() {
                            if (expanded) {
                              _expandedFreeAgents.remove(item.id);
                            } else {
                              _expandedFreeAgents.add(item.id);
                              _signAndTradeSalaries.putIfAbsent(item.id, () => min);
                            }
                          })
                      : null,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(item.signAndTradeReady ? 'Action' : 'Rights only'),
                ),
              ),
            ],
          ),
          if (expanded && item.signAndTradeReady) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        destinations.contains(destination) ? destination : null,
                    decoration: const InputDecoration(
                      labelText: 'Sign-and-trade to',
                      isDense: true,
                    ),
                    items: [
                      for (final team in destinations)
                        DropdownMenuItem(
                          value: team,
                          child: Text(_teamName(team)),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      if (value == null) {
                        _signAndTradeDestinations.remove(item.id);
                      } else {
                        _signAndTradeDestinations[item.id] = value;
                      }
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 130,
                  child: Text(
                    _money(salary),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            Slider(
              value: salary,
              min: min,
              max: max,
              divisions: 100,
              label: _money(salary),
              onChanged: (value) =>
                  setState(() => _signAndTradeSalaries[item.id] = value),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Source-backed S&T range: ${_money(min)} – ${_money(max)}. A sign-and-trade is still subject to hard-cap and matching rules.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _routeControl({
    required String assetId,
    required String originTeam,
    required bool enabled,
  }) {
    final current = _routes[assetId];
    final destinations = _teams.where((team) => team != originTeam).toList();

    if (current != null && destinations.contains(current)) {
      return InputChip(
        label: Text(_teamMeta[current]?.shortName ?? current),
        onDeleted: () => setState(() => _routes.remove(assetId)),
      );
    }

    if (!enabled) {
      return const OutlinedButton(
        onPressed: null,
        child: Text('Restricted'),
      );
    }

    if (destinations.length == 1) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _routes[assetId] = destinations.first),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Trade'),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Trade asset',
      onSelected: (team) => setState(() => _routes[assetId] = team),
      itemBuilder: (_) => [
        for (final team in destinations)
          PopupMenuItem(
            value: team,
            child: Text('Trade to ${_teamName(team)}'),
          ),
      ],
      child: const OutlinedButton(
        onPressed: null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 16),
            SizedBox(width: 5),
            Text('Trade'),
          ],
        ),
      ),
    );
  }

  Widget _tradeSummary(
    BuildContext context,
    TradeScenario scenario,
    TradeValidationReport report,
    NbaTradeContractSnapshot data,
  ) {
    final hasActivity = scenario.assignments.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    return _surface(
      context,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: !hasActivity
                      ? colors.surfaceContainerHighest
                      : report.isValid
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  !hasActivity
                      ? 'BUILD A TRADE'
                      : report.isValid
                          ? 'PASS'
                          : 'FAIL',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: !hasActivity ? colors.onSurface : Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              FilterChip(
                label: const Text('Financials'),
                selected: _showFinancials,
                onSelected: (value) => setState(() => _showFinancials = value),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: hasActivity ? () => _saveTrade(scenario, report, data) : null,
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Snapshot'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasActivity)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Choose assets on the left. Each selected team’s incoming package and CBA result will appear here.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          for (final team in _teams)
            _teamAcquireCard(context, team, scenario, report),
          if (hasActivity) ...[
            const SizedBox(height: 4),
            for (final finding in report.findings.where((item) => item.team == null))
              _findingLine(context, finding),
          ],
        ],
      ),
    );
  }

  Widget _teamAcquireCard(
    BuildContext context,
    String team,
    TradeScenario scenario,
    TradeValidationReport report,
  ) {
    final incoming = scenario.incomingFor(team).toList();
    final findings = report.findings.where((item) => item.team == team).toList();
    final hasError = findings.any(
      (item) => item.severity == TradeValidationSeverity.error,
    );
    final summary = report.teamSummaries[team];
    final accent = hasError ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .08),
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            child: Row(
              children: [
                _teamBadge(context, team, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_teamName(team)} Acquire',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          if (incoming.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'No incoming assets.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final assignment in incoming)
              _incomingRow(context, assignment),
          if (summary != null && _showFinancials)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 5,
                children: [
                  _smallMetric('Match out', _money(summary.outgoingSalary)),
                  _smallMetric('Match in', _money(summary.incomingSalary)),
                  _smallMetric('Max in', _money(summary.maximumIncomingSalary)),
                  _smallMetric('Post salary', _money(summary.postTradeSalary)),
                  _smallMetric('Roster', '${summary.projectedRosterPlayers}'),
                ],
              ),
            ),
          for (final finding in findings)
            _findingLine(context, finding),
        ],
      ),
    );
  }

  Widget _incomingRow(BuildContext context, TradeAssignment assignment) {
    final asset = assignment.asset;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Icon(_assetIcon(asset.type), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(asset.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (asset.type == TradeAssetType.player && asset.salary > 0)
            Text(
              _money(asset.salary),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeAssignment(asset.id),
            icon: const Icon(Icons.undo_rounded, size: 17),
          ),
        ],
      ),
    );
  }

  Widget _findingLine(BuildContext context, TradeValidationFinding finding) {
    final color = switch (finding.severity) {
      TradeValidationSeverity.error => const Color(0xFFC62828),
      TradeValidationSeverity.warning => const Color(0xFFD58B45),
      TradeValidationSeverity.info => const Color(0xFF2E7D32),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Text(
        finding.message,
        style: TextStyle(color: color, fontSize: 11, height: 1.35),
      ),
    );
  }

  Widget _recentTrades(
    BuildContext context,
    NbaTradeContractSnapshot data,
  ) {
    final allTeams = ['All', ...data.teams]..sort((a, b) {
        if (a == 'All') return -1;
        if (b == 'All') return 1;
        return a.compareTo(b);
      });

    final rows = _savedTrades.where((trade) {
      if (_recentTeam != 'All' && !trade.teams.contains(_recentTeam)) return false;
      final query = _recentSearch.trim().toLowerCase();
      if (query.isEmpty) return true;
      return trade.incomingAssets.values
          .expand((items) => items)
          .any((item) => item.toLowerCase().contains(query));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _surface(
          context,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _recentSearch = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search saved trades by player or asset...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: allTeams.contains(_recentTeam)
                      ? _recentTeam
                      : 'All',
                  decoration: const InputDecoration(
                    labelText: 'Filter by team',
                    isDense: true,
                  ),
                  items: [
                    for (final team in allTeams)
                      DropdownMenuItem(
                        value: team,
                        child: Text(team == 'All' ? 'All teams' : _teamName(team)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _recentTeam = value ?? 'All'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _surface(
            context,
            child: const Text(
              'No saved trades yet. Build a trade and press Snapshot to create your personal Recent Trades history.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 1100
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 720
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final trade in rows)
                    SizedBox(
                      width: width,
                      child: _savedTradeCard(context, trade),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _savedTradeCard(
    BuildContext context,
    TradeMachineSavedTrade trade,
  ) {
    return _surface(
      context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _tag(
                  context,
                  trade.passed ? 'Passed' : 'Needs work',
                  danger: !trade.passed,
                ),
                const Spacer(),
                Text(
                  _savedAtLabel(trade.savedAtIso),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final team in trade.teams)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _teamBadge(context, team, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$team receives', style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                          (trade.incomingAssets[team] ?? const []).isEmpty
                              ? 'No incoming assets'
                              : (trade.incomingAssets[team] ?? const []).join('\n'),
                          style: const TextStyle(fontSize: 11, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _loadSavedTrade(trade),
                    child: const Text('Load a copy'),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete saved trade',
                  onPressed: () async {
                    final rows = await _savedStore.delete(trade.id);
                    if (mounted) setState(() => _savedTrades = rows);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTradeResearch() async {
    var query = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selected = _savedTrades.where((trade) {
            if (!trade.passed) return false;
            if (!_teams.every(trade.teams.contains)) return false;
            if (query.trim().isEmpty) return true;
            final needle = query.trim().toLowerCase();
            return trade.incomingAssets.values
                .expand((items) => items)
                .any((item) => item.toLowerCase().contains(needle));
          }).toList();

          return AlertDialog(
            title: const Text('Trade research'),
            content: SizedBox(
              width: 760,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Successful saved trades involving ${_teams.map(_teamName).join(', ')}.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) =>
                        setDialogState(() => query = value),
                    decoration: const InputDecoration(
                      labelText: 'Filter by player or asset',
                      hintText: 'Search saved trades...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: selected.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(22),
                              child: Text('No matching successful saved trades yet.'),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: selected.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (_, index) {
                              final trade = selected[index];
                              final summary = trade.incomingAssets.entries
                                  .map((entry) =>
                                      '${entry.key}: ${entry.value.join(', ')}')
                                  .join(' · ');
                              return ListTile(
                                title: Text(summary),
                                subtitle: Text(_savedAtLabel(trade.savedAtIso)),
                                trailing: TextButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    _loadSavedTrade(trade);
                                  },
                                  child: const Text('Load'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  TradeScenario _scenario(
    NbaTradeContractSnapshot data,
    List<NbaFutureDraftAsset> draftAssets,
  ) {
    final playerById = {for (final item in data.records) item.id: item};
    final pickById = {for (final item in draftAssets) item.id: item};
    final rightById = {
      for (final item in NbaTradeSupplementalAssets202627.draftRights)
        item.id: item,
    };
    final freeAgentById = {
      for (final item in NbaTradeSupplementalAssets202627.freeAgentRights)
        item.id: item,
    };
    final assignments = <TradeAssignment>[];

    for (final entry in _routes.entries) {
      final destination = entry.value;
      final player = playerById[entry.key];
      if (player != null) {
        final restriction = _restrictionFor(player.player);
        final twoWay = NbaTwoWayContractReference202627.records.any(
          (item) => item.player == player.player && item.team == player.team,
        );
        final restricted = _restrictionMode != _RestrictionMode.off &&
            restriction != null &&
            _effectiveTradeDate.isBefore(DateTime.parse(restriction.eligibleDate));
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
                'two_way': twoWay,
                'trade_restricted': restricted,
                if (_restrictionMode != _RestrictionMode.off &&
                    restriction != null)
                  'trade_restricted_until': restriction.eligibleDate,
                'no_trade': restriction?.hasTradeVeto == true,
                'trade_kicker':
                    NbaTradeKickerReference202627.forPlayer(player.player)?.percent,
              },
            ),
            destinationTeam: destination,
          ),
        );
        continue;
      }

      final pick = pickById[entry.key];
      if (pick != null) {
        assignments.add(
          TradeAssignment(
            asset: TradeAsset(
              id: pick.id,
              type: TradeAssetType.draftPick,
              label: pick.label,
              originTeam: pick.team,
              metadata: {
                'draft_year': pick.year,
                'round': '${pick.round}',
                'frozen': pick.frozen,
                'swap_right': pick.swapRight,
                'stepien_safe': pick.stepienSafe,
                'protection': pick.protection ?? '',
                'conveyance_uncertain': pick.conditional,
              },
            ),
            destinationTeam: destination,
          ),
        );
        continue;
      }

      final right = rightById[entry.key];
      if (right != null) {
        assignments.add(
          TradeAssignment(
            asset: TradeAsset(
              id: right.id,
              type: TradeAssetType.draftRights,
              label: '${right.player} (draft rights)',
              originTeam: right.team,
              metadata: {'position': right.position, 'source': right.source},
            ),
            destinationTeam: destination,
          ),
        );
      }
    }

    for (final entry in _signAndTradeDestinations.entries) {
      final right = freeAgentById[entry.key];
      if (right == null) continue;
      final salary = _signAndTradeSalaries[right.id] ??
          right.signAndTradeMinimum ??
          0;
      assignments.add(
        TradeAssignment(
          asset: TradeAsset(
            id: right.id,
            type: TradeAssetType.player,
            label: '${right.player} (sign-and-trade)',
            originTeam: right.team,
            salary: salary,
            metadata: {
              'sign_and_trade': true,
              'free_agent_rights': right.rights,
              'cap_hold': right.capHold,
            },
          ),
          destinationTeam: entry.value,
        ),
      );
    }

    for (final team in _teams) {
      final amount = _cashAmounts[team] ?? 0;
      final destination = _cashDestinations[team];
      if (amount > 0 &&
          destination != null &&
          destination != team &&
          _teams.contains(destination)) {
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
      id: 'sports-terminal-video-trade',
      name: '2026-27 Trade',
      operatingSeason: '2026-27',
      asOfDateIso: _effectiveTradeDate.toIso8601String(),
      teams: List<String>.from(_teams),
      assignments: assignments,
      capContexts: {
        for (final team in _teams)
          team: TeamCapContext(
            team: team,
            teamSalary: _teamSalary(team, data),
            salaryCap: NbaLeagueEnvironment202627.salaryCap,
            taxLine: NbaLeagueEnvironment202627.luxuryTax,
            firstApron: NbaLeagueEnvironment202627.firstApron,
            secondApron: NbaLeagueEnvironment202627.secondApron,
            hardCappedAt: switch (
              NbaFrontOfficeTracker202627.hardCaps[team]?.capLevel
            ) {
              'first' => NbaLeagueEnvironment202627.firstApron,
              'second' => NbaLeagueEnvironment202627.secondApron,
              _ => null,
            },
            standardRosterPlayers: _standardRosterCount(team, data),
            cashSentThisSeason: NbaCashTradeReference202627.limit -
                (NbaCashTradeReference202627.teams[team]?.availableToSend ??
                    NbaCashTradeReference202627.limit),
            cashLimitThisSeason: NbaCashTradeReference202627.limit,
          ),
      },
    );
  }

  Future<void> _saveTrade(
    TradeScenario scenario,
    TradeValidationReport report,
    NbaTradeContractSnapshot data,
  ) async {
    final labels = _routeLabels(data);
    final incoming = <String, List<String>>{
      for (final team in _teams) team: [],
    };
    for (final assignment in scenario.assignments) {
      incoming[assignment.destinationTeam]?.add(assignment.asset.label);
    }

    final now = DateTime.now();
    final saved = TradeMachineSavedTrade(
      id: 'trade-${now.microsecondsSinceEpoch}',
      savedAtIso: now.toIso8601String(),
      teams: List<String>.from(_teams),
      routes: Map<String, String>.from(_routes),
      routeLabels: labels,
      cashAmounts: Map<String, double>.from(_cashAmounts),
      cashDestinations: Map<String, String>.from(_cashDestinations),
      signAndTradeDestinations:
          Map<String, String>.from(_signAndTradeDestinations),
      signAndTradeSalaries:
          Map<String, double>.from(_signAndTradeSalaries),
      incomingAssets: incoming,
      passed: report.isValid,
      restrictionMode: _restrictionMode.name,
    );
    final rows = await _savedStore.save(saved);
    if (!mounted) return;
    setState(() => _savedTrades = rows);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trade snapshot saved to Recent Trades.')),
    );
  }

  void _loadSavedTrade(TradeMachineSavedTrade trade) {
    setState(() {
      _teams
        ..clear()
        ..addAll(trade.teams.take(5));
      _activeTeam = _teams.isEmpty ? null : _teams.first;
      _routes
        ..clear()
        ..addAll(trade.routes);
      _cashAmounts
        ..clear()
        ..addAll(trade.cashAmounts);
      _cashDestinations
        ..clear()
        ..addAll(trade.cashDestinations);
      _signAndTradeDestinations
        ..clear()
        ..addAll(trade.signAndTradeDestinations);
      _signAndTradeSalaries
        ..clear()
        ..addAll(trade.signAndTradeSalaries);
      _restrictionMode = _RestrictionMode.values.firstWhere(
        (item) => item.name == trade.restrictionMode,
        orElse: () => _RestrictionMode.on,
      );
      _builderActive = _teams.length >= 2;
      _page = _TradePage.build;
      _assetTab = _AssetTab.roster;
      _search = '';
      _repairTradeState();
    });
  }

  Map<String, String> _routeLabels(NbaTradeContractSnapshot data) {
    final result = <String, String>{};
    for (final player in data.records) {
      if (_routes.containsKey(player.id)) result[player.id] = player.player;
    }
    for (final pick in _drafts.all()) {
      if (_routes.containsKey(pick.id)) result[pick.id] = pick.label;
    }
    for (final right in NbaTradeSupplementalAssets202627.draftRights) {
      if (_routes.containsKey(right.id)) {
        result[right.id] = '${right.player} (draft rights)';
      }
    }
    for (final right in NbaTradeSupplementalAssets202627.freeAgentRights) {
      if (_signAndTradeDestinations.containsKey(right.id)) {
        result[right.id] = '${right.player} (sign-and-trade)';
      }
    }
    return result;
  }

  void _clearTrade() {
    setState(() {
      _routes.clear();
      _cashAmounts.clear();
      _cashDestinations.clear();
      _signAndTradeDestinations.clear();
      _signAndTradeSalaries.clear();
      _expandedFreeAgents.clear();
      _search = '';
    });
  }

  void _removeAssignment(String assetId) {
    setState(() {
      if (assetId.startsWith('cash:')) {
        final team = assetId.substring(5);
        _cashAmounts.remove(team);
        _cashDestinations.remove(team);
      } else if (assetId.startsWith('fa-right:')) {
        _signAndTradeDestinations.remove(assetId);
        _signAndTradeSalaries.remove(assetId);
      } else {
        _routes.remove(assetId);
      }
    });
  }

  void _repairTeams(List<String> validTeams) {
    _teams.removeWhere((team) => !validTeams.contains(team));
    if (_activeTeam != null && !_teams.contains(_activeTeam)) {
      _activeTeam = _teams.isEmpty ? null : _teams.first;
    }
  }

  void _repairTradeState() {
    _routes.removeWhere(
      (_, destination) => !_teams.contains(destination),
    );
    _cashAmounts.removeWhere((team, _) => !_teams.contains(team));
    _cashDestinations.removeWhere(
      (team, destination) =>
          !_teams.contains(team) ||
          !_teams.contains(destination) ||
          team == destination,
    );
    _signAndTradeDestinations.removeWhere(
      (_, destination) => !_teams.contains(destination),
    );
  }

  DateTime get _effectiveTradeDate => switch (_restrictionMode) {
        _RestrictionMode.deadline => _modeledDeadlineDate,
        _ => _currentTradeDate,
      };

  NbaTradeEligibilityRestriction? _restrictionFor(String player) {
    for (final item in NbaContractStatusReference202627.january15) {
      if (item.player == player) return item;
    }
    return null;
  }

  bool _playerBlocked(String player) {
    if (_restrictionMode == _RestrictionMode.off) return false;
    final restriction = _restrictionFor(player);
    if (restriction == null) return false;
    return _effectiveTradeDate.isBefore(DateTime.parse(restriction.eligibleDate));
  }

  int _standardRosterCount(
    String team,
    NbaTradeContractSnapshot data,
  ) {
    final twoWays = NbaTwoWayContractReference202627.forTeam(team)
        .map((item) => item.player)
        .toSet();
    return data
        .forTeam(team, '2026-27')
        .where((item) => !twoWays.contains(item.player))
        .length;
  }

  double _teamSalary(String team, NbaTradeContractSnapshot data) =>
      NbaTeamSalaryPosition202627.forTeam(team)?.totalSalary ??
      NbaTeamCapReference202627.teamSalary(
        team,
        data.payroll(team, '2026-27'),
      );

  String _operatingAs(String team, NbaTradeContractSnapshot data) {
    final salary = _teamSalary(team, data);
    final hard = NbaFrontOfficeTracker202627.hardCaps[team]?.capLevel;
    if (hard == 'second') return '2nd Apron (Hard-Cap)';
    if (hard == 'first') return '1st Apron (Hard-Cap)';
    if (salary > NbaLeagueEnvironment202627.secondApron) return '2nd Apron';
    if (salary > NbaLeagueEnvironment202627.firstApron) return '1st Apron';
    if (salary > NbaLeagueEnvironment202627.luxuryTax) {
      return 'Over The Cap/Tax';
    }
    if (salary > NbaLeagueEnvironment202627.salaryCap) return 'Over The Cap';
    return 'Cap Space';
  }

  Widget _tableHeader(BuildContext context, List<String> labels) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          SizedBox(width: 210, child: Text(labels[0], style: _headerStyle(context))),
          Expanded(child: Text(labels[1], style: _headerStyle(context))),
          Expanded(child: Text(labels[2], style: _headerStyle(context))),
          SizedBox(width: 150, child: Text(labels[3], style: _headerStyle(context))),
        ],
      ),
    );
  }

  TextStyle _headerStyle(BuildContext context) => TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  Widget _genericAssetRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    Widget? control,
    bool warning = false,
    List<String> badges = const [],
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: warning ? const Color(0xFFC62828).withValues(alpha: .06) : null,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    children: [
                      for (final badge in badges) _tag(context, badge),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (control != null) SizedBox(width: 150, child: control),
        ],
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text),
        ),
      );

  Widget _teamBadge(BuildContext context, String team, {double size = 34}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        team,
        style: TextStyle(
          fontSize: size <= 26 ? 8 : 10,
          fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _initialAvatar(BuildContext context, String player) {
    final parts = player.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
                .toUpperCase();
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(initials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _tag(BuildContext context, String text, {bool danger = false}) {
    final color = danger
        ? const Color(0xFFC62828)
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _smallMetric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9)),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _surface(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }

  IconData _assetIcon(TradeAssetType type) => switch (type) {
        TradeAssetType.player => Icons.person_outline_rounded,
        TradeAssetType.draftPick => Icons.receipt_long_outlined,
        TradeAssetType.draftRights => Icons.badge_outlined,
        TradeAssetType.cash => Icons.payments_outlined,
        TradeAssetType.freeAgentRights => Icons.handshake_outlined,
        TradeAssetType.tradeException => Icons.account_balance_wallet_outlined,
        TradeAssetType.signingException => Icons.edit_document,
      };
}

String _teamName(String team) => _teamMeta[team]?.name ?? team;

String _money(double value) {
  final absolute = value.abs();
  if (absolute >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (absolute >= 1000) {
    return '\$${(value / 1000).toStringAsFixed(0)}K';
  }
  return '\$${value.toStringAsFixed(0)}';
}

String _signedMoney(double value) =>
    '${value >= 0 ? '+' : '-'}${_money(value.abs())}';

String _dateLabel(DateTime value) =>
    '${value.month}/${value.day}/${value.year}';

String _savedAtLabel(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return '${date.month}/${date.day}/${date.year}';
}

class _TeamMeta {
  const _TeamMeta(this.code, this.name, this.conference, [this.shortName = '']);

  final String code;
  final String name;
  final String conference;
  final String shortName;
}

const _teamMeta = <String, _TeamMeta>{
  'ATL': _TeamMeta('ATL', 'Atlanta Hawks', 'East', 'Hawks'),
  'BOS': _TeamMeta('BOS', 'Boston Celtics', 'East', 'Celtics'),
  'BRK': _TeamMeta('BRK', 'Brooklyn Nets', 'East', 'Nets'),
  'BKN': _TeamMeta('BKN', 'Brooklyn Nets', 'East', 'Nets'),
  'CHA': _TeamMeta('CHA', 'Charlotte Hornets', 'East', 'Hornets'),
  'CHI': _TeamMeta('CHI', 'Chicago Bulls', 'East', 'Bulls'),
  'CLE': _TeamMeta('CLE', 'Cleveland Cavaliers', 'East', 'Cavaliers'),
  'DAL': _TeamMeta('DAL', 'Dallas Mavericks', 'West', 'Mavericks'),
  'DEN': _TeamMeta('DEN', 'Denver Nuggets', 'West', 'Nuggets'),
  'DET': _TeamMeta('DET', 'Detroit Pistons', 'East', 'Pistons'),
  'GSW': _TeamMeta('GSW', 'Golden State Warriors', 'West', 'Warriors'),
  'HOU': _TeamMeta('HOU', 'Houston Rockets', 'West', 'Rockets'),
  'IND': _TeamMeta('IND', 'Indiana Pacers', 'East', 'Pacers'),
  'LAC': _TeamMeta('LAC', 'LA Clippers', 'West', 'Clippers'),
  'LAL': _TeamMeta('LAL', 'Los Angeles Lakers', 'West', 'Lakers'),
  'MEM': _TeamMeta('MEM', 'Memphis Grizzlies', 'West', 'Grizzlies'),
  'MIA': _TeamMeta('MIA', 'Miami Heat', 'East', 'Heat'),
  'MIL': _TeamMeta('MIL', 'Milwaukee Bucks', 'East', 'Bucks'),
  'MIN': _TeamMeta('MIN', 'Minnesota Timberwolves', 'West', 'Timberwolves'),
  'NOP': _TeamMeta('NOP', 'New Orleans Pelicans', 'West', 'Pelicans'),
  'NYK': _TeamMeta('NYK', 'New York Knicks', 'East', 'Knicks'),
  'OKC': _TeamMeta('OKC', 'Oklahoma City Thunder', 'West', 'Thunder'),
  'ORL': _TeamMeta('ORL', 'Orlando Magic', 'East', 'Magic'),
  'PHI': _TeamMeta('PHI', 'Philadelphia 76ers', 'East', '76ers'),
  'PHO': _TeamMeta('PHO', 'Phoenix Suns', 'West', 'Suns'),
  'POR': _TeamMeta('POR', 'Portland Trail Blazers', 'West', 'Trail Blazers'),
  'SAC': _TeamMeta('SAC', 'Sacramento Kings', 'West', 'Kings'),
  'SAS': _TeamMeta('SAS', 'San Antonio Spurs', 'West', 'Spurs'),
  'TOR': _TeamMeta('TOR', 'Toronto Raptors', 'East', 'Raptors'),
  'UTA': _TeamMeta('UTA', 'Utah Jazz', 'West', 'Jazz'),
  'WAS': _TeamMeta('WAS', 'Washington Wizards', 'East', 'Wizards'),
};
