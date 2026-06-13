# User Mode and Internal Workspaces

The application now has a local development login gate and a separate regular-user shell.

## Demo accounts

```text
analyst@sportsterminal.local / demo123
admin@sportsterminal.local / demo123
platform@sportsterminal.local / demo123
```

The analyst and organization-admin accounts enter User Mode. The platform-admin account enters the existing internal terminal with Build Lab and Data Ops surfaces.

This is local development authentication, not production security. Real accounts require a backend, persistent sessions, password recovery, invitations, organization membership storage, and server-side authorization.

## User Mode

User Mode contains NBA research and workflow surfaces plus internal spreadsheet and code-workspace entry points. It excludes Build Lab, Source Registry, Import Jobs, QA Console, ingestion controls, and other platform-administration screens.

The shell switches to an app bar and drawer below desktop width. Navigation labels, account names, and organization names are constrained with wrapping or ellipsis.

## Organization model

Every session carries:

```text
userId
email
displayName
organizationId
organizationName
role
```

The initial roles are Analyst, Organization Admin, and Platform Admin.

## Internal spreadsheet

The first functional spreadsheet workspace loads final roster and team data, supports filters, selectable columns, row selection, and organization-scoped saves. It intentionally provides no CSV or workbook download.

Saved documents are currently held in application memory. Backend persistence is the next required layer.

## Controlled code workspace

The repository includes a read-only statement engine supporting a restricted table query shape over explicitly approved datasets. It supports selected columns, equality filters, sorting, and row limits. Mutation, filesystem, network, and arbitrary execution are outside the allowed model.

A production Python workspace requires isolated execution workers, resource limits, approved packages, organization-scoped data access, network denial by default, result serialization, and audit logs.

## Internal-only output policy

Regular-user terminal data should flow only to:

```text
Internal Spreadsheet
Controlled Code Workspace
Saved View
Report
Chart
Organization Project
```

The product should not expose unrestricted raw CSV, workbook, API, or bulk-download paths to regular users. Platform-level exports should be separately permissioned and audited.
