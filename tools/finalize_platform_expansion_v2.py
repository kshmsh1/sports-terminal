from __future__ import annotations

from pathlib import Path

MAIN = Path('backend/app/main_launch.py')
COMMUNITY = Path('lib/screens/product_community_v2_screen.dart')
WORKFLOW = Path('.github/workflows/finalize_platform_expansion_v2.yml')
SELF = Path('tools/finalize_platform_expansion_v2.py')

main = MAIN.read_text(encoding='utf-8')
if 'from .profile_api import router as profile_router' not in main:
    anchor = 'from .python_runtime_api import router as python_runtime_router\n'
    if anchor not in main:
        raise SystemExit('profile import anchor not found')
    main = main.replace(anchor, 'from .profile_api import router as profile_router\n' + anchor, 1)
if 'app.include_router(profile_router)' not in main:
    anchor = 'app.include_router(community_router)\napp.include_router(python_runtime_router)'
    if anchor not in main:
        raise SystemExit('profile router mount anchor not found')
    main = main.replace(anchor, 'app.include_router(community_router)\napp.include_router(profile_router)\napp.include_router(python_runtime_router)', 1)
main = main.replace('app.version = "1.8.0"', 'app.version = "1.9.0"')
MAIN.write_text(main, encoding='utf-8')

community = COMMUNITY.read_text(encoding='utf-8')
if 'title.addListener(_refreshValidity);' not in community:
    old = """  @override
  void initState() {
    super.initState();
    final slugs = widget.boards.map((item) => '${item['slug']}').toSet();
"""
    new = """  @override
  void initState() {
    super.initState();
    title.addListener(_refreshValidity);
    body.addListener(_refreshValidity);
    final slugs = widget.boards.map((item) => '${item['slug']}').toSet();
"""
    if old not in community:
        raise SystemExit('community initState anchor not found')
    community = community.replace(old, new, 1)
if 'void _refreshValidity()' not in community:
    old = """  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }
"""
    new = """  void _refreshValidity() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    title.removeListener(_refreshValidity);
    body.removeListener(_refreshValidity);
    title.dispose();
    body.dispose();
    super.dispose();
  }
"""
    if old not in community:
        raise SystemExit('community dispose anchor not found')
    community = community.replace(old, new, 1)
COMMUNITY.write_text(community, encoding='utf-8')

for path in (WORKFLOW, SELF):
    if path.exists():
        path.unlink()
