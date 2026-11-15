/**
 * Spreadsheet analysis helpers: deterministic, no eval or unsafe scripting.
 * Charts/pivots accept evaluated worksheet arrays with headers as row zero.
 */
const limit=(n,min,max)=>Math.max(min,Math.min(max,n));
export function fieldIndex(headers,field) {
  const index=Number.isInteger(field)?field:headers.indexOf(String(field));
  if(index<0||index>=headers.length)throw Error('Unknown worksheet field: '+String(field));
  return index;
}
function numeric(v){
  if(v===null||v===undefined||v==='')return null;
  const n=Number(String(v).replace(/,/g,''));
  return Number.isFinite(n)?n:null;
}
function text(v){return v===null||v===undefined?'':String(v);}
function selectRows(rows,filters=[]) {
  const headers=rows[0]??[];
  const predicates=filters.map(({field,op='equals',value=''})=>{
    const index=fieldIndex(headers,field),wanted=text(value).toLowerCase();
    return (row)=>{
      const actual=text(row[index]),lower=actual.toLowerCase(),a=numeric(actual),b=numeric(value);
      switch(op){
        case 'equals':return lower===wanted;
        case 'notEquals':return lower!==wanted;
        case 'contains':return lower.includes(wanted);
        case 'startsWith':return lower.startsWith(wanted);
        case 'endsWith':return lower.endsWith(wanted);
        case 'greater':return a!==null&&b!==null&&a>b;
        case 'greaterOrEqual':return a!==null&&b!==null&&a>=b;
        case 'less':return a!==null&&b!==null&&a<b;
        case 'lessOrEqual':return a!==null&&b!==null&&a<=b;
        case 'notBlank':return actual!=='';
        case 'blank':return actual==='';
        default:throw Error('Unsupported filter: '+op);
      }
    };
  });
  return rows.slice(1).filter(row=>predicates.every(p=>p(row)));
}
export function filterTable(rows,filters=[]){
  if(!Array.isArray(rows)||!Array.isArray(rows[0]))throw Error('Filter requires header row');
  if(rows.length>100001)throw Error('Maximum 100,000 table records');
  return [rows[0],...selectRows(rows,filters)];
}
function accumulator(){return {count:0,sum:0,min:Infinity,max:-Infinity,values:[],distinct:new Set()};}
function accumulate(target,value){
  const displayed=text(value);
  if(!displayed)return;
  target.count++;
  target.distinct.add(displayed);
  const n=numeric(value);
  if(n===null)return;
  target.sum+=n;
  target.min=Math.min(target.min,n);
  target.max=Math.max(target.max,n);
  if(target.values.length<100000)target.values.push(n);
}
function finalize(target,aggregate){
  switch(aggregate){
    case 'sum':return target.sum;
    case 'count':return target.count;
    case 'distinctCount':return target.distinct.size;
    case 'average':return target.values.length?target.sum/target.values.length:0;
    case 'min':return target.min===Infinity?'':target.min;
    case 'max':return target.max===-Infinity?'':target.max;
    case 'median':{
      const values=target.values.sort((a,b)=>a-b);
      if(!values.length)return '';
      const i=Math.floor(values.length/2);
      return values.length%2?values[i]:(values[i-1]+values[i])/2;
    }
    case 'stdev':{
      const n=target.values.length;if(n<2)return '';
      const avg=target.sum/n;
      return Math.sqrt(target.values.reduce((sum,v)=>sum+(v-avg)**2,0)/(n-1));
    }
    default:throw Error('Unsupported pivot aggregation: '+aggregate);
  }
}
export function pivotTable(rows,options={}) {
  if(!Array.isArray(rows)||!Array.isArray(rows[0])||rows[0].length<2)
    throw Error('Pivot requires a header and at least two columns');
  if(rows.length>100001)throw Error('Maximum 100,000 source records');
  const headers=rows[0].map((v,i)=>text(v)||'Field '+(i+1));
  const rowFields=(options.rows?.length?options.rows:[0]).map(field=>fieldIndex(headers,field));
  const columnField=options.column===undefined||options.column===null||options.column===''
    ?null:fieldIndex(headers,options.column);
  const metrics=(options.metrics?.length?options.metrics:[{field:1,aggregate:'sum'}]).map(metric=>({
    ...metric,index:fieldIndex(headers,metric.field),aggregate:metric.aggregate||'sum',
  }));
  if(rowFields.length>4||metrics.length>8)throw Error('Up to four row fields and eight measures');
  const filtered=selectRows(rows,options.filters??[]);
  const groups=new Map(),columns=new Set(),totals=new Map();
  function record(key,rowValues,columnValue,values){
    if(!groups.has(key))groups.set(key,{rowValues,columnMap:new Map()});
    const group=groups.get(key);
    if(!group.columnMap.has(columnValue))group.columnMap.set(columnValue,metrics.map(()=>accumulator()));
    const buckets=group.columnMap.get(columnValue);
    metrics.forEach((metric,i)=>accumulate(buckets[i],values[metric.index]));
  }
  for(const row of filtered){
    const rowValues=rowFields.map(i=>text(row[i])),key=JSON.stringify(rowValues);
    const col=columnField===null?'':text(row[columnField]);
    columns.add(col);
    record(key,rowValues,col,row);
    if(!totals.has(col))totals.set(col,metrics.map(()=>accumulator()));
    metrics.forEach((metric,i)=>accumulate(totals.get(col)[i],row[metric.index]));
  }
  const columnValues=[...columns].sort((a,b)=>a.localeCompare(b,undefined,{numeric:true}));
  if(!columnValues.length)columnValues.push('');
  const resultHeaders=[
    ...rowFields.map(i=>headers[i]),
    ...columnValues.flatMap(col=>metrics.map(metric=>{
      const name=metric.label||headers[metric.index];
      return (columnField===null?'':(col||'(blank)')+' / ')+name+' · '+metric.aggregate;
    })),
  ];
  if(resultHeaders.length>256)throw Error('Pivot exceeds 256 result columns');
  const records=[...groups.values()];
  const ascending=options.sortDescending?-1:1;
  records.sort((a,b)=>a.rowValues.join(' / ').localeCompare(b.rowValues.join(' / '),undefined,{numeric:true})*ascending);
  if(records.length>20000)throw Error('Pivot exceeds 20,000 output groups');
  const matrix=[resultHeaders];
  for(const group of records){
    matrix.push([...group.rowValues,...columnValues.flatMap(col=>
      metrics.map((m,i)=>finalize(group.columnMap.get(col)?.[i]??accumulator(),m.aggregate))
    )]);
  }
  if(options.totals!==false){
    matrix.push([
      'Grand Total',...rowFields.slice(1).map(()=>''),
      ...columnValues.flatMap(col=>metrics.map((m,i)=>
        finalize(totals.get(col)?.[i]??accumulator(),m.aggregate)
      )),
    ]);
  }
  return {matrix,sourceRows:filtered.length,groupCount:groups.size,
    dimensions:{rowFields:rowFields.map(i=>headers[i]),column:columnField===null?null:headers[columnField],
      metrics:metrics.map(m=>({field:headers[m.index],aggregate:m.aggregate}))}};
}
export function chartData(rows,config={}) {
  if(!rows?.length||!Array.isArray(rows[0]))throw Error('Chart requires a table');
  const headers=rows[0].map(String);
  const labelIndex=fieldIndex(headers,config.category??0);
  const measures=(config.series?.length?config.series:[1]).map(field=>fieldIndex(headers,field));
  if(measures.length>12)throw Error('Up to 12 chart series');
  const chartRows=selectRows(rows,config.filters??[]).slice(0,500);
  return {
    type:config.type??'bar',
    title:config.title??'Chart',
    labels:chartRows.map(row=>text(row[labelIndex])),
    series:measures.map(i=>({
      name:headers[i],
      values:chartRows.map(row=>numeric(row[i])),
    })),
  };
}
export function conditionalStyle(value,rule,position={row:1,col:1},rangeStats=null) {
  if(rule?.sheet && rule.sheet!==position.sheet)return null;
  const rect=rule?.range??{};
  if(position.row<(rect.a??1)||position.row>(rect.b??100000)||
    position.col<(rect.l??1)||position.col>(rect.r??256))return null;
  const n=numeric(value),a=numeric(rule.value),b=numeric(rule.second);
  let matched=false;
  switch(rule.kind){
    case 'greaterThan':matched=n!==null&&a!==null&&n>a;break;
    case 'lessThan':matched=n!==null&&a!==null&&n<a;break;
    case 'equalTo':matched=text(value).toLowerCase()===text(rule.value).toLowerCase();break;
    case 'between':matched=n!==null&&a!==null&&b!==null&&n>=Math.min(a,b)&&n<=Math.max(a,b);break;
    case 'contains':matched=text(value).toLowerCase().includes(text(rule.value).toLowerCase());break;
    case 'notBlank':matched=text(value)!=='';break;
    case 'dataBar':{
      if(n===null)return null;
      const lower=rangeStats?.min??0,upper=rangeStats?.max??Math.max(1,a??100);
      const span=upper-lower,percentage=limit(span?((n-lower)/span)*100:100,0,100);
      const fill=rule.color??'#356caa';
      return {background:'linear-gradient(to right, '+fill+' '+percentage+'%,transparent '+percentage+'%)'};
    }
    case 'colorScale':{
      if(n===null)return null;
      const min=rangeStats?.min??0,max=rangeStats?.max??Math.max(1,a??100);
      const intensity=limit(max===min?0.5:(n-min)/(max-min),0,1);
      const low=[48,75,112],high=[25,156,124];
      const rgb=low.map((v,i)=>Math.round(v*(1-intensity)+high[i]*intensity));
      return {fill:'rgb('+rgb.join(',')+')'};
    }
    default:return null;
  }
  return matched?{fill:rule.color??'#1c644f',color:rule.textColor??'#e6f8ef'}:null;
}
