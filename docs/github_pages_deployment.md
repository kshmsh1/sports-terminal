# GitHub Pages + object-storage deployment

Sports Terminal's public web deployment is split into two layers:

- **GitHub Pages:** the lightweight compiled Flutter application at
  `https://kshmsh1.github.io/sports-terminal/`.
- **S3-compatible object storage/CDN:** the generated browser-safe
  `web/data/nba_static` corpus.

This is necessary because the generated historical corpus is larger than a
comfortable GitHub Pages deployment. It also keeps the raw canonical warehouse
off GitHub.

## Local development is unchanged

`scripts/open_terminal.sh` still works exactly as before. When no build-time
override is supplied, the application reads `data/nba_static` relative to the
local web origin.

The public build alone receives
`SPORTS_TERMINAL_NBA_STATIC_BASE` through a Flutter `--dart-define`.

The following remain local and are never uploaded by this deployer:

- `nba_history.sqlite`
- raw source exports/captures
- Python environments
- source credentials

Only the generated browser-safe static corpus is uploaded to object storage.

## Recommended storage: Cloudflare R2

Create one R2 bucket for the public static corpus. Enable a public URL (an
`r2.dev` development URL is sufficient initially, or use a custom domain)
and configure CORS to allow browser GET/HEAD requests from:

`https://kshmsh1.github.io`

Create an R2 API token scoped to that bucket with object read/write access.
Keep the credentials only in your shell/password manager; do not commit them.

R2 exposes an S3-compatible endpoint, so the deployment script uses the AWS
CLI rather than adding Cloudflare-specific application code.

## One-time Mac setup

Install the AWS CLI if needed:

```bash
brew install awscli
```

Set the deployment environment variables. Replace the placeholders with the
values from the R2 dashboard:

```bash
export AWS_ACCESS_KEY_ID="<R2 access key ID>"
export AWS_SECRET_ACCESS_KEY="<R2 secret access key>"
export AWS_DEFAULT_REGION="auto"

export SPORTS_TERMINAL_STATIC_S3_ENDPOINT="https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
export SPORTS_TERMINAL_STATIC_S3_URI="s3://<BUCKET_NAME>/nba_static"
export SPORTS_TERMINAL_STATIC_PUBLIC_BASE="https://<PUBLIC_R2_OR_CUSTOM_DOMAIN>/nba_static"
```

Do not put the secret values in this repository.

## Validate without uploading

```bash
bash scripts/deploy_github_pages.sh --dry-run
```

Dry-run rebuilds/checks the corpus and compiles the lightweight Pages shell,
but does not upload data and does not touch `kshmsh1.github.io`.

If no public base is configured, dry-run uses a deliberately non-routable
placeholder so the shell-size check can still run.

## Publish

```bash
bash scripts/deploy_github_pages.sh
```

The deployment performs these operations in order:

1. finds the existing local canonical NBA warehouse;
2. builds/fingerprint-checks the browser-safe static corpus;
3. runs the existing normalization/enrichment/materialization passes;
4. synchronizes only `web/data/nba_static/` to the configured S3-compatible
   bucket prefix;
5. compiles Flutter with `--base-href /sports-terminal/` and the public
   static-data URL;
6. removes the copied local corpus from `build/web`, leaving a lightweight
   application shell;
7. verifies the public `manifest.json` is reachable;
8. clones `kshmsh1/kshmsh1.github.io` into a temporary directory;
9. synchronizes only the `sports-terminal/` subdirectory;
10. commits and pushes that subdirectory.

The root of the existing personal website is not replaced or deleted.

## Force a fresh static compile

```bash
bash scripts/deploy_github_pages.sh --force-static
```

## Updating the public site later

After Sports Terminal changes, pull the latest `main` and run the same
deployment command. `aws s3 sync` uploads changed/new static objects and
removes stale objects under the configured `nba_static` prefix; GitHub Pages
receives the newly compiled Flutter shell.

Because `--delete` is scoped to the configured bucket prefix, use a dedicated
bucket or dedicated `nba_static` prefix for Sports Terminal.
