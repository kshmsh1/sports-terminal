import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../models/nba_cap_environment.dart';
import '../models/route_payload.dart';
import '../services/nba_financial_repository.dart';
import '../services/product_local_store.dart';
import '../services/sports_object_router.dart';
import '../services/workspace_route_import_service.dart';

const _capNavy = Color(0xFF071A33);
const _capBlue = Color(0xFF2563EB);
const _capOrange = Color(0xFFFF7A1A);
const _capGreen = Color(0xFF059669);
const _capRed = Color(0xFFDC2626);
const _capInk = Color(0xFF102033);
const _capMuted = Color(0xFF667085);
const _capLine = Color(0xFFE3E8F0);
const _capSoft = Color(0xFFF6F8FC);

class ProductCapLabScreen extends StatefulWidget {
  const ProductCapLabScreen({super.key});

  @override
  State<ProductCapLabScreen> createState() => _ProductCapLabScreenState();
}

class _ProductCapLabScreenState extends State<ProductCapLabScreen> {
  final ProductLocalStore store = const ProductLocalStore();
  final SportsObjectRouter router = const SportsObjectRouter();
  final WorkspaceRouteImportService workspaceImporter =
      const WorkspaceRouteImportService();
  final TextEditingController teamController =
      TextEditingController(text: 'Modeled Team');
  final TextEditingController salaryController =
      TextEditingController(text: '180.0');
  late final Future<List<NbaCapEnvironment>> future;

  String season = '2026-27';
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    future = const NbaFinancialRepository().loadCapEnvironments();
    _restore();
  }

  @override
  void dispose() {
    teamController.dispose();
    salaryController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final state = await store.loadStringMap(ProductLocalStore.capLabStateKey);
    if (!mounted) return;
    setState(() {
      season = state['season'] ?? season;
      teamController.text = state['team'] ?? teamController.text;
      salaryController.text = state['salaryMillions'] ?? salaryController.text;
      loaded = true;
    });
  }

  Future<void> _persist() async {
    await store.saveStringMap(ProductLocalStore.capLabStateKey, {
      'season': season,
      'team': teamController.text.trim(),
      'salaryMillions': salaryController.text.trim(),
    });
  }

  double get _teamSalary {
    final normalized = salaryController.text
        .replaceAll(',', '')
        .replaceAll(r'$', '')
        .trim();
    return (double.tryParse(normalized) ?? 0) * 1000000;
  }

  RoutePayload _payload(
    NbaCapEnvironment environment,
    NbaCapPosition position,
    String route,
  ) {
    final team = teamController.text.trim().isEmpty
        ? 'Modeled Team'
        : teamController.text.trim();
    return router.packageRows(
      datasetId: 'nba_cap_position_${environment.season}',
      packageId: '${environment.season}:${team.toLowerCase().replaceAll(' ', '-')}',
      displayLabel: '$team · ${environment.season} Cap Position',
      sourceObjectType: 'NbaCapScenario',
      rows: [position.toRow()],
      targetRoute: route,
      rowKey: 'season',
      sourceSnapshot: environment.sourceLabel,
      filterSummary: 'User-entered modeled team salary: ${_money(position.teamSalary)}',
      preferredColumns: const [
        'season',
        'modeled_team_salary',
        'salary_cap',
        'tax_level',
        'first_apron',
        'second_apron',
        'cap_room',
        'tax_room',
        'first_apron_room',
        'second_apron_room',
        'tier',
        'source',
      ],
      metadata: {
        'teamLabel': team,
        'effectiveDate': environment.effectiveDate,
        'sourceUrl': environment.sourceUrl,
        'officialLeagueThresholds': true,
        'teamSalaryIsUserModeled': true,
      },
    );
  }

  Future<void> _publish(
    NbaCapEnvironment environment,
    NbaCapPosition position,
    String route,
  ) async {
    final controller = RoutePayloadScope.maybeOf(context);
    if (controller == null) return;
    final payload = _payload(environment, position, route);
    controller.setActivePayload(payload, origin: 'NBA Cap Lab');
    await _persist();
    if (route == 'Workspace') {
      final result = await workspaceImporter.importPayload(payload);
      if (!mounted) return;
      _show('${result.summary}. Open Workspace to continue modeling.');
      return;
    }
    _show('Cap scenario published to $route.');
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NbaCapEnvironment>>(
      future: future,
      builder: (context, snapshot) {
        if (!loaded || snapshot.connectionState != ConnectionState.done) {
          return const _CapSurface(
            child: Text(
              'Loading official NBA cap environments...',
              style: TextStyle(color: _capMuted),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
          return _CapSurface(
            child: Text(
              'Cap environment data unavailable: ${snapshot.error}',
              style: const TextStyle(color: _capMuted),
            ),
          );
        }
        final environments = snapshot.data!;
        if (!environments.any((item) => item.season == season)) {
          season = environments.last.season;
        }
        final environment = environments.firstWhere(
          (item) => item.season == season,
        );
        final position = environment.positionFor(_teamSalary);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CapHero(environment: environment, position: position),
            const SizedBox(height: 18),
            _ScenarioControls(
              environments: environments,
              season: season,
              teamController: teamController,
              salaryController: salaryController,
              onSeason: (value) {
                setState(() => season = value);
                _persist();
              },
              onChanged: () {
                setState(() {});
                _persist();
              },
              onWorkspace: () => _publish(environment, position, 'Workspace'),
              onPython: () => _publish(environment, position, 'Python Lab'),
            ),
            const SizedBox(height: 18),
            _MetricGrid(position: position),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final ladder = _CapLadder(
                  environment: environment,
                  position: position,
                );
                final exceptions = _ExceptionPanel(environment: environment);
                if (constraints.maxWidth < 980) {
                  return Column(
                    children: [
                      ladder,
                      const SizedBox(height: 18),
                      exceptions,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: ladder),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: exceptions),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            _SeasonComparison(environments: environments),
            const SizedBox(height: 18),
            _SourcePanel(environment: environment),
          ],
        );
      },
    );
  }
}

class _CapHero extends StatelessWidget {
  const _CapHero({required this.environment, required this.position});

  final NbaCapEnvironment environment;
  final NbaCapPosition position;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [_capNavy, _capBlue, _capOrange],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NBA FINANCIAL WAREHOUSE',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${environment.season} Cap Lab',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.04,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Official league thresholds plus a user-entered team salary scenario. This screen never substitutes an estimated payroll for a sourced team ledger.',
            style: TextStyle(
              color: Color(0xFFEAF2FF),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CapChip('Cap ${_money(environment.salaryCap)}'),
              _CapChip('Tax ${_money(environment.taxLevel)}'),
              _CapChip('1st apron ${_money(environment.firstApron)}'),
              _CapChip('2nd apron ${_money(environment.secondApron)}'),
              _CapChip(position.tier),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapChip extends StatelessWidget {
  const _CapChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ScenarioControls extends StatelessWidget {
  const _ScenarioControls({
    required this.environments,
    required this.season,
    required this.teamController,
    required this.salaryController,
    required this.onSeason,
    required this.onChanged,
    required this.onWorkspace,
    required this.onPython,
  });

  final List<NbaCapEnvironment> environments;
  final String season;
  final TextEditingController teamController;
  final TextEditingController salaryController;
  final ValueChanged<String> onSeason;
  final VoidCallback onChanged;
  final VoidCallback onWorkspace;
  final VoidCallback onPython;

  @override
  Widget build(BuildContext context) {
    return _CapSurface(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: season,
              isExpanded: true,
              decoration: _capInput('Operating season'),
              items: [
                for (final item in environments)
                  DropdownMenuItem(value: item.season, child: Text(item.season)),
              ],
              onChanged: (value) {
                if (value != null) onSeason(value);
              },
            ),
          ),
          SizedBox(
            width: 250,
            child: TextField(
              controller: teamController,
              decoration: _capInput('Scenario / team label'),
              onChanged: (_) => onChanged(),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: salaryController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _capInput('Modeled salary · $M'),
              onChanged: (_) => onChanged(),
            ),
          ),
          FilledButton.icon(
            onPressed: onWorkspace,
            icon: const Icon(Icons.grid_on_rounded),
            label: const Text('Send to Workspace'),
          ),
          OutlinedButton.icon(
            onPressed: onPython,
            icon: const Icon(Icons.code_rounded),
            label: const Text('Send to Python'),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.position});
  final NbaCapPosition position;

  @override
  Widget build(BuildContext context) {
    final items = [
      _CapMetric('Modeled salary', _money(position.teamSalary), position.tier),
      _CapMetric('Cap room', _signedMoney(position.capRoom), 'vs salary cap'),
      _CapMetric('Tax room', _signedMoney(position.taxRoom), 'vs tax line'),
      _CapMetric('First apron room', _signedMoney(position.firstApronRoom), 'transaction threshold'),
      _CapMetric('Second apron room', _signedMoney(position.secondApronRoom), 'maximum restriction tier'),
      _CapMetric('Minimum salary gap', _signedMoney(position.minimumSalaryGap), 'positive means below minimum'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 680
                ? 2
                : 1;
        final width = (constraints.maxWidth - 14 * (columns - 1)) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _CapSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: _capMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        style: const TextStyle(
                          color: _capInk,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.detail,
                        style: const TextStyle(
                          color: _capMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CapMetric {
  const _CapMetric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _CapLadder extends StatelessWidget {
  const _CapLadder({required this.environment, required this.position});
  final NbaCapEnvironment environment;
  final NbaCapPosition position;

  @override
  Widget build(BuildContext context) {
    final thresholds = [
      ('Minimum team salary', environment.minimumTeamSalary),
      ('Salary cap', environment.salaryCap),
      ('Tax level', environment.taxLevel),
      ('First apron', environment.firstApron),
      ('Second apron', environment.secondApron),
    ];
    return _CapSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cap threshold ladder',
            style: TextStyle(
              color: _capInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Position the modeled salary against every official threshold.',
            style: TextStyle(color: _capMuted, height: 1.35),
          ),
          const SizedBox(height: 16),
          for (final threshold in thresholds)
            _ThresholdRow(
              label: threshold.$1,
              threshold: threshold.$2,
              salary: position.teamSalary,
            ),
        ],
      ),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow({
    required this.label,
    required this.threshold,
    required this.salary,
  });

  final String label;
  final double threshold;
  final double salary;

  @override
  Widget build(BuildContext context) {
    final delta = threshold - salary;
    final over = delta < 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _capLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: over ? _capRed : _capGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _capInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            _money(threshold),
            style: const TextStyle(
              color: _capInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Text(
              _signedMoney(delta),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: over ? _capRed : _capGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExceptionPanel extends StatelessWidget {
  const _ExceptionPanel({required this.environment});
  final NbaCapEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return _CapSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mid-level exception library',
            style: TextStyle(
              color: _capInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Official season amounts. Eligibility still depends on full CBA context.',
            style: TextStyle(color: _capMuted, height: 1.35),
          ),
          const SizedBox(height: 16),
          _ExceptionRow('Non-taxpayer MLE', environment.nonTaxpayerMle),
          _ExceptionRow('Taxpayer MLE', environment.taxpayerMle),
          _ExceptionRow('Room MLE', environment.roomMle),
          const SizedBox(height: 14),
          const Text(
            'This is a threshold and planning layer—not a complete legality engine. Hard caps, aggregation, trade matching, base-year compensation, poison-pill treatment, sign-and-trades and exception expiry still require transaction-specific rules.',
            style: TextStyle(
              color: _capMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExceptionRow extends StatelessWidget {
  const _ExceptionRow(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _capLine)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _capInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            _money(value),
            style: const TextStyle(
              color: _capBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonComparison extends StatelessWidget {
  const _SeasonComparison({required this.environments});
  final List<NbaCapEnvironment> environments;

  @override
  Widget build(BuildContext context) {
    return _CapSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'Versioned cap environment history',
              style: TextStyle(
                color: _capInk,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Divider(height: 1, color: _capLine),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_capSoft),
              columns: const [
                DataColumn(label: Text('Season')),
                DataColumn(label: Text('Cap')),
                DataColumn(label: Text('Tax')),
                DataColumn(label: Text('Minimum')),
                DataColumn(label: Text('First Apron')),
                DataColumn(label: Text('Second Apron')),
                DataColumn(label: Text('NTMLE')),
                DataColumn(label: Text('TMLE')),
                DataColumn(label: Text('Room MLE')),
              ],
              rows: [
                for (final item in environments)
                  DataRow(
                    cells: [
                      DataCell(Text(item.season)),
                      DataCell(Text(_money(item.salaryCap))),
                      DataCell(Text(_money(item.taxLevel))),
                      DataCell(Text(_money(item.minimumTeamSalary))),
                      DataCell(Text(_money(item.firstApron))),
                      DataCell(Text(_money(item.secondApron))),
                      DataCell(Text(_money(item.nonTaxpayerMle))),
                      DataCell(Text(_money(item.taxpayerMle))),
                      DataCell(Text(_money(item.roomMle))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({required this.environment});
  final NbaCapEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return _CapSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Source and modeling boundary',
            style: TextStyle(
              color: _capInk,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            environment.sourceLabel,
            style: const TextStyle(
              color: _capInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            environment.sourceUrl,
            style: const TextStyle(color: _capBlue, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Text(
            'Effective ${environment.effectiveDate}. League thresholds are sourced; the team salary field is a user-entered scenario and is deliberately not presented as a live team payroll.',
            style: const TextStyle(
              color: _capMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _CapSurface extends StatelessWidget {
  const _CapSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _capLine),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F071A33),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

InputDecoration _capInput(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _capSoft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _capLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _capLine),
    ),
  );
}

String _money(double value) => '\$${(value / 1000000).toStringAsFixed(3)}M';

String _signedMoney(double value) {
  final sign = value > 0 ? '+' : value < 0 ? '−' : '';
  return '$sign\$${(value.abs() / 1000000).toStringAsFixed(3)}M';
}
