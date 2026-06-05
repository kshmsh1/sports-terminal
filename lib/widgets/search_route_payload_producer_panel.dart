import 'package:flutter/material.dart';

import '../controllers/route_payload_controller.dart';
import '../models/route_payload.dart';
import '../models/season.dart';
import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import 'terminal_primitives.dart';

class SearchRoutePayloadProducerPanel extends StatefulWidget {
  const SearchRoutePayloadProducerPanel({super.key, this.compact = false});

  final bool compact;

  @override
  State<SearchRoutePayloadProducerPanel> createState() => _SearchRoutePayloadProducerPanelState();
}

class _SearchRoutePayloadProducerPanelState extends State<SearchRoutePayloadProducerPanel> {
  final repository = const NbaAssetRepository();
  late final Future<_SearchProducerPayload> future = _load();
  String targetRoute = 'Workspace';

  Future<_SearchProducerPayload> _load() async {
    final results = await Future.wait<dynamic>([repository.loadTeams(), repository.loadSeasons()]);
    return _SearchProducerPayload(teams: results[0] as List<Team>, seasons: results[1] as List<Season>);
  }

  @override
  Widget build(BuildContext context) {
    final controller = RoutePayloadScope.maybeOf(context);
    return FutureBuilder<_SearchProducerPayload>(
      future: future,
      builder: (context, snapshot) {
        final payload = snapshot.data;
        final teams = payload?.teams ?? const <Team>[];
        final seasons = payload?.seasons ?? const <Season>[];
        return TerminalCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(child: Text('Search RoutePayload Producer', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
            InfoPill(label: targetRoute),
          ]),
          const SizedBox(height: 10),
          const Text('Search should be a command producer, not only a filtered result list. This panel publishes connected Team and Season search results into the shared active RoutePayload store so the rest of the terminal can consume the selected object.', style: TextStyle(color: terminalTextSoft, height: 1.4)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(width: 240, child: DropdownButtonFormField<String>(value: targetRoute, dropdownColor: terminalPanelDark, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Target route', labelStyle: const TextStyle(color: terminalTextMuted), filled: true, fillColor: terminalPanelDark, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent))), items: immediateRouteTargets.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) { if (value != null) setState(() => targetRoute = value); })),
            InfoPill(label: '${teams.length} teams'),
            InfoPill(label: '${seasons.length} seasons'),
            InfoPill(label: controller == null ? 'Scope missing' : 'Shared state ready'),
          ]),
          const SizedBox(height: 16),
          if (snapshot.connectionState != ConnectionState.done) const Text('Loading connected search assets...', style: TextStyle(color: terminalTextSoft)) else ...[
            const Text('Connected Team Results', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final team in teams.take(widget.compact ? 6 : 12))
                OutlinedButton(onPressed: controller == null ? null : () => controller.setActivePayload(_teamPayload(team), origin: 'Search result producer'), child: Text('${team.abbreviation} → $targetRoute')),
            ]),
            const SizedBox(height: 16),
            const Text('Connected Season Results', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final season in seasons.take(widget.compact ? 6 : 12))
                OutlinedButton(onPressed: controller == null ? null : () => controller.setActivePayload(_seasonPayload(season), origin: 'Search result producer'), child: Text('${season.label} → $targetRoute')),
            ]),
          ],
        ]));
      },
    );
  }

  RoutePayload _teamPayload(Team team) => RoutePayload(
        sourceObjectType: 'Team',
        sourceObjectId: team.id,
        displayLabel: '${team.city} ${team.name}',
        selectedColumns: const ['teamId', 'city', 'name', 'abbreviation', 'conference', 'division'],
        selectedRows: [team.id],
        filterSummary: 'Search result: team=${team.abbreviation}; targetRoute=$targetRoute',
        sourceSnapshot: 'Connected local reference asset: teams.json',
        readinessState: 'Reference data connected',
        blockers: const ['Team stats pending', 'Standings pending', 'Rosters pending', 'Games pending'],
        targetRoute: targetRoute,
        availableActions: immediateRouteTargets,
      );

  RoutePayload _seasonPayload(Season season) => RoutePayload(
        sourceObjectType: 'Season',
        sourceObjectId: season.id,
        displayLabel: season.label,
        selectedColumns: const ['seasonId', 'label', 'startYear', 'endYear', 'league'],
        selectedRows: [season.id],
        filterSummary: 'Search result: season=${season.label}; targetRoute=$targetRoute',
        sourceSnapshot: 'Connected local reference asset: seasons.json',
        readinessState: 'Reference data connected',
        blockers: const ['Standings pending', 'Playoffs pending', 'Awards pending', 'Games pending'],
        targetRoute: targetRoute,
        availableActions: immediateRouteTargets,
      );
}

class _SearchProducerPayload {
  const _SearchProducerPayload({required this.teams, required this.seasons});
  final List<Team> teams;
  final List<Season> seasons;
}
