import type {JsonRow} from './data';
// Small non-visual module. App can render dossier headings without eagerly
// importing heavy, lazily loaded player-career and advanced-stat tables.
const asRows=(v:unknown):JsonRow[]=>Array.isArray(v)?
 v.filter((r):r is JsonRow=>r!==null&&typeof r==='object'&&!Array.isArray(r)):[];
const source=(row:JsonRow,aliases:string[])=>{
 for(const key of aliases){const value=row[key];if(value!==undefined&&value!==null&&value!=='')return value;}
 return null;
};
export function dossierSegments(dossier:JsonRow|null){
 return {regular:asRows(dossier?.regular_seasons),playoffs:asRows(dossier?.playoff_seasons)};
}
export function dossierName(dossier:JsonRow|null,fallback='Player profile'){
 const profile=dossier?.profile;
 const record=profile&&typeof profile==='object'&&!Array.isArray(profile)?profile as JsonRow:{};
 return String(source(record,['canonical_name','player_name','name'])??
  source(dossier??{},['canonical_name','player_name','player_label'])??fallback);
}
