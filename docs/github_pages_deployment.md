# GitHub Pages deployment

Sports Terminal is published at:

`https://kshmsh1.github.io/sports-terminal/`

The public deployment uses GitHub only. It does **not** require Cloudflare,
AWS, object storage, a credit card, or a billing account.

## Why the public data is bundled

The normal generated `web/data/nba_static` corpus is more than 1.6 GiB and
contains tens of thousands of JSON files. GitHub Pages currently limits a
published site to 1 GiB.

The deployment therefore converts those JSON files into 512 deterministic
gzip-compressed bundles. JSON paths are assigned with FNV-1a. The Flutter web
repository calculates the same bucket number when a document is requested,
downloads that bundle, decompresses it in the browser, and returns the same
JSON object the application would have read from the loose local file.

This changes the transport used by the public website, not the canonical data
or the application's logical data paths.

## Local development is unchanged

Continue using:

```bash
bash scripts/open_terminal.sh
```

Local builds do not enable bundled mode. They continue reading
`web/data/nba_static` exactly as before.

The following are not changed or uploaded by the Pages deployment:

- `nba_history.sqlite`
- raw source exports/captures
- historical ingestion/build logic
- local Python environments
- the existing personal-site files at the root of `kshmsh1.github.io`

## Validate

```bash
bash scripts/deploy_github_pages.sh --dry-run
```

The dry run rebuilds/checks the browser-safe corpus, creates all 512 compressed
bundles, builds Flutter for `/sports-terminal/`, removes the loose 1.6+ GiB
copy from `build/web`, and reports the final published-site size.

It does not push anything.

The deployer refuses to publish if the compressed site is above 950,000 KiB,
leaving margin below GitHub Pages' 1 GiB published-site limit.

## Publish

```bash
bash scripts/deploy_github_pages.sh
```

The script:

1. finds the same local canonical warehouse used by the normal launcher;
2. builds/fingerprint-checks the normal browser-safe static corpus;
3. runs the existing normalization/enrichment/materialization passes;
4. generates 512 deterministic gzip bundles in `web/data/nba_bundles`;
5. builds Flutter with bundled public-data mode enabled;
6. removes only the loose `build/web/data/nba_static` copy;
7. checks individual-file and complete-site size limits;
8. clones `kshmsh1/kshmsh1.github.io` into a temporary directory;
9. synchronizes only its `sports-terminal/` directory;
10. commits and pushes the compiled site.

The existing personal homepage at `https://kshmsh1.github.io/` is preserved.

## Force a fresh static compile

```bash
bash scripts/deploy_github_pages.sh --force-static
```

## Updating the site later

Pull the latest Sports Terminal `main` and run the same deployment command.
The generated bundles are deterministic, so unchanged bundles remain identical
and Git only records bundles whose underlying JSON changed.

The Pages repository will accumulate binary history as bundles change over
time. If that eventually becomes material, compacting deployment history can
be handled separately without changing Sports Terminal's source repository or
local data workflow.
