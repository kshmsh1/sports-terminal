# Trade Machine v2

Trade Machine v2 is the front-office transaction workspace for Sports Terminal. It is designed around the current 2023 NBA CBA architecture and exposes rule reasoning instead of returning a single opaque legal/illegal badge.

The workspace supports two-to-five-team scenarios, player routing, draft picks, draft rights, cash, free-agent rights, traded-player exceptions and signing exceptions. Each team receives a live pre-trade/outgoing/incoming/max-incoming/matching-room/post-trade/roster summary and cap tier before and after the transaction.

The rules engine currently models salary matching, cap-room structures, tax/first-apron/second-apron states, hard-cap ceilings supplied in team context, second-apron aggregation and cash restrictions, recently acquired aggregation restrictions, roster-count warnings, trade-eligibility dates, signing restrictions, no-trade consent, poison-pill flags, trade bonuses/kickers, pick tradeability, frozen future picks and a Stepien consecutive-future-first screen. It also records CBA/rule references on findings where the implementation has a defined reference.

The engine deliberately separates a **modeled pass** from official NBA approval. Contract amendments, guarantees, bonuses, options, protected-pick conveyance, pick ownership chains, timing, exceptions and league interpretation may require authoritative records not present in the local scenario. Production certification therefore requires a complete contracts/assets data release and a reviewed CBA rule package.

Scenario state persists locally during development. The share action produces portable JSON containing the trade routing, team-level salary effects, findings and notes. Organization workflows can continue to wrap this screen through the existing connected Trade Machine entrypoint and later promote portable scenarios into server-backed cases/approvals.

Future certification work should add complete authoritative player contract ledgers, protected-pick chain resolution, exception expiration/amount ledgers, sign-and-trade/base-year-compensation handling, qualifying-offer and consent edge cases, real roster/cap holds, cash annual limits, season-escalated matching constants, automated transaction timing and a versioned CBA ruleset with tests derived from league/NBPA primary materials.