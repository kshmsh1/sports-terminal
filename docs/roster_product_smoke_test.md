# Roster Product Smoke Test

Run the automated product gate first:

```bash
bash tools/check_roster_product_release.sh
```

Then launch the application:

```bash
flutter run -d chrome
```

## Players

1. Open **Players**.
2. Confirm the page shows the connected final-roster player count.
3. Search for a known player.
4. Filter by team.
5. Sort player name alphabetically in both directions.
6. Sort age, height, weight, and salary in both directions.
7. Filter to **Missing From**, **Missing jersey**, and **Missing salary**.
8. Click a player name and confirm the shared player profile opens.
9. From the player profile, click **Open team** and confirm the shared team profile opens.

## Teams

1. Open **Teams**.
2. Confirm all 30 teams appear.
3. Filter East and West conferences.
4. Filter by division.
5. Sort roster size, average age, average height, average weight, payroll, and identity completion.
6. Click a team name and confirm the shared team profile opens.
7. On the team profile, sort the final roster by player, jersey, age, height, weight, From, and salary.
8. Click a player on the team roster and confirm the shared player profile opens.

## Rosters

1. Open **Rosters**.
2. Confirm the page identifies the data as the **2025-26 final roster snapshot**.
3. Confirm the league table shows player and team links.
4. Confirm heights show feet/inches and meters.
5. Confirm weights show pounds and kilograms.
6. Sort all supported columns in both directions.
7. Filter a single team.
8. Filter the metadata completion queue by From, Jersey, Salary, Position, Height, and Weight.
9. Confirm broken joins remain zero.
10. Open player and team profiles from the roster table and completion queue.

## Expected source-pending behavior

Player and team profile sections for season statistics, standings, games, awards, draft picks, and transactions may show zero rows until those data families are imported. They should render a clear empty state rather than fake records or zeros.

## Completion report

The product gate writes:

```text
raw/roster_completeness_report.json
```

Review this file when resolving missing From, jersey, or salary fields. Missing values are explicit completion tasks. They are not to be guessed merely to make the completion rate reach 100 percent.
