/**
 * Pivot engine shared by the browser and a dedicated Web Worker.
 * No eval(), no DOM dependencies; source cells are passed as primitives.
 */
export const PIVOT_AGGREGATES=['sum','average','count','countDistinct','min','max','median'];
function key(parts){return JSON.stringify(parts);}
function label(parts){return parts.map(x=>x===null||x===undefined||x===''?'(blank)':String(x));}
function createBucket(){return {count:0,numericCount:0,sum:0,min:Infinity,max:-Infinity,items:[],distinct:new Set()};}
function add(bucket,value){
  if(value!==null&&value!==undefined&&value!==''){
    bucket.count++;bucket.distinct.add(String(value));
    if(Number.isFinite(Number(value))){
      const n=Number(value);
      bucket.numericCount++;bucket.sum+=n;
      bucket.min=Math.min(bucket.min,n);bucket.max=Math.max(bucket.max,n);
      bucket.items.push(n);
    }
  }
}
function finish(bucket,aggregate){
  switch(aggregate){
    case 'sum':return bucket.sum;
    case 'count':return bucket.count;
    case 'countDistinct':return bucket.distinct.size;
    case 'average':return bucket.numericCount?bucket.sum/bucket.numericCount:null;
    case 'min':return bucket.numericCount?bucket.min:null;
    case 'max':return bucket.numericCount?bucket.max:null;
    case 'median':{
      if(!bucket.items.length)return null;
      const sorted=bucket.items.sort((a,b)=>a-b),n=sorted.length,mid=Math.floor(n/2);
      return n%2?sorted[mid]:(sorted[mid-1]+sorted[mid])/2;
    }
    default:throw Error('Unknown pivot aggregation: '+aggregate);
  }
}
function natural(a,b){
  return String(a).localeCompare(String(b),undefined,{numeric:true,sensitivity:'base'});
}
function match(row,filter){
  if(!filter)return true;
  const value=row[filter.field];
  const actual=String(value??'').toLowerCase(),target=String(filter.value??'').toLowerCase();
  switch(filter.mode){
    case 'equals':return actual===target;
    case 'notEquals':return actual!==target;
    case 'contains':return actual.includes(target);
    case 'notBlank':return actual!=='';
    default:return true;
  }
}
/**
 * config: {rows:[colIdx,...],column:null|colIdx,value:colIdx,
 *          aggregate:'sum',filter:{field,mode,value}|null,grandTotal:true}.
 * Result matrix includes a header and optional grand-total row.
 */
export function buildPivot(matrix,config){
  if(!Array.isArray(matrix)||!Array.isArray(matrix[0])||matrix.length<2)
    throw Error('Pivot requires a table with headers and data rows');
  if(matrix.length>100001)throw Error('Pivot source exceeds 100,000 rows');
  const headers=matrix[0],width=headers.length;
  const fields=Array.isArray(config.rows)?config.rows:[config.rows??0];
  const rowFields=fields.filter(v=>Number.isInteger(v)&&v>=0&&v<width);
  const colField=config.column===null||config.column===undefined?-1:Number(config.column);
  const valueField=Number(config.value);
  const aggregate=config.aggregate??'sum';
  if(!rowFields.length||rowFields.length>3||colField>=width||colField< -1||
      !Number.isInteger(valueField)||valueField<0||valueField>=width||
      !PIVOT_AGGREGATES.includes(aggregate))
    throw Error('Invalid pivot fields');
  const rowLabels=new Map(),colLabels=new Map();
  const buckets=new Map(),rowTotals=new Map(),colTotals=new Map();
  const total=createBucket();
  let records=0;
  for(const row of matrix.slice(1)){
    if(!match(row,config.filter))continue;
    records++;
    const rowParts=rowFields.map(i=>row[i]??''),colParts=colField<0?[]:[row[colField]??''];
    const rowKey=key(rowParts),colKey=key(colParts),pair=rowKey+'\u0000'+colKey;
    rowLabels.set(rowKey,rowParts);colLabels.set(colKey,colParts);
    if(!buckets.has(pair))buckets.set(pair,createBucket());
    if(!rowTotals.has(rowKey))rowTotals.set(rowKey,createBucket());
    if(!colTotals.has(colKey))colTotals.set(colKey,createBucket());
    const n=row[valueField];
    for(const bucket of [buckets.get(pair),rowTotals.get(rowKey),colTotals.get(colKey),total])add(bucket,n);
    if(rowLabels.size>1000||colLabels.size>150)
      throw Error('Pivot has too many unique groups (limit 1,000 rows / 150 columns)');
  }
  const rows=[...rowLabels.keys()].sort((a,b)=>natural(label(rowLabels.get(a)).join(' / '),label(rowLabels.get(b)).join(' / ')));
  const cols=[...colLabels.keys()].sort((a,b)=>natural(label(colLabels.get(a)).join(' / '),label(colLabels.get(b)).join(' / ')));
  const withCols=colField>=0,grand=config.grandTotal!==false;
  const colsHead=withCols?cols.map(k=>label(colLabels.get(k)).join(' / ')):[String(headers[valueField]||'Value')+' · '+aggregate];
  const out=[[...rowFields.map(i=>String(headers[i]||('Field '+(i+1)))),...colsHead,...(grand&&withCols?['Grand Total']:[])]];
  if(out[0].length>256)throw Error('Pivot exceeds 256 output columns');
  for(const rowKey of rows){
    const values=withCols?cols.map(colKey=>finish(buckets.get(rowKey+'\u0000'+colKey)??createBucket(),aggregate))
      :[finish(rowTotals.get(rowKey),aggregate)];
    out.push([...label(rowLabels.get(rowKey)),...values,
      ...(grand&&withCols?[finish(rowTotals.get(rowKey),aggregate)]:[])]);
  }
  if(grand){
    const labelRow=['Grand Total',...rowFields.slice(1).map(()=>'')];
    const values=withCols?cols.map(k=>finish(colTotals.get(k),aggregate))
      :[finish(total,aggregate)];
    out.push([...labelRow,...values,...(withCols?[finish(total,aggregate)]:[])]);
  }
  if(out.length*(out[0].length)>100000)
    throw Error('Pivot output is too large; filter the source');
  return {matrix:out,meta:{records,groups:rows.length,columnGroups:cols.length,aggregate,
                           sourceColumns:headers.length}};
}
/** Filter rows without mutating the source table, optionally sort a column. */
export function filterTable(matrix,{field=0,mode='contains',value='',sort='none'}={}){
  if(!matrix.length)return [];
  const [header,...rows]=matrix;
  const filtered=rows.filter(row=>match(row,{field,mode,value}));
  if(sort==='asc'||sort==='desc'){
    filtered.sort((a,b)=>natural(a[field]??'',b[field]??'')*(sort==='asc'?1:-1));
  }
  return [header,...filtered];
}
