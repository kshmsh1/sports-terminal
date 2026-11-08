# Ask Arcside — source-backed Research queries

Arcside Research supports limited, no-login questions about **published historical NBA player-season data**. This is a deterministic search-and-format feature, **not** an OpenAI or ChatGPT integration. It has no API billing, LLM inference, outside sports API calls, web scraping or secrets.

## Supported examples

- `Top 5 scorers in 2025-26`
- `Who led in assists in 2024-25?`
- `Stephen Curry 2015-16 points per game`
- `Stephen Curry 2015-16 total points`
- `Michael Jordan 1995-96 stats`
- `Top 5 TS% in 2023-24 playoffs`

A player query must use the complete canonical name, and a leaderboard must mention a supported metric. A year in the question overrides the selected default season. An explicit "playoffs" or "regular season" overrides the selected segment.

Answers are derived only from the season shard loaded by `WebsiteNbaApiService.seasonSnapshot`, using the same `NbaStatsWorkstationEngine` as Stats and Advanced Stats. A leaderboard requires 50 games for regular-season records, 4 for playoff records. Results identify their season and segment. Unsupported questions and unpublished metrics return a clear unavailable/unsupported message rather than a guessed fact.

## Usage limits

The browser UI allows at most **8 questions per local calendar day**, one question every **15 seconds**, and **180 characters per question**. Leaderboards display at most **10 players**. Users cannot upload files or create a multi-turn chat; answers have no conversation memory. These limits are implemented using Flutter's `shared_preferences` local browser storage.

**These browser limits are not an anti-abuse boundary.** Visitors can clear storage, use another browser or modify their client. That is acceptable for a zero-cost same-origin static query feature. For any future paid inference endpoint, enforce rate limits and global budget caps on the server before making requests.

## OpenAI integration boundary

The free logged-out ChatGPT website does **not** provide a public free inference API for embedding in Arcside. Do not scrape ChatGPT, automate its logged-out web interface, proxy another user's consumer session, expose an API key in Flutter web, or claim these deterministic answers are produced by ChatGPT.

A future opt-in AI assistant would require an officially supported integration, a separately hosted backend, a secured server-side API key and paid API usage (or another appropriately licensed inference provider), plus server-enforced authentication/session controls, rate limits, request quotas, abuse controls, cost ceilings and clear source references. The static GitHub Pages deployment must continue to operate when that optional backend is not configured.

## Data constraints

Arcside's historical corpus can lack requested metrics or entire player-season records. Missing data must stay unavailable rather than become 0 or be inferred. This widget cannot answer current events, sports betting recommendations, unsupported historical questions, general chat, or internet research.
