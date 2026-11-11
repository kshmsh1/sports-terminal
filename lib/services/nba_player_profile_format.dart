/// Pure formatting helpers shared by historical player profile views.
/// Honors only come from recorded canonical awards, never invented totals.
class ArcsidePlayerHonor {
  const ArcsidePlayerHonor(this.title, this.years);
  final String title;
  final List<int> years;
}

String nbaOrderedPositions(String value) {
  const order = ['PG', 'SG', 'SF', 'PF', 'C'];
  final tokens = RegExp(r'(?<![A-Z])(PG|SG|SF|PF|C)(?![A-Z])')
      .allMatches(value.toUpperCase())
      .map((match) => match.group(1)!)
      .toSet();
  return order.where(tokens.contains).join(', ');
}

int? _awardYear(Map<String, dynamic> row) {
  final season = (row['season_id'] ?? row['year'] ?? '').toString();
  final match = RegExp(r'^(19|20)\d{2}').firstMatch(season);
  if (match == null) return null;
  final start = int.parse(match.group(0)!);
  return season.contains('-') ? start + 1 : start;
}

String? _honorName(String raw) {
  final name = raw.toLowerCase().trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty) return null;
  if (name.contains('finals') && name.contains('mvp')) {
    return 'Finals Most Valuable Player (Finals MVP)';
  }
  if (name == 'mvp' || name == 'nba mvp' ||
      name.contains('most valuable player')) {
    return 'Most Valuable Player (MVP)';
  }
  if (name == 'nba roy' || name == 'roy' ||
      name.contains('rookie of the year')) {
    return 'Rookie of the Year (ROY)';
  }
  if (name == 'nba dpoy' || name == 'dpoy' ||
      name.contains('defensive player of the year')) {
    return 'Defensive Player of the Year (DPOY)';
  }
  if (name == 'nba mip' || name == 'mip' ||
      name.contains('most improved')) {
    return 'Most Improved Player (MIP)';
  }
  if (name.contains('sixth man') || name == '6moy') {
    return 'Sixth Man of the Year (6MOY)';
  }
  if (name.contains('all nba') || name == 'all nba') {
    return 'All-NBA Team';
  }
  if (name.contains('all defense') || name.contains('all defensive')) {
    return 'All-Defensive Team';
  }
  if (name.contains('all rookie')) return 'All-Rookie Team';
  if (name.contains('scoring champion')) return 'Scoring Champion';
  if (name.contains('assist champion')) return 'Assists Leader';
  if (name.contains('rebound champion')) return 'Rebounds Leader';
  if (name.contains('steals leader')) return 'Steals Leader';
  if (name.contains('blocks leader')) return 'Blocks Leader';
  if (name == 'all star' || name == 'allstar') return 'NBA All-Star';
  // Preserve recorded honors not in the standard dictionary, but avoid
  // returning opaque source keys or category identifiers as polished titles.
  return raw.replaceAll('_', ' ').split(' ').where((v) => v.isNotEmpty)
      .map((part) => part.length <= 3 && part == part.toUpperCase()
          ? part : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

bool _isSelection(String name) =>
    name.startsWith('All-') || name == 'NBA All-Star';

List<ArcsidePlayerHonor> nbaPlayerHonors(
  List<Map<String, dynamic>> awards, {
  List<Map<String, dynamic>> allStar = const [],
}) {
  final years = <String, Set<int>>{};
  for (final row in awards) {
    final raw = (row['award'] ?? row['award_name'] ?? '').toString();
    final title = _honorName(raw);
    final year = _awardYear(row);
    if (title == null || year == null) continue;

    // Canonical tables can contain ballot rankings and nominees. Only a
    // positive winner flag qualifies for an individual-award win. All-NBA,
    // All-Defensive and All-Rookie are selections, not ballot winners.
    final winner = row['winner'];
    final won = winner == true || winner == 1 ||
        winner?.toString().toLowerCase() == 'true';
    if (!won && !_isSelection(title)) continue;
    years.putIfAbsent(title, () => {}).add(year);
  }
  for (final row in allStar) {
    final year = _awardYear(row);
    if (year != null) {
      years.putIfAbsent('NBA All-Star', () => {}).add(year);
    }
  }
  final output = [
    for (final entry in years.entries)
      ArcsidePlayerHonor(entry.key, entry.value.toList()..sort()),
  ]..sort((a, b) {
    final byCount = b.years.length.compareTo(a.years.length);
    return byCount != 0 ? byCount : a.title.compareTo(b.title);
  });
  return output;
}
