import 'dart:convert';

import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../models/internal_workspace_document.dart';
import '../models/player_profile.dart';
import '../models/roster_directory_row.dart';
import '../models/roster_entry.dart';
import '../models/team.dart';
import '../services/nba_asset_repository.dart';
import '../services/roster_directory_service.dart';
import '../services/roster_measurement_formatter.dart';
import '../widgets/terminal_filter_dropdown.dart';
import '../widgets/terminal_primitives.dart';

class InternalSpreadsheetScreen extends StatefulWidget {
  const InternalSpreadsheetScreen({
    super.key,
    required this.session,
    required this.workspaceController,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;

  @override
  State<InternalSpreadsheetScreen> createState() => _InternalSpreadsheetScreenState();
}

class _InternalSpreadsheetScreenState extends State<InternalSpreadsheetScreen> {
  late final Future<_SpreadsheetPayload> payloadFuture = _loadPayload();
  final nameController = TextEditingController(text: 'Final Roster Analysis');
  String dataset = 'Final Rosters';
  String search = '';
  String selectedTeam = 'All teams';
  final Set<String> selectedRowKeys = {};
  final Set<String> visibleColumns = {
    'Player',
    'Team',
    'No.',
    'Position',
    'Age',
    'Height',
    'Weight',
    'From',
    'Salary',
  };

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<_SpreadsheetPayload> _loadPayload() async {
    const repository = NbaAssetRepository();
    final results = await Future.wait<dynamic>([
      repository.loadPlayerProfiles(),
      repository.loadTeams(),
      repository.loadRosters(),
    ]);
    final players = results[0] as List<PlayerProfile>;
    final teams = results[1] as List<Team>;
    final rosters = results[2] as List<RosterEntry>;
    return _SpreadsheetPayload(
      teams: teams,
      rosterRows: const RosterDirectoryService().join(
        rosters: rosters,
        players: players,
        teams: teams,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SpreadsheetPayload>(
      future: payloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const TerminalCard(
            child: Text('Loading internal spreadsheet workspace...', style: TextStyle(color: terminalTextSoft)),
          );
        }
        if (snapshot.hasError) {
          return TerminalCard(
            child: Text('Unable to load spreadsheet workspace: ${snapshot.error}', style: const TextStyle(color: terminalTextSoft)),
          );
        }
        final payload = snapshot.data ?? const _SpreadsheetPayload(teams: [], rosterRows: []);
        final teamById = {for (final team in payload.teams) team.id: team};
        final teamIds = payload.rosterRows.map((row) => row.teamId).toSet().toList()
          ..sort((a, b) => (teamById[a]?.name ?? a).compareTo(teamById[b]?.name ?? b));
        final rosterRows = payload.rosterRows.where((row) {
          final q = search.trim().toLowerCase();
          final text = '${row.playerName} ${row.teamName} ${row.position} ${row.from}'.toLowerCase();
          return (q.isEmpty || text.contains(q)) &&
              (selectedTeam == 'All teams' || row.teamId == selectedTeam);
        }).toList()
          ..sort((a, b) => a.playerName.compareTo(b.playerName));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Internal Spreadsheet',
              subtitle:
                  'Organization-scoped spreadsheet workspace. Terminal data can be selected, filtered, arranged, and saved internally, but this surface intentionally provides no raw CSV or workbook download.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InfoPill(label: widget.session.organizationName),
                const InfoPill(label: 'Internal output only'),
                InfoPill(label: '${selectedRowKeys.length} selected rows'),
                InfoPill(label: '${widget.workspaceController.documentsFor(widget.session).length} saved documents'),
              ],
            ),
            const SizedBox(height: 22),
            _WorkspaceControls(
              nameController: nameController,
              dataset: dataset,
              datasetChanged: (value) {
                setState(() {
                  dataset = value;
                  selectedRowKeys.clear();
                });
              },
              searchChanged: (value) => setState(() => search = value),
              selectedTeam: selectedTeam,
              teamIds: ['All teams', ...teamIds],
              teamLabel: (value) => value == 'All teams' ? value : teamById[value]?.name ?? value,
              teamChanged: (value) => setState(() => selectedTeam = value),
              onSave: () => _saveWorkspace(rosterRows, payload.teams),
            ),
            const SizedBox(height: 18),
            _ColumnPicker(
              availableColumns: dataset == 'Final Rosters'
                  ? const ['Player', 'Team', 'No.', 'Position', 'Age', 'Height', 'Weight', 'From', 'Salary']
                  : const ['Team', 'Abbreviation', 'City', 'Conference', 'Division'],
              visibleColumns: visibleColumns,
              onChanged: (column, selected) {
                setState(() {
                  if (selected) {
                    visibleColumns.add(column);
                  } else if (visibleColumns.length > 1) {
                    visibleColumns.remove(column);
                  }
                });
              },
            ),
            const SizedBox(height: 18),
            if (dataset == 'Final Rosters')
              _RosterSpreadsheet(
                rows: rosterRows,
                visibleColumns: visibleColumns,
                selectedRowKeys: selectedRowKeys,
                onSelectionChanged: (key, selected) {
                  setState(() {
                    if (selected) {
                      selectedRowKeys.add(key);
                    } else {
                      selectedRowKeys.remove(key);
                    }
                  });
                },
              )
            else
              _TeamSpreadsheet(
                teams: payload.teams,
                visibleColumns: visibleColumns,
                selectedRowKeys: selectedRowKeys,
                onSelectionChanged: (key, selected) {
                  setState(() {
                    if (selected) {
                      selectedRowKeys.add(key);
                    } else {
                      selectedRowKeys.remove(key);
                    }
                  });
                },
              ),
            const SizedBox(height: 22),
            _SavedWorkspaceList(
              session: widget.session,
              controller: widget.workspaceController,
            ),
          ],
        );
      },
    );
  }

  void _saveWorkspace(List<RosterDirectoryRow> rosterRows, List<Team> teams) {
    final selectedRows = dataset == 'Final Rosters'
        ? rosterRows
            .where((row) => selectedRowKeys.isEmpty || selectedRowKeys.contains('${row.playerId}|${row.teamId}'))
            .map((row) => {
                  'playerId': row.playerId,
                  'player': row.playerName,
                  'teamId': row.teamId,
                  'team': row.teamName,
                  'jersey': row.entry.jerseyNumber,
                  'position': row.position,
                  'age': row.entry.age,
                  'height': row.height,
                  'weightPounds': row.weightPounds,
                  'from': row.from,
                  'salaryUsd': row.entry.salaryUsd,
                })
            .toList(growable: false)
        : teams
            .where((team) => selectedRowKeys.isEmpty || selectedRowKeys.contains(team.id))
            .map((team) => {
                  'teamId': team.id,
                  'team': team.name,
                  'abbreviation': team.abbreviation,
                  'city': team.city,
                  'conference': team.conference,
                  'division': team.division,
                })
            .toList(growable: false);

    widget.workspaceController.save(
      session: widget.session,
      name: nameController.text,
      type: InternalWorkspaceDocumentType.spreadsheet,
      sourceDataset: dataset,
      content: jsonEncode({
        'visibleColumns': visibleColumns.toList(),
        'rows': selectedRows,
        'internalOnly': true,
      }),
      rowCount: selectedRows.length,
    );
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to the organization workspace.')),
    );
  }
}

class _SpreadsheetPayload {
  const _SpreadsheetPayload({required this.teams, required this.rosterRows});

  final List<Team> teams;
  final List<RosterDirectoryRow> rosterRows;
}

class _WorkspaceControls extends StatelessWidget {
  const _WorkspaceControls({
    required this.nameController,
    required this.dataset,
    required this.datasetChanged,
    required this.searchChanged,
    required this.selectedTeam,
    required this.teamIds,
    required this.teamLabel,
    required this.teamChanged,
    required this.onSave,
  });

  final TextEditingController nameController;
  final String dataset;
  final ValueChanged<String> datasetChanged;
  final ValueChanged<String> searchChanged;
  final String selectedTeam;
  final List<String> teamIds;
  final String Function(String value) teamLabel;
  final ValueChanged<String> teamChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final width = compact ? constraints.maxWidth : 250.0;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: compact ? constraints.maxWidth : 280,
                child: TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Workspace name', Icons.edit_outlined),
                ),
              ),
              TerminalFilterDropdown(
                label: 'Dataset',
                value: dataset,
                values: const ['Final Rosters', 'Teams'],
                width: width,
                onChanged: datasetChanged,
              ),
              SizedBox(
                width: compact ? constraints.maxWidth : 300,
                child: TextField(
                  onChanged: searchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Filter visible rows', Icons.search),
                ),
              ),
              TerminalFilterDropdown(
                label: 'Team',
                value: selectedTeam,
                values: teamIds,
                width: width,
                displayBuilder: teamLabel,
                onChanged: teamChanged,
              ),
              FilledButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save internally'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ColumnPicker extends StatelessWidget {
  const _ColumnPicker({
    required this.availableColumns,
    required this.visibleColumns,
    required this.onChanged,
  });

  final List<String> availableColumns;
  final Set<String> visibleColumns;
  final void Function(String column, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Visible columns', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final column in availableColumns)
                FilterChip(
                  label: Text(column),
                  selected: visibleColumns.contains(column),
                  onSelected: (selected) => onChanged(column, selected),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RosterSpreadsheet extends StatelessWidget {
  const _RosterSpreadsheet({
    required this.rows,
    required this.visibleColumns,
    required this.selectedRowKeys,
    required this.onSelectionChanged,
  });

  final List<RosterDirectoryRow> rows;
  final Set<String> visibleColumns;
  final void Function(String key, bool selected) onSelectionChanged;
  final Set<String> selectedRowKeys;
  static const measurements = RosterMeasurementFormatter();

  @override
  Widget build(BuildContext context) {
    final columns = visibleColumns.toList(growable: false);
    return _GridCard(
      title: 'Final Roster Sheet',
      rowCount: rows.length,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: [
          const DataColumn(label: Text('Select')),
          for (final column in columns) DataColumn(label: Text(column)),
        ],
        rows: [
          for (final row in rows.take(750))
            DataRow(
              selected: selectedRowKeys.contains('${row.playerId}|${row.teamId}'),
              cells: [
                DataCell(
                  Checkbox(
                    value: selectedRowKeys.contains('${row.playerId}|${row.teamId}'),
                    onChanged: (selected) => onSelectionChanged('${row.playerId}|${row.teamId}', selected ?? false),
                  ),
                ),
                for (final column in columns) DataCell(Text(_rosterValue(row, column))),
              ],
            ),
        ],
      ),
    );
  }

  String _rosterValue(RosterDirectoryRow row, String column) => switch (column) {
        'Player' => row.playerName,
        'Team' => row.teamName,
        'No.' => row.entry.jerseyNumber ?? '—',
        'Position' => row.position,
        'Age' => row.entry.age?.toString() ?? '—',
        'Height' => measurements.heightLabel(row.height),
        'Weight' => measurements.weightLabel(row.weightPounds),
        'From' => row.from,
        'Salary' => row.entry.salaryDisplay ?? '—',
        _ => '—',
      };
}

class _TeamSpreadsheet extends StatelessWidget {
  const _TeamSpreadsheet({
    required this.teams,
    required this.visibleColumns,
    required this.selectedRowKeys,
    required this.onSelectionChanged,
  });

  final List<Team> teams;
  final Set<String> visibleColumns;
  final Set<String> selectedRowKeys;
  final void Function(String key, bool selected) onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final allowed = const ['Team', 'Abbreviation', 'City', 'Conference', 'Division'];
    final columns = allowed.where(visibleColumns.contains).toList(growable: false);
    return _GridCard(
      title: 'Team Directory Sheet',
      rowCount: teams.length,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(terminalPanelDark),
        headingTextStyle: const TextStyle(color: terminalTextMuted, fontWeight: FontWeight.w800),
        dataTextStyle: const TextStyle(color: Color(0xFFDDE6F1)),
        columns: [
          const DataColumn(label: Text('Select')),
          for (final column in columns) DataColumn(label: Text(column)),
        ],
        rows: [
          for (final team in teams)
            DataRow(
              selected: selectedRowKeys.contains(team.id),
              cells: [
                DataCell(
                  Checkbox(
                    value: selectedRowKeys.contains(team.id),
                    onChanged: (selected) => onSelectionChanged(team.id, selected ?? false),
                  ),
                ),
                for (final column in columns) DataCell(Text(_teamValue(team, column))),
              ],
            ),
        ],
      ),
    );
  }

  String _teamValue(Team team, String column) => switch (column) {
        'Team' => team.name,
        'Abbreviation' => team.abbreviation,
        'City' => team.city,
        'Conference' => team.conference,
        'Division' => team.division,
        _ => '—',
      };
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.title, required this.rowCount, required this.child});

  final String title;
  final int rowCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TerminalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                Text('$rowCount rows', style: const TextStyle(color: terminalTextMuted)),
              ],
            ),
          ),
          const Divider(height: 1, color: terminalBorder),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
        ],
      ),
    );
  }
}

class _SavedWorkspaceList extends StatelessWidget {
  const _SavedWorkspaceList({required this.session, required this.controller});

  final AppSession session;
  final InternalWorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final documents = controller.documentsFor(session);
        return TerminalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Organization workspace documents', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (documents.isEmpty)
                const Text('No internal documents have been saved in this local session.', style: TextStyle(color: terminalTextSoft))
              else
                for (final document in documents)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(document.type == InternalWorkspaceDocumentType.spreadsheet ? Icons.grid_on_outlined : Icons.code_outlined, color: terminalAccent),
                    title: Text(document.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    subtitle: Text('${document.type.label} • ${document.sourceDataset} • ${document.rowCount} rows', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: terminalTextSoft)),
                    trailing: IconButton(
                      tooltip: 'Delete internal document',
                      onPressed: () => controller.delete(document.id, session),
                      icon: const Icon(Icons.delete_outline, color: terminalTextMuted),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: terminalTextMuted),
      prefixIcon: Icon(icon, color: terminalTextMuted),
      filled: true,
      fillColor: terminalPanelDark,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: terminalAccent)),
    );
