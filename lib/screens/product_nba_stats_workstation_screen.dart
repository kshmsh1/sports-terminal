import 'product_nba_advanced_stats_page_screen.dart';

/// Compatibility entrypoint for the full advanced statistics workstation.
///
/// The implementation is page-scroll native: it never owns a vertical scroll
/// view, so the Sports Terminal shell remains the single vertical scroll owner.
class ProductNbaStatsWorkstationScreen extends ProductNbaAdvancedStatsPageScreen {
  const ProductNbaStatsWorkstationScreen({super.key});
}
