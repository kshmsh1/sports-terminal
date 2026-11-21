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
  team_records?:JsonRow[];
  standings?:JsonRow[];
  teams?:JsonRow[];
  team_game_logs?:JsonRow[];
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
    team_records:asRows(raw.team_records??[], 'team_records'),
    standings:asRows(raw.standings??[], 'standings'),
    teams:asRows(raw.teams??[], 'teams'),
    team_game_logs:asRows(raw.team_game_logs??[], 'team_game_logs'),
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

export interface DatedContractRecord {
 id:string;player:string;team:string;salaries:Record<string,number>;
 guaranteed:number|null;sourceStatus:string;sourceLabel:string;
}
export interface DatedContractSnapshot {
 kind:'ARCSIDE_ORIGINAL_FLUTTER_2026_27_CONTRACT_SEED_V1';
 asOf:string;sourceNote:string;dartSeedSha256:string;records:DatedContractRecord[];
}
export async function getDatedContracts(signal?:AbortSignal):Promise<DatedContractSnapshot|null>{
 const res=await fetch('/data/phase3/2026-27-contracts.json',{signal,credentials:'same-origin'});
 if(res.status===404)return null;
 if(!res.ok)throw Error('Original Flutter 2026–27 contract snapshot could not be loaded: '+res.status);
 const raw=asObject(await res.json());
 if(raw.kind!=='ARCSIDE_ORIGINAL_FLUTTER_2026_27_CONTRACT_SEED_V1'||!Array.isArray(raw.records)||
    typeof raw.asOf!=='string'||typeof raw.dartSeedSha256!=='string')
  throw Error('Unverified dated contract seed response.');
 return raw as unknown as DatedContractSnapshot;
}
export async function getFrontOfficeContracts(signal?:AbortSignal):Promise<JsonRow[]>{
 const res=await fetch('/data/nba_static/front_office/contracts.json',{signal,credentials:'same-origin'});
 if(res.status===404)return [];
 if(!res.ok)throw Error('Front-office static contract read failed: '+res.status);
 const data=await res.json();
 return asRows(data,'front_office/contracts.json');
}

export async function getGameIndex(signal?:AbortSignal):Promise<JsonRow[]> {
 return asRows(await getJson('games/index.json',signal),'games/index');
}
export async function getGameDetail(game:JsonRow,signal?:AbortSignal):Promise<JsonRow|null> {
 if(typeof game.file!=='string'||!game.file)return null;
 return asObject(await getJson(game.file,signal));
}
export interface WithWithoutRow {
 team:string;player_id:string;teammate_id:string;minutes_with:number|null;minutes_without:number|null;
 with:Record<string,number|null>;without:Record<string,number|null>;
}
export interface WithWithoutData {
 available:boolean;source:string;rows:WithWithoutRow[];message:string;
}
const asNullableNumber=(value:unknown):number|null=>{
 if(typeof value==='number'&&Number.isFinite(value))return value;
 if(typeof value==='string'&&value.trim()!==''&&Number.isFinite(Number(value)))return Number(value);
 return null;
};
export async function getWithWithout(season:string,segment:SeasonType,signal?:AbortSignal):Promise<WithWithoutData>{
 if(!/^\d{4}-\d{2}$/.test(season))throw Error('Invalid lineup season');
 const path='lineups/'+season+'/'+segment+'/with_without.json';
 const res=await fetch(BASE+'/'+path,{signal,credentials:'same-origin'});
 if(res.status===404)return {available:false,source:'',rows:[],message:'Lineup stint / play-by-play splits have not been materialized for this season yet.'};
 if(!res.ok)return {available:false,source:'',rows:[],message:'With/without dataset is unavailable ('+res.status+').'};
 if(!(res.headers.get('content-type')??'').includes('json'))return {available:false,source:'',rows:[],message:'Lineup split data has not been published for this season.'};
 const raw=asObject(await res.json());
 const data=asRows(raw.rows??[],'lineups');
 const records=data.map(row=>{
  const statMap=(obj:unknown):Record<string,number|null>=>!obj||Array.isArray(obj)||typeof obj!=='object'?{}:
   Object.fromEntries(Object.entries(obj).map(([key,val])=>[key,asNullableNumber(val)]));
  return {team:String(row.team??''),player_id:String(row.player_id??''),teammate_id:String(row.teammate_id??''),
   minutes_with:asNullableNumber(row.minutes_with),minutes_without:asNullableNumber(row.minutes_without),
   with:statMap(row.with),without:statMap(row.without)};
 });
 return {available:records.length>0,source:String(raw.source??''),rows:records,
  message:records.length?'':'The lineup split file is present but contains no player-pair rows.'};
}

/** Original Flutter WebsiteNbaStaticRepository teamIndex/teamDossier contract. */
export async function getTeamIndex(signal?:AbortSignal):Promise<JsonRow[]>{
 return asRows(await getJson('teams/index.json',signal),'teams/index');
}
export function resolveTeamIndex(index:JsonRow[],requested:string):JsonRow|null{
 const token=(v:unknown)=>String(v??'').toLowerCase().replace(/[^a-z0-9]/g,'');
 const needle=token(requested);
 if(!needle)return null;
 let best:JsonRow|null=null,score=-1,latest=-1;
 for(const item of index){
  const key=token(item.team_key),abbr=token(item.abbreviation),
   name=token(item.canonical_name),franchise=token(item.franchise_key);
  let rank=-1;
  if(key===needle)rank=100;
  else if(abbr===needle)rank=95;
  else if(name===needle)rank=90;
  else if(key.endsWith(needle)||key.includes(needle))rank=75;
  else if(franchise===needle||franchise.endsWith(needle))rank=70;
  else if(name.includes(needle)||needle.includes(name)&&name.length>0)rank=60;
  if(rank<0)continue;
  const season=String(item.active_to??'').match(/^\d{4}/);
  const year=season?Number(season[0]):9999;
  if(rank>score||rank===score&&year>latest){best=item;score=rank;latest=year}
 }
 return best;
}
export async function getTeamDossier(key:string,index?:JsonRow[],signal?:AbortSignal):Promise<JsonRow>{
 const entries=index??await getTeamIndex(signal);
 const item=resolveTeamIndex(entries,key);
 if(!item||typeof item.file!=='string'||!item.file)throw Error('Original team dossier unavailable: '+key);
 return asObject(await getJson(item.file,signal));
}
export async function getGamePlayByPlay(game:JsonRow,signal?:AbortSignal):Promise<JsonRow[]>{
 if(typeof game.pbp_file!=='string'||!game.pbp_file)return [];
 return asRows(asObject(await getJson(game.pbp_file,signal)).rows,'game play-by-play rows');
}
