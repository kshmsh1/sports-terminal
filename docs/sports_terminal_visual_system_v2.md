# Sports Terminal Visual System v2

## Product direction

Sports Terminal should feel like an institutional operating system for professional sports, not a themed analytics website and not a visual derivative of another basketball product. External references may inform the expected level of polish, density, responsiveness, and technical sophistication, but should not determine the product's layout grammar, color system, navigation model, component shapes, or information hierarchy.

The core visual identity is **graphite, structured, source-aware, and command-oriented**. The interface should look credible in a front office, research department, league office, agency, media research desk, or institutional analytics environment.

## Visual grammar

The primary canvas is near-black graphite rather than saturated navy. Surfaces use small tonal steps instead of large cards. Borders and rules create hierarchy more often than shadows. Accent color is a restrained research blue, with amber reserved for warnings/expandable analytical detail and green/red reserved for state or directional meaning.

Rounded pills, oversized chips, decorative gradients, bright neon panels, and large dashboard cards should be used sparingly. Controls should read as compact instruments. Navigation should favor codes, labels, tabs, command bars, and structured readouts.

Typography should emphasize dense legibility. Section labels are small uppercase technical labels; primary titles remain plain and direct. Numeric tables should prioritize alignment, consistent widths, and compact row height over decorative presentation.

## Stats workstation pattern

The Stats Workstation establishes the first full implementation of this system:

- an institutional header with a release/status readout;
- a permanent Regular Season / Playoffs split, with Regular Season as the default;
- a single stat-family dropdown rather than a long row of category tabs;
- family-specific expandable columns using compact directional triangles;
- source-aware availability, with unavailable provider/model metrics rendered as `—` rather than fabricated;
- neutral striped data rows and minimal chrome;
- a complete metric glossary at the bottom of the page;
- compact controls for rate basis, team, position, minimum games, player search, comparison, and export.

## Product-wide migration rule

Future surface work should use this visual system as the default direction. Existing modules do not need to be mechanically restyled in one commit, but new work and substantive rewrites should move away from prior bright-yellow/chip-heavy dashboard patterns and toward the structured terminal system described here.

The objective is a recognizable Sports Terminal design language that can expand beyond basketball without resembling any single existing sports analytics platform.
