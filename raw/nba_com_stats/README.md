# NBA.com Stats Local Landing Zone

This directory is reserved for **local, uncommitted** NBA.com Stats response files that the developer is authorized to use.

The repository commits this README only. Response bodies, HAR files, session material, and generated normalized data must remain local.

Use:

```bash
python3 tools/inventory_nba_com_stats_har.py ~/Downloads/nba-stats.har
```

for endpoint discovery, and:

```bash
python3 tools/import_nba_com_authorized_response.py RESPONSE.json \
  --surface players_advanced \
  --season 2025-26
```

for an authorized response import.

Do not place cookies, authorization tokens, API keys, or licensed vendor credentials in committed files.
