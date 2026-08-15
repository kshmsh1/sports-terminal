# Sports Terminal Traditional Website UX Reset

## Decision

The default Sports Terminal customer experience is now a conventional responsive website rather than a permanently visible Bloomberg-style terminal frame.

The underlying canonical object graph, analytics engines, Research Objects, Boards, Metric and Model registries, rights envelopes, source audit, query continuity, Python runtime and spreadsheet workspace are preserved. The reset changes how those capabilities are exposed to users; it does not discard the underlying product work.

## Default information architecture

Primary navigation is intentionally limited to six destinations:

1. Home
2. NBA
3. Stats
4. Analytics
5. Trade Machine
6. Front Office

Secondary customer features live under one More menu. Research is a secondary destination instead of a permanent floating layer. Account controls are grouped in the account menu.

Python Lab and spreadsheet/Excel-style Workspace are deliberately detached from primary customer navigation. Their code and routed-data contracts remain intact for future advanced-tool packaging, but they no longer compete with basic navigation.

## Removed from the default shell

The normal authenticated website no longer mounts:

- the global Blueprint Terminal frame;
- the always-visible terminal command strip;
- SUMMARY / ANALYST / TERMINAL density controls;
- the bottom terminal status ticker;
- the floating Entity Intelligence shortcut;
- the floating Historical Intelligence shortcut;
- the floating NBA Universe shortcut;
- the floating Quick Research shortcut;
- the floating NBA Research shortcut;
- the floating NBA Terminal launcher;
- the floating Automation launcher;
- the floating launch-status chip;
- the giant shell-level page header and Quick Open control.

These systems may remain implemented internally where they still support advanced workflows, but they are not allowed to surround every page.

## Visual rules

The website shell uses one header, one page content column and conventional responsive navigation. Primary content is constrained to a readable desktop width and uses ordinary cards, lists, tables and page-level controls. Global gradients, persistent floating action stacks and duplicate navigation systems are not part of the default website.

Pages should own their own hierarchy. The global shell should not repeat a page title that the page itself already renders.

## NBA data behavior

The repository does not commit generated NBA terminal-seed JSON. A fresh checkout therefore must not expose a raw Flutter missing-asset exception as a product state.

`scripts/open_terminal.sh` now checks for an existing local validated asset seed first. If it is missing, it will reuse an existing exported seed, warehouse or raw Basketball Reference catalog when one already exists locally. It does not silently download or synthesize sports data.

If no source dataset exists, the website still launches and data-dependent pages must present a clean data-setup/unavailable state. Missing source data must never be hidden by fabricated statistics.

## Product direction

Future UI work should optimize for the behavior of a high-quality sports website first:

- obvious navigation;
- fast access to players, teams, games and statistics;
- progressively disclosed advanced tools;
- ordinary browser-friendly page hierarchy;
- minimal persistent chrome;
- no feature exposed globally merely because it exists technically.

Terminal-like workflows can return later as optional power-user modes after the core website is polished and intuitive.
