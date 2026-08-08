from pathlib import Path

catalog_path = Path('lib/services/nba_stats_metric_catalog.dart')
screen_path = Path('lib/screens/product_nba_stats_workstation_v2_screen.dart')

catalog = catalog_path.read_text()

catalog = catalog.replace('lowerIsBetter: false,', 'higherIsBetter: false,')

catalog = catalog.replace(
    "    required this.metrics,\n  });\n\n  final String id;\n  final String label;\n  final String description;\n  final List<String> metrics;",
    "    required this.metrics,\n    this.expansionOverrides = const {},\n  });\n\n  final String id;\n  final String label;\n  final String description;\n  final List<String> metrics;\n  final Map<String, List<String>> expansionOverrides;",
)

catalog = catalog.replace(
    "    metrics: [\n      'rpg', 'dreb', 'oreb', 'box_out_pct', 'tap_outs_pg', 'deferred_rebounds_pg',\n    ],\n  ),",
    "    metrics: [\n      'rpg', 'dreb', 'oreb', 'box_out_pct', 'tap_outs_pg', 'deferred_rebounds_pg',\n    ],\n    expansionOverrides: {\n      'rpg': ['contested_rpg', 'uncontested_rpg', 'trb_pct'],\n    },\n  ),",
)

catalog = catalog.replace(
    "      'switch_attrition_rate', 'closeout_speed',\n    ],",
    "      'switch_attrition_rate', 'closeout_speed', 'anticipation',\n    ],",
    1,
)

catalog = catalog.replace(
    "  _m('closeout_speed', 'Closeout Speed', 'CL SPEED', 'Defense', 'Tracked average speed while closing out to a shooter.', raw: ['closeout_speed', 'avg_closeout_speed'], providerNative: true),\n",
    "  _m('closeout_speed', 'Closeout Speed', 'CL SPEED', 'Defense', 'Tracked average speed while closing out to a shooter.', raw: ['closeout_speed', 'avg_closeout_speed'], providerNative: true),\n  _m('anticipation', 'Defensive Anticipation', 'ANTICIP', 'Defense', 'Model or tracking estimate of how early a defender recognizes and reacts to developing actions.', raw: ['anticipation', 'defensive_anticipation'], providerNative: true),\n",
)

catalog = catalog.replace(
    "    final metric = nbaTerminalMetricByKey[key];\n    if (metric != null && expanded.contains(key)) {\n      output.addAll(metric.children);\n    }",
    "    final metric = nbaTerminalMetricByKey[key];\n    if (metric != null && expanded.contains(key)) {\n      output.addAll(family.expansionOverrides[key] ?? metric.children);\n    }",
)

catalog = catalog.replace(
    "  _m('oreb', 'Offensive Rebounds', 'ORB', 'Rebounding', 'Offensive rebounds under the selected rate basis.', engineKey: 'oreb'),",
    "  _m('oreb', 'Offensive Rebounds', 'ORB', 'Rebounding', 'Offensive rebounds under the selected rate basis.', engineKey: 'oreb', children: ['contested_orb_pg', 'uncontested_orb_pg', 'orb_pct']),",
)

catalog_path.write_text(catalog)

screen = screen_path.read_text()
screen = screen.replace(
    "        fontFeatures: const [FontFeature.tabularFigures()],\n",
    "",
)
screen_path.write_text(screen)

print('stats overhaul patch applied')
