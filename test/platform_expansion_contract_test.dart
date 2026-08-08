import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('platform shell owns vertical page scrolling', () {
    final shell = File(
      'lib/widgets/connected_role_terminal_shell.dart',
    ).readAsStringSync();
    expect(shell, contains('The platform shell owns the vertical scroll'));
    expect(shell, contains('SingleChildScrollView('));
    expect(shell, contains('ProductNbaStatsCenterScreen'));
    expect(shell, contains("label: 'Advanced Stats'"));
    expect(shell, contains('ProductNbaHubV2Screen'));
    expect(shell, contains('ProductNbaAwardsScreen'));
    expect(shell, contains('ProductCommunityV2Screen'));
    expect(shell, contains('ProductArticlesV2Screen'));
  });

  test('basic Stats is basic-only and links every rendered player/team', () {
    final stats = File(
      'lib/screens/product_nba_basic_stats_screen.dart',
    ).readAsStringSync();
    expect(stats, contains("'gp'"));
    expect(stats, contains("'pts'"));
    expect(stats, contains("'fg_pct'"));
    expect(stats, isNot(contains("'bpm'")));
    expect(stats, isNot(contains("'epm'")));
    expect(stats, contains('openNbaPlayerPage'));
    expect(stats, contains('openNbaTeamPage'));
    expect(stats, isNot(contains('ListView(')));
  });

  test('Advanced Stats owns the full metric workstation in document flow', () {
    final advanced = File(
      'lib/screens/product_nba_advanced_stats_document_screen.dart',
    ).readAsStringSync();
    expect(advanced, contains('nbaTerminalStatFamilies'));
    expect(advanced, contains('nbaTerminalMetrics'));
    expect(advanced, contains('NbaStatsBasis.values'));
    expect(advanced, contains('ADVANCED STAT GLOSSARY'));
    expect(advanced, contains('openNbaPlayerPage'));
    expect(advanced, contains('openNbaTeamPage'));
    expect(advanced, isNot(contains('ListView(')));
  });

  test('NBA Hub exposes league-wide product desks and linked entities', () {
    final hub = File(
      'lib/screens/product_nba_hub_v2_screen.dart',
    ).readAsStringSync();
    for (final label in const [
      'Overview',
      'Players',
      'Teams',
      'Standings',
      'Schedule & Results',
      'Leaders',
      'Awards & Voting',
      'League Data',
    ]) {
      expect(hub, contains(label));
    }
    expect(hub, contains('openNbaPlayerPage'));
    expect(hub, contains('openNbaTeamPage'));
  });

  test(
    'account creation requires separately versioned Terms and Privacy acceptance',
    () {
      final login = File('lib/screens/login_screen.dart').readAsStringSync();
      final authClient = File(
        'lib/services/launch_auth_client.dart',
      ).readAsStringSync();
      expect(login, contains('acceptedTerms'));
      expect(login, contains('acceptedPrivacy'));
      expect(login, contains('sportsTerminalTermsVersion'));
      expect(login, contains('sportsTerminalPrivacyVersion'));
      expect(authClient, contains("'accepted_terms': acceptedTerms"));
      expect(authClient, contains("'accepted_privacy': acceptedPrivacy"));
      expect(authClient, contains("'terms_version': termsVersion"));
      expect(authClient, contains("'privacy_version': privacyVersion"));
    },
  );

  test(
    'Python output is structurally below code rather than a desktop side pane',
    () {
      final python = File(
        'lib/screens/product_python_lab_v2_screen.dart',
      ).readAsStringSync();
      final codeIndex = python.indexOf("'CODE CELL 1'");
      final outputIndex = python.indexOf("'CELL OUTPUT'");
      expect(codeIndex, greaterThan(0));
      expect(outputIndex, greaterThan(codeIndex));
      expect(
        python,
        contains(
          'Output intentionally sits below the notebook code cell at every width.',
        ),
      );
    },
  );

  test(
    'team blogs community articles and profile are substantive product surfaces',
    () {
      final blogs = File(
        'lib/screens/product_team_blogs_screen.dart',
      ).readAsStringSync();
      final community = File(
        'lib/screens/product_community_v2_screen.dart',
      ).readAsStringSync();
      final articles = File(
        'lib/screens/product_articles_v2_screen.dart',
      ).readAsStringSync();
      final profile = File(
        'lib/screens/product_profile_persisted_screen.dart',
      ).readAsStringSync();

      for (final label in const [
        'Coverage',
        'Roster',
        'Schedule',
        'Stats',
        'Fan Room',
      ]) {
        expect(blogs, contains(label));
      }
      for (final label in const [
        'Hot',
        'New',
        'Top',
        'Most Discussed',
        'Rising',
      ]) {
        expect(community, contains(label));
      }
      for (final sport in const [
        'NBA',
        'WNBA',
        'NFL',
        'NHL',
        'MLB',
        'NCAAM',
        'NCAAW',
        'College Football',
        'Tennis',
        'MLS',
        'Premier League',
        'Champions League',
      ]) {
        expect(articles, contains("'$sport'"));
      }
      for (final label in const [
        'Identity',
        'Teams',
        'Interests',
        'Notifications',
        'Privacy',
        'Awards & Badges',
      ]) {
        expect(profile, contains(label));
      }
    },
  );
}
