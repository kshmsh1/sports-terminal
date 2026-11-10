import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/nba_player_profile_presentation.dart';

void main() {
  test('Player positions always appear PG SG SF PF C', () {
    expect(nbaOrderedPositions('SG, SF, PF, PG, C'),
        'PG, SG, SF, PF, C');
    expect(nbaOrderedPositions('C, PF, PF, SG'), 'SG, PF, C');
    expect(nbaOrderedPositions(''), isEmpty);
  });

  test('Award labels normalize source codes and deduplicate award years', () {
    final awards = <Map<String, dynamic>>[
      for (final season in ['2008-09','2009-10','2011-12','2012-13'])
        {'award': 'nba_mvp', 'season_id': season, 'winner': 1},
      {'award': 'NBA MVP', 'season_id': '2008-09', 'winner': 1},
      {'award': 'nba_mvp', 'season_id': '2003-04', 'winner': 0},
      {'award': 'All-NBA', 'season_id': '2004-05', 'winner': 0},
      {'award': 'all_nba', 'season_id': '2004-05', 'winner': 0},
      {'award': 'all_defense', 'season_id': '2008-09', 'winner': 0},
    ];
    final groups = nbaGroupPlayerHonors(awards, const []);
    final mvp = groups.firstWhere(
      (g) => g.title == 'Most Valuable Player (MVP)');
    expect(mvp.summary, '4x: 2009, 2010, 2012, 2013');
    expect(groups.first.title, 'Most Valuable Player (MVP)');
    final allNba = groups.firstWhere((g) => g.title == 'All-NBA Team');
    expect(allNba.summary, '1x: 2005');
    expect(groups.any((g) => g.years.contains(2004)), isFalse);
  });

  test('All-Star years group once even for duplicate selections', () {
    final groups = nbaGroupPlayerHonors(const [], const [
      {'season_id': '2019-20'},
      {'season_id': '2019-20'},
      {'season_id': '2020-21'},
    ]);
    expect(groups.single.title, 'NBA All-Star');
    expect(groups.single.summary, '2x: 2020, 2021');
  });

  test('Every advanced family is available for player dossiers', () {
    final page = File('lib/screens/website_nba_entity_pages_legacy.dart')
        .readAsStringSync();
    expect(page, contains('nbaTerminalStatFamilies'));
    expect(page, contains('nbaVisibleMetricKeys'));
    expect(page, contains('columnSpacing: 19'));
    expect(page, contains('dataRowMinHeight: 35'));
    expect(page, contains('nbaGroupPlayerHonors'));
    expect(page, contains('columns = constraints.maxWidth >= 1000 ? 4'));
    expect(page, contains("salaryFor('2026-27')"));
    expect(page, isNot(contains("const _SectionTitle('Recent games')")));
  });

  test('Research uses an unboxed layout and Community retains actions', () {
    final research = File('lib/widgets/nba_research_query_panel.dart')
        .readAsStringSync();
    final researchScreen =
        File('lib/screens/website_nba_research_screen.dart').readAsStringSync();
    final community = File('lib/screens/product_community_v2_screen.dart')
        .readAsStringSync();
    expect(research, contains('Recent queries'));
    expect(research, contains('Research Hub'));
    expect(research, contains('Ask about NBA history'));
    expect(research, contains('_history.insert'));
    expect(researchScreen, contains('ExpansionTile('));
    expect(community, contains('_communitySidebar'));
    expect(community, contains('_communityFeed'));
    expect(community, contains('Create post'));
    expect(community, contains('onVote'));
    expect(community, contains('onSave'));
    expect(community, contains('onReport'));
    expect(community, contains('onMute'));
    expect(community, contains('onBlock'));
  });
}
