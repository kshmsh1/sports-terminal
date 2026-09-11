# JJNBA 2026-27 front-office research

Research date: 2026-09-11

Primary reference: https://jjnba.com/

JJNBA states that its 2026-27 salary/cap figures are compiled by hand from public reporting and the 2023 CBA, are projections rather than official league accounting, and are reusable with attribution under CC BY 4.0. Sports Terminal should therefore treat these values as a sourced secondary reference, preserve attribution, and keep them separate from user-supplied/league-source values when they differ.

## Product patterns worth incorporating

1. **Team cap sheet hub** - one team page that combines active roster, multi-year salary, cap holds, dead money, two-way contracts, options/guarantees, draft picks, exhibit players, spending tools and cap-position context.
2. **Hard-cap tracker** - team-by-team hard-cap level, trigger, ceiling and remaining room. This should feed the Trade Machine rather than live only as a reference table.
3. **Trade-exception tracker** - every live TPE with amount, originating transaction/player, expiry date and remaining life. TPEs should be selectable trade assets with validation against incoming player salary and second-apron rules.
4. **Mid-level / bi-annual tracker** - available MLE type and remaining amount by team. Keep the full exception value and remaining balance separately.
5. **Spending-power view** - cap room or exceptions/TPEs summarized into a single team acquisition-tool view, while still allowing users to drill into the components.
6. **Repeater-tax tracker** - four-year tax history, repeater status and projected current tax bill. This belongs in Front Office / Team pages and can be surfaced in trade results as owner-cost impact.
7. **Frozen-pick tracker** - frozen future firsts need first-class metadata in the draft asset registry and must be unselectable in the Trade Machine while frozen.
8. **Exhibit-contract tracker** - Exhibit 9/10-style contract metadata belongs in player contract records and roster/cap sheets rather than being inferred from salary alone.
9. **Player contract pages** - year-by-year salaries, options, guarantees and team-share context should become a dedicated player contract tab in Sports Terminal.
10. **Contract calculators** - extension/raise calculators and rest-of-season minimum/proration calculators fit naturally in the Advanced / Front Office toolset.

## Trade Machine implications

The Trade Machine should evolve from player-salary routing into a transaction workbench with tabs for Players, Draft Picks and Money/Exceptions. Each team panel should expose: current cap allocation, cap/tax/apron room, hard-cap ceiling, standard/two-way roster counts, live TPEs, remaining MLE/BAE, future picks and restrictions. Validation should explain *why* a move fails instead of returning only a pass/fail result.

The user-supplied RealGM future-pick PDFs are the immediate source for draft ownership, swaps, protections, conveyance chains and frozen-pick language. Complex interests should be stored as conditional draft assets rather than flattened into a guaranteed pick owner.

## Source reconciliation policy

Sports Terminal currently uses user-supplied 2026-27 operating thresholds ($166.0M cap, $201.69M tax, $210.69M first apron, $223.69M second apron). JJNBA currently displays a different threshold set ($164.961M / $200.428M / $209.015M / $221.686M). Do not silently overwrite the user-supplied operating environment with JJNBA values. Keep each source versioned, dated and attributable, and make source conflicts visible in data QA/admin tooling.
