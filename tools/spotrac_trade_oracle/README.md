# Spotrac Trade Oracle

Offline diagnostic tooling for converting a browser HAR into sanitized Trade
Machine states that can be compared with Sports Terminal's independent CBA
engine.

The parser recognizes Spotrac's `/nba/trade-machine/run/_/year/.../` POST flow
and extracts only the transaction state: participating team slugs, routed
players, draft assets, draft rights/cash fields, request sequence and any
response body that the browser actually preserved.

It deliberately does **not** retain or replay CSRF tokens, Turnstile tokens,
cookies, request headers or other session credentials.

Usage:

```bash
python3 tools/spotrac_trade_oracle/parse_har.py local_capture.har \
  -o artifacts/spotrac_trade_states.json
```

Raw HAR files should remain local. The repository ignores `*.har`.
Normalized fixtures may be committed only after review and should be treated as
behavioral comparison data, not as copied implementation code.

A HAR exported without response bodies can still reconstruct the full sequence
of trade inputs. For PASS/FAIL differential testing, capture the relevant
`/run/` response body in DevTools and preserve it in the HAR.
