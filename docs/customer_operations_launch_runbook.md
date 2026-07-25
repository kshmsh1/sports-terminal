# Sports Terminal Customer Operations Launch Runbook

## Purpose

This runbook covers the internally implemented customer and launch-operations systems that support the individual and organization terminals. It deliberately separates repository-complete workflows from external services that require credentials, contracts, staffing or legal approval.

The production entrypoint is `app.main_launch:app`. The connected Flutter surface is the role-aware Launch Center available from every authenticated terminal.

## Implemented operating domains

The customer-operations API provides durable workflows for:

- plan entitlements and scoped subscriptions;
- personal and organization onboarding;
- organization seats, roles and invitations;
- support requests and customer-visible event history;
- privacy access, export, correction, deletion, restriction and objection requests;
- in-app notifications;
- billing, email, SMS and webhook provider outboxes;
- idempotent provider webhook receipts;
- service components and incidents;
- backup and restore-test evidence;
- retention policies;
- immutable customer-operations audit events;
- consolidated account, organization and readiness overviews.

External provider actions are never reported as delivered merely because the internal workflow completed. They remain `pending`, `processing`, `failed`, `delivered` or `cancelled` in `provider_outbox`.

## Full overnight acceptance

Run the complete code, data and operational gate:

```bash
bash scripts/overnight_full_launch.sh
```

This runs the existing platform completion gate and then:

1. executes the customer-operations lifecycle contract;
2. executes provider, backup and privacy tool contracts;
3. compiles all operational tools;
4. verifies a consistent SQLite backup and a full restore when the operational database exists;
5. dry-runs every eligible provider event by default;
6. optionally creates a controlled privacy export;
7. writes one timestamped machine-readable report under `data/full_launch_reports/`.

Useful options:

```bash
bash scripts/overnight_full_launch.sh \
  --database backend/.data/sports_terminal.db \
  --record-backup-evidence \
  --privacy-user-id usr_example \
  --privacy-request-id privacy_example
```

Actual provider delivery is opt-in and requires adapter credentials:

```bash
bash scripts/overnight_full_launch.sh \
  --process-provider-outbox
```

Do not use `--process-provider-outbox` until every provider adapter URL, bearer token, rate limit, retry policy and environment boundary has been reviewed.

## Provider adapters

The worker is:

```bash
python tools/process_provider_outbox.py \
  --database backend/.data/sports_terminal.db \
  --dry-run
```

Provider-specific environment variables follow this pattern:

```text
SPORTS_TERMINAL_BILLING_ADAPTER_URL
SPORTS_TERMINAL_BILLING_ADAPTER_TOKEN
SPORTS_TERMINAL_EMAIL_ADAPTER_URL
SPORTS_TERMINAL_EMAIL_ADAPTER_TOKEN
SPORTS_TERMINAL_SMS_ADAPTER_URL
SPORTS_TERMINAL_SMS_ADAPTER_TOKEN
SPORTS_TERMINAL_WEBHOOK_ADAPTER_URL
SPORTS_TERMINAL_WEBHOOK_ADAPTER_TOKEN
```

The worker sends:

- an `Idempotency-Key` header;
- the internal event ID;
- event type;
- destination;
- structured payload.

It claims a row before delivery, increments attempts only for real delivery, applies exponential retry delay and preserves the last provider error. Dry-run mode never changes row state.

A provider adapter must return a 2xx response only after it has durably accepted responsibility for the event. A network connection alone is not delivery evidence.

## Billing activation

The Launch Center can record plan choice, billing period and organization seat count before a payment provider is active. In this state:

- the subscription status is `pending_provider`;
- entitlements reflect the recorded plan for controlled testing;
- a `subscription.sync_requested` event is queued;
- no charge is attempted;
- the UI explicitly labels provider mode as outbox-only.

Before enabling real billing:

1. configure plan and price identifiers in the billing adapter;
2. configure taxes, invoices, refunds, cancellation and proration rules;
3. verify webhook signatures in the adapter;
4. map provider customer and subscription IDs back to `customer_subscriptions`;
5. test duplicate webhook delivery and replay;
6. test payment failure, cancellation, reactivation and seat changes;
7. complete legal and finance approval.

## Organization invitations and seats

Organization invitations are versioned operating records with:

- email;
- requested role;
- status;
- hashed token;
- inviter;
- accepting user;
- expiration;
- audit event;
- queued email delivery event.

The raw invitation token appears only in the queued provider payload. The invitation table stores only a SHA-256 hash.

Before public organization onboarding:

1. configure email delivery;
2. add a public invitation-acceptance route that verifies the raw token against the hash;
3. enforce seat limits during acceptance;
4. define whether owners can be transferred or removed;
5. test expired, revoked, duplicate and already-member states;
6. confirm role descriptions and customer-facing permissions.

## Support operations

Support tickets include scope, requester, organization, category, priority, status, assignment, related product object and customer-visible history.

Recommended service levels:

| Priority | Initial response target | Operating expectation |
| --- | ---: | --- |
| Urgent | 1 hour | Active product or security impact |
| High | 4 business hours | Material workflow interruption |
| Normal | 1 business day | Standard product assistance |
| Low | 3 business days | Advice, feedback or minor issue |

Do not mark a request resolved without a customer-visible event explaining the resolution. Internal-only investigative notes should set `is_customer_visible` to false.

## Privacy operations

Create an export from first-party records:

```bash
python tools/build_privacy_export.py \
  --database backend/.data/sports_terminal.db \
  --user-id usr_example \
  --request-id privacy_example \
  --output-dir data/privacy_exports
```

The builder:

- excludes authentication sessions;
- excludes passwords and provider credentials;
- redacts keys containing secret or token material;
- includes first-party records linked to the user;
- includes conversation content for conversations in which the user is a member;
- writes a JSON export and manifest;
- computes SHA-256;
- can complete the associated privacy request and write an event.

Exports must be delivered through a time-limited authenticated download flow. Do not send raw exports as ordinary email attachments.

Deletion is intentionally a request workflow, not an immediate client-side database delete. Before executing deletion:

1. verify identity;
2. identify legal holds and records that must be retained;
3. define organization-owned work-product handling;
4. define anonymization versus deletion by table;
5. revoke sessions and provider identities;
6. delete or anonymize source records;
7. verify backups age out according to policy;
8. preserve only the minimum compliance evidence.

## Backup and restore

Create and verify a backup:

```bash
python tools/backup_and_verify.py \
  --database backend/.data/sports_terminal.db \
  --output-dir data/backups \
  --record-evidence
```

The verifier performs:

1. WAL checkpoint;
2. source `PRAGMA integrity_check`;
3. SQLite online backup;
4. backup integrity check;
5. a full restore into a separate temporary database;
6. restored integrity check;
7. source, backup and restore table-count comparison;
8. SHA-256 calculation;
9. optional `backup_runs` evidence record.

A copied file without a successful restore test is not a verified backup.

Production still requires encrypted offsite storage, retention, deletion, access controls, monitoring and periodic disaster-recovery exercises.

## Incident response

Incident severity guidance:

| Severity | Example | Expected response |
| --- | --- | --- |
| SEV1 | Broad outage, active compromise, material data integrity loss | Immediate incident command and customer communication |
| SEV2 | Major feature unavailable or substantial performance degradation | Immediate owner assignment and frequent updates |
| SEV3 | Limited degradation with workaround | Same-day investigation and status updates |
| SEV4 | Minor defect or operational concern | Normal engineering queue |

Incident lifecycle:

1. `investigating` — impact is detected and ownership is assigned;
2. `identified` — cause or failing component is known;
3. `monitoring` — mitigation is deployed and metrics are observed;
4. `resolved` — customer impact has ended;
5. `postmortem` — causes, corrective actions and prevention are documented.

Every update should include internal detail and, where appropriate, a plain-language public message. Component state must be updated with incident state so the Launch Center never presents stale operational status.

## Retention

Default policies are seeded for sessions, provider outbox, audit events, support, privacy, Workspace versions and other operating evidence. These are engineering defaults, not final legal determinations.

Before launch, counsel and operations must approve:

- retention duration;
- legal basis;
- archive versus anonymize versus delete;
- litigation and investigation holds;
- jurisdiction-specific requirements;
- deletion propagation to providers and backups;
- customer-facing disclosures.

## Required external activation

The repository can validate, queue, audit and expose these workflows, but public launch still requires:

- payment provider and product identifiers;
- transactional email provider;
- optional SMS provider;
- managed production database;
- object storage for exports and backups;
- secret manager;
- monitoring and paging provider;
- domain, TLS and production hosting;
- licensed NBA data and data-rights approval;
- staffed support, privacy and moderation operations;
- incident commander and escalation ownership;
- final legal, privacy, security and financial approval.

The customer-operations readiness endpoint reports these separately from internal implementation:

```text
GET /v2/customer-ops/readiness
```
