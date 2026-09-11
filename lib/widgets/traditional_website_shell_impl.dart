import 'package:flutter/material.dart';

import '../controllers/internal_workspace_controller.dart';
import '../models/app_session.dart';
import '../screens/institutional_research_hub_screen.dart';
import '../screens/product_advanced_nba_tools_screen.dart';
import '../screens/product_community_v2_screen.dart';
import '../screens/product_connected_network_screens.dart';
import '../screens/product_content_ops_screens.dart';
import '../screens/product_fantasy_community_screens.dart';
import '../screens/product_front_office_registry_screen.dart';
import '../screens/product_nba_awards_v2_screen.dart';
import '../screens/product_profile_v3_screen.dart';
import '../screens/product_transaction_command_center_screen.dart';
import '../screens/website_nba_advanced_stats_screen.dart';
import '../screens/website_nba_data_coverage_screen.dart';
import '../screens/website_nba_entity_pages.dart';
import '../screens/website_nba_game_finder_screen.dart';
import '../screens/website_nba_history_screen.dart';
import '../screens/website_nba_home_dashboard.dart';
import '../screens/website_nba_lineup_analysis_screen.dart';
import '../screens/website_nba_player_compare_screen.dart';
import '../screens/website_nba_stat_glossary_screen.dart';
import '../screens/website_nba_stats_screen.dart';
import '../screens/website_nba_team_compare_screen.dart';
import '../screens/website_nba_watchlist_screen.dart';
import '../screens/website_trade_machine_screen.dart';
import '../services/product_local_store.dart';
import '../services/website_nba_api_service.dart';
import 'website_nba_data_gate.dart';

const _brandBlue = Color(0xFF6F8BFF);

class TraditionalWebsiteShell extends StatefulWidget {
  const TraditionalWebsiteShell({
    super.key,
    required this.session,
    required this.workspaceController,
    required this.onSignOut,
  });

  final AppSession session;
  final InternalWorkspaceController workspaceController;
  final VoidCallback onSignOut;

  @override
  State<TraditionalWebsiteShell> createState() => _TraditionalWebsiteShellState();
}

class _TraditionalWebsiteShellState extends State<TraditionalWebsiteShell> {
  final ProductLocalStore _store = const ProductLocalStore();
  String _selectedId = 'nba-home';
  bool _darkMode = true;

  bool get _organizationMode => widget.session.role.canManageOrganization;

  List<_Destination> get _nbaDestinations => [
        _Destination(
          id: 'nba-home',
          label: 'Home',
          icon: Icons.home_rounded,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => WebsiteNbaHomeDashboard(session: widget.session),
          ),
        ),
        _Destination(
          id: 'nba-stats',
          label: 'Stats',
          icon: Icons.leaderboard_rounded,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => WebsiteNbaStatsScreen(session: widget.session),
          ),
        ),
        _Destination(
          id: 'nba-advanced',
          label: 'Advanced Stats',
          icon: Icons.analytics_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => WebsiteNbaAdvancedStatsScreen(session: widget.session),
          ),
        ),
        _Destination(
          id: 'nba-lineups',
          label: 'Lineup Analysis',
          icon: Icons.groups_2_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => WebsiteNbaLineupAnalysisScreen(session: widget.session),
          ),
        ),
        _Destination(
          id: 'nba-trade',
          label: 'Trade Machine',
          icon: Icons.swap_horiz_rounded,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => WebsiteTradeMachineScreen(session: widget.session),
          ),
        ),
        _Destination(
          id: 'nba-games',
          label: 'Games',
          icon: Icons.sports_basketball_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => WebsiteNbaGameFinderScreen(session: widget.session),
          ),
        ),
        _Destination(
          id: 'nba-history',
          label: 'History',
          icon: Icons.history_rounded,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => WebsiteNbaHistoryScreen(session: widget.session),
          ),
        ),
        _Destination(
          id: 'nba-front-office',
          label: 'Front Office',
          icon: Icons.account_tree_outlined,
          builder: () => ProductFrontOfficeRegistryScreen(session: widget.session),
        ),
        _Destination(
          id: 'nba-awards',
          label: 'Awards',
          icon: Icons.emoji_events_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => const ProductNbaAwardsVotingScreen(),
          ),
        ),
        _Destination(
          id: 'nba-tools',
          label: 'NBA Tools',
          icon: Icons.tune_rounded,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => const ProductAdvancedNbaToolsScreen(),
          ),
        ),
        _Destination(
          id: 'nba-compare',
          label: 'Player Compare',
          icon: Icons.compare_arrows_rounded,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => WebsiteNbaPlayerCompareScreen(session: widget.session),
          ),
        ),
        _Destination(
          id: 'nba-team-compare',
          label: 'Team Compare',
          icon: Icons.compare_rounded,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => WebsiteNbaTeamCompareScreen(session: widget.session),
          ),
        ),
        _Destination(
          id: 'nba-watchlist',
          label: 'Watchlist',
          icon: Icons.bookmark_outline_rounded,
          builder: () => WebsiteNbaWatchlistScreen(session: widget.session),
        ),
        _Destination(
          id: 'nba-glossary',
          label: 'Stat Glossary',
          icon: Icons.menu_book_outlined,
          builder: () => const WebsiteNbaStatGlossaryScreen(),
        ),
        _Destination(
          id: 'nba-data-coverage',
          label: 'Data Coverage',
          icon: Icons.dataset_outlined,
          builder: () => const WebsiteNbaDataCoverageScreen(),
        ),
      ];

  List<_Destination> get _secondary => [
        _Destination(
          id: 'my-work',
          label: _organizationMode ? 'Organization' : 'My Work',
          icon: _organizationMode ? Icons.corporate_fare_outlined : Icons.work_outline_rounded,
          builder: () => ProductTransactionCommandCenterScreen(
            session: widget.session,
            organizationMode: _organizationMode,
          ),
        ),
        _Destination(
          id: 'research',
          label: 'Research',
          icon: Icons.science_outlined,
          builder: () => InstitutionalResearchHubScreen(session: widget.session),
        ),
        _Destination(
          id: 'fantasy',
          label: 'Fantasy',
          icon: Icons.bolt_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => const ProductFantasyWarRoomScreen(),
          ),
        ),
        _Destination(
          id: 'articles',
          label: 'Articles',
          icon: Icons.article_outlined,
          builder: () => WebsiteNbaDataGate(
            builder: (_, _) => const ProductArticlesArenaScreen(),
          ),
        ),
        _Destination(
          id: 'community',
          label: 'Community',
          icon: Icons.forum_outlined,
          builder: () => ProductCommunityV2Screen(session: widget.session),
        ),
        _Destination(
          id: 'messages',
          label: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
          builder: () => ProductConnectedMessagesScreen(session: widget.session),
        ),
        _Destination(
          id: 'profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          builder: () => ProductProfileV3Screen(session: widget.session),
        ),
      ];

  static const _futureSports = [
    'NFL', 'NHL', 'MLB', 'MLS', 'Tennis', 'WNBA', 'NCAAB', 'NCAAF', 'Champions League', 'Premier League',
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final dark = await _store.loadBool(ProductLocalStore.darkModeKey, fallback: true);
    if (mounted) setState(() => _darkMode = dark);
  }

  Future<void> _toggleTheme() async {
    final next = !_darkMode;
    setState(() => _darkMode = next);
    await _store.saveBool(ProductLocalStore.darkModeKey, next);
  }

  void _select(String id) {
    final all = [..._nbaDestinations, ..._secondary];
    if (all.any((item) => item.id == id)) setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final nba = _nbaDestinations;
    final secondary = _secondary;
    final all = [...nba, ...secondary];
    final selected = all.firstWhere((item) => item.id == _selectedId, orElse: () => nba.first);
    final brightness = _darkMode ? Brightness.dark : Brightness.light;
    final theme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(seedColor: _brandBlue, brightness: brightness),
      scaffoldBackgroundColor: _darkMode ? const Color(0xFF0A1018) : const Color(0xFFF6F8FC),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkMode ? const Color(0xFF121B26) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _darkMode ? const Color(0xFF263241) : const Color(0xFFE4E8F0)),
        ),
      ),
      dividerColor: _darkMode ? const Color(0xFF2B3747) : const Color(0xFFE5E9F0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkMode ? const Color(0xFF101923) : const Color(0xFFF9FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkMode ? const Color(0xFF334155) : const Color(0xFFD7DDE7)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: _darkMode ? const Color(0xFF334155) : const Color(0xFFD7DDE7)),
      ),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _SiteHeader(
                session: widget.session,
                nbaItems: nba,
                secondary: secondary,
                selectedId: selected.id,
                darkMode: _darkMode,
                futureSports: _futureSports,
                onSelect: _select,
                onToggleTheme: _toggleTheme,
                onSignOut: widget.onSignOut,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 72),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1540),
                      child: selected.builder(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteHeader extends StatelessWidget {
  const _SiteHeader({required this.session,required this.nbaItems,required this.secondary,required this.selectedId,required this.darkMode,required this.futureSports,required this.onSelect,required this.onToggleTheme,required this.onSignOut});
  final AppSession session; final List<_Destination> nbaItems; final List<_Destination> secondary; final String selectedId; final bool darkMode; final List<String> futureSports; final ValueChanged<String> onSelect; final VoidCallback onToggleTheme; final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(builder: (context,constraints){
        final width=constraints.maxWidth;
        final primaryCount=width>=1250?5:width>=980?3:width>=760?1:0;
        final primary=nbaItems.take(primaryCount).toList();
        final moreNba=nbaItems.skip(primaryCount).toList();
        final showBrandText=width>=620;
        final showWideSearch=width>=940;
        final searchWidth=width>=1250?225.0:190.0;
        return Container(
          height:68,
          padding:const EdgeInsets.symmetric(horizontal:14),
          decoration:BoxDecoration(border:Border(bottom:BorderSide(color:Theme.of(context).dividerColor))),
          child:Row(children:[
            Container(width:40,height:40,alignment:Alignment.center,decoration:BoxDecoration(color:colors.primaryContainer,borderRadius:BorderRadius.circular(10)),child:Text('ST',style:TextStyle(color:colors.onPrimaryContainer,fontWeight:FontWeight.w900))),
            if(showBrandText)...[const SizedBox(width:10),const Text('Sports Terminal',style:TextStyle(fontWeight:FontWeight.w900,fontSize:17))],
            if(primary.isNotEmpty)...[const SizedBox(width:20),for(final item in primary)_HeaderButton(label:item.label,selected:item.id==selectedId,onTap:()=>onSelect(item.id))],
            const Spacer(),
            if(showWideSearch) SizedBox(width:searchWidth,child:OutlinedButton.icon(onPressed:()=>_openSearch(context),icon:const Icon(Icons.search_rounded,size:18),label:const Align(alignment:Alignment.centerLeft,child:Text('Search players & teams')))) else IconButton(onPressed:()=>_openSearch(context),tooltip:'Search players & teams',icon:const Icon(Icons.search_rounded)),
            const SizedBox(width:4),
            PopupMenuButton<String>(tooltip:'More',onSelected:(value){if(!value.startsWith('future:')&&!value.startsWith('detached:')&&!value.startsWith('header:')) onSelect(value);},itemBuilder:(context)=>[
              const PopupMenuItem(value:'header:nba',enabled:false,child:_MenuHeading('NBA')),
              for(final item in moreNba) PopupMenuItem(value:item.id,child:_MenuDestination(item:item)),
              const PopupMenuDivider(),
              const PopupMenuItem(value:'header:workspace',enabled:false,child:_MenuHeading('WORKSPACE & NETWORK')),
              for(final item in secondary) PopupMenuItem(value:item.id,child:_MenuDestination(item:item)),
              const PopupMenuDivider(),
              const PopupMenuItem(value:'header:detached',enabled:false,child:_MenuHeading('DETACHED TOOLS')),
              const PopupMenuItem(value:'detached:python',enabled:false,child:Row(children:[Icon(Icons.code_rounded,size:18),SizedBox(width:10),Text('Python Lab · detached')])),
              const PopupMenuItem(value:'detached:excel',enabled:false,child:Row(children:[Icon(Icons.grid_on_outlined,size:18),SizedBox(width:10),Text('Excel Workspace · detached')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value:'header:future',enabled:false,child:_MenuHeading('FUTURE SPORTS')),
              for(final sport in futureSports) PopupMenuItem(value:'future:$sport',enabled:false,child:Text(sport)),
            ],child:const Padding(padding:EdgeInsets.symmetric(horizontal:8,vertical:12),child:Row(mainAxisSize:MainAxisSize.min,children:[Text('More'),SizedBox(width:2),Icon(Icons.keyboard_arrow_down_rounded,size:18)]))),
            IconButton(onPressed:onToggleTheme,tooltip:darkMode?'Use light mode':'Use dark mode',icon:Icon(darkMode?Icons.light_mode_outlined:Icons.dark_mode_outlined)),
            PopupMenuButton<String>(tooltip:'Account',onSelected:(value){if(value=='signout')onSignOut();},itemBuilder:(context)=>const [PopupMenuItem(value:'profile',child:Text('Profile')),PopupMenuItem(value:'signout',child:Text('Sign out'))],child:CircleAvatar(radius:18,child:Text(session.displayName.trim().split(RegExp(r'\s+')).where((part)=>part.isNotEmpty).take(2).map((part)=>part[0].toUpperCase()).join()))),
          ]),
        );
      }),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    final controller = TextEditingController();
    final api = const WebsiteNbaApiService();
    await showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(title:const Text('Search players & teams'),content:SizedBox(width:520,child:TextField(controller:controller,autofocus:true,decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),hintText:'Search players or teams'))),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Close')),FilledButton(onPressed:() async {final query=controller.text.trim(); if(query.isEmpty)return; final result=await api.searchEntities(query); if(!dialogContext.mounted)return; Navigator.pop(dialogContext); if(context.mounted){showDialog<void>(context:context,builder:(context)=>AlertDialog(title:Text('Search results · $query'),content:SingleChildScrollView(child:Text(result.toString())),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Close'))]));}},child:const Text('Search'))]));
  }
}

class _HeaderButton extends StatelessWidget { const _HeaderButton({required this.label,required this.selected,required this.onTap}); final String label; final bool selected; final VoidCallback onTap; @override Widget build(BuildContext context)=>TextButton(onPressed:onTap,style:TextButton.styleFrom(foregroundColor:selected?Theme.of(context).colorScheme.primary:Theme.of(context).colorScheme.onSurface),child:Text(label,style:TextStyle(fontWeight:selected?FontWeight.w800:FontWeight.w600))); }
class _MenuHeading extends StatelessWidget { const _MenuHeading(this.label); final String label; @override Widget build(BuildContext context)=>Text(label,style:Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight:FontWeight.w900,letterSpacing:.8)); }
class _MenuDestination extends StatelessWidget { const _MenuDestination({required this.item}); final _Destination item; @override Widget build(BuildContext context)=>Row(children:[Icon(item.icon,size:18),const SizedBox(width:10),Text(item.label)]); }
class _Destination { const _Destination({required this.id,required this.label,required this.icon,required this.builder}); final String id; final String label; final IconData icon; final Widget Function() builder; }
