#!/usr/bin/env python3
from pathlib import Path

platform = Path('test/platform_expansion_contract_test.dart')
text = platform.read_text(encoding='utf-8')
text = text.replace(
    "    expect(shell, contains('ProductNbaBasicStatsScreen'));\n",
    "    expect(shell, contains('ProductNbaStatsCenterScreen'));\n",
)
text = text.replace(
    "    final codeIndex = python.indexOf(\"Text('CODE CELL 1'\");\n    final outputIndex = python.indexOf(\"Text('CELL OUTPUT'\");",
    "    final codeIndex = python.indexOf(\"'CODE CELL 1'\");\n    final outputIndex = python.indexOf(\"'CELL OUTPUT'\");",
)
platform.write_text(text, encoding='utf-8')

trade = Path('test/trade_machine_v2_engine_test.dart')
text = trade.read_text(encoding='utf-8')
text = text.replace(
    "  const thresholds = NbaCbaSeasonThresholds.seasons['2025-26']!;",
    "  final thresholds = NbaCbaSeasonThresholds.seasons['2025-26']!;",
)
trade.write_text(text, encoding='utf-8')
print('fixed expansion regression tests')
