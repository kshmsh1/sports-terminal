#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path: str, old: str, new: str) -> None:
    target = ROOT / path
    text = target.read_text(encoding="utf-8")
    if old not in text:
        print(f"WARN {path}: pattern not found: {old[:90]!r}")
        return
    target.write_text(text.replace(old, new), encoding="utf-8")
    print(f"patched {path}")


# Remove an unused parameter and keep the Advanced Stats contract aligned with
# the enum-based rate-basis implementation.
replace(
    "lib/screens/product_nba_advanced_stats_document_screen.dart",
    "              favoriteOnly: false,\n",
    "",
)
replace(
    "lib/screens/product_nba_advanced_stats_document_screen.dart",
    "    required this.favoriteOnly,\n",
    "",
)
replace(
    "lib/screens/product_nba_advanced_stats_document_screen.dart",
    "  final bool favoriteOnly;\n",
    "",
)
replace(
    "test/platform_expansion_contract_test.dart",
    "    expect(advanced, contains('NbaStatsBasis.per100'));",
    "    expect(advanced, contains('NbaStatsBasis.values'));",
)

# Team Blogs uses simple local display formatting and prefers team abbreviations
# for cross-product links.
replace(
    "lib/screens/product_team_blogs_screen.dart",
    "Text('${engine.formatValue('ts_pct', row.value('ts_pct'))} TS · ${engine.formatValue('bpm', row.value('bpm'))} BPM', style: const TextStyle(color: _tbMuted, fontSize: 9)),",
    "Text('${_percent(row.value('ts_pct'))} TS · ${_numberText(row.value('bpm'))} BPM', style: const TextStyle(color: _tbMuted, fontSize: 9)),",
)
replace(
    "lib/screens/product_team_blogs_screen.dart",
    "for (final key in const ['team_id', 'team', 'abbreviation', 'team_abbreviation', 'id']) {",
    "for (final key in const ['team_abbreviation', 'abbreviation', 'team', 'team_id', 'id']) {",
)
team_blog = ROOT / "lib/screens/product_team_blogs_screen.dart"
text = team_blog.read_text(encoding="utf-8")
helpers = """
String _numberText(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  return number == null ? '—' : number.toStringAsFixed(1);
}

String _percent(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  if (number == null) return '—';
  final normalized = number.abs() <= 1.5 ? number * 100 : number;
  return '${normalized.toStringAsFixed(1)}%';
}
"""
if "String _numberText(Object? value)" not in text:
    team_blog.write_text(text.rstrip() + "\n\n" + helpers.strip() + "\n", encoding="utf-8")
    print("added Team Blogs display helpers")

# Switch statements use explicit breaks for analyzer compatibility.
profile = ROOT / "lib/screens/product_profile_persisted_screen.dart"
text = profile.read_text(encoding="utf-8")
for old, new in {
    "case 'email': _emailDigest = value;": "case 'email': _emailDigest = value; break;",
    "case 'team': _teamAlerts = value;": "case 'team': _teamAlerts = value; break;",
    "case 'player': _playerAlerts = value;": "case 'player': _playerAlerts = value; break;",
    "case 'reply': _replyAlerts = value;": "case 'reply': _replyAlerts = value; break;",
    "case 'message': _messageAlerts = value;": "case 'message': _messageAlerts = value; break;",
    "case 'product': _productUpdates = value;": "case 'product': _productUpdates = value; break;",
    "case 'public': _publicProfile = value;": "case 'public': _publicProfile = value; break;",
    "case 'favorites': _showFavorites = value;": "case 'favorites': _showFavorites = value; break;",
    "case 'activity': _showActivity = value;": "case 'activity': _showActivity = value; break;",
    "case 'awards': _showAwards = value;": "case 'awards': _showAwards = value; break;",
}.items():
    text = text.replace(old, new)
text = text.replace(
    "for (final key in const ['team_id', 'team', 'abbreviation', 'team_abbreviation', 'id']) {",
    "for (final key in const ['team_abbreviation', 'abbreviation', 'team', 'team_id', 'id']) {",
)
profile.write_text(text, encoding="utf-8")
print("patched profile control flow and team keys")

# A newsletter module contains TextField and therefore cannot be a const subtree.
replace(
    "lib/screens/product_articles_v2_screen.dart",
    "final newsletter = const _ArticlePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [",
    "final newsletter = _ArticlePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [",
)
# The children are now const-compatible except TextField/FilledButton, so remove
# the const-list marker and leave literals individually canonicalizable.
replace(
    "lib/screens/product_articles_v2_screen.dart",
    "children: const [Text('THE MORNING TERMINAL'",
    "children: [const Text('THE MORNING TERMINAL'",
)
# If the exact minified source instead has the const marker immediately after
# `children:`, normalize that form as well.
articles = ROOT / "lib/screens/product_articles_v2_screen.dart"
text = articles.read_text(encoding="utf-8")
text = text.replace(
    "_ArticlePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [const Text('THE MORNING TERMINAL'",
    "_ArticlePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('THE MORNING TERMINAL'",
)
articles.write_text(text, encoding="utf-8")

# Trade workbench roster counts remain ints and cross-product IDs prefer team
# abbreviations. Also make explicit-consent semantics unambiguous.
replace(
    "lib/screens/product_trade_machine_v2_screen.dart",
    "return names.isEmpty ? 15 : names.length.clamp(10, 18);",
    "return names.isEmpty ? 15 : names.length.clamp(10, 18).toInt();",
)
replace(
    "lib/screens/product_trade_machine_v2_screen.dart",
    "for (final key in const ['team_id','abbreviation','team_abbreviation','id']) {",
    "for (final key in const ['team_abbreviation','abbreviation','team','team_id','id']) {",
)

# Basic and entity/team pages should resolve abbreviations before internal IDs.
for path in [
    "lib/screens/product_nba_entity_pages_v2.dart",
    "lib/screens/product_nba_hub_v2_screen.dart",
]:
    target = ROOT / path
    if not target.exists():
        continue
    value = target.read_text(encoding="utf-8")
    value = value.replace(
        "['team_id', 'team', 'abbreviation', 'team_abbreviation', 'id']",
        "['team_abbreviation', 'abbreviation', 'team', 'team_id', 'id']",
    )
    value = value.replace(
        "['team_id','team','abbreviation','team_abbreviation','id']",
        "['team_abbreviation','abbreviation','team','team_id','id']",
    )
    target.write_text(value, encoding="utf-8")

print("platform expansion quality fixes complete")
