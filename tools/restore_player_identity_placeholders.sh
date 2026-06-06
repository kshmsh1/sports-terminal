#!/usr/bin/env bash
set -euo pipefail

cat > assets/data/nba/players/player_profiles.json <<'JSON'
{
  "source": {"id":"nba-player-profile-index","asOf":null,"type":"pending-source","usage":"Schema-ready placeholder; no fake player records"},
  "players": []
}
JSON

cat > assets/data/nba/players/player_aliases.json <<'JSON'
{
  "source": {"id":"nba-player-alias-index","asOf":null,"type":"pending-source","usage":"Schema-ready placeholder; no fake alias records"},
  "aliases": []
}
JSON

rm -f raw/player_identity_held_rows.json

echo "Restored player profile and alias placeholders."
