import 'nba_future_draft_asset_repository.dart';
import 'nba_second_round_draft_seed.dart';

class NbaCompleteDraftAssetRepository {
  const NbaCompleteDraftAssetRepository();

  List<NbaFutureDraftAsset> all() {
    final firsts = const NbaFutureDraftAssetRepository().all();
    final seconds = <NbaFutureDraftAsset>[];
    var sequence = 0;
    for (final row in parseNbaSecondRoundSeed()) {
      sequence += 1;
      final raw = row.text;
      final outgoing = raw.startsWith('OUT:');
      final conditional = raw.startsWith('COND:') || raw.startsWith('SWAP:') ||
          raw.contains(' if ') || raw.contains('favorable') || raw.contains('allocation');
      final swap = raw.startsWith('SWAP:') || raw.toLowerCase().contains('swap');
      final clean = raw.replaceFirst(RegExp(r'^(OUT|COND|SWAP):\s*'), '');
      final slug = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
      seconds.add(NbaFutureDraftAsset(
        id: '${row.team}-${row.year}-2-${sequence}_$slug',
        team: row.team,
        year: row.year,
        round: 2,
        label: '${row.year} 2nd · $clean',
        description: clean,
        tradable: !outgoing,
        conditional: conditional,
        swapRight: swap,
        stepienSafe: true,
        source: 'RealGM future draft tables, normalized 2026-09-11',
      ));
    }
    return List.unmodifiable([...firsts, ...seconds]);
  }

  List<NbaFutureDraftAsset> forTeam(String team) {
    final rows = all().where((asset) => asset.team == team).toList()
      ..sort((a, b) {
        final byYear = a.year.compareTo(b.year);
        if (byYear != 0) return byYear;
        final byRound = a.round.compareTo(b.round);
        if (byRound != 0) return byRound;
        return a.label.compareTo(b.label);
      });
    return rows;
  }

  List<NbaFutureDraftAsset> secondRoundForTeam(String team) =>
      forTeam(team).where((asset) => asset.round == 2).toList();
}
