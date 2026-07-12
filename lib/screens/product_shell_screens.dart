import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_terminal_seed_repository.dart';

const _ink = Color(0xFF102033);
const _muted = Color(0xFF667085);
const _soft = Color(0xFFF4F7FB);
const _line = Color(0xFFE3E8F0);
const _blue = Color(0xFF2563EB);
const _orange = Color(0xFFFF7A1A);
const _green = Color(0xFF059669);

class ProductHomeScreen extends StatelessWidget {
  const ProductHomeScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return _SeedBlock(
      builder: (data) {
        final leaders = _asRows(data.playerLeaders['points_per_game']).take(5).toList();
        final recentGames = data.games.length <= 5 ? data.games : data.games.sublist(data.games.length - 5).reversed.toList();
        return _PageStack(children: [
          _HeroPanel(
            eyebrow: 'Welcome back, ${session.displayName}',
            title: 'Your sports home base, not an endless terminal menu.',
            body: 'Sports Terminal is now organized around the experience users will actually see: personalized NBA data, fantasy workflows, community, articles, workspace, messages, profile, and a separate admin/internal area.',
            primaryAction: 'Open NBA Hub',
            secondaryAction: 'Review Admin Console',
          ),
          _MetricStrip(items: [
            _Metric('NBA games loaded', '${data.games.length}', '2024-25 warehouse'),
            _Metric('Players', '${data.playerSeasonTotals.length}', '${data.players.length} identities'),
            _Metric('Teams', '${data.teams.length}', 'league coverage'),
            _Metric('Data health', data.validationStatus.toUpperCase(), 'seed validation'),
          ]),
          _SectionTitle('Today on Sports Terminal', 'A friendlier landing page that pulls the product together.'),
          _FeatureGrid(cards: const [
            _FeatureCardData(Icons.sports_basketball_outlined, 'NBA hub', 'Browse teams, players, games, leaders, and generated 2024-25 data from one readable league page.'),
            _FeatureCardData(Icons.groups_outlined, 'Community', 'Forums, discussions, team rooms, comments, and moderation workflows are now first-class product areas.'),
            _FeatureCardData(Icons.grid_on_outlined, 'Workspace', 'A simpler spreadsheet-style workspace for watchlists, fantasy notes, team comps, and saved analysis.'),
            _FeatureCardData(Icons.admin_panel_settings_outlined, 'Admin console', 'Data operations, content, moderation, users, billing, legal, and feature flags are separated from the user app.'),
          ]),
          _TwoColumn(
            left: _TableCard(
              title: 'Scoring leaders',
              columns: const ['Player', 'PPG', 'Teams'],
              rows: [for (final row in leaders) [_txt(row['player_label']), _decimal(row['points_per_game'], decimals: 1), _txt(row['team_ids'])]],
            ),
            right: _TableCard(
              title: 'Recent loaded games',
              columns: const ['Date', 'Game', 'Winner'],
              rows: [for (final row in recentGames) [_txt(row['game_date']), _txt(row['game_id']), _txt(row['winner_team_id'])]],
            ),
          ),
          const _RoadmapPanel(),
        ]);
      },
    );
  }
}

class ProductNbaHubScreen extends StatefulWidget {
  const ProductNbaHubScreen({super.key});

  @override
  State<ProductNbaHubScreen> createState() => _ProductNbaHubScreenState();
}

class _ProductNbaHubScreenState extends State<ProductNbaHubScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    return _SeedBlock(
      builder: (data) {
        final q = query.trim().toLowerCase();
        final teams = q.isEmpty ? data.teamRecords : data.teamRecords.where((row) => _txt(row['team_id']).toLowerCase().contains(q)).toList();
        final players = q.isEmpty ? data.playerSeasonTotals.take(15).toList() : data.playerSeasonTotals.where((row) => '${_txt(row['player_label'])} ${_txt(row['team_ids'])}'.toLowerCase().contains(q)).toList();
        final games = q.isEmpty ? data.games.take(20).toList() : data.games.where((row) => '${_txt(row['game_id'])} ${_txt(row['game_date'])} ${_txt(row['away_team_id'])} ${_txt(row['home_team_id'])}'.toLowerCase().contains(q)).toList();
        return _PageStack(children: [
          const _HeroPanel(
            eyebrow: 'NBA',
            title: 'One league hub for teams, players, games, standings, leaders, and discussion.',
            body: 'The old individual data tabs should become sections inside league, team, player, and game pages. This hub is the entry point normal users should understand immediately.',
            primaryAction: 'Search league data',
            secondaryAction: 'Follow favorites soon',
          ),
          _SearchCard(value: query, hint: 'Search teams, players, dates, or game IDs...', onChanged: (value) => setState(() => query = value)),
          _MetricStrip(items: [
            _Metric('Teams', '${teams.length}', q.isEmpty ? 'all teams' : 'matching'),
            _Metric('Players', '${players.length}', q.isEmpty ? 'top slice' : 'matching'),
            _Metric('Games', '${games.length}', q.isEmpty ? 'first slice' : 'matching'),
            _Metric('PBP events', _compact(data.playByPlayEvents), 'warehouse depth'),
          ]),
          _TwoColumn(
            left: _TableCard(
              title: 'Team snapshot',
              columns: const ['Team', 'W-L', 'PPG', 'Margin'],
              rows: [for (final row in teams.take(12)) [_txt(row['team_id']), '${_txt(row['wins'])}-${_txt(row['losses'])}', _decimal(row['points_per_game'], decimals: 1), _decimal(row['average_margin'], decimals: 1)]],
            ),
            right: _TableCard(
              title: 'Player snapshot',
              columns: const ['Player', 'Teams', 'PPG', 'BPM'],
              rows: [for (final row in players.take(12)) [_txt(row['player_label']), _txt(row['team_ids']), _decimal(row['points_per_game'], decimals: 1), _decimal(row['avg_bpm'], decimals: 1)]],
            ),
          ),
          _TableCard(
            title: 'Game finder',
            columns: const ['Date', 'Game', 'Away', 'Home', 'Winner'],
            rows: [for (final row in games.take(30)) [_txt(row['game_date']), _txt(row['game_id']), _txt(row['away_team_id']), _txt(row['home_team_id']), _txt(row['winner_team_id'])]],
          ),
          _SectionTitle('Next NBA page work', 'Convert this hub into real routed team pages, player pages, game pages, standings, schedules, and discussion pages.'),
        ]);
      },
    );
  }
}

class ProductFantasyScreen extends StatelessWidget {
  const ProductFantasyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SeedBlock(builder: (data) {
      final leaders = _asRows(data.playerLeaders['points_per_game']).take(12).toList();
      return _PageStack(children: [
        const _HeroPanel(
          eyebrow: 'Fantasy',
          title: 'A fantasy workspace that starts with watchlists and player discovery.',
          body: 'This is the future home for roster tracking, waiver targets, player cards, matchup notes, projections, league imports, and saved fantasy workspaces.',
          primaryAction: 'Create watchlist soon',
          secondaryAction: 'Import league later',
        ),
        _MetricStrip(items: const [
          _Metric('Watchlists', 'Demo', 'persistence needed'),
          _Metric('League import', 'Planned', 'backend needed'),
          _Metric('Waiver board', 'Planned', 'ranking model needed'),
          _Metric('Alerts', 'Planned', 'notifications needed'),
        ]),
        _TableCard(
          title: 'Starter fantasy watchlist seed',
          columns: const ['Player', 'Teams', 'PPG', 'REB/G', 'AST/G', 'BPM'],
          rows: [for (final row in leaders) [_txt(row['player_label']), _txt(row['team_ids']), _decimal(row['points_per_game'], decimals: 1), _decimal(row['rebounds_per_game'], decimals: 1), _decimal(row['assists_per_game'], decimals: 1), _decimal(row['avg_bpm'], decimals: 1)]],
        ),
        _FeatureGrid(cards: const [
          _FeatureCardData(Icons.bookmark_add_outlined, 'Watchlists', 'Save players and teams to monitor across fantasy, betting research, and fandom.'),
          _FeatureCardData(Icons.compare_arrows_outlined, 'Player comps', 'Compare scoring, efficiency, role, recent form, and game-log patterns.'),
          _FeatureCardData(Icons.notifications_active_outlined, 'Alerts', 'Notify users when a player crosses thresholds, trends, or matchup criteria.'),
          _FeatureCardData(Icons.upload_file_outlined, 'League import', 'Eventually connect fantasy leagues or upload rosters to make this personalized.'),
        ]),
      ]);
    });
  }
}

class ProductCommunityScreen extends StatelessWidget {
  const ProductCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageStack(children: const [
      _HeroPanel(
        eyebrow: 'Community',
        title: 'Forums, team rooms, comments, and public profiles should be core to the product.',
        body: 'The data terminal gets users in the door, but community keeps them coming back. This section is the placeholder product surface for forums, posts, comments, likes, saved threads, and moderation.',
        primaryAction: 'Create post soon',
        secondaryAction: 'Browse team rooms soon',
      ),
      _SectionTitle('Community modules to build', 'These need a backend, user accounts, moderation rules, and persistence.'),
      _FeatureGrid(cards: [
        _FeatureCardData(Icons.forum_outlined, 'Forums', 'League-wide, team-specific, fantasy, betting-research, and product-feedback boards.'),
        _FeatureCardData(Icons.comment_outlined, 'Comments', 'Discussion under articles, player pages, team pages, game pages, and workspace templates.'),
        _FeatureCardData(Icons.verified_user_outlined, 'Moderation', 'Report queues, user bans, content flags, safe defaults, and admin review flows.'),
        _FeatureCardData(Icons.people_outline, 'Social graph', 'Profiles, follows, saved posts, reputation, and notification preferences.'),
      ]),
      _TableCard(
        title: 'Demo forum structure',
        columns: ['Board', 'Purpose', 'Launch status'],
        rows: [
          ['NBA General', 'League discussion and news', 'Needs backend'],
          ['Team Rooms', 'Dedicated team communities', 'Needs routing'],
          ['Fantasy', 'Waivers, trades, starts/sits', 'Needs persistence'],
          ['Product Feedback', 'User ideas and bug reports', 'Needs moderation'],
        ],
      ),
    ]);
  }
}

class ProductArticlesScreen extends StatelessWidget {
  const ProductArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageStack(children: const [
      _HeroPanel(
        eyebrow: 'Articles & Blogs',
        title: 'Editorial and user-generated writing belong beside the data.',
        body: 'This should become the content layer for explainers, team/player breakdowns, fantasy notes, platform updates, and eventually community-submitted posts.',
        primaryAction: 'Write article soon',
        secondaryAction: 'Open CMS in admin',
      ),
      _FeatureGrid(cards: [
        _FeatureCardData(Icons.article_outlined, 'Editorial posts', 'Founder/team-created posts, explainers, release notes, and analysis.'),
        _FeatureCardData(Icons.edit_note_outlined, 'User blogs', 'Community writing with drafts, moderation, author profiles, and comments.'),
        _FeatureCardData(Icons.newspaper_outlined, 'Team/player pages', 'Article modules embedded directly into entity pages.'),
        _FeatureCardData(Icons.dashboard_customize_outlined, 'CMS', 'Admin tools for publishing, featuring, tagging, and unpublishing content.'),
      ]),
      _TableCard(
        title: 'Starter content plan',
        columns: ['Content type', 'Examples', 'Needed for launch'],
        rows: [
          ['Platform', 'What is Sports Terminal?', 'Yes'],
          ['NBA explainers', 'How to read team splits and player roles', 'Yes'],
          ['Fantasy', 'Weekly waiver and watchlist posts', 'Later'],
          ['Community', 'Featured user posts', 'Later'],
        ],
      ),
    ]);
  }
}

class ProductWorkspaceHubScreen extends StatelessWidget {
  const ProductWorkspaceHubScreen({super.key, required this.workspace});

  final Widget workspace;

  @override
  Widget build(BuildContext context) {
    return _PageStack(children: [
      const _HeroPanel(
        eyebrow: 'Workspace',
        title: 'A simpler Excel-like workspace for sports work.',
        body: 'The workspace should let users save sheets, create watchlists, compare players, add notes, use templates, and eventually export or share their analysis.',
        primaryAction: 'Open sheet below',
        secondaryAction: 'Templates soon',
      ),
      const _FeatureGrid(cards: [
        _FeatureCardData(Icons.table_chart_outlined, 'Simple sheets', 'Rows, columns, saved views, and sports-specific templates without full Excel complexity.'),
        _FeatureCardData(Icons.functions_outlined, 'Calculated fields', 'Basic formulas for margins, ranks, fantasy scores, and player filters.'),
        _FeatureCardData(Icons.folder_copy_outlined, 'Saved workspaces', 'Persisted personal and organization workbooks once backend storage exists.'),
        _FeatureCardData(Icons.share_outlined, 'Share/export', 'Shareable read-only views, CSV export, and team collaboration later.'),
      ]),
      workspace,
    ]);
  }
}

class ProductMessagesScreen extends StatelessWidget {
  const ProductMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageStack(children: const [
      _HeroPanel(
        eyebrow: 'Messages',
        title: 'Private chats and group rooms should live inside the product eventually.',
        body: 'This is the future home for DMs, group chats, notifications, mentions, saved threads, and team/community conversation surfaces.',
        primaryAction: 'Start chat soon',
        secondaryAction: 'Notifications soon',
      ),
      _TableCard(
        title: 'Messaging roadmap',
        columns: ['Feature', 'Purpose', 'Dependency'],
        rows: [
          ['Direct messages', 'User-to-user private chats', 'Backend + abuse controls'],
          ['Group rooms', 'Private fantasy or team groups', 'Backend + invites'],
          ['Notifications', 'Mentions, replies, alerts', 'Notification service'],
          ['Safety tools', 'Block, report, mute', 'Moderation console'],
        ],
      ),
    ]);
  }
}

class ProductProfileScreen extends StatelessWidget {
  const ProductProfileScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return _PageStack(children: [
      _HeroPanel(
        eyebrow: 'Profile & settings',
        title: session.displayName,
        body: 'User profiles should eventually include favorite teams, favorite players, public bio, saved posts, saved workspaces, privacy settings, notifications, subscription, and account security.',
        primaryAction: 'Edit profile soon',
        secondaryAction: 'Manage plan soon',
      ),
      _MetricStrip(items: [
        _Metric('Organization', session.organizationName, 'current session'),
        _Metric('Role', session.role.label, 'access model'),
        const _Metric('Favorites', 'Planned', 'teams and players'),
        const _Metric('Billing', 'Planned', 'subscription layer'),
      ]),
      const _TableCard(
        title: 'Profile launch checklist',
        columns: ['Area', 'Launch need', 'Status'],
        rows: [
          ['Public profile', 'Bio, avatar, favorite teams, activity', 'Not built'],
          ['Account settings', 'Email, password/provider, privacy', 'Not built'],
          ['Notifications', 'Email/in-app preferences', 'Not built'],
          ['Billing', 'Plan, invoices, cancellation', 'Not built'],
        ],
      ),
    ]);
  }
}

class ProductAdminConsoleScreen extends StatelessWidget {
  const ProductAdminConsoleScreen({super.key, required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    return _SeedBlock(builder: (data) {
      return _PageStack(children: [
        _HeroPanel(
          eyebrow: 'Admin / platform console',
          title: 'Separate the operator view from the user product.',
          body: 'This is where you should manage data, content, users, organizations, moderation, legal, billing, feature flags, and pipeline health. It should not be mixed into the normal user navigation.',
          primaryAction: 'Data health: ${data.validationStatus.toUpperCase()}',
          secondaryAction: 'Signed in as ${session.role.label}',
        ),
        _MetricStrip(items: [
          _Metric('Generated games', '${data.games.length}', 'seed asset'),
          _Metric('Asset files', '${data.copiedAssetFiles}', 'Flutter mirror'),
          _Metric('PBP events', _compact(data.playByPlayEvents), 'warehouse'),
          _Metric('Validation', data.validationStatus.toUpperCase(), 'pipeline gate'),
        ]),
        const _FeatureGrid(cards: [
          _FeatureCardData(Icons.storage_outlined, 'Data operations', 'Pipeline runs, season imports, validation reports, asset sync, and current-season refreshes.'),
          _FeatureCardData(Icons.article_outlined, 'Content CMS', 'Create, edit, feature, tag, and remove articles, blogs, announcements, and homepage cards.'),
          _FeatureCardData(Icons.gavel_outlined, 'Moderation', 'Review reports, remove content, suspend users, audit community behavior, and manage safety.'),
          _FeatureCardData(Icons.payments_outlined, 'Billing & plans', 'Plans, trials, paid tiers, org subscriptions, usage limits, and invoices.'),
          _FeatureCardData(Icons.people_alt_outlined, 'Users & orgs', 'Manage accounts, roles, teams, organizations, permissions, and support status.'),
          _FeatureCardData(Icons.flag_outlined, 'Feature flags', 'Turn modules on/off, run beta programs, and gate experimental functionality.'),
        ]),
        const _TableCard(
          title: 'Admin build status',
          columns: ['Admin area', 'Purpose', 'Current status'],
          rows: [
            ['Data operations', 'Pipeline and asset health', 'Partial prototype'],
            ['CMS', 'Blogs, articles, homepage content', 'Not built'],
            ['Community moderation', 'Reports and enforcement', 'Not built'],
            ['Billing', 'Plans and payment state', 'Not built'],
            ['Users/orgs', 'Roles and permissions', 'Session shell only'],
            ['Legal/trust', 'Policy pages and notices', 'Static pages added'],
          ],
        ),
      ]);
    });
  }
}

class ProductInternalLabScreen extends StatelessWidget {
  const ProductInternalLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageStack(children: const [
      _HeroPanel(
        eyebrow: 'Internal lab',
        title: 'The raw NBA 2025 surfaces are now treated as internal components, not the main product.',
        body: 'The many generated screens we built are still useful as QA, data exploration, and future page sections. They should be exposed to admins and analysts, then embedded into player/team/game pages where appropriate.',
        primaryAction: 'Consolidated',
        secondaryAction: 'User nav cleaned up',
      ),
      _TableCard(
        title: 'Where the old lab surfaces belong',
        columns: ['Surface family', 'Final destination', 'Reason'],
        rows: [
          ['Player screeners, roles, efficiency', 'Player pages and fantasy tools', 'Users need context around players, not a raw tab list'],
          ['Team power, splits, momentum', 'Team pages and NBA hub', 'Team analytics should sit under team pages'],
          ['Game detail, daily tape, box finder', 'Game pages and NBA hub', 'Game workflows should be searchable from schedules/results'],
          ['QA, source map, validation', 'Admin data operations', 'Normal users should not see pipeline internals'],
          ['Compare and trend labs', 'Workspace templates', 'Comparisons should become saved user workbooks'],
        ],
      ),
      _FeatureGrid(cards: [
        _FeatureCardData(Icons.science_outlined, 'Prototype value', 'These screens validated that the generated static asset layer can power many product workflows.'),
        _FeatureCardData(Icons.merge_type_outlined, 'Next step', 'Merge these analytics into friendly user pages and hide raw tooling behind admin/internal access.'),
        _FeatureCardData(Icons.cleaning_services_outlined, 'Navigation cleanup', 'The main nav is now organized around user goals instead of one tab per data slice.'),
        _FeatureCardData(Icons.rocket_launch_outlined, 'Launch path', 'Build backend-backed community, profiles, workspaces, billing, and live data around this foundation.'),
      ]),
    ]);
  }
}

class ProductLegalScreen extends StatelessWidget {
  const ProductLegalScreen({super.key, required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final content = _legalContent(kind);
    return _PageStack(children: [
      _HeroPanel(
        eyebrow: content.eyebrow,
        title: content.title,
        body: content.body,
        primaryAction: content.primary,
        secondaryAction: 'Static draft page',
      ),
      _TableCard(title: content.tableTitle, columns: const ['Section', 'Draft content'], rows: content.rows),
      const _NoticeCard(),
    ]);
  }
}

class _LegalContent {
  const _LegalContent(this.eyebrow, this.title, this.body, this.primary, this.tableTitle, this.rows);
  final String eyebrow;
  final String title;
  final String body;
  final String primary;
  final String tableTitle;
  final List<List<String>> rows;
}

_LegalContent _legalContent(String kind) {
  switch (kind) {
    case 'privacy':
      return const _LegalContent('Privacy', 'Privacy Policy', 'A real privacy policy will need to describe account data, analytics, community content, cookies, payments, communications, and data-sharing practices.', 'Footer-ready', 'Privacy policy draft structure', [
        ['Information collected', 'Account details, profile content, saved workspaces, community posts, usage analytics, and support communications.'],
        ['How it is used', 'To operate the product, personalize the experience, secure the platform, improve features, and provide support.'],
        ['Sharing', 'Payment processors, hosting providers, analytics tools, and legal/safety obligations.'],
        ['User controls', 'Profile edits, notification preferences, deletion/export requests, and privacy settings.'],
      ]);
    case 'terms':
      return const _LegalContent('Terms', 'Terms & Conditions', 'A real terms page will need acceptable-use rules, account terms, subscriptions, data/source disclaimers, community rules, and limitations of liability.', 'Footer-ready', 'Terms draft structure', [
        ['Accounts', 'Users are responsible for account security, accurate information, and activity under their accounts.'],
        ['Community rules', 'No harassment, illegal content, spam, impersonation, or abuse of messaging/community tools.'],
        ['Sports data', 'Stats and analysis are informational and may contain delays, errors, or third-party source limitations.'],
        ['Subscriptions', 'Paid plans, cancellation, refunds, and billing terms must be finalized before launch.'],
      ]);
    case 'contact':
      return const _LegalContent('Contact', 'Contact the Team', 'A contact page should give users a simple way to reach the company for support, partnerships, press, data issues, and trust/safety concerns.', 'Support-ready', 'Contact channels to create', [
        ['Support', 'General product questions, account issues, billing, and bug reports.'],
        ['Data issues', 'Report incorrect stats, missing games, player/team mismatches, or source problems.'],
        ['Partnerships', 'Teams, leagues, agencies, creators, fantasy operators, and data vendors.'],
        ['Trust & safety', 'Community reports, harassment, impersonation, privacy, or moderation appeals.'],
      ]);
    default:
      return const _LegalContent('About', 'About Sports Terminal', 'Sports Terminal is being built as a modern sports intelligence and community platform: deep data, friendly workflows, fantasy tools, community, content, workspaces, and admin-grade operations.', 'Public-ready', 'About page structure', [
        ['Mission', 'Make high-quality sports data, analysis, discussion, and workflows accessible to fans, fantasy players, creators, and operators.'],
        ['Product', 'NBA-first platform with player/team/game pages, community, articles, fantasy tools, workspace, and internal/admin tools.'],
        ['Data philosophy', 'Start with a validated historical warehouse, then add current-season updates and live integrations over time.'],
        ['Roadmap', 'Launch a clean consumer product first, then expand history, current data, subscriptions, and organization features.'],
      ]);
  }
}

class _SeedBlock extends StatelessWidget {
  const _SeedBlock({required this.builder});
  final Widget Function(NbaTerminalSeedSnapshot data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PageStack(children: [_InfoCard('Loading NBA data...', 'The generated seed assets are being loaded from local Flutter assets.')]);
        }
        if (snapshot.hasError) {
          return _PageStack(children: [_InfoCard('NBA data unavailable', '${snapshot.error}\n\nRun the NBA terminal data pipeline and restart Flutter.')]);
        }
        return builder(snapshot.data!);
      },
    );
  }
}

class _PageStack extends StatelessWidget {
  const _PageStack({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final child in children) ...[child, const SizedBox(height: 18)],
    ]);
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.eyebrow, required this.title, required this.body, required this.primaryAction, required this.secondaryAction});
  final String eyebrow;
  final String title;
  final String body;
  final String primaryAction;
  final String secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF102A56), Color(0xFF1D4ED8), Color(0xFFFF7A1A)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: 12)),
        const SizedBox(height: 12),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 850), child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 38, height: 1.05, fontWeight: FontWeight.w900))),
        const SizedBox(height: 14),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: Text(body, style: const TextStyle(color: Color(0xFFE8F0FF), fontSize: 16, height: 1.5))),
        const SizedBox(height: 22),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _ActionPill(label: primaryAction, filled: true),
          _ActionPill(label: secondaryAction, filled: false),
        ]),
      ]),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.filled});
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: filled ? Colors.white : Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.28))),
      child: Text(label, style: TextStyle(color: filled ? const Color(0xFF1D4ED8) : Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.items});
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 900;
      return GridView.count(
        crossAxisCount: wide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: wide ? 2.2 : 1.45,
        children: [for (final item in items) _MetricTile(item)],
      );
    });
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.detail);
  final String label;
  final String value;
  final String detail;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.item);
  final _Metric item;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(item.label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        Text(item.value, style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
        Text(item.detail, style: const TextStyle(color: _blue, fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.cards});
  final List<_FeatureCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 900;
      return GridView.count(
        crossAxisCount: wide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: wide ? 1.12 : 1.0,
        children: [for (final card in cards) _FeatureCard(card)],
      );
    });
  }
}

class _FeatureCardData {
  const _FeatureCardData(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.card);
  final _FeatureCardData card;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(14)), child: Icon(card.icon, color: _blue)),
        const SizedBox(height: 14),
        Text(card.title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 8),
        Expanded(child: Text(card.body, style: const TextStyle(color: _muted, height: 1.35), overflow: TextOverflow.fade)),
      ]),
    );
  }
}

class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 900) return Column(children: [left, const SizedBox(height: 18), right]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 18), Expanded(child: right)]);
    });
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.title, required this.columns, required this.rows});
  final String title;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 18))), Text('${rows.length} rows', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700))])),
        const Divider(height: 1, color: _line),
        if (rows.isEmpty)
          const Padding(padding: EdgeInsets.all(18), child: Text('No rows yet.', style: TextStyle(color: _muted)))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingTextStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w900),
              dataTextStyle: const TextStyle(color: _ink),
              columns: [for (final column in columns) DataColumn(label: Text(column))],
              rows: [for (final row in rows) DataRow(cells: [for (final cell in row) DataCell(SizedBox(width: cell.length > 32 ? 260 : 112, child: Text(cell, overflow: TextOverflow.ellipsis)))]),],
            ),
          ),
      ]),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.value, required this.hint, required this.onChanged});
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: TextField(
        controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
        onChanged: onChanged,
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: hint, filled: true, fillColor: _soft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _line))),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line), boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 8))]), child: child);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: _muted, height: 1.4))]);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => _Surface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(body, style: const TextStyle(color: _muted, height: 1.5))]));
}

class _RoadmapPanel extends StatelessWidget {
  const _RoadmapPanel();

  @override
  Widget build(BuildContext context) {
    return const _TableCard(
      title: 'What changed in this phase',
      columns: ['Before', 'Now', 'Why it matters'],
      rows: [
        ['Endless tabs', 'Goal-based product areas', 'Normal users can understand the app quickly.'],
        ['Internal data tools exposed', 'Internal Lab/Admin split', 'Raw analytics no longer dominate consumer navigation.'],
        ['No legal/footer structure', 'Footer pages added', 'Privacy, terms, contact, and about are now part of the shell.'],
        ['Data prototype', 'Product shell foundation', 'The app can now evolve toward launchable consumer and admin experiences.'],
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard('Legal note', 'This is product placeholder copy, not legal advice. Before public launch, these pages should be reviewed and finalized by counsel, especially if accounts, payments, community content, messaging, analytics, or third-party data integrations are enabled.');
  }
}

List<Map<String, dynamic>> _asRows(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) if (item is Map) item.cast<String, dynamic>()];
}

String _txt(Object? value) => value?.toString() ?? '—';

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _decimal(Object? value, {int decimals = 1}) {
  final number = _num(value);
  return decimals == 0 ? number.round().toString() : number.toStringAsFixed(decimals);
}

String _compact(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
