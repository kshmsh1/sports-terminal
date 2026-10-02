import 'package:flutter/material.dart';

import '../services/nba_complete_draft_asset_repository.dart';
import '../services/nba_contract_status_reference_2026.dart';
import '../services/nba_front_office_tracker_2026.dart';
import '../services/nba_future_draft_asset_repository.dart';
import '../services/nba_league_environment_2026.dart';
import '../services/nba_team_cap_reference_2026.dart';
import '../services/nba_team_salary_position_2026.dart';
import '../services/nba_trade_contract_repository.dart';
import '../services/nba_trade_exception_reference_2026.dart';
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
  bool _showAllFindings = false;
  String _search = '';
  String _positionFilter = 'All';

  final Map<String, String> _routes = {};
  final Map<String, double> _cashAmounts = {};
  final Map<String, String> _cashDestinations = {};
  final Map<String, String> _signAndTradeDestinations = {};
  final Map<String, double> _signAndTradeSalaries = {};
  final Map<String, String> _acquisitionMechanisms = {};
  final Set<String> _renouncedFreeAgentRights = {};
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
        final report = scenario == null
            ? null
            : _applyAcquisitionMechanisms(
                _engine.validate(scenario),
                scenario,
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_builderActive || _page == _TradePage.recent) ...[
              _header(context),
              const SizedBox(height: 14),
            ],
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
    Widget tab(String label, _TradePage page) {
      final selected = _page == page;
      return InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => setState(() => _page = page),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: selected
                ? Border.all(color: const Color(0xFFD7E0EC))
                : null,
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF1D5D98) : const Color(0xFF64748B),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: .1,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF4FA),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFD8E2EE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            tab('BUILD A TRADE', _TradePage.build),
            const SizedBox(width: 4),
            tab(
              _savedTrades.isEmpty
                  ? 'RECENT TRADES'
                  : 'RECENT TRADES  ${_savedTrades.length}',
              _TradePage.recent,
            ),
          ],
        ),
      ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final season = SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  initialValue: '2026-27',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Season',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '2026-27',
                      child: Text(
                        '2026-27',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (_) {},
                ),
              );
              final conference = SegmentedButton<_TeamFilter>(
                segments: const [
                  ButtonSegment(value: _TeamFilter.all, label: Text('All teams')),
                  ButtonSegment(value: _TeamFilter.east, label: Text('East')),
                  ButtonSegment(value: _TeamFilter.west, label: Text('West')),
                ],
                selected: {_teamFilter},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _teamFilter = value.first),
              );
              final actions = Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.end,
                children: [
                  Text(
                    '${_teams.length} teams selected',
                    style: TextStyle(
                      color: const Color(0xFF536A81),
                    ),
                  ),
                  TextButton(
                    onPressed: _teams.isEmpty
                        ? null
                        : () => setState(() => _teams.clear()),
                    child: const Text('Clear'),
                  ),
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
              );

              if (constraints.maxWidth < 920) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [season, conference],
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  season,
                  const SizedBox(width: 10),
                  conference,
                  const Spacer(),
                  Flexible(child: actions),
                ],
              );
            },
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
              'Select 2–5 teams. Select a card again to remove it; cap status is calculated from the 2026–27 trade ledger.',
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
    final status = _operatingAs(team, data);
    final accent = _teamAccent(team);

    return Material(
      color: selected
          ? const Color(0xFFF7FBFF)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? const Color(0xFF4D91CC) : const Color(0xFFDCE4EE),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: accent.withValues(alpha: .20)),
                ),
                child: _teamLogo(team, fallbackColor: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _teamName(team),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17243A),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5E7085),
                        fontSize: 9.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1769AA) : const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF1769AA)
                        : const Color(0xFFD8E1EB),
                  ),
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.add_rounded,
                  size: 17,
                  color: selected ? Colors.white : const Color(0xFF63758B),
                ),
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
        const SizedBox(height: 8),
        _workspaceStatusStrip(context, team, scenario, report),
        const SizedBox(height: 8),
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

    Widget teamChip(String team) {
      final active = activeTeam == team;
      final accent = _teamAccent(team);
      final shortName = _teamMeta[team]?.shortName ?? team;
      return Container(
        height: 38,
        decoration: BoxDecoration(
          color: active ? accent : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? accent : const Color(0xFFD5E0EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(5),
              ),
              onTap: () => setState(() {
                _activeTeam = team;
                _assetTab = _AssetTab.roster;
                _search = '';
              }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 5, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: _teamLogo(
                        team,
                        fallbackColor: active ? Colors.white : accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shortName.toUpperCase(),
                      style: TextStyle(
                        color:
                            active ? Colors.white : const Color(0xFF263D55),
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Team options',
              padding: EdgeInsets.zero,
              onSelected: (value) {
                if (value == 'view') {
                  setState(() {
                    _activeTeam = team;
                    _assetTab = _AssetTab.roster;
                    _search = '';
                  });
                } else if (value == 'remove' && _teams.length > 2) {
                  _removeTeamFromBuilder(team);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Text('View team'),
                ),
                PopupMenuItem(
                  value: 'remove',
                  enabled: _teams.length > 2,
                  child: const Text('Remove team'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 7, 0),
                child: Icon(
                  active
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.more_horiz_rounded,
                  size: 15,
                  color:
                      active ? Colors.white : const Color(0xFF6B7E93),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget modeButton(
      _RestrictionMode mode,
      String title,
      String subtitle,
    ) {
      final selected = _restrictionMode == mode;
      return InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => setState(() => _restrictionMode = mode),
        child: Container(
          width: 58,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF2F7FD) : Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: selected
                  ? const Color(0xFF88B4D9)
                  : const Color(0xFFD6E0EA),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF1769AA)
                      : const Color(0xFF6C7E92),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF8998A9),
                  fontSize: 6.5,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget squareAction(IconData icon, String tooltip, VoidCallback onPressed) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFD6E0EA)),
            ),
            child: Icon(icon, size: 17, color: const Color(0xFF58728E)),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final team in _teams) ...[
                  teamChip(team),
                  const SizedBox(width: 5),
                ],
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
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFD6E0EA)),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 17,
                        color: Color(0xFF4D8DC1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        modeButton(_RestrictionMode.on, 'On', 'Restrictions'),
        const SizedBox(width: 4),
        modeButton(_RestrictionMode.off, 'Off', 'Restrictions'),
        const SizedBox(width: 4),
        modeButton(_RestrictionMode.deadline, 'Deadline', 'Trade mode'),
        const SizedBox(width: 7),
        squareAction(Icons.manage_search_rounded, 'Trade research', _openTradeResearch),
        const SizedBox(width: 4),
        squareAction(Icons.restart_alt_rounded, 'Reset trade', _clearTrade),
        const SizedBox(width: 4),
        squareAction(
          Icons.home_outlined,
          'Back to team selection',
          () => setState(() {
            _builderActive = false;
            _activeTeam = null;
          }),
        ),
      ],
    );
  }

  Widget _workspaceStatusStrip(
    BuildContext context,
    String activeTeam,
    TradeScenario scenario,
    TradeValidationReport report,
  ) {
    final participating = _teams.where((team) {
      return scenario.incomingFor(team).isNotEmpty &&
          scenario.outgoingFor(team).isNotEmpty;
    }).length;
    final hasActivity = scenario.assignments.isNotEmpty;
    final incomplete = hasActivity && participating < _teams.length;
    final statusColor = !hasActivity
        ? const Color(0xFF60758B)
        : incomplete
            ? const Color(0xFF2877B5)
            : report.isValid
                ? const Color(0xFF148A55)
                : const Color(0xFFC23A4B);
    final statusLabel = !hasActivity
        ? 'No assets routed'
        : incomplete
            ? '$participating of ${_teams.length} teams complete'
            : report.isValid
                ? 'Trade passes'
                : '${report.errorCount} blocker${report.errorCount == 1 ? '' : 's'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        border: Border.all(color: const Color(0xFFDCE4EE)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: _teamLogo(
              activeTeam,
              fallbackColor: _teamAccent(activeTeam),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 7,
              runSpacing: 3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Viewing ${_teamName(activeTeam)}',
                  style: const TextStyle(
                    color: Color(0xFF20364D),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  '•',
                  style: TextStyle(color: Color(0xFF9AA8B7)),
                ),
                Text(
                  _assetTabLabel(_assetTab),
                  style: const TextStyle(
                    color: Color(0xFF62758A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  '•',
                  style: TextStyle(color: Color(0xFF9AA8B7)),
                ),
                Text(
                  _restrictionMode == _RestrictionMode.off
                      ? 'Timing restrictions off'
                      : 'As of ${_dateLabel(_effectiveTradeDate)}',
                  style: const TextStyle(
                    color: Color(0xFF62758A),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: .24)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (hasActivity && report.warningCount > 0) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: '${report.warningCount} warning${report.warningCount == 1 ? '' : 's'}',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD58B45).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${report.warningCount} warn',
                  style: const TextStyle(
                    color: Color(0xFFA96422),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamFinancialStrip(
    BuildContext context,
    NbaTradeContractSnapshot data,
    String team,
  ) {
    final payroll = _teamSalary(team, data);
    final capAllocation =
        (NbaTeamCapReference202627.forTeam(team)?.totalCap ?? payroll) -
        _renouncedCapHoldTotal(team);
    final metrics = [
      ('Operating As', _operatingAs(team, data), null),
      (
        'Cap Space',
        _signedMoney(NbaLeagueEnvironment202627.salaryCap - capAllocation),
        NbaLeagueEnvironment202627.salaryCap - capAllocation,
      ),
      (
        '1st Apron Space',
        _signedMoney(NbaLeagueEnvironment202627.firstApron - payroll),
        NbaLeagueEnvironment202627.firstApron - payroll,
      ),
      (
        '2nd Apron Space',
        _signedMoney(NbaLeagueEnvironment202627.secondApron - payroll),
        NbaLeagueEnvironment202627.secondApron - payroll,
      ),
      (
        'Tax Space',
        _signedMoney(NbaLeagueEnvironment202627.luxuryTax - payroll),
        NbaLeagueEnvironment202627.luxuryTax - payroll,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 5),
          child: Row(
            children: [
              Text(
                '${_teamName(team)} financial position',
                style: const TextStyle(
                  color: Color(0xFF40566F),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              const Text(
                '2026–27',
                style: TextStyle(
                  color: Color(0xFF7A8999),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 900
                ? (constraints.maxWidth - 4 * 8) / 5
                : constraints.maxWidth >= 520
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
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
        ),
      ],
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
    Widget tabButton(_AssetTab tab, String label) {
      final selected = _assetTab == tab;
      return InkWell(
        onTap: () => setState(() {
          _assetTab = tab;
          _search = '';
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF7FAFE) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: selected ? const Color(0xFF1769AA) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF173C62) : const Color(0xFF68798E),
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ),
      );
    }

    return _surface(
      context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        tabButton(_AssetTab.roster, 'ACTIVE ROSTER'),
                        tabButton(_AssetTab.draftPicks, 'DRAFT PICKS'),
                        tabButton(_AssetTab.draftRights, 'DRAFT RIGHTS'),
                        tabButton(_AssetTab.cash, 'CASH'),
                        tabButton(_AssetTab.freeAgents, 'FREE AGENTS'),
                      ],
                    ),
                  ),
                ),
                if (_assetTab == _AssetTab.roster ||
                    _assetTab == _AssetTab.freeAgents) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 190,
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, size: 17),
                        hintText: _assetTab == _AssetTab.roster
                            ? 'Search players...'
                            : 'Search free agents...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
                if (_assetTab == _AssetTab.roster) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 132,
                    child: DropdownButtonFormField<String>(
                      initialValue: _positionFilter,
                      isExpanded: true,
                      isDense: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text(
                            'All positions',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(value: 'PG', child: Text('Point Guard', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'SG', child: Text('Shooting Guard', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'SF', child: Text('Small Forward', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'PF', child: Text('Power Forward', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'C', child: Text('Center', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) =>
                          setState(() => _positionFilter = value ?? 'All'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
        .where((item) =>
            _positionFilter == 'All' ||
            _playerPositionReference[item.player] == _positionFilter)
        .toList();

    final twoWays = NbaTwoWayContractReference202627.forTeam(team)
        .where((item) =>
            query.isEmpty || item.player.toLowerCase().contains(query))
        .where((item) =>
            _positionFilter == 'All' || item.position == _positionFilter)
        .where((item) =>
            !players.any((player) => player.player == item.player))
        .toList();

    return Column(
      children: [
        _tableHeader(context, const ['PLAYER', '2026-27 CAP HIT', 'CONTRACT', 'FLAGS']),
        for (final player in players)
          _playerRow(context, player),
        for (final player in twoWays)
          _twoWayPlayerRow(context, player),
        if (players.isEmpty && twoWays.isEmpty)
          _empty('No roster players match this search.'),
      ],
    );
  }

  Widget _twoWayPlayerRow(
    BuildContext context,
    NbaTwoWayContractRecord player,
  ) {
    final assetId = 'two-way:${player.team}:${player.player.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    final routedTo = _routes[assetId];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: routedTo != null
            ? const Color(0xFF2E7D32).withValues(alpha: .08)
            : null,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            child: Row(
              children: [
                _initialAvatar(context, player.player),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.player, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        '${player.position} · two-way contract',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Text('Two-Way', style: TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Text(
              'Two-Way',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _tag(context, 'Two-Way'),
                const SizedBox(width: 6),
                SizedBox(
                  width: 84,
                  child: _routeControl(
                    assetId: assetId,
                    originTeam: player.team,
                    enabled: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerRow(BuildContext context, NbaTradeContract player) {
    final restriction = _restrictionFor(player.player);
    final blocked = _playerBlocked(player.player);
    final kicker = NbaTradeKickerReference202627.forPlayer(player.player);
    final routedTo = _routes[player.id];

    final baseRow = Container(
      color: routedTo != null
          ? const Color(0xFF2E7D32).withValues(alpha: .08)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            child: Row(
              children: [
                _initialAvatar(context, player.player),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.player,
                        style: const TextStyle(
                          color: Color(0xFF17243A),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      if (restriction != null)
                        Text(
                          blocked
                              ? 'Restricted until ${_displayRestrictionDate(restriction.eligibleDate)}'
                              : 'Trade eligible',
                          style: TextStyle(
                            color: blocked
                                ? const Color(0xFFC55B5B)
                                : const Color(0xFF62758B),
                            fontSize: 9,
                          ),
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
              style: const TextStyle(
                color: Color(0xFF40566F),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _contractLabel(player),
              style: const TextStyle(
                color: Color(0xFF526980),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: Wrap(
              spacing: 5,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (kicker != null) _tag(context, 'Trade Kicker'),
                if (restriction?.hasTradeVeto == true)
                  _tag(context, 'Consent'),
                SizedBox(
                  width: 84,
                  child: _routeControl(
                    assetId: player.id,
                    originTeam: player.team,
                    enabled: !blocked,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baseRow,
        if (routedTo != null)
          _acquisitionMechanismRow(
            context,
            player: player,
            destinationTeam: routedTo,
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: blocked
          ? CustomPaint(
              painter: const _RestrictionStripePainter(),
              child: row,
            )
          : row,
    );
  }

  Widget _acquisitionMechanismRow(
    BuildContext context, {
    required NbaTradeContract player,
    required String destinationTeam,
  }) {
    final selected = _acquisitionMechanisms[player.id] ?? 'match';
    final tpes = NbaTradeExceptionReference202627.forTeam(
      destinationTeam,
      asOfIso: _effectiveTradeDate.toIso8601String(),
    )
        .where((tpe) =>
            !tpe.exhausted &&
            player.salaryFor('2026-27') <= tpe.available + 100000)
        .take(5)
        .toList();

    Widget methodChip(String value, String label) {
      final active = selected == value;
      return ChoiceChip(
        label: Text(label),
        selected: active,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: active ? const Color(0xFF1769AA) : const Color(0xFF63758A),
        ),
        side: const BorderSide(color: Color(0xFFD3DFEA)),
        selectedColor: const Color(0xFFEAF4FC),
        backgroundColor: Colors.white,
        onSelected: (_) => setState(() {
          if (value == 'match') {
            _acquisitionMechanisms.remove(player.id);
          } else {
            _acquisitionMechanisms[player.id] = value;
          }
        }),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(40, 3, 8, 7),
      color: const Color(0xFF2E7D32).withValues(alpha: .05),
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          methodChip('match', 'SALARY MATCH'),
          for (final tpe in tpes)
            methodChip(
              'tpe:${tpe.id}',
              'TPE ${_money(tpe.available)}',
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
            selected: _routes.containsKey(asset.id),
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
            selected: _routes.containsKey(item.id),
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
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Send cash to',
            isDense: true,
          ),
          items: [
            for (final item in destinations)
              DropdownMenuItem(
                value: item,
                child: Text(
                  _teamName(item),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                style: const TextStyle(
                  color: Color(0xFF24435F),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        if (available > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 5,
              children: [
                for (final preset in const [
                  ('25%', .25),
                  ('50%', .50),
                  ('Max', 1.0),
                ])
                  ActionChip(
                    label: Text(preset.$1),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(
                      () => _cashAmounts[team] = available * preset.$2,
                    ),
                  ),
              ],
            ),
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
    final allRights =
        NbaTradeSupplementalAssets202627.freeAgentRightsFor(team);
    final rights = allRights
        .where((item) =>
            query.isEmpty || item.player.toLowerCase().contains(query))
        .toList();

    return Column(
      children: [
        if (allRights.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  for (final item in allRights) {
                    _renouncedFreeAgentRights.add(item.id);
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
    final renounced = _renouncedFreeAgentRights.contains(item.id);
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
                  renounced ? 'Renounced' : _money(item.capHold),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 150,
                child: OutlinedButton.icon(
                  onPressed: renounced
                      ? () => setState(() {
                            _renouncedFreeAgentRights.remove(item.id);
                          })
                      : item.signAndTradeReady
                          ? () => setState(() {
                                if (expanded) {
                                  _expandedFreeAgents.remove(item.id);
                                } else {
                                  _expandedFreeAgents.add(item.id);
                                  _signAndTradeSalaries.putIfAbsent(item.id, () => min);
                                }
                              })
                          : () => setState(() {
                                _renouncedFreeAgentRights.add(item.id);
                              }),
                  icon: Icon(
                    renounced ? Icons.undo_rounded : Icons.add_rounded,
                    size: 16,
                  ),
                  label: Text(
                    renounced
                        ? 'Restore'
                        : item.signAndTradeReady
                            ? 'Action'
                            : 'Renounce',
                  ),
                ),
              ),
            ],
          ),
          if (expanded && item.signAndTradeReady && !renounced) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        destinations.contains(destination) ? destination : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sign-and-trade to',
                      isDense: true,
                    ),
                    items: [
                      for (final team in destinations)
                        DropdownMenuItem(
                          value: team,
                          child: Text(
                            _teamName(team),
                            overflow: TextOverflow.ellipsis,
                          ),
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
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _renouncedFreeAgentRights.add(item.id);
                  _signAndTradeDestinations.remove(item.id);
                  _signAndTradeSalaries.remove(item.id);
                  _expandedFreeAgents.remove(item.id);
                }),
                icon: const Icon(Icons.block_rounded, size: 14),
                label: const Text('Renounce rights'),
              ),
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
      final accent = _teamAccent(current);
      return InputChip(
        avatar: Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Text(
            current == 'BRK' ? 'BKN' : current,
            style: TextStyle(
              color: accent,
              fontSize: 6.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        label: Text(
          current == 'BRK' ? 'BKN' : current,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onDeleted: () => setState(() {
          _routes.remove(assetId);
          _acquisitionMechanisms.remove(assetId);
        }),
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
        onPressed: () => setState(() {
          _routes[assetId] = destinations.first;
          _acquisitionMechanisms.remove(assetId);
        }),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Trade'),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Trade asset',
      onSelected: (team) => setState(() {
        _routes[assetId] = team;
        _acquisitionMechanisms.remove(assetId);
      }),
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

  Widget _guideStep(String number, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E8F0)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FB),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF1769AA),
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF536A81),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _participationRow(
    BuildContext context,
    String team, {
    required bool sends,
    required bool receives,
  }) {
    Widget state(String label, bool complete) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: complete
              ? const Color(0xFF148A55).withValues(alpha: .08)
              : const Color(0xFF2877B5).withValues(alpha: .07),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              complete ? Icons.check_rounded : Icons.arrow_forward_rounded,
              color: complete
                  ? const Color(0xFF148A55)
                  : const Color(0xFF2877B5),
              size: 11,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: complete
                    ? const Color(0xFF148A55)
                    : const Color(0xFF2877B5),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE3EAF1))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: _teamLogo(team, fallbackColor: _teamAccent(team)),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _teamName(team),
              style: const TextStyle(
                color: Color(0xFF31465C),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          state(sends ? 'Sending' : 'Needs outgoing', sends),
          const SizedBox(width: 5),
          state(receives ? 'Receiving' : 'Needs incoming', receives),
        ],
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
    final incompleteTeams = _teams.where((team) {
      return scenario.incomingFor(team).isEmpty ||
          scenario.outgoingFor(team).isEmpty;
    }).toList();
    final incomplete = hasActivity && incompleteTeams.isNotEmpty;

    Widget countPill(String label, int count, Color color) {
      if (count <= 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count $label',
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return _surface(
      context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasActivity)
            Container(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 26),
              decoration: const BoxDecoration(
                color: Color(0xFFFBFCFE),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1769AA).withValues(alpha: .08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      color: Color(0xFF1769AA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'Start building the trade',
                    style: TextStyle(
                      color: Color(0xFF23394F),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Choose an asset on the left, route it to another team, then balance every participating team.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF63758A),
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _guideStep('1', 'Choose an asset')),
                      const SizedBox(width: 7),
                      Expanded(child: _guideStep('2', 'Set destination')),
                      const SizedBox(width: 7),
                      Expanded(child: _guideStep('3', 'Resolve blockers')),
                    ],
                  ),
                ],
              ),
            )
          else if (incomplete) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF4F9FD),
                border: Border(
                  left: BorderSide(color: Color(0xFF2877B5), width: 4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_tree_outlined,
                    color: Color(0xFF2877B5),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trade in progress',
                          style: TextStyle(
                            color: Color(0xFF245F8D),
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Every selected team needs both incoming and outgoing consideration before the full CBA result is shown.',
                          style: TextStyle(
                            color: Color(0xFF58758D),
                            fontSize: 9.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final team in _teams)
              _participationRow(
                context,
                team,
                sends: scenario.outgoingFor(team).isNotEmpty,
                receives: scenario.incomingFor(team).isNotEmpty,
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: report.isValid
                    ? const Color(0xFFF3FBF7)
                    : const Color(0xFFFFF4F5),
                border: Border(
                  left: BorderSide(
                    color: report.isValid
                        ? const Color(0xFF1E9C65)
                        : const Color(0xFFC93E50),
                    width: 5,
                  ),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: report.isValid
                          ? const Color(0xFF1E9C65)
                          : const Color(0xFFC93E50),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          report.isValid
                              ? Icons.check_circle_outline_rounded
                              : Icons.cancel_outlined,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          report.isValid ? 'PASS' : 'FAIL',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  countPill(
                    'blocker${report.errorCount == 1 ? '' : 's'}',
                    report.errorCount,
                    const Color(0xFFC93E50),
                  ),
                  countPill(
                    'warning${report.warningCount == 1 ? '' : 's'}',
                    report.warningCount,
                    const Color(0xFFA96422),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Financials',
                    style: TextStyle(
                      color: Color(0xFF66798D),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Switch(
                    value: _showFinancials,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) =>
                        setState(() => _showFinancials = value),
                  ),
                  if (report.findings.length > 3)
                    TextButton(
                      onPressed: () => setState(
                        () => _showAllFindings = !_showAllFindings,
                      ),
                      child: Text(
                        _showAllFindings ? 'Less detail' : 'All findings',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _saveTrade(scenario, report, data),
                    icon: const Icon(Icons.camera_alt_outlined, size: 14),
                    label: const Text('Snapshot'),
                  ),
                ],
              ),
            ),
            for (final team in _teams)
              _teamAcquireCard(context, team, scenario, report),
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
    final findings = report.findings.where((item) => item.team == team).toList()
      ..sort((a, b) {
        int rank(TradeValidationSeverity severity) => switch (severity) {
              TradeValidationSeverity.error => 0,
              TradeValidationSeverity.warning => 1,
              TradeValidationSeverity.info => 2,
            };
        return rank(a.severity).compareTo(rank(b.severity));
      });
    final errors = findings
        .where((item) => item.severity == TradeValidationSeverity.error)
        .length;
    final warnings = findings
        .where((item) => item.severity == TradeValidationSeverity.warning)
        .length;
    final visibleFindings =
        _showAllFindings ? findings : findings.take(3).toList();
    final summary = report.teamSummaries[team];
    final accent = _teamAccent(team);
    final post = summary?.postTradeSalary;

    final checkLabel = errors > 0
        ? '$errors blocker${errors == 1 ? '' : 's'}'
        : warnings > 0
            ? 'Passes with $warnings review item${warnings == 1 ? '' : 's'}'
            : 'All modeled checks pass';
    final checkColor = errors > 0
        ? const Color(0xFFC93E50)
        : warnings > 0
            ? const Color(0xFFA96422)
            : const Color(0xFF17844F);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE4EE)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .06),
              border: Border(left: BorderSide(color: accent, width: 4)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: _teamLogo(team, fallbackColor: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_teamName(team)} Acquire',
                        style: const TextStyle(
                          color: Color(0xFF273A50),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      if (summary != null)
                        Text(
                          'Out ${_money(summary.outgoingSalary)}  •  In ${_money(summary.incomingSalary)}  •  Max ${_money(summary.maximumIncomingSalary)}',
                          style: const TextStyle(
                            color: Color(0xFF687A8F),
                            fontSize: 8.5,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
            color: const Color(0xFFFAFBFD),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'INCOMING ASSETS',
                    style: TextStyle(
                      color: Color(0xFF73859A),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(
                  width: 78,
                  child: Text(
                    '2026–27 CAP HIT',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF73859A),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 24),
              ],
            ),
          ),
          if (incoming.isEmpty)
            const Padding(
              padding: EdgeInsets.all(11),
              child: Text(
                'No incoming assets.',
                style: TextStyle(color: Color(0xFF7A8999), fontSize: 11),
              ),
            )
          else
            for (final assignment in incoming)
              _incomingRow(context, assignment),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: BoxDecoration(
              color: checkColor.withValues(alpha: .045),
              border: const Border(
                top: BorderSide(color: Color(0xFFE4EAF1)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  errors > 0
                      ? Icons.error_outline_rounded
                      : warnings > 0
                          ? Icons.info_outline_rounded
                          : Icons.check_circle_outline_rounded,
                  color: checkColor,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    checkLabel,
                    style: TextStyle(
                      color: checkColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!_showAllFindings && findings.length > 3)
                  Text(
                    '+${findings.length - 3} more',
                    style: const TextStyle(
                      color: Color(0xFF73859A),
                      fontSize: 8.5,
                    ),
                  ),
              ],
            ),
          ),
          for (final finding in visibleFindings)
            _findingLine(context, finding),
          if (_showFinancials && summary != null && post != null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              padding: const EdgeInsets.only(top: 7),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE3E8EF))),
              ),
              child: Row(
                children: [
                  const Text(
                    'AFTER THE TRADE',
                    style: TextStyle(
                      color: Color(0xFF5F7388),
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _signedMoney(
                      post - (scenario.capContexts[team]?.teamSalary ?? post),
                    ),
                    style: TextStyle(
                      color: post <=
                              (scenario.capContexts[team]?.teamSalary ?? post)
                          ? const Color(0xFF17844F)
                          : const Color(0xFFC93E50),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 10),
              child: Wrap(
                spacing: 15,
                runSpacing: 8,
                children: [
                  _smallMetric(
                    'Cap space',
                    _signedMoney(
                      NbaLeagueEnvironment202627.salaryCap -
                          ((NbaTeamCapReference202627.forTeam(team)?.totalCap ??
                                  (scenario.capContexts[team]?.teamSalary ??
                                      post)) -
                              _renouncedCapHoldTotal(team) +
                              (post -
                                  (scenario.capContexts[team]?.teamSalary ??
                                      post))),
                    ),
                  ),
                  _smallMetric(
                    '1st apron',
                    _signedMoney(
                      NbaLeagueEnvironment202627.firstApron - post,
                    ),
                  ),
                  _smallMetric(
                    '2nd apron',
                    _signedMoney(
                      NbaLeagueEnvironment202627.secondApron - post,
                    ),
                  ),
                  _smallMetric(
                    'Tax',
                    _signedMoney(
                      NbaLeagueEnvironment202627.luxuryTax - post,
                    ),
                  ),
                  _smallMetric('Outgoing', _money(summary.outgoingSalary)),
                  _smallMetric('Incoming', _money(summary.incomingSalary)),
                  _smallMetric(
                    'Match limit',
                    _money(summary.maximumIncomingSalary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _incomingRow(BuildContext context, TradeAssignment assignment) {
    final asset = assignment.asset;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE4EAF1))),
      ),
      child: Row(
        children: [
          _assetBadge(context, asset),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.label,
                  style: const TextStyle(
                    color: Color(0xFF273A50),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                if (_acquisitionMechanismLabel(asset.id) != null)
                  Text(
                    _acquisitionMechanismLabel(asset.id)!,
                    style: const TextStyle(
                      color: Color(0xFF6E8196),
                      fontSize: 8,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            child: Text(
              asset.type == TradeAssetType.player && asset.salary > 0
                  ? _money(asset.salary)
                  : '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF33485E),
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeAssignment(asset.id),
            icon: const Icon(Icons.undo_rounded, size: 15),
          ),
        ],
      ),
    );
  }

  Widget _findingLine(BuildContext context, TradeValidationFinding finding) {
    final color = switch (finding.severity) {
      TradeValidationSeverity.error => const Color(0xFFB93646),
      TradeValidationSeverity.warning => const Color(0xFFA96422),
      TradeValidationSeverity.info => const Color(0xFF177D4E),
    };
    final icon = switch (finding.severity) {
      TradeValidationSeverity.error => Icons.block_rounded,
      TradeValidationSeverity.warning => Icons.warning_amber_rounded,
      TradeValidationSeverity.info => Icons.check_circle_outline_rounded,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .055),
        border: const Border(
          top: BorderSide(color: Color(0xFFE5EBF1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              finding.message,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
      if (_recentTeam != 'All' && !trade.teams.contains(_recentTeam)) {
        return false;
      }
      final query = _recentSearch.trim().toLowerCase();
      if (query.isEmpty) return true;
      final teamMatch = trade.teams.any((team) {
        final name = _teamName(team).toLowerCase();
        return team.toLowerCase().contains(query) || name.contains(query);
      });
      if (teamMatch) return true;
      return trade.incomingAssets.values
          .expand((items) => items)
          .any((item) => item.toLowerCase().contains(query));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _surface(
          context,
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                onChanged: (value) => setState(() => _recentSearch = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  hintText: 'Search teams, players or assets...',
                  isDense: true,
                ),
              );
              final filter = DropdownButtonFormField<String>(
                initialValue:
                    allTeams.contains(_recentTeam) ? _recentTeam : 'All',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Team',
                  isDense: true,
                ),
                items: [
                  for (final team in allTeams)
                    DropdownMenuItem(
                      value: team,
                      child: Text(
                        team == 'All' ? 'All teams' : _teamName(team),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _recentTeam = value ?? 'All'),
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    search,
                    const SizedBox(height: 8),
                    filter,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 8),
                  SizedBox(width: 190, child: filter),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          _surface(
            context,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 30,
                    color: Color(0xFF7B8EA2),
                  ),
                  SizedBox(height: 9),
                  Text(
                    'No matching trade snapshots',
                    style: TextStyle(
                      color: Color(0xFF2D445A),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Save a scenario from the builder and it will appear here for comparison or reuse.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF718398),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 1100
                  ? (constraints.maxWidth - 20) / 3
                  : constraints.maxWidth >= 720
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
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
    final assetCount = trade.incomingAssets.values
        .fold<int>(0, (sum, items) => sum + items.length);
    return _surface(
      context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFD),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                _tag(
                  context,
                  trade.passed ? 'Passed' : 'Needs work',
                  danger: !trade.passed,
                ),
                const SizedBox(width: 7),
                Text(
                  '${trade.teams.length} teams • $assetCount asset${assetCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF64778B),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  _savedAtLabel(trade.savedAtIso),
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: Color(0xFF718398),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (final team in trade.teams)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5EBF1))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: _teamLogo(
                      team,
                      fallbackColor: _teamAccent(team),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_teamName(team)} receives',
                          style: const TextStyle(
                            color: Color(0xFF293F55),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (trade.incomingAssets[team] ?? const []).isEmpty
                              ? 'No incoming assets'
                              : (trade.incomingAssets[team] ?? const [])
                                  .join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF62758A),
                            fontSize: 9.5,
                            height: 1.3,
                          ),
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
                  child: FilledButton.tonalIcon(
                    onPressed: () => _loadSavedTrade(trade),
                    icon: const Icon(Icons.content_copy_rounded, size: 14),
                    label: const Text('Load a copy'),
                  ),
                ),
                const SizedBox(width: 5),
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

  TradeValidationReport _applyAcquisitionMechanisms(
    TradeValidationReport base,
    TradeScenario scenario,
  ) {
    final findings = [...base.findings];
    final grouped = <String, double>{};
    final tpeById = {
      for (final tpe in NbaTradeExceptionReference202627.tpes) tpe.id: tpe,
    };
    final validAbsorbedByTeam = <String, double>{};

    for (final assignment in scenario.assignments) {
      if (assignment.asset.type != TradeAssetType.player) continue;
      final mechanism = _acquisitionMechanisms[assignment.asset.id];
      if (mechanism == null || !mechanism.startsWith('tpe:')) continue;

      final tpeId = mechanism.substring(4);
      final tpe = tpeById[tpeId];
      final team = assignment.destinationTeam;
      if (tpe == null || tpe.team != team) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_MISSING',
            message:
                '${assignment.asset.label} references an unavailable traded-player exception for $team.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: assignment.asset.id,
          ),
        );
        continue;
      }

      final expiry = DateTime.tryParse(tpe.expires);
      if (expiry != null && expiry.isBefore(_effectiveTradeDate)) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_EXPIRED',
            message:
                '${tpe.sourceTransaction} expired ${tpe.expires}.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: assignment.asset.id,
          ),
        );
        continue;
      }

      final context = scenario.capContexts[team];
      if (context != null &&
          (context.aboveSecondApron ||
              scenario.postTradeSalary(team) > context.secondApron)) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_APRON',
            message:
                '$team cannot use ${tpe.sourceTransaction} under the modeled second-apron restriction.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: assignment.asset.id,
          ),
        );
        continue;
      }

      final total =
          (grouped[tpeId] ?? 0) + assignment.asset.salary;
      grouped[tpeId] = total;
      if (total > tpe.available + 100000) {
        findings.add(
          TradeValidationFinding(
            code: 'TPE_AMOUNT',
            message:
                '${tpe.sourceTransaction} cannot absorb ${_money(total)} of routed salary; ${_money(tpe.available)} is available.',
            severity: TradeValidationSeverity.error,
            team: team,
            assetId: assignment.asset.id,
          ),
        );
        continue;
      }

      validAbsorbedByTeam[team] =
          (validAbsorbedByTeam[team] ?? 0) + assignment.asset.salary;
      findings.add(
        TradeValidationFinding(
          code: 'TPE_OK',
          message:
              '$team absorbs ${assignment.asset.label} with ${tpe.sourceTransaction}.',
          severity: TradeValidationSeverity.info,
          team: team,
          assetId: assignment.asset.id,
        ),
      );
    }

    for (final entry in validAbsorbedByTeam.entries) {
      final summary = base.teamSummaries[entry.key];
      if (summary == null) continue;
      final salaryMatchedIncoming =
          (summary.incomingSalary - entry.value).clamp(0, double.infinity);
      if (salaryMatchedIncoming <= summary.maximumIncomingSalary + .01) {
        findings.removeWhere(
          (finding) =>
              finding.team == entry.key && finding.code == 'SALARY_MATCH',
        );
      }
    }

    return TradeValidationReport(
      findings: findings,
      teamSummaries: base.teamSummaries,
    );
  }

  String? _acquisitionMechanismLabel(String assetId) {
    final mechanism = _acquisitionMechanisms[assetId];
    if (mechanism == null || !mechanism.startsWith('tpe:')) return null;
    final id = mechanism.substring(4);
    for (final tpe in NbaTradeExceptionReference202627.tpes) {
      if (tpe.id == id) {
        return 'Via TPE · ${_money(tpe.available)}';
      }
    }
    return 'Via TPE';
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
                  const Text(
                    'Saved-trade research',
                    style: TextStyle(
                      color: Color(0xFF263E55),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Successful snapshots involving ${_teams.map(_teamName).join(', ')}. These results are local to this browser.',
                    style: const TextStyle(
                      color: Color(0xFF65788D),
                      fontSize: 9.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final team in _teams)
                        Chip(
                          avatar: SizedBox(
                            width: 18,
                            height: 18,
                            child: _teamLogo(
                              team,
                              fallbackColor: _teamAccent(team),
                            ),
                          ),
                          label: Text(
                            team == 'BRK' ? 'BKN' : team,
                            style: const TextStyle(fontSize: 9),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                    constraints: BoxConstraints(
                      maxHeight: selected.isEmpty ? 130 : 360,
                    ),
                    child: selected.isEmpty
                        ? const SizedBox(
                            height: 110,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    color: Color(0xFF8192A3),
                                    size: 24,
                                  ),
                                  SizedBox(height: 7),
                                  Text(
                                    'No matching successful snapshots yet.',
                                    style: TextStyle(
                                      color: Color(0xFF50677E),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
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
    final twoWayById = <String, NbaTwoWayContractRecord>{
      for (final item in NbaTwoWayContractReference202627.records)
        'two-way:${item.team}:${item.player.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}': item,
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

      final twoWay = twoWayById[entry.key];
      if (twoWay != null) {
        assignments.add(
          TradeAssignment(
            asset: TradeAsset(
              id: entry.key,
              type: TradeAssetType.player,
              label: twoWay.player,
              originTeam: twoWay.team,
              salary: 0,
              metadata: {
                'two_way': true,
                'position': twoWay.position,
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
      acquisitionMechanisms:
          Map<String, String>.from(_acquisitionMechanisms),
      renouncedFreeAgentRights:
          _renouncedFreeAgentRights.toList(growable: false),
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
      _acquisitionMechanisms
        ..clear()
        ..addAll(trade.acquisitionMechanisms);
      _renouncedFreeAgentRights
        ..clear()
        ..addAll(trade.renouncedFreeAgentRights);
      _restrictionMode = _RestrictionMode.values.firstWhere(
        (item) => item.name == trade.restrictionMode,
        orElse: () => _RestrictionMode.on,
      );
      _builderActive = _teams.length >= 2;
      _page = _TradePage.build;
      _assetTab = _AssetTab.roster;
      _showAllFindings = false;
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
    for (final player in NbaTwoWayContractReference202627.records) {
      final id = 'two-way:${player.team}:${player.player.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
      if (_routes.containsKey(id)) result[id] = player.player;
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

  void _removeTeamFromBuilder(String team) {
    if (_teams.length <= 2) return;
    setState(() {
      _teams.remove(team);
      if (_activeTeam == team) {
        _activeTeam = _teams.isEmpty ? null : _teams.first;
      }
      _cashAmounts.remove(team);
      _cashDestinations.remove(team);
      _cashDestinations.removeWhere((_, destination) => destination == team);
      _routes.removeWhere(
        (assetId, destination) =>
            destination == team ||
            assetId.startsWith('$team:') ||
            assetId.startsWith('$team-') ||
            assetId.startsWith('two-way:$team:') ||
            assetId.startsWith('draft-right:$team:') ||
            assetId.startsWith('cash:$team'),
      );
      _signAndTradeDestinations.removeWhere(
        (assetId, destination) =>
            destination == team || assetId.startsWith('fa-right:$team:'),
      );
      _signAndTradeSalaries.removeWhere(
        (assetId, _) => assetId.startsWith('fa-right:$team:'),
      );
      _renouncedFreeAgentRights.removeWhere(
        (assetId) => assetId.startsWith('fa-right:$team:'),
      );
      _repairTradeState();
    });
  }

  void _clearTrade() {
    setState(() {
      _routes.clear();
      _cashAmounts.clear();
      _cashDestinations.clear();
      _signAndTradeDestinations.clear();
      _signAndTradeSalaries.clear();
      _acquisitionMechanisms.clear();
      _renouncedFreeAgentRights.clear();
      _expandedFreeAgents.clear();
      _showAllFindings = false;
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
        _acquisitionMechanisms.remove(assetId);
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
    _acquisitionMechanisms.removeWhere(
      (assetId, _) => !_routes.containsKey(assetId),
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

  double _renouncedCapHoldTotal(String team) {
    return NbaTradeSupplementalAssets202627.freeAgentRightsFor(team)
        .where((item) => _renouncedFreeAgentRights.contains(item.id))
        .fold<double>(0, (sum, item) => sum + item.capHold);
  }

  double _teamSalary(String team, NbaTradeContractSnapshot data) {
    final activePayroll = data.payroll(team, '2026-27');
    if (activePayroll > 0) return activePayroll;
    return NbaTeamSalaryPosition202627.forTeam(team)?.totalSalary ??
        NbaTeamCapReference202627.teamSalary(team, 0);
  }

  String _operatingAs(String team, NbaTradeContractSnapshot data) {
    final reference = _spotracOperatingStatus[team];
    if (reference != null) return reference;
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

  Widget _teamLogo(String team, {required Color fallbackColor}) {
    final display = team == 'BRK' ? 'BKN' : team;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .88),
        shape: BoxShape.circle,
        border: Border.all(color: fallbackColor.withValues(alpha: .35)),
      ),
      child: Text(
        display,
        style: TextStyle(
          color: fallbackColor,
          fontSize: display.length > 3 ? 7 : 9,
          fontWeight: FontWeight.w900,
          letterSpacing: -.2,
        ),
      ),
    );
  }

  Color _teamAccent(String team) =>
      _teamAccentColors[team] ?? const Color(0xFF1769AA);

  Widget _assetBadge(BuildContext context, TradeAsset asset) {
    if (asset.type == TradeAssetType.player) {
      return _initialAvatar(context, asset.label.replaceAll(' (sign-and-trade)', ''));
    }
    final color = switch (asset.type) {
      TradeAssetType.draftPick => const Color(0xFF5C7EA5),
      TradeAssetType.draftRights => const Color(0xFF5C7EA5),
      TradeAssetType.cash => const Color(0xFF2E9A69),
      TradeAssetType.freeAgentRights => const Color(0xFF7768A8),
      TradeAssetType.tradeException => const Color(0xFF8D6E63),
      TradeAssetType.signingException => const Color(0xFF8D6E63),
      TradeAssetType.player => const Color(0xFF1769AA),
    };
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(_assetIcon(asset.type), color: color, size: 15),
    );
  }

  String _displayRestrictionDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    const months = <String>[
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _assetTabLabel(_AssetTab tab) => switch (tab) {
        _AssetTab.roster => 'Active roster',
        _AssetTab.draftPicks => 'Draft picks',
        _AssetTab.draftRights => 'Draft rights',
        _AssetTab.cash => 'Cash',
        _AssetTab.freeAgents => 'Free agents',
      };

  String _contractLabel(NbaTradeContract player) {
    final salary = player.salaryFor('2026-27');
    final guaranteed = player.guaranteed;
    if (guaranteed == null || guaranteed <= 0) return '2026–27 salary';
    if ((guaranteed - salary).abs() < 1) return 'Fully guaranteed';
    return '${_money(guaranteed)} guaranteed';
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
    bool selected = false,
    List<String> badges = const [],
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF1976D2).withValues(alpha: .08)
            : warning
                ? const Color(0xFFC62828).withValues(alpha: .06)
                : null,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: warning
                        ? const Color(0xFF7B3038)
                        : const Color(0xFF23394F),
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
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
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF78899B),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF31485F),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
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

class _RestrictionStripePainter extends CustomPainter {
  const _RestrictionStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x18D45B66)
      ..strokeWidth = 1;
    const gap = 9.0;
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

const _teamAccentColors = <String, Color>{
  'ATL': Color(0xFFE03A3E),
  'BOS': Color(0xFF007A33),
  'BRK': Color(0xFF111111),
  'BKN': Color(0xFF111111),
  'CHA': Color(0xFF1D1160),
  'CHI': Color(0xFFCE1141),
  'CLE': Color(0xFF860038),
  'DAL': Color(0xFF00538C),
  'DEN': Color(0xFF0E2240),
  'DET': Color(0xFFC8102E),
  'GSW': Color(0xFF1D428A),
  'HOU': Color(0xFFCE1141),
  'IND': Color(0xFF002D62),
  'LAC': Color(0xFFC8102E),
  'LAL': Color(0xFF552583),
  'MEM': Color(0xFF5D76A9),
  'MIA': Color(0xFF98002E),
  'MIL': Color(0xFF00471B),
  'MIN': Color(0xFF0C2340),
  'NOP': Color(0xFF0C2340),
  'NYK': Color(0xFF006BB6),
  'OKC': Color(0xFF007AC1),
  'ORL': Color(0xFF0077C0),
  'PHI': Color(0xFF006BB6),
  'PHO': Color(0xFF1D1160),
  'POR': Color(0xFFE03A3E),
  'SAC': Color(0xFF5A2D81),
  'SAS': Color(0xFF777777),
  'TOR': Color(0xFFCE1141),
  'UTA': Color(0xFF4B2E83),
  'WAS': Color(0xFF002B5C),
};

const _spotracOperatingStatus = <String, String>{
  'ATL': '1st Apron (Hard-Cap)',
  'BOS': '1st Apron (Hard-Cap)',
  'BRK': 'Cap Space',
  'BKN': 'Cap Space',
  'CHA': '1st Apron (Hard-Cap)',
  'CHI': '1st Apron (Hard-Cap)',
  'CLE': '1st Apron (Hard-Cap)',
  'DAL': '1st Apron (Hard-Cap)',
  'DEN': '2nd Apron',
  'DET': '1st Apron (Hard-Cap)',
  'GSW': '2nd Apron (Hard-Cap)',
  'HOU': '2nd Apron (Hard-Cap)',
  'IND': '1st Apron (Hard-Cap)',
  'LAC': '1st Apron (Hard-Cap)',
  'LAL': '1st Apron (Hard-Cap)',
  'MEM': '1st Apron (Hard-Cap)',
  'MIA': '1st Apron (Hard-Cap)',
  'MIL': '1st Apron (Hard-Cap)',
  'MIN': '2nd Apron (Hard-Cap)',
  'NOP': '1st Apron',
  'NYK': '1st Apron',
  'OKC': '1st Apron',
  'ORL': '1st Apron',
  'PHI': '1st Apron (Hard-Cap)',
  'PHO': '2nd Apron (Hard-Cap)',
  'POR': '1st Apron (Hard-Cap)',
  'SAC': '1st Apron (Hard-Cap)',
  'SAS': '1st Apron (Hard-Cap)',
  'TOR': 'Over The Cap/Tax',
  'UTA': '1st Apron (Hard-Cap)',
  'WAS': '1st Apron (Hard-Cap)',
};

const _playerPositionReference = <String, String>{
  'Jayson Tatum': 'PF',
  'Paul George': 'SG',
  'Derrick White': 'PG',
  'Mitchell Robinson': 'C',
  'Sam Hauser': 'SF',
  'Payton Pritchard': 'PG',
  'Ron Harper Jr.': 'SG',
  'Chris Cenac Jr.': 'PF',
  'Hugo González': 'SF',
  'Luka Garza': 'C',
  'Baylor Scheierman': 'SG',
  'Neemias Queta': 'C',
  'Mike Conley': 'PG',
  'Jordan Walsh': 'SF',
  'Joel Embiid': 'C',
  'Jaylen Brown': 'SF',
  'Tyrese Maxey': 'PG',
  'VJ Edgecombe': 'SG',
  'Dean Wade': 'PF',
  'Anfernee Simons': 'SG',
  'LeBron James': 'PF',
  'Duncan Robinson': 'SF',
  'Isaiah Joe': 'SG',
  'Ausar Thompson': 'SF',
  'Kevin Huerter': 'SG',
  'Ron Holland II': 'SF',
};

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
