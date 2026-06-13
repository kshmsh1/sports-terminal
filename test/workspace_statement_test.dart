import 'package:flutter_test/flutter_test.dart';
import 'package:sports_terminal/services/workspace_data_service.dart';

void main() {
  const service = WorkspaceDataService();
  const datasets = <String, List<Map<String, Object?>>>{
    'teams': [
      {'team': 'Boston Celtics', 'conference': 'East', 'wins': 60},
      {'team': 'Chicago Bulls', 'conference': 'East', 'wins': 40},
      {'team': 'Los Angeles Lakers', 'conference': 'West', 'wins': 50},
    ],
  };

  test('selects filters sorts and limits rows', () {
    final result = service.run(
      statement: 'SELECT team, wins FROM teams WHERE conference = East ORDER BY wins DESC LIMIT 1;',
      datasets: datasets,
    );

    expect(result.columns, ['team', 'wins']);
    expect(result.rows, hasLength(1));
    expect(result.rows.single['team'], 'Boston Celtics');
  });

  test('rejects an unknown dataset', () {
    expect(
      () => service.run(
        statement: 'SELECT * FROM unknown_table LIMIT 10;',
        datasets: datasets,
      ),
      throwsFormatException,
    );
  });
}
