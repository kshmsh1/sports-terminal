class NbaTeamCapReference202627 {
  const NbaTeamCapReference202627._();

  /// Team-level 2026-27 cap allocations transcribed from the user-supplied
  /// Spotrac team cap tracker screenshot. These totals are intentionally kept
  /// separate from active-player cash salary because they can include dead
  /// money, retained salary and other cap accounting items.
  static const Map<String, double> totalCap = {
    'ATL': 230094791,
    'BOS': 207991480,
    'BRK': 163229398,
    'CHA': 184339245,
    'CHI': 163000867,
    'CLE': 273135134,
    'DAL': 212186952,
    'DEN': 242092779,
    'DET': 183436388,
    'GSW': 254337411,
    'HOU': 212396723,
    'IND': 210934471,
    'LAC': 207895992,
    'LAL': 200897322,
    'MEM': 161792655,
    'MIA': 226225834,
    'MIL': 197382274,
    'MIN': 253034934,
    'NOP': 219591402,
    'NYK': 226484114,
    'OKC': 216464608,
    'ORL': 222499858,
    'PHI': 218904967,
    'PHO': 242376222,
    'POR': 205996284,
    'SAC': 218796337,
    'SAS': 231173962,
    'TOR': 209710899,
    'UTA': 190585796,
    'WAS': 243265055,
  };

  /// Hard-cap status shown in the supplied Spotrac 2026-27 team summary.
  /// `first` and `second` identify the apron ceiling; omitted teams were shown
  /// without a hard-cap designation in that reference.
  static const Map<String, String> hardCap = {
    'ATL': 'first', 'BOS': 'first', 'CHA': 'first', 'CHI': 'first',
    'CLE': 'first', 'DAL': 'first', 'DET': 'first', 'GSW': 'second',
    'HOU': 'second', 'IND': 'first', 'LAC': 'first', 'LAL': 'first',
    'MEM': 'first', 'MIA': 'first', 'MIN': 'second', 'NOP': 'first',
    'PHI': 'first', 'PHO': 'second', 'POR': 'first', 'SAC': 'first',
    'SAS': 'first', 'UTA': 'first', 'WAS': 'first',
  };

  static double teamSalary(String team, double fallback) =>
      totalCap[team] ?? fallback;

  static double? hardCapAt(String team, double firstApron, double secondApron) {
    return switch (hardCap[team]) {
      'first' => firstApron,
      'second' => secondApron,
      _ => null,
    };
  }
}
