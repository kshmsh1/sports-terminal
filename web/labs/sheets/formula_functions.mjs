// Spreadsheet function implementations kept separate from the AST parser.
// These functions accept already evaluated arguments; they never run JS code.
const flatten=value=>Array.isArray(value)?value.flat(Infinity):[value];
function asRange(value,CellError) {
  if(!Array.isArray(value))throw new CellError('#VALUE!');
  return flatten(value);
}
function asNumber(value,CellError) {
  if(value===null||value==='')return 0;
  const n=Number(value);
  if(!Number.isFinite(n))throw new CellError('#VALUE!');
  return n;
}
function equal(a,b) {
  if(typeof a==='string'&&typeof b==='string')return a.toLowerCase()===b.toLowerCase();
  return a===b||(a!==null&&b!==null&&a!==''&&b!==''&&
    !isNaN(Number(a))&&!isNaN(Number(b))&&Number(a)===Number(b));
}
function criterionMatch(value,criteria) {
  const raw=String(criteria??'');
  const match=/^(<=|>=|<>|=|<|>)(.*)$/.exec(raw);
  const op=match?.[1]??'=',wanted=match?match[2]:raw;
  const numeric=v=>v!==null&&v!==''&&!isNaN(Number(v));
  let a=value,b=wanted;
  if(numeric(a)&&numeric(b)){a=Number(a);b=Number(b);}
  else {
    a=String(a??'').toLowerCase();
    b=String(b??'').toLowerCase();
    if((wanted.includes('*')||wanted.includes('?'))&&(op==='='||op==='<>')){
      const escaped=wanted.replace(/[.+^$()|[\]\\]/g,'\\$&')
        .replace(/\*/g,'.*').replace(/\?/g,'.');
      const matching=new RegExp('^'+escaped+'$','i').test(String(value??''));
      return op==='='?matching:!matching;
    }
  }
  switch(op){
    case '=':return a===b;
    case '<>':return a!==b;
    case '>':return a>b;
    case '<':return a<b;
    case '>=':return a>=b;
    case '<=':return a<=b;
    default:return false;
  }
}
function dimensions(node,parseRef) {
  if(node?.kind!=='range')return {rows:1,cols:1};
  const a=parseRef(node.from),b=parseRef(node.to);
  return {rows:Math.abs(a.row-b.row)+1,cols:Math.abs(a.col-b.col)+1};
}
export function excelRound(value,places,mode,CellError){
  const n=asNumber(value,CellError),p=asNumber(places??0,CellError);
  if(Math.abs(p)>15)throw new CellError('#NUM!');
  const scale=10**p,scaled=Math.abs(n)*scale;
  const epsilon=Math.max(1,scaled)*1e-12;
  const out=mode==='up'?Math.ceil(scaled-epsilon)
    :mode==='down'?Math.floor(scaled+epsilon)
    :Math.floor(scaled+0.5+epsilon);
  const result=Math.sign(n)*out/scale;
  if(!Number.isFinite(result))throw new CellError('#NUM!');
  return result;
}
export const advancedNames=new Set([
  'COUNTIF','SUMIF','AVERAGEIF','COUNTIFS','SUMIFS',
  'MATCH','VLOOKUP','XLOOKUP','INDEX',
  'ROUND','ROUNDUP','ROUNDDOWN','PRODUCT',
  'MID','FIND','SEARCH','SUBSTITUTE','CONCATENATE',
  'ISNUMBER','ISTEXT','ISBLANK','VALUE','NA'
]);
export function evaluateAdvanced(name,args,ast,{CellError,parseRef}) {
  if(!advancedNames.has(name))return {handled:false};
  let value;
  if(['COUNTIF','SUMIF','AVERAGEIF'].includes(name)){
    const criteria=asRange(args[0],CellError),wanted=args[1];
    const data=name==='COUNTIF'?criteria:asRange(args[2]??args[0],CellError);
    if(data.length!==criteria.length)throw new CellError('#VALUE!');
    let count=0,total=0;
    for(let i=0;i<criteria.length;i++){
      if(!criterionMatch(criteria[i],wanted))continue;
      if(name==='COUNTIF'){count++;continue;}
      if(data[i]!==null&&data[i]!==''&&!isNaN(Number(data[i]))){
        count++;total+=Number(data[i]);
      }
    }
    value=name==='COUNTIF'?count:name==='SUMIF'?total:count?total/count:null;
    if(value===null)throw new CellError('#DIV/0!');
  }else if(name==='COUNTIFS'||name==='SUMIFS'){
    const start=name==='SUMIFS'?1:0;
    if(args.length<=start||(args.length-start)%2!==0)throw new CellError('#VALUE!');
    const ranges=[],criteria=[];
    for(let i=start;i<args.length;i+=2){ranges.push(asRange(args[i],CellError));criteria.push(args[i+1]);}
    const count=ranges[0].length;
    if(ranges.some(x=>x.length!==count))throw new CellError('#VALUE!');
    const amounts=start?asRange(args[0],CellError):null;
    if(amounts&&amounts.length!==count)throw new CellError('#VALUE!');
    value=0;
    for(let i=0;i<count;i++){
      if(!ranges.every((range,j)=>criterionMatch(range[i],criteria[j])))continue;
      if(!amounts){value++;continue;}
      if(amounts[i]!==null&&amounts[i]!==''&&!isNaN(Number(amounts[i])))value+=Number(amounts[i]);
    }
  }else if(name==='MATCH'){
    if(args[2]!==undefined&&asNumber(args[2],CellError)!==0)throw new CellError('#N/A');
    const index=asRange(args[1],CellError).findIndex(v=>equal(v,args[0]));
    if(index<0)throw new CellError('#N/A');
    value=index+1;
  }else if(name==='INDEX'){
    const entries=asRange(args[0],CellError),size=dimensions(ast.args[0],parseRef);
    const row=asNumber(args[1],CellError),col=asNumber(args[2]??1,CellError);
    if(!Number.isInteger(row)||!Number.isInteger(col)||row<1||col<1||row>size.rows||col>size.cols)
      throw new CellError('#REF!');
    value=entries[(row-1)*size.cols+col-1];
  }else if(name==='VLOOKUP'){
    if(args[3]!==undefined&&Boolean(args[3]))throw new CellError('#N/A');
    const entries=asRange(args[1],CellError),size=dimensions(ast.args[1],parseRef);
    const col=asNumber(args[2],CellError);
    if(!Number.isInteger(col)||col<1||col>size.cols)throw new CellError('#REF!');
    let found=false;
    for(let i=0;i<size.rows;i++){
      if(equal(entries[i*size.cols],args[0])){
        value=entries[i*size.cols+col-1];found=true;break;
      }
    }
    if(!found)throw new CellError('#N/A');
  }else if(name==='XLOOKUP'){
    const lookup=asRange(args[1],CellError),results=asRange(args[2],CellError);
    if(lookup.length!==results.length)throw new CellError('#VALUE!');
    const index=lookup.findIndex(v=>equal(v,args[0]));
    if(index>=0)value=results[index];
    else if(args.length>3)value=args[3];
    else throw new CellError('#N/A');
  }else if(name==='PRODUCT'){
    const nums=flatten(args).filter(x=>x!==null&&x!==''&&!isNaN(Number(x)));
    value=nums.reduce((product,n)=>product*Number(n),1);
  }else if(['ROUND','ROUNDUP','ROUNDDOWN'].includes(name)){
    value=excelRound(args[0],args[1]??0,name==='ROUND'?'nearest':name==='ROUNDUP'?'up':'down',CellError);
  }else if(name==='MID'){
    const start=Math.max(0,asNumber(args[1],CellError)-1);
    value=String(args[0]??'').slice(start,start+Math.max(0,asNumber(args[2],CellError)));
  }else if(name==='FIND'||name==='SEARCH'){
    const source=String(args[1]??''),needle=String(args[0]??'');
    const start=Math.max(0,asNumber(args[2]??1,CellError)-1);
    const index=name==='FIND'?source.indexOf(needle,start)
      :source.toLowerCase().indexOf(needle.toLowerCase(),start);
    if(index<0)throw new CellError('#VALUE!');
    value=index+1;
  }else if(name==='SUBSTITUTE')value=String(args[0]??'').split(String(args[1]??'')).join(String(args[2]??''));
  else if(name==='CONCATENATE')value=flatten(args).map(v=>String(v??'')).join('');
  else if(name==='ISNUMBER')value=typeof args[0]==='number';
  else if(name==='ISTEXT')value=typeof args[0]==='string';
  else if(name==='ISBLANK')value=args[0]===null||args[0]==='';
  else if(name==='VALUE')value=asNumber(args[0],CellError);
  else if(name==='NA')throw new CellError('#N/A');
  return {handled:true,value};
}
