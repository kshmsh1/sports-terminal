/// Shared formatting for the Arcside NBA statistical tables.
///
/// Common basketball acronyms remain uppercase, while descriptive headers
/// use title case (e.g. HEIGHT -> Height, MAX VERT -> Max Vert).
const _nbaStatAcronyms = <String>{
  'NBA', 'ABA', 'GP', 'G', 'MPG', 'PPG', 'RPG', 'APG', 'SPG', 'BPG',
  'TPG', 'PF', 'PG', 'SG', 'SF', 'F', 'C', 'MIN', 'PTS', 'AST', 'REB',
  'ORB', 'DRB', 'OREB', 'DREB', 'STL', 'BLK', 'TOV',
  'FG', 'FGM', 'FGA', 'FG3M', 'FG3A', 'FT', 'FTM', 'FTA',
  '2P', '2PM', '2PA', '3P', '3PM', '3PA', '2PT', '3PT',
  'TS', 'PER', 'BPM', 'OBPM', 'DBPM', 'VORP', 'WS', 'OWS', 'DWS',
  'EFG', 'USG', 'PPP', 'PACE', 'RAPM', 'EPM', 'LEBRON', 'DARKO',
  'WAR', 'WARP', 'RAPTOR', 'PIE', 'PPS', 'FTR', 'DFG', 'DFGM', 'DFGA',
  'RC3', 'LC3', 'RW3', 'LW3', 'C3', 'PnR', 'ISO', 'PnR', 'ID',
  'TM', '2TM', '3TM', '4TM', 'ASTD', 'UNAST',
};

String nbaTitleCaseStatLabel(String label) {
  return label.replaceAllMapped(RegExp(r'[A-Za-z0-9]+'), (match) {
    final word = match.group(0)!;
    if (word == 'eFG' || word == 'eFG') return 'eFG';
    if (word == 'PnR') return 'PnR';
    final upper = word.toUpperCase();
    if (_nbaStatAcronyms.contains(upper)) return upper;
    if (RegExp(r'^\\d+$').hasMatch(word)) return word;
    return word.substring(0, 1).toUpperCase() +
        word.substring(1).toLowerCase();
  });
}

/// NBA height is normally reported in whole inches. For example
/// 88.0 inches is displayed as 7'4" rather than 88.0.
String nbaFormatFeetInches(double inches) {
  if (!inches.isFinite || inches < 0) return '—';
  final whole = inches.round();
  return "${whole ~/ 12}'${whole % 12}\"";
}
