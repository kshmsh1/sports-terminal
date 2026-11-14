import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_profile_stats.dart';
import 'package:sports_terminal/services/nba_stats_workstation_engine.dart';

void main() {
  final dossier = <String, dynamic>{
    'profile': {
      'player_key': 'nba_999',
      'canonical_name': 'Sample Player',
      'primary_position': 'SG',
    },
    'regular_seasons': [
      {
        'player_key': 'nba_999',
        'season_id': '2024-25',
        'season_type': 'regular',
        'team_abbreviation': 'BOS',
        'games': 80,
        'minutes': 2800,
        'points': 2400,
        'rebounds': 400,
        'assists': 640,
        'steals': 100,
        'blocks': 40,
        'turnovers': 200,
        'field_goals_made': 800,
        'field_goal_attempts': 1600,
        'three_pointers_made': 240,
        'three_point_attempts': 600,
        'free_throws_made': 560,
        'free_throw_attempts': 650,
        'ts_pct': .627,
        'ast_pct': .38,
        'bpm': 4.7,
        'ws': 10.1,
        'hustle_gp': 75,
        'contested_shots_pg': 3.9,
        'bio_country': 'United States',
      },
      {
        'player_key': 'nba_999',
        'season_id': '2004-05',
        'season_type': 'regular',
        'team_abbreviation': 'BOS',
        'games': 60,
        'minutes': 1900,
        'points': 900,
        'assists': 240,
        // This older season has no three-point attempts recorded.
      },
    ],
    'playoff_seasons': [
      {
        'player_key': 'nba_999',
        'season_id': '2024-25',
        'season_type': 'playoffs',
        'team_abbreviation': 'BOS',
        'games': 12,
        'points': 312,
        'assists': 96,
      },
    ],
  };

  test('Profile season uses the same per-game values as the Stats engine', () {
    const service = ArcsidePlayerProfileStats();
    final rows = service.rows(dossier, segment: 'regular');
    expect(rows, hasLength(2));
    expect(rows.first.season, '2024-25');
    expect(rows.first.row.player, 'Sample Player');
    expect(rows.first.row.team, 'BOS');
    expect(service.value(rows.first.row, 'ppg'), 30);
    expect(service.value(rows.first.row, 'apg'), 8);
    expect(service.format(rows.first.row, 'ppg'), '30.0');
    expect(service.format(rows.first.row, 'fg_pct'), '50.0%');
    expect(service.format(rows.first.row, 'three_pct'), '40.0%');
    expect(service.format(rows.first.row, 'ast_pct'), '38.0%');
    expect(service.value(rows.first.row, 'bpm'), closeTo(4.7, .001));
  });

  test('Advanced catalog fields are preserved from the historical dossier', () {
    const service = ArcsidePlayerProfileStats();
    final season = service.rows(dossier, segment: 'regular').first.row;
    expect(service.value(season, 'ws'), closeTo(10.1, .001));
    expect(service.value(season, 'hustle_gp'), 75);
    expect(service.value(season, 'contested_shots_pg'), closeTo(3.9, .001));
    expect(season.raw['bio_country'], 'United States');
  });

  test('Missing historical inputs are not rendered as fabricated zeros', () {
    const service = ArcsidePlayerProfileStats();
    final early = service.rows(dossier, segment: 'regular').last.row;
    expect(service.format(early, 'three_pa'), '—');
    expect(service.format(early, 'steals_per_game'), '—');
    expect(service.format(early, 'spg'), '—');
  });

  test('Playoffs and regular seasons remain separate', () {
    const service = ArcsidePlayerProfileStats();
    final rows = service.rows(dossier, segment: 'playoffs');
    expect(rows, hasLength(1));
    expect(service.value(rows.single.row, 'ppg'), 26);
  });

  test('Totals and per-36 bases reuse the canonical stats calculations', () {
    const service = ArcsidePlayerProfileStats();
    final total = service.rows(dossier,
        segment: 'regular', basis: NbaStatsBasis.totals).first.row;
    final per36 = service.rows(dossier,
        segment: 'regular', basis: NbaStatsBasis.per36).first.row;
    expect(service.value(total, 'ppg'), 2400);
    expect(service.value(per36, 'ppg'), closeTo(2400 * 36 / 2800, .001));
  });

  test('Unpublished season values stay unavailable', () {
    const service = ArcsidePlayerProfileStats();
    expect(service.rows({'profile': {'canonical_name': 'Missing'}},
      segment: 'regular'), isEmpty);
  });
}
