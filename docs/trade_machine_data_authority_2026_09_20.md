# Trade Machine Data Authority Pass — 2026-09-20

## Newly supplied / normalized in this pass

### Official 2026-27 league environment
- Salary cap: $164,961,000
- Tax level: $200,428,000
- Minimum team salary: $148,465,000
- First apron: $209,015,000
- Second apron: $221,686,000
- Non-taxpayer MLE: $15,044,000
- Taxpayer MLE: $6,064,000
- Room MLE: $9,366,000
- Bi-annual exception remains $5,477,000 in the existing 2026-27 exception reference.

The previous Sports Terminal operating figures were projections and have been replaced in the canonical cap environment and Trade Machine UI constants.

### Current team salary positions
A 30-team current salary commitment table supplied on 2026-09-20 has been normalized into `nba_team_salary_position_2026.dart`.
It is kept separate from the detailed cap-ledger decomposition because "current salary commitments" and cap-accounting buckets are not necessarily identical.

### Team-by-team salary sheets

A second user-supplied data pass on 2026-09-20 provided detailed ShamSports salary sheets for:
ATL, BOS, BRK, CHA, CHI, CLE, DAL, DEN, DET, GSW, HOU, IND, LAC, LAL, MEM and MIA.

For those teams, Sports Terminal now treats the team-level sheet as the newer authority for current total salary and guaranteed salary. Dead-money figures visible on the sheet are also stored separately. The remaining 14 teams still use the earlier league-wide salary-position table until corresponding team sheets are supplied or independently reconciled.

The team sheets also provide cap holds and available signing exceptions. Exception balances were cross-checked against the existing reference; Miami's remaining non-taxpayer MLE was corrected to $8,979,000. Where a source displays a room-MLE amount above the NBA's official maximum, Sports Terminal retains the official league maximum rather than an impossible higher balance.

A final team-sheet batch supplied MIL, MIN, NOP, NYK, OKC, ORL, PHI, PHO, POR, SAC, SAS, TOR, UTA and WAS. Together with the earlier batch, all 30 NBA teams now have team-level current salary-position coverage in the normalized reference.

### Trade kickers

The final user-supplied recorded-kicker table supersedes the earlier mixed-status list for current 2026-27 team assignments. Sports Terminal now stores the recorded current-team kicker inventory as active contract metadata, including moved players such as Darius Garland (LAC), Desmond Bane (ORL), Giannis Antetokounmpo (MIA), LaMelo Ball (MIN), Paul George (BOS) and Zach LaVine (SAC). Jaylen Brown retains an explicit note that the source lists "7% / $7,000,000", which requires fixed-dollar cap treatment when the exact bonus is calculated.

The user-supplied 2026-27 trade-kicker list has been normalized with four explicit states:
- active in 2026-27;
- contract kicker exists but produces no 2026-27 bonus because the player is already at the max;
- kicker begins with a later extension;
- kicker waived in connection with a completed trade.

Kawhi Leonard is stored as a Toronto player with a waived 2026 trade bonus. Amen Thompson is retained in the future-extension group because the supplied salary schedule shows the extension beginning after 2026-27.

## Multi-year salary / option screenshots

The supplied salary screenshots contain:
- 2026-27 through 2031-32 salary columns;
- total guaranteed dollars;
- green salary text = player option;
- blue salary text = team option.

These screenshots materially close the multi-year salary and option-data gap, but they should not be blindly pasted into the current single-row-per-player contract seed.

### Important modeling issue exposed by the screenshots

The source table contains some players more than once under different teams/obligations (examples visible in the supplied screenshots include Damian Lillard, Klay Thompson, Bradley Beal, Devin Carter, and others). The existing `NbaTradeContractRepository` collapses duplicate names to the first row it sees.

That behavior is not safe for a production Trade Machine because duplicate rows may represent:
- current active contract ownership;
- dead/waived/stretch obligations;
- retained salary;
- prior-team salary accounting;
- another cap obligation rather than a second active player contract.

Before normalizing all screenshot rows into the canonical player contract table, each duplicate must be classified rather than silently deduplicated.

## Remaining data still needed for authoritative CBA validation

The new data resolves the official cap thresholds, current team salary-position baseline, trade-kicker inventory, and provides a source for multi-year salary/options.

Still needed or requiring classification:

1. **Current active contract ownership vs dead/retained obligations**
   - resolve duplicate player rows from the salary source;
   - identify which row represents the tradeable active player contract.

2. **Guarantee structure by season**
   - current screenshots provide a total "Guaranteed" figure;
   - Trade Machine rules need guaranteed/non-guaranteed treatment by year and guarantee dates for some cases.

3. **Signing / extension / acquisition dates**
   - required to automate recently-signed and recently-acquired aggregation restrictions.

4. **No-trade clauses and trade-consent rights**
   - must be explicit player metadata.

5. **Poison-pill / BYC applicability**
   - identify affected players and the salary values needed for both sides of the trade calculation.

6. **Hard-cap trigger history**
   - current hard-cap level is stored, but the triggering transaction/mechanism should also be captured.

7. **Standard vs two-way roster classification and roster counts**
   - needed for deterministic roster-limit validation.

8. **Likely/unlikely bonuses and other salary adjustments where trade salary is affected**
   - avoid assuming displayed base salary always equals trade salary.

9. **Trade-kicker calculation inputs**
   - exact eligible remaining contract value;
   - option years excluded where required;
   - maximum-salary ceiling;
   - waiver amount, if a player waives only part of a bonus.

10. **Draft asset final certification**
    - the rich first/second-round repositories exist, but ownership/protection/swap/Stepien metadata still needs a final source-by-source certification pass.

## Current recommendation

Do not replace the existing contract seed wholesale with OCR/transcription output from the screenshots until duplicate obligations are classified.

The next focused data task should be a **contract normalization pass**:
- one canonical active contract record per tradeable player;
- separate dead/retained/cap-obligation records;
- year-by-year salary;
- player/team option flags;
- guarantee metadata;
- trade-kicker metadata;
- signing/acquisition timing fields.

That will allow the Trade Machine rules engine to stop relying on manual "review required" flags for several edge cases.


## Exception, hard-cap, tax and transaction tracker pass

A further 2026-09-20 data pass added six tracker sources:
- mid-level exception tracker;
- bi-annual exception tracker;
- disabled player exception tracker;
- traded-player exception tracker;
- hard-cap trigger tracker;
- 2026-27 luxury-tax tracker.

These are now normalized into `nba_front_office_tracker_2026.dart` alongside the existing signing-exception and TPE references.

### Disabled Player Exceptions captured
- DAL — Dereck Lively II — $3,619,565
- HOU — Fred VanVleet — $12,500,000
- IND — Tyrese Haliburton — $15,044,000
- LAC — Bradley Beal — $3,212,400
- OKC — Thomas Sorber — $2,443,860

### Hard-cap trigger history
The supplied tracker identifies first-apron and second-apron triggering events by team, including TP-MLE usage, BAE usage, sign-and-trades, trade salary acquired, cash traded, aggregation and prior-season TPE use. This materially closes the prior gap where Sports Terminal knew some teams were hard-capped but did not know why.

### Luxury-tax / repeater status
The supplied tracker now gives a static 2026-27 tax snapshot with estimated tax, taxed amount and repeater status. This should remain separate from trade-matching salary because tax payroll and trade salary are different accounting concepts.

### Transaction history
The supplied official 2026 offseason trade list has been normalized into `nba_transaction_history_2026.dart`. The transaction history now provides dated acquisition events that can be used to automate recently-acquired aggregation checks rather than relying only on manual review flags.

The supplied all-30-team free-agency / extension / trade transaction log is retained as the next source for signing-date and extension-date normalization. It should be modeled separately from trade acquisition events because signing restrictions depend on the precise transaction type and date.


## Two-way contracts, guarantee triggers, cash limits, extensions and draft status

A further user-supplied 2026-09-20 pass materially closes the remaining roster/contract-status gaps.

### Two-way contracts
The current two-way roster has been normalized into `nba_two_way_contract_reference_2026.dart`, including team, player, position, contract length, signed date and G League affiliate where supplied. Open two-way slots are derived from a three-slot maximum.

### Guarantee triggers and partially guaranteed contracts
Early guarantee triggers have been normalized into `nba_contract_status_reference_2026.dart`, preserving:
- trigger date;
- guaranteed amount before and after the trigger;
- whether the trigger had already resolved as of the source snapshot.

This is kept separate from nominal salary because trade/cap treatment can depend on protected salary rather than headline salary.

### January 15 trade restrictions
The supplied list of Bird/Early Bird re-signings that cannot be traded until January 15, 2027 has been normalized, including the reported player veto flags.

### League constants and trade cash
Additional 2026-27 constants have been added:
- maximum salaries by service tier;
- two-way salary;
- Early Bird maximum;
- estimated average salary;
- trade cash limit;
- Exhibit 10 / two-way protection maximum;
- expanded traded-player exception increment.

Per-team remaining cash-send and cash-receive capacity is now stored separately, including Denver's current inability to send cash while above the second apron.

### Frozen first-round picks and 2027 first-round status
The frozen 2032/2033 pick information and the full 2027 first-round ownership/protection/swap summary have been normalized into `nba_draft_asset_status_2026.dart`. Complex multi-team conveyance pools remain represented as conditional summaries rather than incorrectly flattening them to a single owner.

### Extensions
The reported 2026-27 rookie-scale and veteran extension list has been normalized into `nba_extension_reference_2026.dart`, preserving option and trade-kicker details where supplied and explicitly marking projected max-contract values as cap-dependent.

## Remaining gaps after this pass

At this point, the broad data categories required for the Trade Machine are present. Remaining work is predominantly normalization and exact-rule implementation rather than new category discovery:

1. one canonical active-contract ledger with every 2026-27 through future-year salary and option flag;
2. exact current protected salary for every non-fully-guaranteed player as of the transaction date;
3. December 15 eligibility dates for the broader free-agent-signing population, plus signing dates for all standard contracts;
4. no-trade / consent rights beyond the January 15 list's explicit veto markers;
5. poison-pill/BYC salary calculations for affected extensions;
6. exact trade-kicker bonus calculation after max-salary and option-year rules;
7. standard-roster counts and automatic post-trade roster validation using the now-separated two-way roster;
8. final merge of the 2027 pick-status authority into the richer multi-year pick repository;
9. transaction-date-aware hard-cap and exception consumption logic;
10. exact tax-payroll recomputation after a hypothetical transaction.

The data-discovery phase is therefore close to complete. The next engineering phase should focus on canonicalization and deterministic CBA logic.
