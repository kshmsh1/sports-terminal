import 'nba_trade_contract_seed.dart';

class NbaTradeContract {
  const NbaTradeContract({
    required this.id,
    required this.player,
    required this.team,
    required this.salaries,
    required this.guaranteed,
    required this.sourceStatus,
    required this.sourceLabel,
  });

  final String id;
  final String player;
  final String team;
  final Map<String, double> salaries;
  final double? guaranteed;
  final String sourceStatus;
  final String sourceLabel;

  double salaryFor(String season) => salaries[season] ?? 0;
}

class NbaTradeContractSnapshot {
  const NbaTradeContractSnapshot({
    required this.records,
    required this.asOf,
    required this.sourceNote,
  });

  final List<NbaTradeContract> records;
  final String asOf;
  final String sourceNote;

  List<String> get teams {
    final values = records
        .map((item) => item.team)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<NbaTradeContract> forTeam(String team, String season) {
    final rows = records
        .where((item) => item.team == team && item.salaryFor(season) > 0)
        .toList()
      ..sort((a, b) => b.salaryFor(season).compareTo(a.salaryFor(season)));
    return rows;
  }

  double payroll(String team, String season) => forTeam(team, season)
      .fold(0, (sum, item) => sum + item.salaryFor(season));
}

class NbaTradeContractRepository {
  const NbaTradeContractRepository();

  Future<NbaTradeContractSnapshot> load() async {
    final rows = <NbaTradeContract>[];
    final seenPlayers = <String>{};
    for (final line in nbaTradeContractSeed202627.split('\n')) {
      final parts = line.split('\t');
      if (parts.length < 4) continue;
      final player = parts[0].trim();
      final team = parts[1].trim().toUpperCase();
      final salary = double.tryParse(parts[2]) ?? 0;
      final guaranteed = double.tryParse(parts[3]);
      if (player.isEmpty || team.isEmpty || salary <= 0) continue;
      final playerKey = player.toLowerCase();
      if (!seenPlayers.add(playerKey)) continue;
      final slug = playerKey
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      rows.add(
        NbaTradeContract(
          id: '$team:$slug',
          player: player,
          team: team,
          salaries: {'2026-27': salary},
          guaranteed:
              guaranteed != null && guaranteed > 0 ? guaranteed : null,
          sourceStatus: 'uploaded',
          sourceLabel:
              'User-supplied Sports Reference salary export (2026-09-11)',
        ),
      );
    }
    return NbaTradeContractSnapshot(
      records: rows,
      asOf: '2026-09-11',
      sourceNote:
          'Duplicate source rows were collapsed to one current-team entry before embedding the salary seed.',
    );
  }
}
