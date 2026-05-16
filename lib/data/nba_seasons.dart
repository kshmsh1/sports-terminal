import '../models/season.dart';

// Historical NBA/BAA season catalog for the NBA-first MVP.
// This is structural season reference data, not a live statistics feed.
const firstNbaSeasonStartYear = 1946;
const latestConfiguredSeasonStartYear = 2025;

final nbaSeasons = List<Season>.generate(
  latestConfiguredSeasonStartYear - firstNbaSeasonStartYear + 1,
  (index) {
    final startYear = firstNbaSeasonStartYear + index;
    final endYear = startYear + 1;
    final shortEndYear = endYear.toString().substring(2);

    return Season(
      id: '$startYear-$shortEndYear',
      label: '$startYear-$shortEndYear',
      startYear: startYear,
      endYear: endYear,
      league: startYear < 1949 ? 'BAA' : 'NBA',
    );
  },
).reversed.toList(growable: false);
