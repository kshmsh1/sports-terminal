import 'dart:convert';

/// Build-time configuration for the browser-safe NBA static corpus.
///
/// Local development intentionally defaults to a path relative to the Flutter
/// application, preserving the existing localhost behavior. Public deployments
/// may override this path, while the GitHub Pages deployment uses bundled mode.
const String sportsTerminalNbaStaticBase = String.fromEnvironment(
  'SPORTS_TERMINAL_NBA_STATIC_BASE',
  defaultValue: 'data/nba_static',
);

String sportsTerminalStaticPath([String suffix = '']) {
  final base = sportsTerminalNbaStaticBase.trim().replaceAll(
        RegExp(r'/+$'),
        '',
      );
  final relative = suffix.trim().replaceAll(RegExp(r'^/+'), '');
  return relative.isEmpty ? base : '$base/$relative';
}

/// Public GitHub Pages builds set this to true. Local development leaves it
/// false and continues reading the existing loose JSON corpus.
const bool sportsTerminalNbaStaticBundled = bool.fromEnvironment(
  'SPORTS_TERMINAL_NBA_STATIC_BUNDLED',
  defaultValue: false,
);

/// Location of the compressed public shards. This is intentionally separate
/// from [sportsTerminalNbaStaticBase] so localhost never needs the bundles.
const String sportsTerminalNbaBundleBase = String.fromEnvironment(
  'SPORTS_TERMINAL_NBA_BUNDLE_BASE',
  defaultValue: 'data/nba_bundles',
);

const int sportsTerminalNbaBundleCount = 512;

/// Must stay byte-for-byte equivalent to tools/bundle_static_nba_for_pages.py.
int sportsTerminalStaticBundleBucket(String relative) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(relative)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash % sportsTerminalNbaBundleCount;
}
