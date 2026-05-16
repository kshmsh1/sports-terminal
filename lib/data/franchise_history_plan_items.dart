class FranchiseHistoryPlanItem {
  const FranchiseHistoryPlanItem({
    required this.area,
    required this.priority,
    required this.status,
    required this.description,
    required this.examples,
  });

  final String area;
  final String priority;
  final String status;
  final String description;
  final String examples;
}

const franchiseHistoryPlanItems = <FranchiseHistoryPlanItem>[
  FranchiseHistoryPlanItem(
    area: 'Current franchise identity',
    priority: 'P0',
    status: 'Started',
    description: 'Current team names, abbreviations, cities, conferences, and divisions.',
    examples: 'Boston Celtics, LAL, Western Conference, Pacific Division',
  ),
  FranchiseHistoryPlanItem(
    area: 'Historical names and relocations',
    priority: 'P1',
    status: 'Planned',
    description: 'Team name changes, city moves, predecessor clubs, and official franchise continuity.',
    examples: 'Seattle SuperSonics to Oklahoma City Thunder, Minneapolis Lakers to Los Angeles Lakers',
  ),
  FranchiseHistoryPlanItem(
    area: 'Expansion and contraction context',
    priority: 'P1',
    status: 'Planned',
    description: 'Expansion years, expansion drafts, folded franchises, and league-size changes.',
    examples: 'Charlotte expansion, Toronto and Vancouver expansion, ABA merger additions',
  ),
  FranchiseHistoryPlanItem(
    area: 'Arenas and geography',
    priority: 'P2',
    status: 'Future',
    description: 'Historical home arenas, market geography, attendance context, and city-specific franchise history.',
    examples: 'Madison Square Garden, Crypto.com Arena, TD Garden, United Center',
  ),
  FranchiseHistoryPlanItem(
    area: 'Ownership and front office',
    priority: 'P3',
    status: 'Future',
    description: 'Ownership groups, governors, presidents, general managers, coaching leadership, and front-office eras.',
    examples: 'Ownership changes, GM tenure, coach tenure, president of basketball operations',
  ),
  FranchiseHistoryPlanItem(
    area: 'G League affiliates',
    priority: 'P3',
    status: 'Future',
    description: 'Current and historical G League affiliate relationships with NBA clubs.',
    examples: 'NBA parent club to G League affiliate mapping and historical affiliate changes',
  ),
];
