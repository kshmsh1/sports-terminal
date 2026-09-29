/// Build-time configuration for the browser-safe NBA static corpus.
///
/// Local development intentionally defaults to a path relative to the Flutter
/// application, preserving the existing localhost behavior. Public deployments
/// can point at object storage/CDN with:
///
///   --dart-define=SPORTS_TERMINAL_NBA_STATIC_BASE=https://data.example.com/nba_static
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
