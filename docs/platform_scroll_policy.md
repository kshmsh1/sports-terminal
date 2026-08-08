# Sports Terminal page scrolling contract

Sports Terminal uses one primary vertical document scroll per top-level product page.

The role shell owns vertical page scrolling. A top-level destination should therefore render document-flow content (`Column`, `Wrap`, `Table`, bounded cards, responsive rows) rather than a second full-page `ListView`, `CustomScrollView`, `SingleChildScrollView`, `Scrollable` or `Expanded` whose height depends on an internal vertical viewport.

Internal scrolling remains appropriate only when it represents a distinct object rather than the page itself, including horizontal data-table overflow, a bounded code editor, a modal/legal reader, a chat transcript, a deliberately virtualized massive dataset with its own explicit viewport, or a compact carousel/rail. Those exceptions must not produce a second page-length scrollbar beside the shell scrollbar.

New product surfaces in the August 2026 expansion follow this policy directly: Basic Stats, Advanced Stats, NBA Hub, Awards & Voting, Trade Machine, Team Blogs, Community, Profile, Articles and Python Lab. Player and team dossiers are standalone full-screen routes and therefore own their route-level scroll when opened.

When older destination screens are modernized, their page-level scrolling should be removed in favor of this same shell-owned document-flow contract.