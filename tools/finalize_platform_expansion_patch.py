from __future__ import annotations

from pathlib import Path

COMMUNITY = Path('lib/screens/product_community_v2_screen.dart')
WORKFLOW = Path('.github/workflows/finalize_platform_expansion.yml')
SELF = Path('tools/finalize_platform_expansion_patch.py')

text = COMMUNITY.read_text(encoding='utf-8')
old_init = """  @override
  void initState() {
    super.initState();
    final slugs = widget.boards.map((item) => '${item['slug']}').toSet();
"""
new_init = """  @override
  void initState() {
    super.initState();
    title.addListener(_refreshValidity);
    body.addListener(_refreshValidity);
    final slugs = widget.boards.map((item) => '${item['slug']}').toSet();
"""
if old_init not in text:
    raise SystemExit('community composer initState signature not found')
text = text.replace(old_init, new_init, 1)
old_dispose = """  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }
"""
new_dispose = """  void _refreshValidity() {
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
if old_dispose not in text:
    raise SystemExit('community composer dispose signature not found')
text = text.replace(old_dispose, new_dispose, 1)
COMMUNITY.write_text(text, encoding='utf-8')

# The workflow and transformer are intentionally one-shot and are removed from
# the branch by the same commit that contains the durable product fix.
for path in (WORKFLOW, SELF):
    if path.exists():
        path.unlink()
