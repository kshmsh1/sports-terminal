# Pre-Data Gate

Run this before treating the terminal as ready for real source imports:

```bash
bash tools/run_pre_data_gate.sh
```

That command runs:

```bash
bash tools/run_pre_data_tests.sh
bash tools/run_all_asset_validators.sh
```

The gate should pass while source-pending datasets are empty. After real imports, the same gate should block bad rows before they become connected.
