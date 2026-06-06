# Pre-Data Gate

Before source rows are added, run:

```bash
bash tools/check_pre_import_state.sh
```

After source rows are added, run:

```bash
bash tools/check_post_import_candidate.sh
```

The pre-import check expects source-pending datasets to remain empty.

The post-import check allows source rows but still runs tests and every asset validator.

The older general command remains available:

```bash
bash tools/run_pre_data_gate.sh
```
