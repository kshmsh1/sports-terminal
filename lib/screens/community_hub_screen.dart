import '../data/community_product_items.dart';
import 'registry_screen_factory.dart';

class CommunityHubScreen extends RegistryScreenFactory {
  const CommunityHubScreen({super.key}) : super(
    title: 'Community Hub',
    subtitle: 'Community and publishing architecture for entity-linked forums, blog posts, creator workspaces, comments, private groups, moderation, and feeds.',
    items: communityProductItems,
    searchHint: 'Search forums, blog, moderation, groups...',
    leadTitle: 'Community Principle',
    leadBody: 'Community should be data-native. Posts, forums, blogs, and private rooms should attach to players, teams, games, award races, draft classes, fantasy boards, reports, charts, and saved views rather than becoming generic message boards.',
  );
}
