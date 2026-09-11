import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_future_draft_asset_repository.dart';

void main() {
  const repo = NbaFutureDraftAssetRepository();

  test('draft registry covers all 30 teams', () {
    final teams = repo.all().map((asset) => asset.team).toSet();
    expect(teams.length, 30);
  });

  test('known frozen assets are not tradable', () {
    final frozen = repo.all().where((asset) => asset.frozen).toList();
    final ids = frozen.map((asset) => asset.id).toSet();
    expect(ids, contains('BOS-2032-1-FROZEN'));
    expect(ids, contains('MIN-2032-1-FROZEN'));
    expect(ids, contains('PHO-2032-1-FROZEN'));
    expect(ids, contains('CLE-2033-1-FROZEN'));
    expect(frozen.every((asset) => !asset.tradable), isTrue);
  });

  test('complex interests retain conditional/swap metadata', () {
    final boston = repo.all().firstWhere((asset) => asset.id == 'BOS-2028-1-COMPLEX');
    expect(boston.conditional, isTrue);
    expect(boston.swapRight, isTrue);
  });
}
