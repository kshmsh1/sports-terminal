#!/usr/bin/env python3
"""Small parser contract test for the HoopsHype salary scraper."""

from scrape_hoopshype_salaries import parse_salary_page

HTML = """
<html><body>
<table>
<thead><tr><th>Rank</th><th>Player</th><th>2025/26</th><th>2026/27</th></tr></thead>
<tbody>
<tr><td>1.</td><td>Example Player</td><td>$12,345,678</td><td title="Player Option">$13,000,000</td></tr>
<tr><td>2.</td><td>Two Way Guy</td><td class="two-way">$578,577</td><td>$0</td></tr>
</tbody>
</table>
</body></html>
"""

wide, long_rows = parse_salary_page(
    HTML,
    "https://hoopshype.com/salaries/players/2025-2026/",
    "2025/26",
)

assert len(wide) == 2
assert wide[0]["player_name"] == "Example Player"
assert wide[0]["salary_2025_26"] == 12345678
assert wide[0]["marker_2026_27"] == "player_option"
assert wide[1]["marker_2025_26"] == "two_way"
assert len(long_rows) == 4
assert long_rows[0].salary == 12345678
print("HoopsHype salary parser contract test passed")
