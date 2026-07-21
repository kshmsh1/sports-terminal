# Transaction Convergence and Collaboration

## Purpose

This phase connects the terminal’s analytical tools to the role-aware transaction workflow introduced in the prior phase. Saved Trade Machine, Front Office, Cap Lab and routed-data state can become persistent transaction cases instead of remaining isolated inside individual tools.

## Individual platform

The Individual Terminal now gains:

- a Transaction Command Center above the existing personal case pipeline;
- automatic discovery of saved analytical scenarios;
- private or organization-visible imports;
- direct case creation from the Trade Machine;
- direct case creation from the Front Office ledger;
- case comments and discussion history;
- case assignments;
- personal notifications;
- organization-submission actions;
- a workflow pulse on the Home surface.

## Organization platform

The Organization Terminal receives the same connected analytical workflow plus:

- organization-wide activity history;
- shared imports that enter review immediately;
- organization member and reviewer records;
- shared assignment controls;
- workload and collaboration metrics;
- organization notification routing;
- direct shared-case creation from Trade Machine and Front Office;
- organization workflow metrics on Home.

## Import sources

### Trade Machine

The convergence service reads the saved operating season, teams, scenario name, routed asset destinations and selected-only state. Imported cases retain a source payload identity so later phases can attach the complete structured scenario.

Trade Machine salary values remain proxy values until reconciled with sourced contract records.

### Front Office Ledger

The service reads contract rows, draft assets, non-contract charges, no-trade assumptions and unspecified pick protections. Current modeled salary is calculated from contract salary plus stored non-contract charges.

### Active routed package

The active route payload can become a case with its source object, structured row count, filters, readiness state, blockers and route identity.

### Cap Lab

Saved Cap Lab state becomes a case candidate with the stored team, season, salary and apron assumptions when those fields are available.

## Collaboration contract

Collaboration data is stored separately from the transaction case object so the existing case schema remains stable.

The workflow repository persists:

- organization activity events;
- per-user notifications;
- organization members and reviewers.

Activity events currently cover imports, submissions, comments, assignments and future approval events. Notifications can be marked read and are scoped to the recipient user.

## Connected tool wrappers

The Trade Machine and Front Office screens remain unchanged internally. Role-aware wrappers add a workflow banner and a Create Case action above each tool.

Analysts can create a private case or submit directly to the organization. Organization administrators always create a shared case in the organization workflow.

## Current persistence boundary

All workflow storage remains local through SharedPreferences. Namespaces are separated by user and organization, but this does not yet provide cross-device or multi-user synchronization.

The next backend phase must map these local contracts to account-scoped and organization-scoped server tables, authorization policies, event history and realtime delivery.

## Next work

The strongest next steps are:

1. persist full structured Trade Machine assignments inside the case source package;
2. connect exact Front Office contracts to incoming and outgoing case sides;
3. add date-aware salary matching and transaction eligibility;
4. add backend organization membership and role permissions;
5. move events and notifications to immutable server records;
6. add reviewer SLAs, escalation and approval thresholds;
7. generate complete transaction approval reports;
8. route cases into Workspace, Python Lab, Reports and exports;
9. add realtime collaboration and cross-device synchronization;
10. replace modeled assumptions with sourced contracts, cap ledgers and draft ownership.
