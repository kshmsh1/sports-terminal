from __future__ import annotations

from pathlib import Path

MAIN = Path('backend/app/main_launch.py')
SHELL = Path('lib/widgets/connected_role_terminal_shell.dart')
WORKFLOW = Path('.github/workflows/flutter_quality.yml')
AWARDS_TEST = Path('backend/scripts/nba_awards_contract_test.py')
PROFILE = Path('lib/screens/product_profile_persisted_screen.dart')
OWN_WORKFLOW = Path('.github/workflows/finalize_platform_expansion_v3.yml')
SELF = Path('tools/finalize_platform_expansion_v3.py')

main = MAIN.read_text(encoding='utf-8')
if 'from .profile_api import router as profile_router' not in main:
    anchor = 'from .python_runtime_api import router as python_runtime_router\n'
    if anchor not in main:
        raise SystemExit('profile import anchor missing')
    main = main.replace(anchor, 'from .profile_api import router as profile_router\n' + anchor, 1)
if 'app.include_router(profile_router)' not in main:
    anchor = 'app.include_router(community_router)\napp.include_router(python_runtime_router)'
    if anchor not in main:
        raise SystemExit('profile mount anchor missing')
    main = main.replace(anchor, 'app.include_router(community_router)\napp.include_router(profile_router)\napp.include_router(python_runtime_router)', 1)
if 'app.version = "1.8.0"' in main:
    main = main.replace('app.version = "1.8.0"', 'app.version = "1.9.0"', 1)
MAIN.write_text(main, encoding='utf-8')

shell = SHELL.read_text(encoding='utf-8')
if "import '../screens/product_profile_v3_screen.dart';" not in shell:
    anchor = "import '../screens/product_profile_persisted_screen.dart';\n"
    if anchor in shell:
        shell = shell.replace(anchor, "import '../screens/product_profile_v3_screen.dart';\n", 1)
    else:
        anchor = "import '../screens/product_platform_content_legal_screen.dart';\n"
        if anchor not in shell:
            raise SystemExit('profile shell import anchor missing')
        shell = shell.replace(anchor, anchor + "import '../screens/product_profile_v3_screen.dart';\n", 1)
shell = shell.replace(
    'screen: ProductPersistedProfileScreen(session: widget.session),',
    'screen: ProductProfileV3Screen(session: widget.session),',
)
SHELL.write_text(shell, encoding='utf-8')

workflow = WORKFLOW.read_text(encoding='utf-8')
if 'Test durable Sports Terminal profile contract' not in workflow:
    anchor = "      - name: Test unified NBA terminal contract\n        run: python backend/scripts/nba_terminal_contract_test.py\n"
    block = """      - name: Test durable Sports Terminal profile contract
        run: python backend/scripts/profile_contract_test.py

"""
    if anchor not in workflow:
        raise SystemExit('profile CI anchor missing')
    workflow = workflow.replace(anchor, block + anchor, 1)
if 'Audit page scroll ownership' not in workflow:
    anchor = "      - name: Set up Flutter\n"
    block = """      - name: Audit page scroll ownership
        run: python tools/audit_page_scroll_ownership.py

"""
    if anchor not in workflow:
        raise SystemExit('scroll audit CI anchor missing')
    workflow = workflow.replace(anchor, block + anchor, 1)
WORKFLOW.write_text(workflow, encoding='utf-8')

awards = AWARDS_TEST.read_text(encoding='utf-8')
if 'import sys\n' not in awards:
    awards = awards.replace('import sqlite3\n', 'import sqlite3\nimport sys\n', 1)
if "sys.path.insert(0, str(Path(__file__).resolve().parents[1]))" not in awards:
    anchor = 'from pathlib import Path\n\n\n'
    if anchor not in awards:
        raise SystemExit('awards sys.path anchor missing')
    awards = awards.replace(
        anchor,
        "from pathlib import Path\n\n\nsys.path.insert(0, str(Path(__file__).resolve().parents[1]))\n\n\n",
        1,
    )
AWARDS_TEST.write_text(awards, encoding='utf-8')

profile = PROFILE.read_text(encoding='utf-8')
if 'class _ReputationBadges extends StatelessWidget' not in profile:
    anchor = '\nclass _Card extends StatelessWidget {'
    if anchor not in profile:
        raise SystemExit('profile badge anchor missing')
    widget = r'''
class _ReputationBadges extends StatelessWidget {
  const _ReputationBadges({
    required this.future,
    required this.favoriteTeams,
    required this.favoritePlayers,
    required this.publicProfile,
  });

  final Future<Map<String, dynamic>?> future;
  final int favoriteTeams;
  final int favoritePlayers;
  final bool publicProfile;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: future,
      builder: (context, snapshot) {
        final payload = snapshot.data;
        final raw = payload?['reputation'];
        final reputation = raw is Map ? raw : const {};
        final badges = reputation['badges'];
        final score = reputation['reputation'] ?? 0;
        return Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            _Badge('REP $score', Icons.bolt_rounded, _blue),
            if (favoriteTeams > 0)
              const _Badge('TEAM LOYALIST', Icons.favorite_rounded, _green),
            if (favoritePlayers >= 5)
              const _Badge('SCOUT', Icons.visibility_rounded, _blue),
            if (publicProfile)
              const _Badge('PUBLIC PROFILE', Icons.public_rounded, _amber),
            if (badges is List)
              for (final badge in badges.take(4))
                _Badge(
                  '$badge'.toUpperCase(),
                  Icons.verified_rounded,
                  _green,
                ),
          ],
        );
      },
    );
  }
}
'''
    profile = profile.replace(anchor, '\n' + widget + anchor, 1)
PROFILE.write_text(profile, encoding='utf-8')

for path in (OWN_WORKFLOW, SELF):
    if path.exists():
        path.unlink()
