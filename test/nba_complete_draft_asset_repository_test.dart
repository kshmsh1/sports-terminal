import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_complete_draft_asset_repository.dart';

void main() {
  const teams = {
    'ATL','BOS','BRK','CHA','CHI','CLE','DAL','DEN','DET','GSW','HOU','IND','LAC','LAL','MEM',
    'MIA','MIL','MIN','NOP','NYK','OKC','ORL','PHI','PHO','POR','SAC','SAS','TOR','UTA','WAS'
  };

  test('second-round registry covers every team and every year 2027-2033', () {
    final repo = const NbaCompleteDraftAssetRepository();
    final seconds = repo.all().where((a) => a.round == 2).toList();
    expect(seconds.map((a) => a.team).toSet(), teams);
    for (final team in teams) {
      final years = seconds.where((a) => a.team == team).map((a) => a.year).toSet();
      for (var year = 2027; year <= 2033; year++) {
        expect(years.contains(year), isTrue, reason: '$team missing $year second-round record');
      }
    }
  });

  test('outgoing second-round obligations are not selectable', () {
    final repo = const NbaCompleteDraftAssetRepository();
    final atl2028 = repo.all().where((a) => a.team == 'ATL' && a.year == 2028 && a.round == 2).toList();
    expect(atl2028.any((a) => !a.tradable && a.description.contains('Brooklyn')), isTrue);
  });

  test('complex second-round interests preserve conditional metadata', () {
    final repo = const NbaCompleteDraftAssetRepository();
    final okc2031 = repo.all().where((a) => a.team == 'OKC' && a.year == 2031 && a.round == 2).toList();
    expect(okc2031.any((a) => a.conditional), isTrue);
  });
}
