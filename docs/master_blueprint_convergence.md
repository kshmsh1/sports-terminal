# Sports Terminal Master Blueprint Convergence

This document is the implementation companion to the Bloomberg-scale Sports Terminal master blueprint. The governing product doctrine is:

**One canonical sports graph. Every relevant lens. Any permitted output. Any device.**

## Implemented convergence layer

The authenticated product now has a shared blueprint frame and reusable operating-system primitives for:

- Universal command/search/action entry.
- Context-aware navigation primitives.
- Shared semantic design tokens and density modes: SUMMARY, ANALYST and TERMINAL.
- Universal Player/Team/Game/Season/etc. object headers.
- Universal actions: COMPARE, CHART, WATCH, QUERY, MODEL, EXPORT, LAB, SOURCE, BOARD, SHARE and DISCUSS.
- Actionable metrics with definition/source/method/release/coverage evidence.
- Persistent Boards that retain panel payloads, filters, layout, collaborators and live-refresh state.
- Immutable/versioned Research Objects with reproduce and fork-with-current-data semantics.
- Certified-release/freshness UI.
- Field-level Data Rights Envelopes.
- Source Audit v2 with display/export/API/redistribution rights.
- One inspectable Universal Query object.
- Query → Chart/Compare/Lab/Workspace/Export/Source-Audit continuity.
- Current/historical NBA Player convergence without assuming provider/release IDs equal historical keys.
- Blueprint coverage and recursive platform audits.

The existing canonical NBA Player ↔ Team ↔ Game ↔ Event ↔ Season ↔ Franchise ↔ Career graph remains the sports-domain foundation underneath these shared primitives.

## Explicit external boundary

The following are **not** marked implemented merely because provider interfaces or UI states exist:

- Commercial NBA data rights and an authoritative production live feed.
- Licensed player/ball tracking.
- Licensed game video distribution.
- Commercial social/news feed redistribution rights.
- Production managed PostgreSQL hosting.
- Production security-email delivery.
- Production durable object storage.
- External monitoring/alert delivery.
- A live payment provider account.
- Customer/enterprise IdP registration.
- Regulated real-money wagering or fantasy execution.

Those require contracts, rights, vendor accounts, legal programs, or capital outside repository code.

## Validation

No GitHub Actions workflow runs automatically. The repository remains `workflow_dispatch` only. With GitHub-hosted Actions unavailable, validate locally:

```bash
bash scripts/validate_local.sh
```

Backend/source-contract validation only:

```bash
bash scripts/validate_local.sh --backend-only
```

The top-level recursive contract is:

```bash
python3 tools/audit_sports_terminal_platform_v4.py --check
```

It composes the prior production v3 contract and the master blueprint v1 contract. This preserves the distinction between software completion and external commercial/rights completion.
