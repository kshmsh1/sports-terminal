/// Shared UI presentation rules; source records remain authoritative.
const nbaPositionOrder = ['PG', 'SG', 'SF', 'PF', 'C'];

String nbaOrderedPositions(String source) {
  final found = RegExp(r'\b(?:PG|SG|SF|PF|C)\b')
      .allMatches(source.toUpperCase())
      .map((match) => match.group(0)!)
      .toSet();
  return nbaPositionOrder.where(found.contains).join(', ');
}

class NbaPlayerHonorGroup {
  const NbaPlayerHonorGroup(this.title, this.years);
  final String title;
  final List<int> years;

  String get summary => '${years.length}x: ${years.join(', ')}';
}

/// Normalizes duplicate source labels without treating MVP votes as MVP wins.
List<NbaPlayerHonorGroup> nbaGroupPlayerHonors(
  List<Map<String, dynamic>> awards,
  List<Map<String, dynamic>> allStar,
) {
  final grouped = <String, Set<int>>{};
  for (final row in awards) {
    final raw = (row['award'] ?? row['award_name'] ?? '').toString().trim();
    if (raw.isEmpty) continue;
    final title = nbaHonorDisplayName(raw);
    if (title == null) continue;
    final teamSelection = title.startsWith('All-NBA') ||
        title.startsWith('All-Defensive') || title.startsWith('All-Rookie');
    final winner = row['winner'] == 1 || row['winner'] == true ||
        row['winner']?.toString().toLowerCase() == 'true';
    // Historical source files include *votes* for All-NBA, All-Defense and
    // All-Rookie alongside actual team selections. A vote is not a selection.
    // Retain a non-winner row only with explicit team-placement evidence.
    final rank = (row['rank_text'] ?? '').toString().toLowerCase();
    final teamPlacement = RegExp(
      r'\b(?:first|second|third|1st|2nd|3rd)\s*(?:team)?\b',
    ).hasMatch(rank);
    if (!winner && !(teamSelection && teamPlacement)) continue;
    final year = nbaHonorSeasonEndYear(row);
    if (year != null) grouped.putIfAbsent(title, () => {}).add(year);
  }
  for (final row in allStar) {
    final year = nbaHonorSeasonEndYear(row);
    if (year != null) grouped.putIfAbsent('NBA All-Star', () => {}).add(year);
  }
  return [
    for (final entry in grouped.entries)
      NbaPlayerHonorGroup(entry.key, entry.value.toList()..sort()),
  ]..sort((a, b) {
    final x = _nbaHonorSortIndex(a.title);
    final y = _nbaHonorSortIndex(b.title);
    return x == y ? a.title.compareTo(b.title) : x.compareTo(y);
  });
}

int? nbaHonorSeasonEndYear(Map<String, dynamic> row) {
  final direct = row['year']?.toString();
  final parsed = direct == null ? null : int.tryParse(direct);
  if (parsed != null && parsed >= 1947 && parsed <= 2100) return parsed;
  final season = (row['season_id'] ?? '').toString();
  final year = RegExp(r'^(19|20)\d{2}').firstMatch(season)?.group(0);
  final start = year == null ? null : int.tryParse(year);
  return start == null ? null : start + 1;
}

String? nbaHonorDisplayName(String raw) {
  final code = raw.toLowerCase().replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ').trim();
  const names = <String, String>{
    'nba mvp': 'Most Valuable Player (MVP)',
    'mvp': 'Most Valuable Player (MVP)',
    'most valuable player': 'Most Valuable Player (MVP)',
    'nba roy': 'Rookie of the Year (ROY)',
    'roy': 'Rookie of the Year (ROY)',
    'rookie of the year': 'Rookie of the Year (ROY)',
    'nba dpoy': 'Defensive Player of the Year (DPOY)',
    'dpoy': 'Defensive Player of the Year (DPOY)',
    'defensive player of the year': 'Defensive Player of the Year (DPOY)',
    'nba mip': 'Most Improved Player (MIP)',
    'mip': 'Most Improved Player (MIP)',
    'most improved player': 'Most Improved Player (MIP)',
    'nba smoy': 'Sixth Man of the Year (6MOY)',
    'smoy': 'Sixth Man of the Year (6MOY)',
    'sixth man of the year': 'Sixth Man of the Year (6MOY)',
    'nba finals mvp': 'NBA Finals MVP',
    'finals mvp': 'NBA Finals MVP',
    'all nba': 'All-NBA Team',
    'all nba team': 'All-NBA Team',
    'all defense': 'All-Defensive Team',
    'all defensive': 'All-Defensive Team',
    'all defensive team': 'All-Defensive Team',
    'all rookie': 'All-Rookie Team',
    'all rookie team': 'All-Rookie Team',
  };
  if (names.containsKey(code)) return names[code];
  if (code.contains('finals') && code.contains('mvp')) {
    return 'NBA Finals MVP';
  }
  if (code.contains('all nba')) return 'All-NBA Team';
  if (code.contains('all defens')) return 'All-Defensive Team';
  if (code.contains('all rookie')) return 'All-Rookie Team';
  if (code.contains('mvp') && !code.contains('share')) {
    return 'Most Valuable Player (MVP)';
  }
  if (code.isEmpty || code.contains('shares') ||
      code.contains('voting')) return null;
  return code.split(' ').map((word) => word.isEmpty ? word
      : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
}

int _nbaHonorSortIndex(String title) {
  const order = [
    'Most Valuable Player (MVP)', 'NBA Finals MVP',
    'Defensive Player of the Year (DPOY)',
    'Rookie of the Year (ROY)', 'Most Improved Player (MIP)',
    'Sixth Man of the Year (6MOY)', 'All-NBA Team',
    'All-Defensive Team', 'All-Rookie Team', 'NBA All-Star',
  ];
  final index = order.indexOf(title);
  return index < 0 ? order.length : index;
}
