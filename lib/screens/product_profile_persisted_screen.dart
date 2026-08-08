import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../services/nba_terminal_seed_repository.dart';
import '../services/product_local_store.dart';
import 'product_nba_entity_pages_v2.dart';

const _pfPanel = Color(0xFF0F151C);
const _pfPanel2 = Color(0xFF141C25);
const _pfLine = Color(0xFF263342);
const _pfText = Color(0xFFE8EDF3);
const _pfMuted = Color(0xFF8895A5);
const _pfBlue = Color(0xFF63A9FF);
const _pfAmber = Color(0xFFE2B866);
const _pfGreen = Color(0xFF69C99A);

enum _ProfileSection { overview, identity, teams, interests, notifications, privacy, awards }

extension on _ProfileSection {
  String get label => switch (this) {
    _ProfileSection.overview => 'Overview',
    _ProfileSection.identity => 'Identity',
    _ProfileSection.teams => 'Teams',
    _ProfileSection.interests => 'Interests',
    _ProfileSection.notifications => 'Notifications',
    _ProfileSection.privacy => 'Privacy',
    _ProfileSection.awards => 'Awards & Badges',
  };
}

class ProductPersistedProfileScreen extends StatefulWidget {
  const ProductPersistedProfileScreen({super.key, required this.session});
  final AppSession session;

  @override
  State<ProductPersistedProfileScreen> createState() => _ProductPersistedProfileScreenState();
}

class _ProductPersistedProfileScreenState extends State<ProductPersistedProfileScreen> {
  final ProductLocalStore _store = const ProductLocalStore();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _avatarUrl = TextEditingController();

  _ProfileSection _section = _ProfileSection.overview;
  bool _loaded = false;
  bool _publicProfile = true;
  bool _showFavorites = true;
  bool _showActivity = true;
  bool _showAwards = true;
  bool _emailDigest = false;
  bool _teamAlerts = true;
  bool _playerAlerts = true;
  bool _replyAlerts = true;
  bool _messageAlerts = true;
  bool _productUpdates = false;
  Set<String> _favoriteTeams = {};
  Set<String> _watchlist = {};
  Set<String> _sports = {'NBA'};
  Set<String> _contentInterests = {'Analysis', 'Transactions', 'Statistics'};

  static const _sportsOptions = [
    'NBA', 'WNBA', 'NFL', 'NHL', 'MLB', 'NCAAM', 'NCAAW', 'College Football',
    'Tennis', 'MLS', 'Premier League', 'Champions League', 'Formula 1', 'Golf',
  ];
  static const _interestOptions = [
    'Breaking News', 'Analysis', 'Statistics', 'Transactions', 'Draft', 'Salary Cap',
    'Fantasy', 'Betting Analysis', 'Team Coverage', 'Long-form', 'Podcasts', 'Community',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _bio.dispose();
    _location.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await _store.loadStringMap(ProductLocalStore.profileSettingsKey);
    final teams = await _store.loadStringSet(ProductLocalStore.favoriteTeamsKey);
    final watchlist = await _store.loadStringSet(ProductLocalStore.playerWatchlistKey);
    if (!mounted) return;
    setState(() {
      _username.text = settings['username']?.trim().isNotEmpty == true
          ? settings['username']!
          : _defaultUsername(widget.session.displayName);
      _displayName.text = settings['displayName']?.trim().isNotEmpty == true
          ? settings['displayName']!
          : widget.session.displayName;
      _bio.text = settings['bio'] ?? '';
      _location.text = settings['location'] ?? '';
      _avatarUrl.text = settings['avatarUrl'] ?? '';
      _publicProfile = settings['publicProfile'] != 'false';
      _showFavorites = settings['showFavorites'] != 'false';
      _showActivity = settings['showActivity'] != 'false';
      _showAwards = settings['showAwards'] != 'false';
      _emailDigest = settings['emailDigest'] == 'true';
      _teamAlerts = settings['teamAlerts'] != 'false';
      _playerAlerts = settings['playerAlerts'] != 'false';
      _replyAlerts = settings['replyAlerts'] != 'false';
      _messageAlerts = settings['messageAlerts'] != 'false';
      _productUpdates = settings['productUpdates'] == 'true';
      _sports = _decodeSet(settings['sports'], fallback: {'NBA'});
      _contentInterests = _decodeSet(settings['contentInterests'], fallback: {'Analysis', 'Transactions', 'Statistics'});
      _favoriteTeams = teams;
      _watchlist = watchlist;
      _loaded = true;
    });
  }

  Future<void> _save({bool toast = false}) async {
    await Future.wait([
      _store.saveStringMap(ProductLocalStore.profileSettingsKey, {
        'username': _cleanHandle(_username.text),
        'displayName': _displayName.text.trim(),
        'bio': _bio.text.trim(),
        'location': _location.text.trim(),
        'avatarUrl': _avatarUrl.text.trim(),
        'publicProfile': '$_publicProfile',
        'showFavorites': '$_showFavorites',
        'showActivity': '$_showActivity',
        'showAwards': '$_showAwards',
        'emailDigest': '$_emailDigest',
        'teamAlerts': '$_teamAlerts',
        'playerAlerts': '$_playerAlerts',
        'replyAlerts': '$_replyAlerts',
        'messageAlerts': '$_messageAlerts',
        'productUpdates': '$_productUpdates',
        'sports': _sports.join('|'),
        'contentInterests': _contentInterests.join('|'),
      }),
      _store.saveStringSet(ProductLocalStore.favoriteTeamsKey, _favoriteTeams),
    ]);
    if (toast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile preferences saved.')));
    }
  }

  Future<void> _toggleTeam(String team) async {
    setState(() {
      if (!_favoriteTeams.add(team)) _favoriteTeams.remove(team);
    });
    await _save();
  }

  void _toggleSport(String sport) {
    setState(() {
      if (!_sports.add(sport)) _sports.remove(sport);
    });
    _save();
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (!_contentInterests.add(interest)) _contentInterests.remove(interest);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _ProfilePanel(child: Center(child: CircularProgressIndicator()));
    return FutureBuilder<NbaTerminalSeedSnapshot>(
      future: const NbaTerminalSeedRepository().load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final teams = data == null
            ? <String>[]
            : (data.teamRecords.map(_teamId).where((value) => value != '—').toSet().toList()..sort());
        final awards = _profileAwards();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ProfileHero(
            session: widget.session,
            displayName: _displayName.text.trim().isEmpty ? widget.session.displayName : _displayName.text.trim(),
            username: _cleanHandle(_username.text),
            bio: _bio.text,
            avatarUrl: _avatarUrl.text.trim(),
            publicProfile: _publicProfile,
            favoriteTeams: _favoriteTeams.length,
            watchlist: _watchlist.length,
            awards: awards.length,
          ),
          const SizedBox(height: 12),
          _ProfileNav(selected: _section, onSelected: (value) => setState(() => _section = value)),
          const SizedBox(height: 12),
          switch (_section) {
            _ProfileSection.overview => _Overview(
                session: widget.session,
                favoriteTeams: _favoriteTeams,
                watchlist: _watchlist,
                sports: _sports,
                interests: _contentInterests,
                awards: awards,
              ),
            _ProfileSection.identity => _IdentityEditor(
                username: _username,
                displayName: _displayName,
                bio: _bio,
                location: _location,
                avatarUrl: _avatarUrl,
                onSave: () => _save(toast: true),
                onChanged: () => setState(() {}),
              ),
            _ProfileSection.teams => _Teams(
                teams: teams,
                data: data,
                selected: _favoriteTeams,
                onToggle: _toggleTeam,
              ),
            _ProfileSection.interests => _Interests(
                sports: _sports,
                sportOptions: _sportsOptions,
                interests: _contentInterests,
                interestOptions: _interestOptions,
                onSport: _toggleSport,
                onInterest: _toggleInterest,
              ),
            _ProfileSection.notifications => _Notifications(
                emailDigest: _emailDigest,
                teamAlerts: _teamAlerts,
                playerAlerts: _playerAlerts,
                replyAlerts: _replyAlerts,
                messageAlerts: _messageAlerts,
                productUpdates: _productUpdates,
                onChanged: (key, value) {
                  setState(() {
                    switch (key) {
                      case 'email': _emailDigest = value; break;
                      case 'team': _teamAlerts = value; break;
                      case 'player': _playerAlerts = value; break;
                      case 'reply': _replyAlerts = value; break;
                      case 'message': _messageAlerts = value; break;
                      case 'product': _productUpdates = value; break;
                    }
                  });
                  _save();
                },
              ),
            _ProfileSection.privacy => _PrivacySettings(
                publicProfile: _publicProfile,
                showFavorites: _showFavorites,
                showActivity: _showActivity,
                showAwards: _showAwards,
                onChanged: (key, value) {
                  setState(() {
                    switch (key) {
                      case 'public': _publicProfile = value; break;
                      case 'favorites': _showFavorites = value; break;
                      case 'activity': _showActivity = value; break;
                      case 'awards': _showAwards = value; break;
                    }
                  });
                  _save();
                },
              ),
            _ProfileSection.awards => _AwardCabinet(awards: awards),
          },
        ]);
      },
    );
  }

  List<_ProfileAward> _profileAwards() {
    final values = <_ProfileAward>[
      const _ProfileAward('Founding Member', 'EARLY', Icons.rocket_launch_rounded, _pfAmber, 'Created a Sports Terminal account during the build-era release.'),
      const _ProfileAward('NBA Researcher', 'RESEARCH', Icons.query_stats_rounded, _pfBlue, 'Uses the NBA intelligence and research platform.'),
    ];
    if (_favoriteTeams.isNotEmpty) values.add(_ProfileAward('Club Loyalist', '${_favoriteTeams.length} TEAM${_favoriteTeams.length == 1 ? '' : 'S'}', Icons.groups_rounded, _pfGreen, 'Declared one or more favorite NBA teams.'));
    if (_watchlist.length >= 5) values.add(_ProfileAward('Scout Board', '${_watchlist.length} WATCHED', Icons.visibility_rounded, _pfBlue, 'Maintains a five-player-or-more research watchlist.'));
    if (widget.session.role.canManageOrganization) values.add(const _ProfileAward('Organization Operator', 'ORG', Icons.apartment_rounded, _pfAmber, 'Operates an organization-scoped Sports Terminal workspace.'));
    if (_sports.length >= 5) values.add(const _ProfileAward('Multi-Sport', '5+ SPORTS', Icons.public_rounded, _pfGreen, 'Follows at least five sports or competitions.'));
    return values;
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.session, required this.displayName, required this.username, required this.bio, required this.avatarUrl, required this.publicProfile, required this.favoriteTeams, required this.watchlist, required this.awards});
  final AppSession session;
  final String displayName;
  final String username;
  final String bio;
  final String avatarUrl;
  final bool publicProfile;
  final int favoriteTeams;
  final int watchlist;
  final int awards;
  @override
  Widget build(BuildContext context) => _ProfilePanel(
        child: LayoutBuilder(builder: (context, constraints) {
          final identity = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Avatar(name: displayName, url: avatarUrl, radius: constraints.maxWidth < 700 ? 37 : 48),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('USER PROFILE', style: TextStyle(color: _pfBlue, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .9)),
              const SizedBox(height: 4),
              Text(displayName, style: const TextStyle(color: _pfText, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text('@$username · ${session.role.label} · ${session.organizationName}', style: const TextStyle(color: _pfMuted, fontSize: 10)),
              if (bio.trim().isNotEmpty) ...[const SizedBox(height: 7), Text(bio, style: const TextStyle(color: _pfText, height: 1.4))],
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _Tag(publicProfile ? 'PUBLIC PROFILE' : 'PRIVATE PROFILE', publicProfile ? _pfGreen : _pfAmber),
                _Tag('$favoriteTeams FAVORITE TEAMS', _pfBlue),
                _Tag('$watchlist WATCHED PLAYERS', _pfBlue),
                _Tag('$awards BADGES', _pfAmber),
              ]),
            ])),
          ]);
          return identity;
        }),
      );
}

class _ProfileNav extends StatelessWidget {
  const _ProfileNav({required this.selected, required this.onSelected});
  final _ProfileSection selected;
  final ValueChanged<_ProfileSection> onSelected;
  @override
  Widget build(BuildContext context) => _ProfilePanel(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 6, runSpacing: 6, children: [for (final item in _ProfileSection.values) ChoiceChip(label: Text(item.label), selected: selected == item, onSelected: (_) => onSelected(item))]),
      );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.session, required this.favoriteTeams, required this.watchlist, required this.sports, required this.interests, required this.awards});
  final AppSession session;
  final Set<String> favoriteTeams;
  final Set<String> watchlist;
  final Set<String> sports;
  final Set<String> interests;
  final List<_ProfileAward> awards;
  @override
  Widget build(BuildContext context) => Column(children: [
        _StatsGrid(items: [
          _Stat('Favorite teams', '${favoriteTeams.length}', favoriteTeams.isEmpty ? 'none selected' : favoriteTeams.take(4).join(' · ')),
          _Stat('Player watchlist', '${watchlist.length}', 'shared across NBA research'),
          _Stat('Sports followed', '${sports.length}', sports.take(4).join(' · ')),
          _Stat('Badges earned', '${awards.length}', awards.take(2).map((item) => item.title).join(' · ')),
        ]),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final left = _ProfilePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionTitle('Sports identity', 'What the rest of Sports Terminal can use to personalize the experience.'),
            const SizedBox(height: 10),
            _KeyValue('Role', session.role.label),
            _KeyValue('Organization', session.organizationName),
            _KeyValue('Account email', session.email),
            _KeyValue('Favorite teams', favoriteTeams.isEmpty ? 'None selected' : favoriteTeams.join(', ')),
            _KeyValue('Content interests', interests.isEmpty ? 'None selected' : interests.join(', ')),
          ]));
          final right = _ProfilePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionTitle('Award cabinet', 'Visible profile recognition generated from real product milestones.'),
            const SizedBox(height: 10),
            for (final award in awards.take(4)) _AwardLine(award: award),
          ]));
          if (constraints.maxWidth < 900) return Column(children: [left, const SizedBox(height: 12), right]);
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)]);
        }),
      ]);
}

class _IdentityEditor extends StatelessWidget {
  const _IdentityEditor({required this.username, required this.displayName, required this.bio, required this.location, required this.avatarUrl, required this.onSave, required this.onChanged});
  final TextEditingController username;
  final TextEditingController displayName;
  final TextEditingController bio;
  final TextEditingController location;
  final TextEditingController avatarUrl;
  final VoidCallback onSave;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => _ProfilePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle('Edit identity', 'Change the public-facing profile information stored by this Sports Terminal client.'),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final avatar = Column(children: [
              _Avatar(name: displayName.text, url: avatarUrl.text, radius: 56),
              const SizedBox(height: 8),
              const Text('Profile photo preview', style: TextStyle(color: _pfMuted, fontSize: 9)),
            ]);
            final fields = Column(children: [
              TextField(controller: displayName, onChanged: (_) => onChanged(), decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: username, onChanged: (_) => onChanged(), decoration: const InputDecoration(labelText: 'Username / handle', prefixText: '@', helperText: 'Letters, numbers and underscores; normalized on save.', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: avatarUrl, onChanged: (_) => onChanged(), decoration: const InputDecoration(labelText: 'Profile picture URL', helperText: 'Paste an HTTPS image URL. Leave blank to use generated initials.', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: location, onChanged: (_) => onChanged(), decoration: const InputDecoration(labelText: 'Location (optional)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: bio, minLines: 3, maxLines: 6, onChanged: (_) => onChanged(), decoration: const InputDecoration(labelText: 'Bio', hintText: 'Teams, sports, analysis interests, work, fandom…', border: OutlineInputBorder())),
            ]);
            return compact ? Column(children: [avatar, const SizedBox(height: 14), fields]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 150, child: avatar), const SizedBox(width: 18), Expanded(child: fields)]);
          }),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: onSave, icon: const Icon(Icons.save_rounded), label: const Text('Save profile')),
            OutlinedButton.icon(onPressed: () { avatarUrl.clear(); onChanged(); }, icon: const Icon(Icons.person_rounded), label: const Text('Use generated avatar')),
          ]),
        ]),
      );
}

class _Teams extends StatelessWidget {
  const _Teams({required this.teams, required this.data, required this.selected, required this.onToggle});
  final List<String> teams;
  final NbaTerminalSeedSnapshot? data;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  @override
  Widget build(BuildContext context) => _ProfilePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle('Teams you root for', 'Select any number of teams. These preferences can drive the Home feed, Team Blogs, alerts and article ranking.'),
          const SizedBox(height: 12),
          if (teams.isEmpty)
            const Text('NBA team data is not loaded.', style: TextStyle(color: _pfMuted))
          else
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1150 ? 4 : constraints.maxWidth >= 760 ? 3 : constraints.maxWidth >= 500 ? 2 : 1;
              final gap = 8.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (final team in teams)
                  SizedBox(width: width, child: _TeamPreference(team: team, name: data == null ? team : _teamName(data!, team), selected: selected.contains(team), onToggle: () => onToggle(team))),
              ]);
            }),
        ]),
      );
}

class _TeamPreference extends StatelessWidget {
  const _TeamPreference({required this.team, required this.name, required this.selected, required this.onToggle});
  final String team;
  final String name;
  final bool selected;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: selected ? const Color(0x2269C99A) : _pfPanel2, border: Border.all(color: selected ? _pfGreen : _pfLine), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: _pfPanel, border: Border.all(color: _pfLine), borderRadius: BorderRadius.circular(7)), child: Text(team, style: const TextStyle(color: _pfBlue, fontSize: 10, fontWeight: FontWeight.w900))),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _pfText, fontWeight: FontWeight.w900)), Text(selected ? 'Rooting for this team' : 'Not selected', style: const TextStyle(color: _pfMuted, fontSize: 9))])),
          IconButton(tooltip: selected ? 'Remove favorite' : 'Root for team', onPressed: onToggle, icon: Icon(selected ? Icons.star_rounded : Icons.star_border_rounded, color: selected ? _pfAmber : _pfMuted)),
          IconButton(tooltip: 'Open team page', onPressed: () => openNbaTeamPage(context, teamId: team), icon: const Icon(Icons.chevron_right_rounded, color: _pfBlue)),
        ]),
      );
}

class _Interests extends StatelessWidget {
  const _Interests({required this.sports, required this.sportOptions, required this.interests, required this.interestOptions, required this.onSport, required this.onInterest});
  final Set<String> sports;
  final List<String> sportOptions;
  final Set<String> interests;
  final List<String> interestOptions;
  final ValueChanged<String> onSport;
  final ValueChanged<String> onInterest;
  @override
  Widget build(BuildContext context) => Column(children: [
        _ProfilePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle('Sports & competitions', 'Choose what belongs in your personalized editorial and community experience.'),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, children: [for (final item in sportOptions) FilterChip(label: Text(item), selected: sports.contains(item), onSelected: (_) => onSport(item))]),
        ])),
        const SizedBox(height: 12),
        _ProfilePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle('Content & research interests', 'These signals can rank articles, dashboards, alerts and suggested communities.'),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, children: [for (final item in interestOptions) FilterChip(label: Text(item), selected: interests.contains(item), onSelected: (_) => onInterest(item))]),
        ])),
      ]);
}

class _Notifications extends StatelessWidget {
  const _Notifications({required this.emailDigest, required this.teamAlerts, required this.playerAlerts, required this.replyAlerts, required this.messageAlerts, required this.productUpdates, required this.onChanged});
  final bool emailDigest;
  final bool teamAlerts;
  final bool playerAlerts;
  final bool replyAlerts;
  final bool messageAlerts;
  final bool productUpdates;
  final void Function(String key, bool value) onChanged;
  @override
  Widget build(BuildContext context) => _ProfilePanel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.all(15), child: _SectionTitle('Notification preferences', 'Separate product, team, research and social notifications so users control signal volume.')),
          _SettingSwitch('Weekly email digest', 'Favorite-team stories, watched-player changes and saved research.', emailDigest, (value) => onChanged('email', value)),
          _SettingSwitch('Favorite-team alerts', 'Breaking news, games, transactions and team coverage.', teamAlerts, (value) => onChanged('team', value)),
          _SettingSwitch('Player watchlist alerts', 'Role, injury, transaction and performance changes for watched players.', playerAlerts, (value) => onChanged('player', value)),
          _SettingSwitch('Replies & mentions', 'Community replies, mentions and thread activity.', replyAlerts, (value) => onChanged('reply', value)),
          _SettingSwitch('Direct messages', 'New message and conversation notifications.', messageAlerts, (value) => onChanged('message', value)),
          _SettingSwitch('Product updates', 'Optional feature announcements and product news.', productUpdates, (value) => onChanged('product', value)),
        ]),
      );
}

class _PrivacySettings extends StatelessWidget {
  const _PrivacySettings({required this.publicProfile, required this.showFavorites, required this.showActivity, required this.showAwards, required this.onChanged});
  final bool publicProfile;
  final bool showFavorites;
  final bool showActivity;
  final bool showAwards;
  final void Function(String key, bool value) onChanged;
  @override
  Widget build(BuildContext context) => _ProfilePanel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.all(15), child: _SectionTitle('Profile privacy', 'Choose what other Sports Terminal users can see. Organization access may be governed separately by organization permissions.')),
          _SettingSwitch('Public profile', 'Allow other users to open your public profile.', publicProfile, (value) => onChanged('public', value)),
          _SettingSwitch('Show favorite teams', 'Display teams you root for on the public profile.', showFavorites, (value) => onChanged('favorites', value)),
          _SettingSwitch('Show public activity', 'Display public posts, comments, published articles and other public activity.', showActivity, (value) => onChanged('activity', value)),
          _SettingSwitch('Show awards & badges', 'Display earned Sports Terminal profile recognition.', showAwards, (value) => onChanged('awards', value)),
          const Padding(padding: EdgeInsets.all(15), child: Text('Account deletion, data export, legal privacy requests, session management and security controls will route through the launch account backend rather than being simulated as local-only destructive actions.', style: TextStyle(color: _pfMuted, fontSize: 10, height: 1.4))),
        ]),
      );
}

class _AwardCabinet extends StatelessWidget {
  const _AwardCabinet({required this.awards});
  final List<_ProfileAward> awards;
  @override
  Widget build(BuildContext context) => _ProfilePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionTitle('Awards & badges', 'Profile recognition is separate from NBA player awards. These are Sports Terminal user milestones and reputation markers.'),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
            final gap = 9.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(spacing: gap, runSpacing: gap, children: [for (final award in awards) SizedBox(width: width, child: _AwardCard(award: award))]);
          }),
          const SizedBox(height: 12),
          const Text('Future server-backed awards can include verified contributor, trusted analyst, community milestones, writer/editor recognition, event participation and organization-issued badges. Paid status alone should not masquerade as community reputation.', style: TextStyle(color: _pfMuted, fontSize: 10, height: 1.4)),
        ]),
      );
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.award});
  final _ProfileAward award;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: _pfPanel2, border: Border.all(color: award.color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(9)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(award.icon, color: award.color, size: 26),
        const SizedBox(height: 8),
        Text(award.title, style: const TextStyle(color: _pfText, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(award.code, style: TextStyle(color: award.color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .7)),
        const SizedBox(height: 7),
        Text(award.description, style: const TextStyle(color: _pfMuted, fontSize: 10, height: 1.35)),
      ]));
}

class _AwardLine extends StatelessWidget {
  const _AwardLine({required this.award});
  final _ProfileAward award;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _pfLine, width: .5))), child: Row(children: [Icon(award.icon, color: award.color, size: 18), const SizedBox(width: 8), Expanded(child: Text(award.title, style: const TextStyle(color: _pfText, fontWeight: FontWeight.w900))), Text(award.code, style: TextStyle(color: award.color, fontSize: 8, fontWeight: FontWeight.w900))]));
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.url, required this.radius});
  final String name;
  final String url;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final parsed = Uri.tryParse(url);
    final valid = parsed != null && parsed.hasScheme && {'http', 'https'}.contains(parsed.scheme);
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF172B46),
      foregroundImage: valid ? NetworkImage(url) : null,
      onForegroundImageError: valid ? (_, __) {} : null,
      child: Text(_initials(name), style: TextStyle(color: _pfBlue, fontSize: radius * .55, fontWeight: FontWeight.w900)),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch(this.title, this.body, this.value, this.onChanged);
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(border: Border(top: BorderSide(color: _pfLine, width: .5))), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _pfText, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(body, style: const TextStyle(color: _pfMuted, fontSize: 10, height: 1.35))])), Switch(value: value, onChanged: onChanged)]));
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});
  final List<_Stat> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 550 ? 2 : 1;
    final gap = 8.0;
    final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
    return Wrap(spacing: gap, runSpacing: gap, children: [for (final item in items) SizedBox(width: width, child: _ProfilePanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.label, style: const TextStyle(color: _pfMuted, fontSize: 8, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(item.value, style: const TextStyle(color: _pfText, fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(item.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _pfBlue, fontSize: 9))])))]);
  });
}

class _Stat { const _Stat(this.label, this.value, this.detail); final String label; final String value; final String detail; }

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(vertical: 7), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _pfLine, width: .5))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 140, child: Text(label, style: const TextStyle(color: _pfMuted, fontSize: 9))), Expanded(child: SelectableText(value, style: const TextStyle(color: _pfText, fontSize: 10, fontWeight: FontWeight.w800)))]));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _pfText, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: _pfMuted, fontSize: 10, height: 1.35))]);
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: .55)), borderRadius: BorderRadius.circular(999)), child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: .4)));
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({required this.child, this.padding = const EdgeInsets.all(15)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: padding, decoration: BoxDecoration(color: _pfPanel, border: Border.all(color: _pfLine), borderRadius: BorderRadius.circular(9)), child: child);
}

class _ProfileAward {
  const _ProfileAward(this.title, this.code, this.icon, this.color, this.description);
  final String title;
  final String code;
  final IconData icon;
  final Color color;
  final String description;
}

Set<String> _decodeSet(String? value, {required Set<String> fallback}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return Set<String>.from(fallback);
  return text.split('|').where((item) => item.trim().isNotEmpty).map((item) => item.trim()).toSet();
}
String _cleanHandle(String value) {
  final cleaned = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return cleaned.isEmpty ? 'sports_fan' : cleaned;
}
String _defaultUsername(String value) => _cleanHandle(value);
String _initials(String value) => value.trim().isEmpty ? 'ST' : value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).map((part) => part[0].toUpperCase()).join();
String _teamId(Map<String, dynamic> row) {
  for (final key in const ['team_abbreviation', 'abbreviation', 'team', 'team_id', 'id']) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '—';
}
String _teamName(NbaTerminalSeedSnapshot data, String team) {
  final row = data.teamRecords.firstWhere((item) => _teamId(item) == team, orElse: () => data.teams.firstWhere((item) => _teamId(item) == team, orElse: () => const {}));
  final value = row['team_name'] ?? row['name'] ?? row['full_name'];
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? team : text;
}
