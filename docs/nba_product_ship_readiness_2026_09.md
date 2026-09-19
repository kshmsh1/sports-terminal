# NBA Product Ship Readiness — September 2026

## What Sports Terminal has become

Sports Terminal has evolved from a collection of NBA screens into a coherent NBA-first research and front-office product.

Implemented foundations include:
- canonical Sports / NBA customer shell;
- historical static NBA corpus with provenance-aware source architecture;
- player, team, season, franchise and game identity;
- core Stats;
- full catalog-driven Advanced Stats;
- player and team comparisons;
- historical box-score and game research;
- visualizations, rankings and with/without analysis surfaces;
- CBA-aware Trade Machine and front-office data models;
- contracts/cap/draft infrastructure;
- research and entity intelligence;
- community/profile scaffolding and persistence layers;
- reusable workspaces and Python-related product architecture;
- comprehensive legal drafts and legal-consent infrastructure;
- global footer plus About, Contact, Privacy, Terms, Sitemap, Accessibility and Data & Methodology surfaces;
- static runtime data policy with live sports/social/backend network paths disabled.

## Advanced Stats status

The canonical metric catalog contains the intended professional workstation families:
- Basic;
- Defensive / Hustle;
- Playmaking / Possession;
- Rebounding;
- Efficiency;
- Impact;
- Aggregate;
- Movement;
- Clutch;
- Shot Profile;
- Play Type, including isolation;
- Gravity / Creation;
- Physical;
- Discipline;
- Availability.

The UI now uses that family registry rather than a six-tab reduced copy.

Important: a column being defined does not mean data exists for every season/player. Source-gated fields should display an unavailable state until a legitimate static source has populated them.

## Remaining work before a fully complete NBA product can ship

### Data completeness
- certify the current supported season snapshot;
- finish source-backed population of modern tracking/advanced fields that Sports Terminal is legally allowed to use;
- reconcile contracts, team cap positions and draft-asset ownership;
- complete detailed box-score/game materialization where historical source coverage permits it;
- define release/version metadata for every static dataset.

### Trade Machine / CBA
- continue fixture-based testing of edge cases;
- verify sign-and-trade, BYC/poison-pill, waiting periods, exceptions, Stepien/protection interactions and apron behavior against the current CBA;
- reconcile transaction assets to the current static financial snapshot;
- make every failure reason explainable in the UI.

### Product QA
- complete a full desktop/compact browser click-through;
- eliminate Flutter overflow/runtime assertions;
- test every entity link and back-navigation path;
- test empty/error/unavailable states;
- test sorting, pagination and exports for very wide Advanced Stats families;
- verify light/dark themes;
- verify keyboard navigation and accessibility semantics.

### Static-data enforcement
- add CI checks that reject new remote runtime URL/network dependencies in customer Dart code;
- distinguish same-origin static asset reads from third-party data calls;
- ensure launcher scripts never silently refresh external sports data;
- document the controlled offline process for producing a new static release.

### Legal, rights and company setup
- replace all legal-entity/contact/effective-date placeholders;
- have qualified counsel review Privacy Policy, Terms, subscription terms, IP/data rights, community terms and launch jurisdictions;
- confirm commercial redistribution rights for every data family;
- license any protected media/assets used commercially;
- establish a corrections/takedown/rights-request process.

### Production engineering
- choose production hosting;
- domain/TLS/CDN;
- durable production account persistence if accounts are in launch scope;
- backups and recovery;
- secrets management;
- error monitoring and observability;
- security review and penetration testing;
- analytics with privacy controls;
- release/rollback process.

### Monetization
- conduct structured design-partner interviews before locking pricing;
- identify the initial paying ICP;
- validate willingness to pay with paid pilots;
- implement billing/entitlements only after the paid workflow is clear;
- create enterprise packaging, support levels and contract process.

### Operational readiness
- support queue and response policy;
- data QA ownership;
- security/incident response;
- community moderation if community launches publicly;
- customer success for B2B accounts;
- legal/privacy contact process.

## Ship definitions

### Private alpha
Can ship when:
- core NBA routes work reliably;
- static data is stable;
- Advanced Stats and Trade Machine are useful;
- known data gaps are explicit;
- no runtime third-party data dependency is required.

### Public beta
Requires:
- browser/runtime QA;
- data-rights review;
- finalized product legal text;
- security basics;
- support process;
- production hosting/account architecture appropriate to the features enabled.

### Paid commercial release
Requires:
- commercial data rights;
- final legal agreements;
- billing and entitlements;
- production-grade identity/security;
- monitoring/backups;
- reliable customer support;
- clear ICP and validated willingness to pay.

## Product-completion principle

Do not define “complete” as having every conceivable NBA feature. Define it as a product where the core NBA research and front-office workflows are trustworthy, fast, source-aware, reproducible, polished and valuable enough that a target customer would choose to use Sports Terminal repeatedly instead of stitching together several other tools.
