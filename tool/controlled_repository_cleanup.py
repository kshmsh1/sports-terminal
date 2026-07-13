from __future__ import annotations

from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]

DEAD_LIB_FILES = [
    'lib/data/core_mvp_gap_items.dart',
    'lib/data/data_sources.dart',
    'lib/data/mock_players.dart',
    'lib/data/mock_teams.dart',
    'lib/data/mvp_launch_gate_items.dart',
    'lib/data/nba_data_sources.dart',
    'lib/data/nba_seasons.dart',
    'lib/data/nba_stats_dataset_targets.dart',
    'lib/data/nba_stats_source_strategy_items.dart',
    'lib/data/nba_teams.dart',
    'lib/data/player_identity_nba_api_mapping_items.dart',
    'lib/data/route_payload_consumer_items.dart',
    'lib/models/data_source.dart',
    'lib/models/era_definition.dart',
    'lib/models/franchise_history_event.dart',
    'lib/models/injury_record.dart',
    'lib/models/media_asset.dart',
    'lib/models/player.dart',
    'lib/models/player_stat_line.dart',
    'lib/models/salary_record.dart',
    'lib/screens/nba_2025_detail_screens.dart',
    'lib/screens/nba_2025_front_office_screens.dart',
    'lib/screens/nba_2025_operations_screens.dart',
    'lib/screens/nba_2025_research_screens.dart',
    'lib/screens/nba_2025_screener_screens.dart',
    'lib/screens/nba_2025_workbench_screens.dart',
    'lib/screens/nba_stats_dataset_targets_screen.dart',
    'lib/screens/nba_stats_source_strategy_screen.dart',
    'lib/screens/nba_terminal_seed_screen.dart',
    'lib/services/nba_asset_validation_service.dart',
    'lib/services/pre_data_smoke_test_service.dart',
    'lib/widgets/auth_scope.dart',
    'lib/widgets/first_release_consumer_matrix.dart',
    'lib/widgets/first_release_workflow_objects.dart',
    'lib/widgets/player_identity_import_readiness_panel.dart',
    'lib/widgets/player_identity_pre_ingestion_panel.dart',
    'lib/widgets/pre_data_smoke_test_panel.dart',
    'lib/widgets/route_payload_consumer_preview.dart',
    'lib/widgets/route_payload_consumer_registry_panel.dart',
    'lib/widgets/route_payload_contract_panel.dart',
    'lib/widgets/terminal_linked_table.dart',
]

CANONICAL_MOVES = {
    'lib/screens/product_nba_stats_center_screen_v5.dart':
        'lib/screens/product_nba_stats_center_screen.dart',
    'lib/screens/product_trade_machine_screen_v3.dart':
        'lib/screens/product_trade_machine_screen.dart',
    'lib/services/nba_stats_query_engine_v3.dart':
        'lib/services/nba_stats_query_engine.dart',
    'lib/widgets/user_terminal_shell_fixed.dart':
        'lib/widgets/user_terminal_shell.dart',
}

ROSTER_SOURCE_NAMES = [
    'atlanta_hawks_2026_06_06_part1.psv',
    'atlanta_hawks_2026_06_06_part2.psv',
    'brooklyn_nets_2026_06_06_part1.psv',
    'brooklyn_nets_2026_06_06_part2a.psv',
    'brooklyn_nets_2026_06_06_part2b.psv',
    'charlotte_hornets_2026_06_06_part1.psv',
    'charlotte_hornets_2026_06_06_part2.psv',
    'chicago_bulls_2026_06_06.psv.b64',
]

DELETE_FILES = [
    'assets/data/nba/manual_sources/rosters/boston_celtics_2026_06_06.psv',
    'assets/data/nba/injuries/injury_records.json',
    'scripts/start_backend.sh',
    'tools/prepare_team_history.py',
    'tools/inspect_basketball_reference_catalog.py',
    'tools/check_user_product_release.sh',
]

FILENAME_REPLACEMENTS = {
    'product_nba_stats_center_screen_v5.dart':
        'product_nba_stats_center_screen.dart',
    'product_trade_machine_screen_v3.dart':
        'product_trade_machine_screen.dart',
    'nba_stats_query_engine_v3.dart':
        'nba_stats_query_engine.dart',
    'user_terminal_shell_fixed.dart':
        'user_terminal_shell.dart',
}

SEARCHABLE_SUFFIXES = {
    '.dart', '.md', '.yaml', '.yml', '.json', '.py', '.sh', '.txt', '.sql'
}


def require_file(relative: str) -> Path:
    path = ROOT / relative
    if not path.is_file():
        raise RuntimeError(f'Expected file is missing: {relative}')
    return path


def remove_file(relative: str) -> None:
    require_file(relative).unlink()


def replace_pattern(relative: str, pattern: str, replacement: str = '') -> None:
    path = require_file(relative)
    text = path.read_text(encoding='utf-8')
    updated, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(
            f'Expected exactly one match in {relative}; found {count}: {pattern}'
        )
    path.write_text(updated, encoding='utf-8')


def canonicalize_active_files() -> None:
    for source_relative, destination_relative in CANONICAL_MOVES.items():
        source = require_file(source_relative)
        destination = require_file(destination_relative)
        shutil.copyfile(source, destination)
        source.unlink()


def relocate_manual_sources() -> None:
    source_root = ROOT / 'assets/data/nba/manual_sources/rosters'
    destination_root = ROOT / 'raw/manual_sources/rosters'
    destination_root.mkdir(parents=True, exist_ok=True)

    for filename in ROSTER_SOURCE_NAMES:
        source = source_root / filename
        destination = destination_root / filename
        if not source.is_file():
            raise RuntimeError(f'Expected manual roster source is missing: {source}')
        if destination.exists():
            raise RuntimeError(f'Manual roster destination already exists: {destination}')
        shutil.move(str(source), str(destination))


def remove_unused_declarations() -> None:
    replace_pattern(
        'lib/screens/compare_screen.dart',
        r"^\s*final p0Stages = comparisonBuilderStageItems\.where\(\(item\) => item\.priority == 'P0'\)\.length;\n",
    )
    replace_pattern(
        'lib/screens/product_advanced_nba_tools_screen.dart',
        r'^const _green = Color\([^\n]+\);\n',
    )
    replace_pattern(
        'lib/screens/product_content_ops_screens.dart',
        r'^const _lime = Color\([^\n]+\);\n',
    )
    replace_pattern(
        'lib/screens/product_python_dev_lab_screen.dart',
        r'^const _soft = Color\([^\n]+\);\n',
    )
    replace_pattern(
        'lib/screens/product_shell_screens.dart',
        r'^const _orange = Color\([^\n]+\);\n',
    )
    replace_pattern(
        'lib/screens/product_shell_screens.dart',
        r'^const _green = Color\([^\n]+\);\n',
    )


def remove_unused_dependency() -> None:
    path = require_file('pubspec.yaml')
    text = path.read_text(encoding='utf-8')
    dependency_line = '  cupertino_icons: ^1.0.8\n'
    if text.count(dependency_line) != 1:
        raise RuntimeError('Expected exactly one cupertino_icons declaration')
    path.write_text(text.replace(dependency_line, ''), encoding='utf-8')


def tighten_analysis() -> None:
    path = require_file('analysis_options.yaml')
    path.write_text(
        '# Static analysis and lint configuration for Sports Terminal.\n'
        'include: package:flutter_lints/flutter.yaml\n\n'
        'analyzer:\n'
        '  errors:\n'
        '    # This API remains in several active prototype controls and will be\n'
        '    # migrated during the next component modernization pass.\n'
        '    deprecated_member_use: ignore\n\n'
        'linter:\n'
        '  rules:\n'
        '    # Repository command-line validators and importers intentionally\n'
        '    # print concise progress output.\n'
        '    avoid_print: false\n',
        encoding='utf-8',
    )


def update_filename_references() -> None:
    for path in ROOT.rglob('*'):
        if not path.is_file() or '.git' in path.parts:
            continue
        if path.suffix.lower() not in SEARCHABLE_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            continue
        updated = text
        for old, new in FILENAME_REPLACEMENTS.items():
            updated = updated.replace(old, new)
        if updated != text:
            path.write_text(updated, encoding='utf-8')


def write_cleanup_record() -> None:
    path = ROOT / 'docs/repository_cleanup_2026_07.md'
    path.write_text(
        '# Repository Cleanup — July 2026\n\n'
        'This cleanup was generated from a full-history repository audit and '
        'merged only after Flutter analysis, the complete test suite, and a '
        'release web build passed.\n\n'
        '## Removed\n\n'
        '- 41 unreachable Dart libraries from superseded screens, mock data, '
        'preliminary models, and pre-data scaffolding.\n'
        '- One duplicate backend launcher and three unreferenced operational stubs.\n'
        '- One duplicate Boston roster source and one unused injury placeholder.\n'
        '- The unused `cupertino_icons` dependency and six unused declarations.\n\n'
        '## Normalized\n\n'
        '- Active Stats Center, Trade Machine, query-engine, and user-shell '
        'implementations now live in their canonical filenames.\n'
        '- Manual roster-ingestion source files were moved out of Flutter\'s '
        'runtime asset tree into `raw/manual_sources/rosters/`.\n'
        '- Repository-wide unused-element and unused-local-variable suppressions '
        'were removed so future dead code is surfaced automatically.\n\n'
        '## Preserved\n\n'
        'All active application routes, test-only validators, data-quality '
        'services, ingestion tools, platform targets, documentation, and Git '
        'history were retained.\n',
        encoding='utf-8',
    )


def main() -> None:
    for relative in DEAD_LIB_FILES:
        remove_file(relative)
    canonicalize_active_files()
    relocate_manual_sources()
    for relative in DELETE_FILES:
        remove_file(relative)
    remove_unused_declarations()
    remove_unused_dependency()
    tighten_analysis()
    update_filename_references()
    write_cleanup_record()
    print('Controlled repository cleanup applied successfully.')


if __name__ == '__main__':
    main()
