# GitHub Cost Guard

Sports Terminal is a public repository. Standard GitHub-hosted Actions runners may therefore be used for automatic repository validation, while paid or externally provisioned compute remains prohibited unless the operator explicitly changes this policy.

## Repository policy

- Automatic `push` and `pull_request` validation is allowed for checked-in quality workflows.
- `workflow_dispatch` remains available for explicit re-validation.
- Workflows must use standard GitHub-hosted runners such as `ubuntu-latest`; do not configure GitHub larger runners, GPU runners, macOS larger runners, or paid self-hosted runner infrastructure without an explicit operator decision.
- Repository workflow permissions remain least-privilege and read-only by default (`contents: read`) unless a narrowly scoped write permission is explicitly required and reviewed.
- Do not add deployment, billing, package-publishing, cloud-provisioning, Codespaces automation, or paid external CI/deployment side effects to validation workflows without an explicit operator decision.
- Do not add automatic `schedule` or `workflow_run` triggers without a concrete product need and review; ordinary code validation should remain push/PR driven.
- Production infrastructure configuration in this repository is descriptive and fail-closed; it does not provision a cloud vendor or subscribe the account to a paid service.
- Billing integration is application functionality only and defaults to `SPORTS_TERMINAL_BILLING_MODE=disabled`.

## Public-repository CI

The quality workflows are intentionally automatic now that the repository is public. They validate source, contracts, Flutter analysis/tests, and release builds on standard GitHub-hosted runners. They do not publish releases, deploy infrastructure, or create paid vendor resources.

## Local validation

`scripts/validate_local.sh` and `scripts/open_terminal.sh` remain independent of GitHub Actions and hosted deployment providers. Local validation never dispatches workflows or provisions cloud resources.

## Change review

`backend/scripts/deployment_contract_test.py` and `backend/scripts/local_session_contract_test.py` enforce the public-repository CI safety contract. Any future change that introduces larger/paid runners, broad write permissions, scheduled automation, workflow-chaining, or deployment side effects must intentionally update those contracts and this policy.
