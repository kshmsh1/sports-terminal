# GitHub Cost Guard

Sports Terminal repository automation is intentionally configured to avoid automatic GitHub Actions consumption while the platform is under active build-out.

## Repository policy

- Every checked-in GitHub Actions workflow is `workflow_dispatch` only.
- Pushes and pull-request updates do not automatically start GitHub-hosted runners.
- Do not add `push`, `pull_request`, `schedule`, `workflow_run`, or other automatic triggers without an explicit cost review.
- Do not enable paid/self-hosted runner infrastructure, GitHub-hosted larger runners, Codespaces automation, or paid external CI/deployment integrations from this repository without an explicit operator decision.
- Production infrastructure configuration in this repository is descriptive and fail-closed; it does not provision a cloud vendor or subscribe the account to a paid service.
- Billing integration is application functionality only and defaults to `SPORTS_TERMINAL_BILLING_MODE=disabled`.

## Manual CI

An operator may manually dispatch a workflow only after independently confirming the GitHub account's Billing & Licensing budgets/limits. Repository code cannot inspect or enforce the personal account's complete billing state because that requires account-level billing permissions outside this GitHub App integration.

## Change review

`backend/scripts/deployment_contract_test.py` and the production platform audit enforce the manual-only workflow contract. Any future automation change that reintroduces automatic Actions triggers must intentionally update those contracts and this policy.
