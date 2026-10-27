/// Shared presentation conventions for Arcside NBA statistical headers.
const _nbaStatAcronyms = <String>{
  'NBA', 'ABA', 'GP', 'G', 'MPG', 'PPG', 'RPG', 'APG', 'SPG', 'BPG',
  'TPG', 'PF', 'PG', 'SG', 'SF', 'F', 'C', 'MIN', 'PTS', 'AST', 'REB',
  'ORB', 'DRB', 'OREB', 'DREB', 'STL', 'BLK', 'TOV',
  'FG', 'FGM', 'FGA', 'FG3M', 'FG3A', 'FT', 'FTM', 'FTA',
  '2P', '2PM', '2PA', '3P', '3PM', '3PA', '2PT', '3PT',
  'TS', 'PER', 'BPM', 'OBPM', 'DBPM', 'VORP', 'WS', 'OWS', 'DWS',
  'USG', 'PPP', 'RAPM', 'EPM', 'LEBRON', 'DARKO',
  'WAR', 'WARP', 'RAPTOR', 'PIE', 'PPS', 'FTR', 'DFG', 'DFGM', 'DFGA',
  'RC3', 'LC3', 'RW3', 'LW3', 'C3', 'ISO', 'ID',
  'TM', '2TM', '3TM', '4TM', 'ASTD', 'UNAST',
};

/// Descriptive labels use title case; established NBA acronyms stay uppercase.
String nbaTitleCaseStatLabel(String label) {
  return label.replaceAllMapped(RegExp(r'[A-Za-z0-9]+'), (match) {
    final word = match.group(0)!;
    if (word.toLowerCase() == 'efg') return 'eFG';
    if (word.toLowerCase() == 'pnr') return 'PnR';
    final upper = word.toUpperCase();
    if (_nbaStatAcronyms.contains(upper)) return upper;
    if (RegExp(r'^[0-9]+$').hasMatch(word)) return word;
    return word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase();
  });
}

/// Whole-inch NBA height, e.g. 88.0 inches -> 7'4".
String nbaFormatFeetInches(double inches) {
  if (!inches.isFinite || inches < 0) return '—';
  final whole = inches.round();
  return "${whole ~/ 12}'${whole % 12}\"";
}
