# Ask Arcside — free, published-data-only Research

Ask Arcside is a deterministic **browser-side** research interface. It is **not** ChatGPT or a hosted LLM. Users can search only data that Arcside has already published as same-origin static datasets. It never sends prompts to external AI services, web search, sports APIs, or a proprietary paid backend, and it never needs a secret key.

## Data access boundary

All query routes are hardcoded in `lib/services/nba_research_query_engine.dart` and use only `WebsiteNbaApiService`, which reads Arcside's already materialized historical corpus. The question is parsed as **data and metric criteria**, never as code, a resource path, URL, or an instruction for a model.

Supported published domains include player-season statistics (traditional and Advanced Stats catalog), team-season records/standings, NBA historical game scores, NBA draft history, recorded award winners, and All-Star selections. Player questions and rankings use the shared Stats engine and metric catalog, including provider-native advanced metrics **only when those metrics actually exist for the selected season**. Missing measures, absent season shards, nonqualifying players, and unsupported requests get explicit unavailable messages.

This accesses the **publicly materialized Arcside dataset**, not unreleased data in a developer's local SQLite warehouse or any private backend service. To expose additional canonical warehouse tables, they first need to be compiled into approved static website datasets with correct source provenance.

## Supported examples

- `Top 50 scorers in 2025-26`
- `Top 100 TS% in 2024-25 minimum 20 games`
- `Top 30 deflections in 2023-24`
- `Top 25 ORTG in 2024-25 team:BOS`
- `Bottom 50 turnovers in 2024-25`
- `Stephen Curry 2015-16 AST%`
- `Stephen Curry 2015-16 all stats` — shows available values only
- `Compare Stephen Curry vs James Harden 2015-16 points`
- `Team standings 2024-25`
- `Team win percentage 2024-25`
- `MVP 2024-25`
- `All star selections 2024-25`
- `2018 NBA draft picks`
- `Games on 2023-06-12`
- `2022-23 game results`

A year in the question overrides the default season; explicit Playoffs/Regular Season overrides the toggle. For player rankings the default minimum is 50 regular-season games or 4 playoff games, unless the user supplies `min_gp:10`, `minimum 20 games`, etc. `team:BOS` and `position:PG` filter the player pool. `per 36`, `per 48`, `per 75`, `per 100` use the Stats engine's existing rate conversions. Counting `total` queries only read recorded source totals; totals are **not reconstructed from rounded averages**. For unambiguous catalog metric lookup, use `metric:net_rating` or another exact Advanced Stats key.

## Usage and costs

**No daily query count limit, no mandatory cooldown, no per-query billing, and no arbitrary ten-result cap.** A question can contain up to **4,096 characters** (an ordinary browser-performance bound). Every matching row remains available in the answer; the interface renders **40 rows per page** to avoid unnecessarily heavy DOM layouts, and offers **Copy all results**.

All computation runs on the user's browser. No server-side computation, LLM inference or usage-metered external API is introduced. This is the strongest approach for keeping Arcside's *query feature* free for both users and its developer.

**Zero query billing is not the same as unlimited free hosting.** GitHub Pages has use, bandwidth and suitability limits; publishing an increasing static NBA dataset is subject to the hosting provider's conditions. At high traffic or for commercial SaaS workloads, you may need an alternative hosting arrangement. The feature is designed to stay functional without enabling a paid service.

## Safety and data quality

- The feature makes no arbitrary network requests and has no API keys or external URLs in its runtime Dart code.
- It does not execute text or generate prose about topics not covered by Arcside records.
- It does not infer missing data or invent answers.
- It never executes user-supplied SQL, shell commands, Python or expressions.
- It does not maintain a conversation or record users' questions in a server.
- The browser can still download the underlying **public** dataset files; do not publish private or restricted records in those shards.

If Arcside ever adds an actual LLM assistant, it would require an appropriately licensed AI model or API and a separate security/cost analysis. The free logged-out ChatGPT website is **not** a reusable free API.
