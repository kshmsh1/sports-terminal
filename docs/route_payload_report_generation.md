# RoutePayload Report Generation Contract

Sports Terminal Reports now has a deterministic generated-output boundary for any active structured `RoutePayload`.

## Product behavior

The Reports intake converts the active route package into a source-backed report shell with four mandatory layers: scope, structured data, source/provenance, and constraints. The report exposes Preview, Markdown, JSON, and TSV representations from the same generated object.

The generator is intentionally generic. It does not write game recaps, scouting opinions, award claims, player evaluations, or other sports conclusions unless those facts already exist as explicit structured values in the upstream payload. This keeps Reports usable before commercial live-data rights while preserving the platform rule that unavailable sports data stays unavailable.

## Data integrity rules

1. Structured `RoutePayload.rows` are the only report table data source.
2. `selectedRows` labels are descriptive only and are never parsed into data.
3. Selected columns are projected by exact column key or label; the generator never invents missing columns.
4. Missing and blank values remain missing (`—` in Markdown/preview, `NA` in TSV, `null` in JSON).
5. Upstream blockers are copied into the report and downgrade report coverage.
6. A payload marked blocked remains blocked. A payload without structured rows cannot be promoted to Ready even if its legacy readiness label says Ready.
7. Source snapshot, payload schema version, creation timestamp, filters, and metadata remain attached to generated output.
8. JSON preserves the native structured values and nulls; Markdown/TSV are presentation/export projections only.

## Coverage states

- **READY**: structured rows and columns exist, source provenance is present, no blockers are declared, and upstream readiness is not partial/pending/unavailable/unknown.
- **PARTIAL**: usable structured evidence exists but source, blocker, or readiness gaps remain; legacy label-only payloads also remain Partial.
- **BLOCKED**: upstream readiness is explicitly blocked, or blockers exist while no structured report data is available.

## Current boundary

This feature completes the local-MVP requirement to move Reports beyond static templates into generated report shells. Rich narrative generation, PDF publishing, scheduled distribution, licensed video embeds, and externally delivered reports remain separate future features and must retain the same source/provenance rules.
