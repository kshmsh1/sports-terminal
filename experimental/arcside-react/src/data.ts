export type JsonRow = Record<string, unknown>;
export type SeasonType = 'regular' | 'playoffs';
export type RateBasis = 'perGame' | 'per36' | 'per48' | 'per75' | 'per100' | 'totals';
export interface Manifest {
  contract: string;
  static_schema_version: number;
  database_fingerprint: unknown;
  latest_season: string | null;
  season_count: number;
}
export interface Season { season_id: string; label?: string; start_year?: number; players?: number; }
export interface SeasonSnapshot {
  season_id: string;
  season_type: SeasonType;
  player_season_totals: JsonRow[];
  players: JsonRow[];
  source_season_id?: string;
}
const BASE = '/data/nba_static';
const version = 5;
export async function getJson(path: string, signal?: AbortSignal): Promise<unknown> {
  if (!/^[a-z0-9/_.-]+$/i.test(path) || path.includes('..')) throw Error('Invalid asset path');
  const res = await fetch(BASE + '/' + path, { signal, credentials: 'same-origin' });
  if (!res.ok) throw Error('Static source unavailable: ' + path + ' (' + res.status + '). Run the existing NBA static compiler first.');
  const type = res.headers.get('content-type') ?? '';
  if (!type.includes('json')) throw Error('Expected JSON at ' + path + '; received ' + type + '. Check static hosting.');
  return res.json();
}
function asObject(value: unknown): JsonRow {
  if (value === null || Array.isArray(value) || typeof value !== 'object') throw Error('Static NBA contract expected object.');
  return value as JsonRow;
}
function asRows(value: unknown, label: string): JsonRow[] {
  if (!Array.isArray(value) || value.some(x => !x || typeof x !== 'object' || Array.isArray(x))) {
    throw Error('Invalid NBA rows in ' + label);
  }
  return value as JsonRow[];
}
export async function getManifest(signal?: AbortSignal): Promise<Manifest> {
  const raw = asObject(await getJson('manifest.json', signal));
  if (raw.contract !== 'sports-terminal-static-nba-website-v5' || raw.static_schema_version !== version ||
      !raw.database_fingerprint || typeof raw.season_count !== 'number') {
    throw Error('Unsupported NBA static manifest. Expected verified v5 compiler output.');
  }
  return raw as unknown as Manifest;
}
export async function getSeasons(signal?: AbortSignal): Promise<Season[]> {
  const rows = asRows(await getJson('seasons.json', signal), 'seasons');
  return rows.map(r => {
    if (typeof r.season_id !== 'string' || !/^\d{4}-\d{2}$/.test(r.season_id)) throw Error('Malformed season ID.');
    return r as unknown as Season;
  }).sort((a,b) => b.season_id.localeCompare(a.season_id));
}
export async function getSeason(season: string, segment: SeasonType, signal?: AbortSignal): Promise<SeasonSnapshot> {
  if (!/^\d{4}-\d{2}$/.test(season)) throw Error('Invalid season.');
  const raw = asObject(await getJson('seasons/' + season + '/' + segment + '.json', signal));
  if (raw.season_id !== season || raw.season_type !== segment) throw Error('Static season ID/segment mismatch.');
  return {
    season_id: season,
    season_type: segment,
    player_season_totals: asRows(raw.player_season_totals, 'player_season_totals'),
    players: asRows(raw.players ?? [], 'players'),
    source_season_id: typeof raw.source_season_id === 'string' ? raw.source_season_id : undefined
  };
}
export async function getPlayerIndex(signal?: AbortSignal): Promise<JsonRow[]> {
  return asRows(await getJson('players/index.json', signal), 'players/index');
}
export async function getPlayerDossier(playerKey: string, signal?: AbortSignal): Promise<JsonRow> {
  const index = await getPlayerIndex(signal);
  const record = index.find(row => row.player_key === playerKey || row.player_id === playerKey ||
    row.bref_id === playerKey || row.nba_id === playerKey);
  if (!record || typeof record.file !== 'string') throw Error('No canonical player dossier for ' + playerKey);
  return asObject(await getJson(record.file, signal));
}
