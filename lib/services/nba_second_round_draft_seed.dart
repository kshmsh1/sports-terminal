class NbaSecondRoundSeedInterest {
  const NbaSecondRoundSeedInterest({required this.team, required this.year, required this.text});
  final String team;
  final int year;
  final String text;
}

/// Normalized 2027-2033 second-round rights snapshot. Each `||` segment is a
/// distinct current draft interest/obligation so the trade machine can expose
/// it separately instead of flattening a team's entire year into one pick.
///
/// Source: RealGM Future Draft Picks By Team / Future Traded Draft Details,
/// synchronized 2026-09-11. `OUT:` marks an outgoing/unavailable obligation;
/// `COND:` marks contingent ownership/conveyance; `SWAP:` marks a swap/favorable
/// selection right. These strings are normalized factual summaries, not source
/// prose.
const nbaSecondRoundSeed2027To2033 = r'''
ATL|2027|COND: Own if pick 31-55; OUT: Dallas if pick 56-60
ATL|2028|OUT: Brooklyn (via Golden State)
ATL|2029|COND: More favorable of ATL/MIA to Charlotte; COND: Other of ATL/MIA to Oklahoma City; Cleveland second
ATL|2030|OUT: Oklahoma City; New York second (via Portland)
ATL|2031|COND: More favorable of ATL/HOU when HOU is 31-55 to Oklahoma City; COND: Other pick to Houston; if HOU 56-60 Atlanta goes to Oklahoma City
ATL|2032|OUT: Oklahoma City
ATL|2033|Own; Sacramento second
BOS|2027|COND: More favorable of BOS/ORL to Utah; COND: Other of BOS/ORL to Phoenix
BOS|2028|COND: Own 31-45 only if Boston has pick 1 in first round; OUT: New York if BOS second is 46-60; COND: Most favorable of GSW/MIL/OKC
BOS|2029|OUT: Oklahoma City
BOS|2030|OUT: Brooklyn; COND: Charlotte 56-60; COND: Most favorable of Phoenix/Portland/Washington
BOS|2031|COND: Less favorable of BOS/CLE; COND: Houston 56-60
BOS|2032|Own
BOS|2033|Own
BRK|2027|COND: Other of Brooklyn/Dallas after more favorable goes to Washington, routed to Milwaukee; COND: Lakers second only if LAL conveys 2027 first to Utah
BRK|2028|Own; Atlanta second; Memphis second; COND: Philadelphia second if PHI first is 1-8
BRK|2029|Own; Dallas second; Golden State second; Memphis second
BRK|2030|Own; Boston second; Dallas second; Lakers second
BRK|2031|Own; Lakers second
BRK|2032|Own; Denver second; Miami second; Toronto second
BRK|2033|Own
CHA|2027|COND: Charlotte obligation goes to Oklahoma City if SAS first is 1-16 or Sacramento if SAS first is 17-30; Memphis second; COND: More favorable of Portland/New Orleans
CHA|2028|COND: More favorable of CHA/LAC; Houston second; COND: Miami second if Dallas first does not convey to Charlotte in 2027; Orlando second
CHA|2029|Own; COND: More favorable of ATL/MIA; COND: Denver second if Denver has conveyed first potential first to Oklahoma City by 2029; COND: Minnesota second if MIN conveys 2029 first to Utah
CHA|2030|COND: Own if 31-55, Boston if 56-60; COND: More favorable of Utah/Clippers
CHA|2031|Own; Milwaukee second; Phoenix second
CHA|2032|Own; Milwaukee second; Minnesota second
CHA|2033|Own; Houston second; Minnesota second
CHI|2027|OUT: Oklahoma City; Cleveland second
CHI|2028|SWAP: Most favorable of Chicago/Indiana/Phoenix
CHI|2029|Own; COND: Least favorable of Detroit/Milwaukee/New York
CHI|2030|SWAP: Own or Indiana
CHI|2031|Own; Denver second; SWAP: More favorable of Minnesota/Golden State; New York second
CHI|2032|Own; SWAP: More favorable of Phoenix/Houston
CHI|2033|Own
CLE|2027|OUT: Chicago
CLE|2028|OUT: Utah
CLE|2029|OUT: Atlanta
CLE|2030|OUT: San Antonio
CLE|2031|COND: More favorable of CLE/BOS goes Utah and other goes Boston
CLE|2032|OUT: Utah
CLE|2033|Own
DAL|2027|COND: Dallas/Brooklyn favorable allocation sends more favorable to Washington and other to Milwaukee; COND: Atlanta 56-60
DAL|2028|OUT: Clippers
DAL|2029|OUT: Brooklyn
DAL|2030|OUT: Brooklyn
DAL|2031|OUT: Detroit
DAL|2032|OUT: New York
DAL|2033|OUT: Washington
DEN|2027|OUT: Utah
DEN|2028|COND: Own 31-33; OUT: Washington if 34-60; Minnesota second
DEN|2029|COND: To Charlotte if first-round obligation has conveyed by 2029, otherwise Oklahoma City
DEN|2030|COND: Denver/Houston/Miami pool: most favorable to Memphis and two least favorable to Oklahoma City
DEN|2031|OUT: Chicago; Sacramento second
DEN|2032|OUT: Brooklyn; Sacramento second
DEN|2033|Own
DET|2027|Own
DET|2028|COND: Own if 31-55, Philadelphia if 56-60; COND: Less favorable of Charlotte/Clippers; COND: Miami second if Dallas first conveys to Charlotte in 2027; New York second; COND: Utah receives least/less favorable among applicable Detroit/CHA-LAC/MIA/NYK interests
DET|2029|COND: Two most favorable of Detroit/Milwaukee/New York
DET|2030|Own
DET|2031|OUT: Oklahoma City; Dallas second; COND: Less favorable of Golden State/Minnesota
DET|2032|Own
DET|2033|Own
GSW|2027|COND: Golden State/Phoenix allocation: more favorable to Philadelphia, other to Washington
GSW|2028|COND: GSW/MIL/OKC pool: most favorable to Boston, other two to Philadelphia
GSW|2029|OUT: Brooklyn
GSW|2030|COND: To Memphis if Golden State does not convey 2030 first to Memphis
GSW|2031|COND: Golden State/Minnesota allocation: more favorable to Chicago, other to Detroit
GSW|2032|COND: Own if 31-50, Memphis if 51-60
GSW|2033|Own
HOU|2027|COND: HOU/OKC/IND/MIA/SAS allocation interest; COND: Less favorable of Portland/New Orleans only if 56-60
HOU|2028|OUT: Charlotte
HOU|2029|OUT: Memphis
HOU|2030|COND: Houston/Denver/Miami pool: most favorable to Memphis and other two to Oklahoma City
HOU|2031|COND: Less favorable of HOU 31-55/ATL stays Houston after other goes OKC; OUT: Boston if Houston 56-60
HOU|2032|COND: Houston/Phoenix allocation: more favorable to Chicago, other to Phoenix
HOU|2033|OUT: Charlotte
IND|2027|COND: IND/OKC/HOU/MIA/SAS allocation interest; Utah second
IND|2028|COND: Indiana/Phoenix/Chicago favorable-allocation interest
IND|2029|COND: More favorable of Indiana/Washington
IND|2030|SWAP: Own or Chicago
IND|2031|COND: Indiana/Miami/Memphis allocation interest
IND|2032|Own
IND|2033|Own
LAC|2027|OUT: Utah
LAC|2028|COND: Clippers/Charlotte allocation: more favorable to Charlotte, other to Detroit; Dallas second
LAC|2029|OUT: San Antonio
LAC|2030|COND: Other of Clippers/Utah after more favorable goes Charlotte; Toronto second
LAC|2031|Own
LAC|2032|Own
LAC|2033|Own; Toronto second; COND: Detroit heavily-protected unspecified second-right claim
LAL|2027|COND: To Brooklyn if Lakers convey 2027 first to Memphis, otherwise Memphis
LAL|2028|COND: Lakers/Washington allocation: more favorable to Orlando, other to Washington
LAL|2029|OUT: Memphis
LAL|2030|OUT: Brooklyn
LAL|2031|OUT: Brooklyn; Washington second
LAL|2032|OUT: Oklahoma City; Washington second
LAL|2033|Own
MEM|2027|OUT: Charlotte; COND: Lakers second if Lakers do not convey 2027 first to Memphis
MEM|2028|OUT: Brooklyn
MEM|2029|OUT: Brooklyn; Houston second; Lakers second; COND: Orlando second if ORL first is 1-2; Portland second
MEM|2030|COND: Own if 31-50, Minnesota if 51-60; COND: Most favorable of Denver/Houston/Miami; COND: Golden State second if GSW does not convey 2030 first to Memphis
MEM|2031|COND: Memphis/Indiana/Miami allocation interest
MEM|2032|COND: Most favorable of Memphis/Philadelphia/Utah; Golden State 51-60
MEM|2033|Own; Oklahoma City second; Washington second; COND: New Orleans unspecified second-round right
MIA|2027|COND: Miami/OKC/Houston/Indiana/San Antonio allocation interest
MIA|2028|COND: To Detroit if Dallas first conveys to Charlotte in 2027, otherwise Charlotte
MIA|2029|COND: Miami/Atlanta allocation sends more favorable to Charlotte, other to Oklahoma City
MIA|2030|COND: Miami/Denver/Houston pool: most favorable to Memphis and other two to Oklahoma City
MIA|2031|COND: Miami/Indiana/Memphis allocation interest
MIA|2032|OUT: Brooklyn
MIA|2033|OUT: Milwaukee
MIL|2027|Own; COND: Less favorable of Brooklyn/Dallas
MIL|2028|COND: GSW/MIL/OKC pool: most favorable to Boston and remaining to Philadelphia
MIL|2029|COND: MIL/Detroit/New York pool: two most favorable to Detroit and other to Chicago
MIL|2030|OUT: Orlando
MIL|2031|OUT: Charlotte
MIL|2032|OUT: Charlotte
MIL|2033|Own; Miami second
MIN|2027|OUT: Portland
MIN|2028|OUT: Denver
MIN|2029|COND: To Charlotte if Minnesota conveys 2029 first to Utah, otherwise Utah
MIN|2030|OUT: Oklahoma City; Memphis 51-60
MIN|2031|COND: Minnesota/Golden State allocation: more favorable to Chicago, other to Detroit
MIN|2032|OUT: Charlotte
MIN|2033|OUT: Charlotte
NOP|2027|COND: New Orleans/Portland allocation: more favorable to Charlotte, other to Portland and potentially Houston; COND: Second-most-favorable of OKC/HOU/IND/MIA
NOP|2028|OUT: San Antonio
NOP|2029|OUT: San Antonio
NOP|2030|SWAP: Own or Orlando
NOP|2031|COND: New Orleans/Orlando allocation sends more favorable to Orlando, other to Oklahoma City; Toronto second
NOP|2032|Own
NOP|2033|Own; COND: Unspecified second-round obligation/swap right owed to Memphis
NYK|2027|Own; COND: Third-most-favorable of OKC/HOU/IND/MIA; Washington second
NYK|2028|OUT: Detroit; COND: Boston 46-60; COND: Less favorable of Indiana/Phoenix
NYK|2029|COND: Two most favorable of NYK/Detroit/Milwaukee to Detroit and other to Chicago; Phoenix second; Sacramento second
NYK|2030|OUT: Atlanta; Philadelphia second
NYK|2031|OUT: Chicago
NYK|2032|Own; Dallas second
NYK|2033|Own; Phoenix second
OKC|2027|COND: OKC/HOU/IND/MIA/SAS allocation interest; COND: Charlotte second if SAS first is 1-16; Chicago second; COND: Sacramento second if SAS first is 1-16
OKC|2028|COND: GSW/MIL/OKC pool: most favorable to Boston and remaining to Philadelphia; Utah second
OKC|2029|Own; COND: Less favorable of Atlanta/Miami; Boston second; COND: Denver second if DEN first obligation has not conveyed by 2029
OKC|2030|Own; Atlanta second; COND: Two least favorable of Denver/Houston/Miami; Minnesota second
OKC|2031|Own; COND: More favorable of ATL/HOU 31-55 or ATL if HOU 56-60; Detroit second; COND: Less favorable of New Orleans/Orlando
OKC|2032|Own; Atlanta second; Lakers second
OKC|2033|OUT: Memphis
ORL|2027|COND: Orlando/Boston allocation: more favorable to Utah, other to Phoenix
ORL|2028|OUT: Charlotte; COND: More favorable of Lakers/Washington
ORL|2029|COND: To Memphis if Orlando first is 1-2
ORL|2030|SWAP: Own or New Orleans; Milwaukee second
ORL|2031|COND: Orlando/New Orleans allocation: more favorable to Orlando, other to Oklahoma City
ORL|2032|Own
ORL|2033|Own
PHI|2027|Own; COND: More favorable of Golden State/Phoenix; COND: Most favorable of OKC/HOU/IND/MIA; COND: second-most-favorable among Philadelphia's three applicable rights goes Washington
PHI|2028|COND: To Brooklyn if PHI first is 1-8; COND: Detroit 56-60; COND: Two least favorable of Golden State/Milwaukee/OKC
PHI|2029|Own
PHI|2030|OUT: New York; COND: Less favorable of more-favorable Phoenix/Portland and Washington
PHI|2031|Own
PHI|2032|COND: Philadelphia/Memphis/Utah allocation interest
PHI|2033|Own
PHO|2027|COND: Phoenix/Golden State allocation: more favorable to Philadelphia, other to Washington; COND: Less favorable of Boston/Orlando
PHO|2028|COND: Phoenix/Indiana/Chicago favorable-allocation interest
PHO|2029|OUT: New York
PHO|2030|COND: Phoenix/Portland/Washington allocation interest
PHO|2031|OUT: Charlotte
PHO|2032|COND: Less favorable of Phoenix/Houston
PHO|2033|OUT: New York
POR|2027|COND: Portland/New Orleans allocation with more favorable to Charlotte and other to Portland, with 56-60 possible Houston conveyance; Minnesota second
POR|2028|Own; Sacramento second
POR|2029|OUT: Memphis; COND: Less favorable of Indiana/Washington
POR|2030|COND: Portland/Phoenix/Washington allocation interest
POR|2031|Own
POR|2032|Own
POR|2033|Own
SAC|2027|COND: To Oklahoma City if SAS first is 1-16; COND: Charlotte second if SAS first is 17-30
SAC|2028|OUT: Portland
SAC|2029|OUT: New York
SAC|2030|OUT: San Antonio
SAC|2031|OUT: Denver
SAC|2032|OUT: Denver
SAC|2033|OUT: Atlanta
SAS|2027|COND: San Antonio/OKC/HOU/IND/MIA allocation interest
SAS|2028|Own; COND: Boston 31-45 if Boston has pick 1 in first round; New Orleans second
SAS|2029|Own; Clippers second; New Orleans second
SAS|2030|Own; Cleveland second; Sacramento second
SAS|2031|Own
SAS|2032|Own
SAS|2033|Own
TOR|2027|Own
TOR|2028|Own
TOR|2029|Own
TOR|2030|OUT: Clippers
TOR|2031|OUT: New Orleans
TOR|2032|OUT: Brooklyn
TOR|2033|OUT: Clippers
UTA|2027|OUT: Indiana; COND: More favorable of Boston/Orlando; Denver second; Clippers second
UTA|2028|OUT: Oklahoma City; Cleveland second; COND: Least/less favorable of Detroit 31-55, less-favorable CHA/LAC, conditional Miami, and New York
UTA|2029|Own; COND: Minnesota second if Minnesota does not convey 2029 first to Utah
UTA|2030|COND: Less favorable of Utah/Clippers
UTA|2031|Own; COND: More favorable of Boston/Cleveland
UTA|2032|COND: Utah/Memphis/Philadelphia allocation interest; Cleveland second
UTA|2033|Own
WAS|2027|OUT: New York; COND: More favorable of Brooklyn/Dallas; COND: Less favorable of Golden State/Phoenix; COND: Second-most-favorable among Philadelphia, more-favorable GSW/PHX, and most-favorable OKC/HOU/IND/MIA
WAS|2028|COND: Less favorable of Washington/Lakers; COND: Denver 34-60
WAS|2029|COND: Other of Washington/Indiana after more favorable goes Indiana
WAS|2030|COND: Washington/Phoenix/Portland allocation interest
WAS|2031|OUT: Lakers; COND: More favorable of Miami/Indiana
WAS|2032|OUT: Lakers; COND: Less favorable of Utah and more-favorable Memphis/Philadelphia
WAS|2033|OUT: Memphis; Dallas second
''';

List<NbaSecondRoundSeedInterest> parseNbaSecondRoundSeed() {
  final result = <NbaSecondRoundSeedInterest>[];
  for (final raw in nbaSecondRoundSeed2027To2033.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final parts = line.split('|');
    if (parts.length < 3) continue;
    final team = parts[0].trim();
    final year = int.tryParse(parts[1].trim());
    if (year == null) continue;
    final payload = parts.sublist(2).join('|');
    for (final segment in payload.split(';')) {
      final text = segment.trim();
      if (text.isNotEmpty) result.add(NbaSecondRoundSeedInterest(team: team, year: year, text: text));
    }
  }
  return result;
}
