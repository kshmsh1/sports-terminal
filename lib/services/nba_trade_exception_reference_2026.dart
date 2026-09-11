class NbaTradeExceptionReference202627 {
  const NbaTradeExceptionReference202627._();

  /// Team-level remaining signing-exception balances transcribed from the
  /// user-supplied Spotrac 2026-27 signing-exceptions screenshot. A missing
  /// entry means no available balance was shown for that exception type.
  static const Map<String, Map<String, double>> signingExceptions = {
    'ATL': {'non_tax_mle': 944000, 'bae': 5477000},
    'BOS': {'non_tax_mle': 0, 'bae': 5477000},
    'BRK': {'room_mle': 9369000},
    'CHA': {'non_tax_mle': 847026},
    'CHI': {'room_mle': 9369000},
    'CLE': {'tax_mle': 6064000},
    'DAL': {'non_tax_mle': 12044000, 'bae': 278017},
    'DEN': {'tax_mle': 6064000},
    'DET': {'non_tax_mle': 3720994},
    'GSW': {'non_tax_mle': 15044000, 'bae': 5477000},
    'HOU': {'non_tax_mle': 8980000, 'bae': 5477000},
    'IND': {'non_tax_mle': 6994000, 'bae': 5477000},
    'LAC': {'non_tax_mle': 1044000, 'bae': 5477000},
    'LAL': {'room_mle': 0},
    'MEM': {'non_tax_mle': 4694000, 'bae': 5477000},
    'MIA': {'non_tax_mle': 3379000, 'bae': 5477000},
    'MIL': {'non_tax_mle': 15044000, 'bae': 5477000},
    'MIN': {'tax_mle': 6064000},
    'NOP': {'non_tax_mle': 7239122, 'bae': 5477000},
    'NYK': {'tax_mle': 6064000},
    'OKC': {'tax_mle': 6064000},
    'ORL': {'tax_mle': 6064000},
    'PHI': {'non_tax_mle': 44000, 'bae': 2077000},
    'PHO': {'tax_mle': 0},
    'POR': {'non_tax_mle': 15044000, 'bae': 5477000},
    'SAC': {'non_tax_mle': 15044000, 'bae': 0},
    'SAS': {'non_tax_mle': 0, 'bae': 5477000},
    'TOR': {'non_tax_mle': 15044000, 'bae': 5477000},
    'UTA': {'non_tax_mle': 3044000},
    'WAS': {'non_tax_mle': 15044000},
  };

  /// Largest TPE balances visible in the supplied Spotrac team-summary
  /// screenshot. This seed is intentionally limited to values actually shown
  /// in that reference and can be expanded with expiry/source metadata as the
  /// authoritative exception ledger is ingested.
  static const Map<String, double> largestTpe = {
    'ATL': 4503720,
    'BOS': 27678571,
    'CHA': 40770520,
    'CLE': 16660836,
    'DAL': 7004114,
    'DEN': 10232558,
    'DET': 15000000,
    'GSW': 2221677,
    'HOU': 13335000,
    'IND': 1075459,
    'LAC': 2654880,
    'MEM': 28872920,
    'MIN': 10774038,
    'NOP': 7021895,
    'NYK': 899118,
    'OKC': 17722222,
    'ORL': 7000000,
    'PHI': 4221360,
    'PHO': 5000000,
    'SAC': 5426400,
    'TOR': 6383525,
    'UTA': 15054411,
    'WAS': 6000000,
  };
}
