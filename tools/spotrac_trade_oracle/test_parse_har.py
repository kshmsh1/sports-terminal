import json
import tempfile
import unittest
from pathlib import Path

from tools.spotrac_trade_oracle.parse_har import extract_states, to_jsonable


class SpotracHarParserTest(unittest.TestCase):
    def test_extracts_routed_players_without_security_headers(self):
        har = {
            "log": {
                "entries": [
                    {
                        "startedDateTime": "2026-10-03T01:54:07.500Z",
                        "request": {
                            "method": "POST",
                            "url": "https://www.spotrac.com/nba/trade-machine/run/_/year/2026/team1/bos/team2/phi",
                            "headers": [{"name": "x-turnstile-token", "value": "secret"}],
                            "postData": {
                                "params": [
                                    {"name": "csrf_test_name", "value": "secret"},
                                    {"name": "trade_reviewed", "value": "0"},
                                    {"name": "selected_players[95][]", "value": "23624:114"},
                                    {"name": "selected_players[114][]", "value": "98600:95"},
                                ]
                            },
                        },
                        "response": {
                            "status": 200,
                            "content": {"mimeType": "text/html", "text": "<div>ok</div>"},
                        },
                    }
                ]
            }
        }
        states = extract_states(har)
        self.assertEqual(len(states), 1)
        self.assertEqual(states[0].teams[0]["slug"], "bos")
        self.assertEqual(states[0].assets[0].asset_id, "23624")
        self.assertEqual(states[0].assets[0].destination_team_id, "114")
        payload = json.dumps(to_jsonable(states))
        self.assertNotIn("turnstile", payload.lower())
        self.assertNotIn("csrf_test_name", payload)


if __name__ == "__main__":
    unittest.main()
