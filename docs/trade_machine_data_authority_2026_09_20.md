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

### Trade kickers
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
