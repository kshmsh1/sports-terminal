import 'package:flutter/material.dart';

import '../services/website_nba_api_service.dart';
import '../widgets/nba_research_query_panel.dart';

/// The Research route is the research experience, not a dashboard of boxed
/// summaries. Data coverage lives in the published source catalog.
class WebsiteNbaResearchScreen extends StatefulWidget {
  const WebsiteNbaResearchScreen({super.key, this.onNavigate});
  final ValueChanged<String>? onNavigate;

  @override
  State<WebsiteNbaResearchScreen> createState() =>
      _WebsiteNbaResearchScreenState();
}

class _WebsiteNbaResearchScreenState extends State<WebsiteNbaResearchScreen> {
  late final Future<List<WebsiteNbaSeason>> seasons =
      const WebsiteNbaApiService().seasons();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<WebsiteNbaSeason>>(
        future: seasons,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(height: 500,
              child: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasData) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('The published Arcside research index is not available: '
                  '${snapshot.error ?? 'Unknown error'}'),
            ));
          }
          return NbaResearchQueryPanel(seasons: snapshot.data!);
        },
      );
}
