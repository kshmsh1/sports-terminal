# Role Platforms and Transaction Workflows

## Purpose

This phase separates the individual and organization user experiences while preserving a shared NBA product and transaction foundation.

## Individual Terminal

Analysts now enter an Individual Terminal rather than a generic user shell. The first destination is **My Work**, which contains:

- private transaction cases;
- a case builder with modeled salary and draft assumptions;
- preliminary CBA review findings;
- personal status pipelines;
- personal portfolio breakdowns;
- organization-sharing controls;
- visibility into pending organization approval.

The Individual Terminal also includes the existing Home, Stats, NBA Hub, Advanced Tools, Trade Machine, Front Office, Workspace, Python Lab, Articles, Messages and Profile destinations.

Organization administration and backend operator controls are no longer presented to ordinary analysts.

## Organization Terminal

Organization administrators now enter a dedicated Organization Terminal. The first destination is **Organization**, which contains:

- a shared transaction-case portfolio;
- organization review and approval queues;
- case ownership and workload breakdowns;
- team and priority portfolio reporting;
- organization-created cases;
- approval and changes-requested decisions;
- synchronization of decisions back into the owning analyst's personal case history.

Organization administrators retain the NBA, transaction, Workspace and Python tools available to analysts and also receive an Organization Admin destination.

## Shared transaction case contract

Every transaction case can preserve:

- owner and organization identity;
- operating season and involved teams;
- workflow status and priority;
- salary assumptions;
- rule findings;
- assigned users;
- approvals;
- comments;
- personal or organization visibility;
- source payload identity for future Trade Machine integration.

The personal and organization repositories use separate local namespaces. Publishing a case to the organization keeps both copies synchronized.

## Preliminary CBA evaluator

The transaction evaluator currently checks:

- negative or empty salary inputs;
- modeled hard-cap excess;
- first-apron review requirements;
- second-apron incoming-salary, aggregation, cash and exception assumptions;
- no-trade consent;
- recently signed and poison-pill review;
- Stepien availability;
- unverified pick terms;
- roster-spot assumptions.

The evaluator produces **Blocked**, **Review required** or **Preliminary clear**. It does not claim final legal approval.

## Product architecture

```text
Individual analyst
    -> private case repository
    -> preliminary rule evaluation
    -> personal workflow pipeline
    -> optional organization publish

Organization administrator
    -> shared organization repository
    -> portfolio and workload views
    -> approval / changes requested
    -> synchronized owner copy

Both roles
    -> Stats / NBA Hub
    -> Trade Machine / Front Office
    -> Workspace / Python Lab
```

## Next convergence work

The next phase should connect Trade Machine scenario packages directly into transaction cases, attach Front Office contract rows to case assumptions, add organization membership and assignment management, introduce backend-scoped persistence, and expand the CBA evaluator into date-aware salary-matching and hard-cap modules.
