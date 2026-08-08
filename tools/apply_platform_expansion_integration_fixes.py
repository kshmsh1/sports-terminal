#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch(path: str, replacements: list[tuple[str, str]], append: str = "") -> None:
    target = ROOT / path
    text = target.read_text(encoding="utf-8")
    original = text
    for old, new in replacements:
        if old not in text:
            print(f"WARN missing replacement in {path}: {old[:100]!r}")
            continue
        text = text.replace(old, new)
    if append and append.strip() not in text:
        text = text.rstrip() + "\n\n" + append.strip() + "\n"
    if text != original:
        target.write_text(text, encoding="utf-8")
        print(f"patched {path}")


patch(
    "lib/services/trade_machine_engine.dart",
    [
        (
            "bool get noTradeConsent => _bool(metadata['no_trade_consent']) || _bool(metadata['trade_consent']);",
            "bool get noTradeConsent => _bool(metadata['no_trade_consent']) || (metadata.containsKey('trade_consent') && !_bool(metadata['trade_consent']));",
        ),
        (
            "if (outgoingSalary <= 0) {\n      // A team under the cap can absorb salary using room; a team over the cap\n      // generally needs an exception or outgoing salary to receive a player.\n      return context.capRoom;\n    }",
            "if (outgoingSalary <= 0) {\n      // A team under the cap can absorb salary using room; a team over the cap\n      // generally needs an exception or outgoing salary to receive a player.\n      return context.capRoom;\n    }\n    // Cap room can be combined with outgoing salary when a below-cap team\n    // structures the trade using room instead of relying solely on an exception.\n    final roomStructure = outgoingSalary + context.capRoom;",
        ),
        (
            "final secondBranch = outgoingSalary * 1.25 + 250000;\n    return firstBranch > secondBranch ? firstBranch : secondBranch;",
            "final secondBranch = outgoingSalary * 1.25 + 250000;\n    final exceptionStructure = firstBranch > secondBranch ? firstBranch : secondBranch;\n    return roomStructure > exceptionStructure ? roomStructure : exceptionStructure;",
        ),
    ],
)

patch(
    "lib/screens/product_trade_machine_v2_screen.dart",
    [
        (
            "_tradeConsent = _bool(widget.item.metadata['trade_consent']);",
            "_tradeConsent = widget.item.metadata.containsKey('no_trade_consent')\n        ? !_bool(widget.item.metadata['no_trade_consent'])\n        : _bool(widget.item.metadata['trade_consent']);",
        ),
        (
            "'no_trade_clause': _noTradeClause, 'trade_consent': _tradeConsent, 'poison_pill': _poisonPill",
            "'no_trade_clause': _noTradeClause, 'no_trade_consent': _noTradeClause && !_tradeConsent, 'poison_pill': _poisonPill",
        ),
    ],
)

patch(
    "lib/screens/product_team_blogs_screen.dart",
    [
        ("_followed.where(teams.contains).firstOrNull ?? teams.first", "_firstOrNull(_followed.where(teams.contains)) ?? teams.first"),
        ("games.firstOrNull", "_firstOrNull(games)"),
    ],
    append="""
T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}
""",
)

patch(
    "lib/screens/product_community_v2_screen.dart",
    [
        (
            "final selected = posts.where((post) => _text(post['id']) == _selectedPostId).firstOrNull;",
            "final selected = _firstOrNull(posts.where((post) => _text(post['id']) == _selectedPostId));",
        ),
        (
            "          FilledButton(onPressed: _title.text.trim().isEmpty ? () {\n            if (_title.text.trim().isEmpty) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A title is required.')));\n          } : null, child: const Text('Publish')),\n",
            "",
        ),
    ],
    append="""
T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}
""",
)

patch(
    "lib/screens/product_articles_v2_screen.dart",
    [
        (
            "Text(article.section.substring(0, article.section.length.clamp(0, 4)).toUpperCase(), style: TextStyle(color: article.accent, fontWeight: FontWeight.w900))",
            "Text((article.section.length <= 4 ? article.section : article.section.substring(0, 4)).toUpperCase(), style: TextStyle(color: article.accent, fontWeight: FontWeight.w900))",
        ),
        ("import 'dart:convert';\n\n", ""),
    ],
)

patch(
    "lib/widgets/connected_role_terminal_shell.dart",
    [
        (
            "import '../screens/product_connected_network_screens.dart';",
            "import '../screens/product_connected_network_screens.dart';\nimport '../screens/product_community_v2_screen.dart';\nimport '../screens/product_articles_v2_screen.dart';",
        ),
        (
            "screen: ProductConnectedCommunityScreen(session: widget.session),",
            "screen: ProductCommunityV2Screen(session: widget.session),",
        ),
        (
            "screen: ProductArticlesArenaScreen(),",
            "screen: ProductArticlesV2Screen(),",
        ),
    ],
)

print("platform expansion integration patch complete")
