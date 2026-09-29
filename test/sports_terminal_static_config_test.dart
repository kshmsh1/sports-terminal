import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/sports_terminal_static_config.dart';

void main() {
  test('local static corpus defaults to the existing relative path', () {
    // Test builds do not provide SPORTS_TERMINAL_NBA_STATIC_BASE. This protects
    // the localhost contract used by scripts/open_terminal.sh.
    expect(sportsTerminalNbaStaticBase, 'data/nba_static');
    expect(sportsTerminalNbaStaticBundled, isFalse);
    expect(sportsTerminalNbaBundleBase, 'data/nba_bundles');
    expect(sportsTerminalNbaBundleCount, 512);
    expect(sportsTerminalStaticPath(), 'data/nba_static');
    expect(
      sportsTerminalStaticPath('front_office'),
      'data/nba_static/front_office',
    );
  });
}
