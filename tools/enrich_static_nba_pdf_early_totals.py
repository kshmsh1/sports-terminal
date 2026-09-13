from __future__ import annotations

import argparse
import base64
import csv
import gzip
import io
import json
import hashlib
from collections import defaultdict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / 'web/data/nba_static'
REFERENCE = ROOT / 'data/reference/nba_regular_totals_1946_49.csv.gz.b64'
MIN_PLAYER_LEADER_GAMES = 50
SOURCE_LABEL = 'User-provided regular-season totals PDFs (Basketball Reference export)'

STAT_MAP = {
    'games': 'games',
    'games_started': 'games_started',
    'minutes': 'minutes',
    'field_goals_made': 'field_goals_made',
    'field_goal_attempts': 'field_goal_attempts',
    'field_goal_pct': 'field_goal_percentage',
    'three_pointers_made': 'three_pointers_made',
    'three_point_attempts': 'three_point_attempts',
    'three_point_pct': 'three_point_percentage',
    'two_pointers_made': 'two_pointers_made',
    'two_point_attempts': 'two_point_attempts',
    'two_point_pct': 'two_point_percentage',
    'efg_pct': 'effective_field_goal_percentage',
    'free_throws_made': 'free_throws_made',
    'free_throw_attempts': 'free_throw_attempts',
    'free_throw_pct': 'free_throw_percentage',
    'offensive_rebounds': 'offensive_rebounds',
    'defensive_rebounds': 'defensive_rebounds',
    'rebounds': 'rebounds',
    'assists': 'assists',
    'steals': 'steals',
    'blocks': 'blocks',
    'turnovers': 'turnovers',
    'personal_fouls': 'personal_fouls',
    'points': 'points',
    'age': 'age',
}
LEADER_METRICS = {
    'points': 'ppg',
    'rebounds': 'rpg',
    'assists': 'apg',
    'steals': 'spg',
    'blocks': 'bpg',
    'deflections': 'deflections_pg',
    'personal_fouls': 'pfpg',
    'turnovers': 'tpg',
    'three_pointers_made': 'three_pmg',
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Apply the user-provided early NBA regular-season totals supplement and rebuild qualified dashboard leaders.'
    )
    parser.add_argument('--output', default=str(DEFAULT_OUTPUT))
    return parser.parse_args()


def number(value: Any) -> float | None:
    if value is None or value == '':
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).strip())
    except (TypeError, ValueError):
        return None


def compact(value: Any) -> int | float | None:
    value = number(value)
    if value is None:
        return None
    return int(value) if value.is_integer() else value


def short_season(full: str) -> str:
    start = int(full[:4])
    return f'{start:04d}-{(start + 1) % 100:02d}'


def read_reference() -> dict[str, list[dict[str, Any]]]:
    if not REFERENCE.is_file():
        raise SystemExit(f'Committed NBA PDF supplement is missing: {REFERENCE}')
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    compressed = base64.b64decode(REFERENCE.read_text(encoding='ascii'))
    text = gzip.decompress(compressed).decode('utf-8')
    with io.StringIO(text, newline='') as handle:
        for raw in csv.DictReader(handle):
            season = short_season(str(raw.get('season_id') or ''))
            row: dict[str, Any] = {
                'season_id': season,
                'player_name': str(raw.get('player_name') or '').strip(),
                'bref_id': str(raw.get('bref_id') or '').strip(),
                'team': str(raw.get('team') or '').strip(),
                'position': str(raw.get('position') or '').strip(),
            }
            for source in STAT_MAP:
                value = compact(raw.get(source))
                if value is not None:
                    row[source] = value
            grouped[season].append(row)
    expected = {'1946-47', '1947-48', '1948-49'}
    if set(grouped) != expected:
        raise SystemExit(f'NBA PDF supplement coverage mismatch: expected={sorted(expected)} actual={sorted(grouped)}')
    return dict(grouped)


def seed_row(ref: dict[str, Any]) -> dict[str, Any]:
    pid = f"bref:{ref['bref_id']}"
    row: dict[str, Any] = {
        'player_id': pid,
        'id': pid,
        'player_label': ref['player_name'],
        'player_name': ref['player_name'],
        'team_ids': ref.get('team') or '',
        'position': ref.get('position') or '',
        'season_type': 'regular',
        'bref_id': ref['bref_id'],
        'primary_source': 'user_pdf_regular_totals',
        'pdf_reference_source': SOURCE_LABEL,
    }
    for source, target in STAT_MAP.items():
        if source in ref:
            row[target] = ref[source]
    # Direct aliases make the source values explicit while the stats engine can
    # still transparently derive TS%, eFG%, 2P%, rates and possession proxies.
    for source, target in (
        ('field_goal_pct', 'fg_pct'),
        ('three_point_pct', 'three_point_pct'),
        ('two_point_pct', 'two_pct'),
        ('efg_pct', 'efg_pct'),
        ('free_throw_pct', 'ft_pct'),
    ):
        if source in ref:
            row[target] = ref[source]
    return row


def empty_snapshot(season: str, refs: list[dict[str, Any]]) -> dict[str, Any]:
    totals = [seed_row(row) for row in refs]
    players = [
        {
            'player_id': row['player_id'],
            'id': row['player_id'],
            'player_name': row['player_name'],
            'display_name': row['player_name'],
            'position': row.get('position') or '',
            'team_abbreviation': row.get('team_ids') or '',
            'bref_id': row.get('bref_id'),
            'age': row.get('age'),
            'primary_source': 'user_pdf_regular_totals',
        }
        for row in totals
    ]
    return {
        'manifest': {
            'league': 'NBA',
            'season': season,
            'seasonType': 'regular',
            'datasetStatus': 'historical-pdf-supplement',
        },
        'teams': [],
        'players': players,
        'games': [],
        'team_records': [],
        'team_game_logs': [],
        'player_season_totals': totals,
        'player_leaders': {},
        'player_game_highs': {},
        'player_game_logs_top': [],
        'search_index': [],
        'data_dictionary': {},
        'standings': [],
        'play_by_play': [],
        'season_id': season,
        'season_type': 'regular',
        'static_data': True,
        'pdf_regular_totals_enrichment': {
            'source': SOURCE_LABEL,
            'reference_rows': len(refs),
        },
    }


def per_game(row: dict[str, Any], total_key: str, direct_key: str | None = None) -> float | None:
    if direct_key:
        direct = number(row.get(direct_key))
        if direct is not None:
            return direct
    games = number(row.get('games') or row.get('gp'))
    total = number(row.get(total_key))
    if games is None or games <= 0 or total is None:
        return None
    return total / games


def dashboard_player(row: dict[str, Any]) -> dict[str, Any]:
    return {
        'player_id': row.get('player_id') or row.get('id'),
        'player_name': row.get('player_name') or row.get('player_label'),
        'team_id': row.get('team_id'),
        'team': row.get('team_ids') or row.get('team') or '',
        'position': row.get('position') or '',
        'games': row.get('games'),
        'ppg': per_game(row, 'points', 'ppg'),
        'rpg': per_game(row, 'rebounds', 'rpg'),
        'apg': per_game(row, 'assists', 'apg'),
        'spg': per_game(row, 'steals', 'spg'),
        'bpg': per_game(row, 'blocks', 'bpg'),
        'tpg': per_game(row, 'turnovers', 'tov_per_game'),
        'pfpg': per_game(row, 'personal_fouls', 'pf_per_game'),
        'three_pmg': per_game(row, 'three_pointers_made', 'three_pm_per_game'),
        'deflections_pg': per_game(row, 'deflections', 'deflections_pg'),
    }


def qualified_leaders(players: list[dict[str, Any]], metric: str) -> list[dict[str, Any]]:
    eligible = [
        row
        for row in players
        if (number(row.get('games')) or 0) >= MIN_PLAYER_LEADER_GAMES
        and number(row.get(metric)) is not None
    ]
    eligible.sort(key=lambda row: float(number(row.get(metric)) or 0), reverse=True)
    return [
        {
            'rank': index,
            'value': row.get(metric),
            'player_id': row.get('player_id'),
            'player_name': row.get('player_name'),
            'team_id': row.get('team_id'),
            'team': row.get('team'),
            'position': row.get('position'),
        }
        for index, row in enumerate(eligible[:10], start=1)
    ]


def rebuild_dashboard(output: Path, season: str) -> bool:
    regular_path = output / 'seasons' / season / 'regular.json'
    if not regular_path.is_file():
        return False
    snapshot = json.loads(regular_path.read_text(encoding='utf-8'))
    raw = [row for row in snapshot.get('player_season_totals', []) if isinstance(row, dict)]
    players = [dashboard_player(row) for row in raw if row.get('player_id') or row.get('id')]
    players.sort(key=lambda row: str(row.get('player_name') or ''))
    dashboard_path = output / 'dashboard' / f'{season}.json'
    if dashboard_path.is_file():
        try:
            dashboard = json.loads(dashboard_path.read_text(encoding='utf-8'))
        except json.JSONDecodeError:
            dashboard = {}
    else:
        dashboard = {}
    dashboard.update(
        {
            'contract': 'sports-terminal-static-dashboard-v2',
            'season_id': season,
            'season_type': 'regular',
            'players': players,
            'leaders': {
                name: qualified_leaders(players, metric)
                for name, metric in LEADER_METRICS.items()
            },
            'runtime_api_required': False,
            'player_leader_min_games': MIN_PLAYER_LEADER_GAMES,
        }
    )
    dashboard.setdefault('teams', snapshot.get('teams', []))
    dashboard.setdefault('team_records', snapshot.get('team_records', []))
    dashboard.setdefault('team_leaders', {})
    dashboard.setdefault('recent_games', [])
    write_json(dashboard_path, dashboard)
    return True


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    temp.replace(path)


def player_file_token(value: str) -> str:
    return hashlib.sha1(value.encode('utf-8')).hexdigest()[:24]


def materialize_player_entities(output: Path, reference: dict[str, list[dict[str, Any]]]) -> dict[str, str]:
    index_path = output / 'players' / 'index.json'
    existing = json.loads(index_path.read_text(encoding='utf-8')) if index_path.is_file() else []
    rows = [row for row in existing if isinstance(row, dict)]
    by_bref = {str(row.get('bref_id') or ''): row for row in rows if row.get('bref_id')}
    by_key = {str(row.get('player_key') or ''): row for row in rows if row.get('player_key')}
    refs_by_bref: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for season_rows in reference.values():
        for ref in season_rows:
            if ref.get('bref_id'):
                refs_by_bref[str(ref['bref_id'])].append(ref)

    key_for_bref: dict[str, str] = {}
    for bref_id, refs in refs_by_bref.items():
        existing_row = by_bref.get(bref_id)
        key = str(existing_row.get('player_key')) if existing_row else f'bref:{bref_id}'
        key_for_bref[bref_id] = key
        seasons = sorted({str(ref['season_id']) for ref in refs})
        name = str(refs[0].get('player_name') or bref_id)
        positions = [str(ref.get('position') or '') for ref in refs if ref.get('position')]
        file = str(existing_row.get('file') or '') if existing_row else f'players/{player_file_token(key)}.json'
        if not file:
            file = f'players/{player_file_token(key)}.json'
        if existing_row is None:
            index_row = {
                'player_key': key, 'canonical_name': name, 'primary_position': positions[-1] if positions else '',
                'nba_id': None, 'bref_id': bref_id, 'active_from': seasons[0], 'active_to': seasons[-1],
                'first_season': short_season(seasons[0]), 'last_season': short_season(seasons[-1]),
                'seasons': len(seasons), 'file': file, 'supplemental_source': SOURCE_LABEL,
            }
            rows.append(index_row)
            by_key[key] = index_row
        else:
            earliest = min([short_season(seasons[0]), str(existing_row.get('first_season') or '9999-99')])
            existing_row['first_season'] = earliest
            existing_row['active_from'] = min([seasons[0], str(existing_row.get('active_from') or '9999-9999')])
            existing_row['supplemental_source'] = SOURCE_LABEL

        dossier_path = output / file
        if dossier_path.is_file():
            try:
                dossier = json.loads(dossier_path.read_text(encoding='utf-8'))
            except json.JSONDecodeError:
                dossier = {}
        else:
            dossier = {}
        existing_seasons = [row for row in dossier.get('seasons', []) if isinstance(row, dict)]
        existing_regular = [row for row in dossier.get('regular_seasons', []) if isinstance(row, dict)]
        seen = {(str(row.get('season_id') or ''), str(row.get('team_abbreviation') or row.get('team_ids') or '')) for row in existing_regular}
        added = []
        for ref in sorted(refs, key=lambda item: str(item['season_id'])):
            seeded = seed_row({**ref, 'bref_id': bref_id})
            seeded['season_id'] = short_season(str(ref['season_id']))
            seeded['player_key'] = key
            seeded['player_id'] = key
            seeded['id'] = key
            identity = (seeded['season_id'], str(seeded.get('team_ids') or ''))
            if identity not in seen:
                added.append(seeded)
                seen.add(identity)
        all_seasons = sorted([*existing_seasons, *added], key=lambda row: (str(row.get('season_id') or ''), str(row.get('season_type') or '')))
        regular_seasons = sorted([*existing_regular, *added], key=lambda row: str(row.get('season_id') or ''))
        dossier.update({
            'kind': 'player',
            'profile': dossier.get('profile') or {
                'player_key': key, 'canonical_name': name, 'primary_position': positions[-1] if positions else '',
                'bref_id': bref_id, 'active_from': seasons[0], 'active_to': seasons[-1],
                'primary_source': 'user_pdf_regular_totals',
            },
            'seasons': all_seasons, 'regular_seasons': regular_seasons,
            'playoff_seasons': dossier.get('playoff_seasons') or [],
            'awards': dossier.get('awards') or [], 'all_star': dossier.get('all_star') or [],
            'draft': dossier.get('draft') or [], 'recent_games': dossier.get('recent_games') or [],
            'static_data': True,
            'pdf_regular_totals_enrichment': {'source': SOURCE_LABEL, 'added_regular_seasons': len(added)},
        })
        dossier['summary'] = {
            **(dossier.get('summary') if isinstance(dossier.get('summary'), dict) else {}),
            'season_rows': len(all_seasons), 'regular_seasons': len({str(row.get('season_id')) for row in regular_seasons}),
            'playoff_seasons': len({str(row.get('season_id')) for row in dossier.get('playoff_seasons', []) if isinstance(row, dict)}),
        }
        write_json(dossier_path, dossier)
    rows.sort(key=lambda row: str(row.get('canonical_name') or ''))
    write_json(index_path, rows)
    return key_for_bref


def main() -> int:
    args = parse_args()
    output = Path(args.output).expanduser().resolve()
    if not output.is_dir():
        raise SystemExit(f'Static NBA corpus is missing: {output}')

    reference = read_reference()
    key_for_bref = materialize_player_entities(output, reference)
    seasons_path = output / 'seasons.json'
    seasons = json.loads(seasons_path.read_text(encoding='utf-8')) if seasons_path.is_file() else []
    by_id = {str(row.get('season_id') or ''): row for row in seasons if isinstance(row, dict)}

    for season, refs in reference.items():
        year = int(season[:4])
        teams = {str(row.get('team') or '') for row in refs if row.get('team') and not str(row.get('team')).endswith('TM')}
        by_id[season] = {
            **by_id.get(season, {}),
            'season_id': season,
            'label': f'{year}-{year + 1}',
            'start_year': year,
            'end_year': year + 1,
            'source_season_id': season,
            'players': len(refs),
            'teams': len(teams),
            'games': int(by_id.get(season, {}).get('games') or 0),
            'supplemental_source': SOURCE_LABEL,
        }
        snapshot = empty_snapshot(season, refs)
        for row in snapshot['player_season_totals']:
            bref_id = str(row.get('bref_id') or '')
            if bref_id in key_for_bref:
                row['player_id'] = key_for_bref[bref_id]
                row['id'] = key_for_bref[bref_id]
        for row in snapshot['players']:
            bref_id = str(row.get('bref_id') or '')
            if bref_id in key_for_bref:
                row['player_id'] = key_for_bref[bref_id]
                row['id'] = key_for_bref[bref_id]
        write_json(output / 'seasons' / season / 'regular.json', snapshot)
        playoffs_path = output / 'seasons' / season / 'playoffs.json'
        if not playoffs_path.is_file():
            playoffs = empty_snapshot(season, [])
            playoffs['season_type'] = 'playoffs'
            playoffs['manifest']['seasonType'] = 'playoffs'
            write_json(playoffs_path, playoffs)

    ordered = sorted(by_id.values(), key=lambda row: int(row.get('start_year') or 0), reverse=True)
    write_json(seasons_path, ordered)

    rebuilt = 0
    for season in [str(row.get('season_id') or '') for row in ordered]:
        if season and rebuild_dashboard(output, season):
            rebuilt += 1

    manifest_path = output / 'manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.is_file() else {}
    manifest['season_count'] = len(ordered)
    manifest['known_missing_seasons'] = []
    manifest['pdf_regular_totals_reference'] = {
        'source': SOURCE_LABEL,
        'supplemented_seasons': sorted(reference),
        'reference_rows': sum(len(rows) for rows in reference.values()),
        'leader_min_games': MIN_PLAYER_LEADER_GAMES,
        'network_requests': 0,
    }
    write_json(manifest_path, manifest)

    print(
        json.dumps(
            {
                'contract': 'sports-terminal-pdf-regular-totals-enrichment-v1',
                'supplemented_seasons': sorted(reference),
                'reference_rows': sum(len(rows) for rows in reference.values()),
                'dashboard_seasons_rebuilt': rebuilt,
                'player_leader_min_games': MIN_PLAYER_LEADER_GAMES,
                'network_requests': 0,
            },
            indent=2,
        )
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
