# Institutional Research OS — 40-Unit Convergence

This convergence turns the source-backed Reports milestone into a durable institutional research workflow. It is software-only: it does not claim commercial NBA rights, live-feed access, tracking/video licenses, external alert delivery, hosted vendors, or regulated-product approval.

The operating rule is unchanged: missing sports evidence stays missing, unknown rights stay unverified, immutable research revisions are never overwritten, and derived artifacts retain their release/provenance context.

## A. Generated report durability

1. Deterministic generated-report content fingerprints.
2. Generated report → immutable ResearchObject adapter.
3. Full generated-report artifact payload retained in research.
4. Release/provenance state retained in saved research.
5. Research tags, status and summary metadata.
6. Save generated report directly from the Reports workflow.
7. Fingerprint-based duplicate-save protection.
8. Generated report → durable Research Board panel handoff.

## B. Research Library and lineage

9. ResearchObject schema v2.
10. Backward-compatible v1 ResearchObject decoding.
11. Research Library search and structured filters.
12. Latest-revision and latest-object projections.
13. Immutable revision helper with previous-revision linkage.
14. Revision-lineage retrieval.
15. Reproduce/fork preserve extended artifact, rights and lineage fields.
16. Research Library JSON export.

## C. Metric Registry

17. Typed TerminalMetricDefinition schema.
18. Built-in metric/method registry for implemented NBA primitives.
19. Alias resolution and registry search.
20. Metric dependency graph.
21. Definition, Method, Source, Release and Coverage metadata for registered metrics.
22. Registry integrity checks for duplicate keys, aliases, dependencies and cycles.

## D. Model Registry

23. Typed TerminalModelDefinition schema.
24. Built-in model registry for implemented Sports Terminal analytical/workflow models.
25. Model search and filtering.
26. Metric-input and model-dependency declarations.
27. Method, limitations, source and release metadata for models.
28. Model registry integrity and dependency-cycle checks.

## E. Watches

29. Typed TerminalWatchRule schema.
30. Direct-comparison and change-comparison operators.
31. Triggered / not-triggered / unavailable evaluation states.
32. Missing observations and missing change baselines fail closed.
33. Persistent local watch-rule store.
34. Persistent evaluation history plus explicit one-shot evaluation workflow.

## F. Portable research and universal UI

35. Typed TerminalResearchBundle schema.
36. Bundle compiler for ResearchObject + Boards + UniversalQuery + metric/model dependencies + rights envelopes.
37. Deterministic bundle fingerprint and integrity verification.
38. Rights-gated export/redistribution state: denied stays denied; unknown stays unverified.
39. Universal Institutional Research OS screen and terminal command entry.
40. Platform-v5 manifest, recursive audit, tests, local-validation hook and CI audit hook.

## Product result

A source-backed RoutePayload can now flow through generated Reports into immutable research, survive navigation, be searched in a Research Library, forked/reproduced/versioned, attached to Boards, described by explicit metric/model registries, monitored with deterministic rules, and compiled into a portable research bundle whose rights state is inspectable.

This is an institutional workflow layer, not a claim that the entire commercial Sports Terminal is externally deployable today. The remaining non-code dependencies continue to include commercial NBA data rights, licensed tracking/video where required, vendor accounts selected for production operation, and legal/regulatory programs for regulated products.
