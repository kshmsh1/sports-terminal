# GitHub Pages deployment

Sports Terminal can be published as a project site at:

`https://kshmsh1.github.io/sports-terminal/`

The deployment is intentionally separate from local development.

## What stays unchanged

- `scripts/open_terminal.sh` remains the local launcher.
- `nba_history.sqlite` remains local and is never copied into the Pages repository.
- Raw source exports remain local/ignored.
- The canonical warehouse and static compiler remain the source of truth.
- The existing `kshmsh1.github.io` homepage is not replaced.

The public deployment contains only the compiled Flutter web application and the static browser files required by that application.

## Publish

From the Sports Terminal repository:

```bash
bash scripts/deploy_github_pages.sh
```

The script:

1. finds the same local canonical NBA warehouse used by the normal launcher;
2. builds/fingerprint-checks `web/data/nba_static`;
3. performs the same static normalization/enrichment/materialization passes used by local launch;
4. builds Flutter with `--base-href /sports-terminal/`;
5. checks GitHub file/site-size limits before publishing;
6. clones `kshmsh1/kshmsh1.github.io` into a temporary directory;
7. synchronizes only its `sports-terminal/` subdirectory;
8. commits and pushes the compiled site.

No files at the root of the personal-site repository are deleted or replaced.

To validate the build without pushing:

```bash
bash scripts/deploy_github_pages.sh --dry-run
```

To force a fresh static-data compile before deployment:

```bash
bash scripts/deploy_github_pages.sh --force-static
```

If Git credentials are not already available on the machine, Git will require authentication when the script pushes the Pages repository.
