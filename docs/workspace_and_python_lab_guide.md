# Sports Terminal Workspace and Python Lab Guide

This guide defines how the Excel-like workspace and embedded Python Lab should work as the product matures.

## Excel-like workspace goals

The workspace should feel familiar to users who live in Excel, Google Sheets, or financial models, but it should be specialized for sports objects. Cells should be able to hold plain text, numbers, formulas, imported stat tables, player references, team references, game references, trade scenarios, charts, and notes.

## Formula roadmap

| Category | Examples | Product goal |
| --- | --- | --- |
| Basic math | `=A1+B1`, `=A1/B1`, `=A1*B1` | Core spreadsheet behavior. |
| Aggregations | `=SUM(C3:C20)`, `=AVG(C3:C20)`, `=MIN(C3:C20)`, `=MAX(C3:C20)` | Already started; needs broader coverage and range robustness. |
| Lookup | `=PLAYER("jokicni01", "PPG")`, `=TEAM("BOS", "NET_RTG")` | Sports-object formulas that pull from the entity graph. |
| Filters | `=FILTER_PLAYERS("PPG > 15 AND RPG < 4")` | Connect the NBA Stats query layer to workbooks. |
| Scenario formulas | `=TRADE_BALANCE("scenario_1")`, `=CAP_SPACE("BOS", 2026)` | Let trade/cap/fantasy outputs become workbook models. |
| Chart formulas | `=CHART(A1:D20, "bar")` | Make workbooks visual and shareable. |

## User workflow

1. Start from NBA Stats, Player Dashboard, Team Page, Game Page, Trade Machine, or Python Lab.
2. Export a table or selected rows to a new workbook sheet.
3. Add formulas, notes, rankings, tiers, or scenario assumptions.
4. Save the workbook locally first, then sync to backend when auth/backend persistence is ready.
5. Share the workbook to an article, team blog, community thread, or private message.

## Python Lab goals

The Python Lab should eventually be a sandboxed notebook environment inside Sports Terminal. It should not be a generic coding editor. It should have first-class helpers for loading Sports Terminal data and exporting results back into product surfaces.

## Python helper API roadmap

| Helper | Purpose |
| --- | --- |
| `st.load_table("player_season_totals")` | Load product tables into dataframes. |
| `st.query_players("PPG > 15 AND RPG < 4")` | Reuse the NBA Stats query layer. |
| `st.plot_bar(...)` / `st.plot_line(...)` | Create chart blocks. |
| `st.export_to_workspace(df, sheet="...")` | Send Python output into the workbook. |
| `st.attach_to_article(chart_id)` | Embed charts into articles/blogs. |
| `st.share_to_thread(object_id)` | Turn notebook results into discussion objects. |

## Safety and launch requirements

Public Python execution must be sandboxed, quota-limited, and isolated. The launch-safe version should start with static examples and local editor state. Real execution should come later through Pyodide in-browser or a locked-down backend kernel with no arbitrary network access, no secrets exposure, execution timeouts, memory limits, and export controls.
