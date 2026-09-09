#!/usr/bin/env python3
from nba_contracts_pipeline import (
    canonicalize_contract_evidence,
    classify_transaction,
    discover_bref_team_payroll_links,
    discover_bref_team_season_links,
    parse_bref_contracts,
    parse_bref_historical_team_salary,
    parse_bref_team_payroll,
    parse_money,
    parse_transaction_page,
    validate_against_cba,
)

CONTRACT_HTML = """
<table id="contracts">
<thead><tr><th>Rk</th><th>Player</th><th>Tm</th><th>Cap Hit</th><th>2026-27</th><th>2027-28</th><th>Signed Using</th><th>Guaranteed</th></tr></thead>
<tbody>
<tr><td>1</td><td><a href="/players/e/example01.html">Example Player</a></td><td>CHI</td><td>$10,000,000</td><td>$10,000,000</td><td class="popt" title="Player Option">$11,000,000</td><td>Bird Rights</td><td>$10,000,000</td></tr>
<tr><td>2</td><td>Second Player</td><td>NYK</td><td>$5,000,000</td><td>$5,000,000</td><td class="topt" title="Team Option">$5,000,000</td><td>MLE</td><td>$5,000,000</td></tr>
</tbody></table>
"""
rows = parse_bref_contracts(CONTRACT_HTML, "https://example.test/contracts")
assert len(rows) == 4
assert rows[0].player_external_id == "example01"
assert rows[0].reported_cap_hit == 10_000_000
assert rows[1].option_type == "player_option"
assert rows[3].option_type == "team_option"
assert rows[0].signed_using == "Bird Rights"
assert rows[0].reported_contract_guaranteed_total == 10_000_000
assert parse_money("$1,234,567") == 1_234_567

# Regression: generic words containing "to" or "po" must not be mistaken for options.
NO_OPTION_HTML = CONTRACT_HTML.replace('class="popt" title="Player Option"', 'class="contract total" title="future salary"')
no_options = parse_bref_contracts(NO_OPTION_HTML, "https://example.test/no-options")
assert no_options[1].option_type is None

INDEX_HTML = """
<a href="/contracts/CHI.html">Chicago Bulls</a><a href="/contracts/NYK.html">Knicks</a>
<a href="/teams/CHI/1996.html">1995-96 Bulls</a><a href="/teams/SEA/1996.html">1995-96 Sonics</a>
"""
assert discover_bref_team_payroll_links(INDEX_HTML) == [
    ("CHI", "https://www.basketball-reference.com/contracts/CHI.html"),
    ("NYK", "https://www.basketball-reference.com/contracts/NYK.html"),
]
assert discover_bref_team_season_links(INDEX_HTML, 1996) == [
    ("CHI", "https://www.basketball-reference.com/teams/CHI/1996.html"),
    ("SEA", "https://www.basketball-reference.com/teams/SEA/1996.html"),
]

TEAM_HTML = """
<table><thead><tr><th>Player</th><th>Age</th><th>2026-27</th><th>2027-28</th><th>Guaranteed</th></tr></thead>
<tbody>
<tr><td><a href="/players/e/example01.html">Example Player</a></td><td>25</td><td>$10,000,000</td><td><em>$11,000,000</em></td><td>$10,000,000</td></tr>
<tr><td>Option Man</td><td>29</td><td>$9,000,000</td><td class="topt">$9,500,000</td><td>$9,000,000</td></tr>
<tr><td>Team Totals</td><td></td><td>$19,000,000</td><td>$20,500,000</td><td>$19,000,000</td></tr>
</tbody></table>
"""
team_rows = parse_bref_team_payroll(TEAM_HTML, "CHI", "https://example.test/CHI")
assert len(team_rows) == 4
assert team_rows[0].reported_salary_fully_guaranteed is True
assert team_rows[1].reported_salary_fully_guaranteed is False
assert team_rows[3].option_type == "team_option"
assert team_rows[3].reported_salary_fully_guaranteed is False

HIST_HTML = """
<!-- <table><thead><tr><th>Player</th><th>Salary</th></tr></thead><tbody>
<tr><td><a href="/players/j/jordami01.html">Michael Jordan</a></td><td>$3,850,000</td></tr>
<tr><td>Scottie Pippen</td><td>$2,925,000</td></tr>
</tbody></table> -->
"""
hist_rows = parse_bref_historical_team_salary(HIST_HTML, "CHI", 1996, "https://example.test/CHI/1996")
assert len(hist_rows) == 2
assert hist_rows[0].season == "1995-96"
assert hist_rows[0].player_external_id == "jordami01"
assert hist_rows[0].reported_salary == 3_850_000
assert hist_rows[0].source_quality_note

TX_HTML = """
<html><body>
<h2>September 3, 2026</h2>
<p>The Houston Rockets re-signed guard Amen Thompson to a Rookie Scale Extension.</p>
<p>The Brooklyn Nets signed forward Grant Nelson to a Two-Way Contract.</p>
<h2>February 17, 2026</h2>
<p>The San Antonio Spurs signed center Mason Plumlee to a 10-Day Contract.</p>
</body></html>
"""
tx = parse_transaction_page(TX_HTML, "https://example.test/tx", "test", "official")
assert len(tx) == 3
assert tx[0].event_date == "2026-09-03"
assert tx[0].player_name == "Amen Thompson"
assert tx[0].contract_type == "rookie_scale_extension"
assert tx[1].player_name == "Grant Nelson"
assert tx[1].contract_type == "two_way"
assert tx[2].player_name == "Mason Plumlee"
assert tx[2].contract_type == "10_day"
assert classify_transaction("The Miami Heat signed X to an Exhibit 10 contract.")[1] == "exhibit_10"

canonical = canonicalize_contract_evidence(rows + team_rows + hist_rows)
example_2026 = next(x for x in canonical if x.player_name == "Example Player" and x.season == "2026-27")
assert example_2026.evidence_count == 2
assert example_2026.reported_salary_fully_guaranteed is True
assert example_2026.salary_source_name == "basketball_reference_team_payroll"

RULES = {"option_clauses": {"minimum_option_salary_ratio_to_prior_year": 1.0, "reference": "Article XII Sections 1-2"}}
issues = validate_against_cba(canonical, RULES)
assert issues == []
print("NBA multi-source contract parser tests passed")
