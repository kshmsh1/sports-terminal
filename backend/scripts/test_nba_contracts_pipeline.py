#!/usr/bin/env python3
from nba_contracts_pipeline import (
    classify_transaction,
    parse_bref_contracts,
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

TX_HTML = """
<html><body>
<h2>September 3, 2026</h2>
<p>The Houston Rockets re-signed guard Amen Thompson to a Rookie Scale Extension.</p>
<p>The Brooklyn Nets signed forward Grant Nelson to a Two-Way Contract.</p>
<h2>February 17, 2026</h2>
<p>The San Antonio Spurs signed Mason Plumlee to a 10-Day Contract.</p>
</body></html>
"""
tx = parse_transaction_page(TX_HTML, "https://example.test/tx", "test", "official")
assert len(tx) == 3
assert tx[0].event_date == "2026-09-03"
assert tx[0].contract_type == "rookie_scale_extension"
assert tx[1].contract_type == "two_way"
assert tx[2].contract_type == "10_day"
assert classify_transaction("The Miami Heat signed X to an Exhibit 10 contract.")[1] == "exhibit_10"

RULES = {"option_clauses": {"minimum_option_salary_ratio_to_prior_year": 1.0, "reference": "Article XII Sections 1-2"}}
issues = validate_against_cba(rows, RULES)
assert issues == []
print("NBA multi-source contract parser tests passed")
