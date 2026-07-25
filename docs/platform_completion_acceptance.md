# Platform Completion Acceptance Gate

This branch is acceptable for merge only when the exact final head passes every check below.

## Data and application integrity

- Pre-Data Gate
- all existing NBA asset validators
- Python compilation for backend, scripts and tools
- launch backend domain contract
- front-office, trust-safety, messaging and Python-runtime completion contract
- Workspace multi-sheet, optimistic-conflict, permission and restore contract
- real Uvicorn HTTP authentication and security contract
- strict Flutter analysis
- complete Flutter test suite
- release Flutter web build

## Product acceptance

- Contracts & Assets is a default customer destination.
- Contract, team-position, draft-asset and ledger records remain versioned and source-classified.
- The authoritative-data catalog cannot pass production thresholds without verified provenance.
- Community posts, comments and messages are authenticated and bounded.
- Reports, blocks, mutes, sanctions and moderator actions are persisted and auditable.
- Messages require explicit conversation membership and honor bilateral blocks.
- Workspace preserves multiple sheets, supports formulas and structural edits, detects stale saves and restores prior versions as new versions.
- Object Router and Cap Lab imports become new connected sheets instead of overwriting the shared workbook.
- Python Lab executes only through the bounded server runtime and retains a non-executing local fallback.
- Completion status separates internal implementation, source population and external launch blockers.

## Explicit non-acceptance claims

A passing repository gate does not claim that commercial data rights, authoritative 2025–26 contract and pick data, managed production infrastructure, payment credentials, production email and MFA delivery, staffed moderation, customer support, incident response or final legal approval exist.
