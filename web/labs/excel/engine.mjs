/* Arcside Spreadsheet calculation engine.
 * No dynamic JavaScript evaluation, macros, telemetry or server-side execution.
 * Sparse workbook, proper tokenized formulas, dependency graph and cycles. */
export class SpreadsheetError extends Error {
  constructor(code){super(code);this.code=code;}
}
export function colLabel(index) {
  let n=index+1,s='';
  while(n>0){n--;s=String.fromCharCode(65+n%26)+s;n=Math.floor(n/26);}
  return s;
}
export function colIndex(label) {
  let n=0;
  for(const c of label.toUpperCase())n=n*26+c.charCodeAt(0)-64;
  return n-1;
}
export function address(row,col){return colLabel(col)+String(row+1);}
export function parseAddress(ref) {
  const m=/^\$?([A-Z]{1,3})\$?([1-9]\d*)$/i.exec(String(ref).trim());
  if(!m)throw new SpreadsheetError('#REF!');
  const row=Number(m[2])-1,col=colIndex(m[1]);
  if(row>=100000||col>=512)throw new SpreadsheetError('#REF!');
  return {row,col,ref:address(row,col)};
}
function tokenize(formula){
  const t=[],pattern=/\s+|"(?:[^"]|"")*"|'(?:[^']|'')*'|\$?[A-Za-z]{1,3}\$?[1-9]\d*|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|[A-Za-z_][A-Za-z0-9_.]*|<=|>=|<>|[()+\-*/^&=<>:,;!]/gy;
  let pos=0;
  while(pos<formula.length){
    pattern.lastIndex=pos;const m=pattern.exec(formula);
    if(!m)throw new SpreadsheetError('#ERROR!');
    pos=pattern.lastIndex;const v=m[0];
    if(/^\s+$/.test(v))continue;
    t.push(v);
    if(t.length>2000)throw new SpreadsheetError('#ERROR!');
  }
  t.push('<EOF>');return t;
}
const precedence={'=':1,'<>':1,'<':1,'>':1,'<=':1,'>=':1,'&':2,'+':3,'-':3,'*':4,'/':4,'^':5};
function formulaAst(expression){
  if(expression.length>4096)throw new SpreadsheetError('#ERROR!');
  const tokens=tokenize(expression);
  let p=0;const peek=()=>tokens[p],eat=()=>tokens[p++];
  function requireToken(t){if(eat()!==t)throw new SpreadsheetError('#ERROR!');}
  function primary(){
    const token=eat();
    if(token==='+'||token==='-')return {t:'un',op:token,x:parse(6)};
    if(token==='('){const result=parse(0);requireToken(')');return result;}
    if(token.startsWith('"'))return {t:'literal',v:token.slice(1,-1).replaceAll('""','"')};
    if(/^\d/.test(token))return {t:'literal',v:Number(token)};
    if(token==='<EOF>')throw new SpreadsheetError('#ERROR!');
    if(/^[A-Za-z_$']/.test(token)){
      let name=token;
      if(peek()==='('){
        eat();const args=[];
        if(peek()!==')'){
          do{
            args.push(parse(0));
            if(peek()!==','&&peek()!==';')break;
            eat();
          }while(true);
        }
        requireToken(')');
        return {t:'fn',name:name.toUpperCase(),args};
      }
      if(name.toUpperCase()==='TRUE')return {t:'literal',v:true};
      if(name.toUpperCase()==='FALSE')return {t:'literal',v:false};
      let sheet=null;
      if(peek()==='!'){
        eat();sheet=name.startsWith("'")?
          name.slice(1,-1).replaceAll("''","'"):name;
        name=eat();
      }
      if(!/^\$?[A-Za-z]{1,3}\$?[1-9]\d*$/.test(name))
        throw new SpreadsheetError('#NAME?');
      const ref=parseAddress(name).ref;
      if(peek()===':'){
        eat();
        const end=eat();
        if(!/^\$?[A-Za-z]{1,3}\$?[1-9]\d*$/.test(end))
          throw new SpreadsheetError('#REF!');
        return {t:'range',sheet,from:ref,to:parseAddress(end).ref};
      }
      return {t:'ref',sheet,ref};
    }
    throw new SpreadsheetError('#ERROR!');
  }
  function parse(min){
    let left=primary();
    while(precedence[peek()]!==undefined&&precedence[peek()]>=min){
      const op=eat(),pr=precedence[op];
      const right=parse(pr+(op==='^'?0:1));
      left={t:'bin',op,left,right};
    }
    return left;
  }
  const ast=parse(0);
  if(peek()!=='<EOF>')throw new SpreadsheetError('#ERROR!');
  return ast;
}
const numeric=x=>{
  if(typeof x==='boolean')return x?1:0;
  if(x===''||x===null||x===undefined)return 0;
  const n=Number(x);
  if(!Number.isFinite(n))throw new SpreadsheetError('#VALUE!');
  return n;
};
const flatten=args=>args.flat(Infinity);
function allRefs(ast,defaultSheet,resolveSheet){
  const dependencies=new Set();
  function add(sheetName,ref){
    const s=resolveSheet(sheetName || defaultSheet.name);
    if(s)dependencies.add(s.id+'!'+ref);
  }
  function walk(n){
    if(!n)return;
    if(n.t==='ref')add(n.sheet,n.ref);
    if(n.t==='range'){
      const s=resolveSheet(n.sheet||defaultSheet.name);
      if(!s)return;
      const a=parseAddress(n.from),b=parseAddress(n.to);
      const area=(Math.abs(a.row-b.row)+1)*(Math.abs(a.col-b.col)+1);
      if(area>15000)throw new SpreadsheetError('#NUM!');
      for(let r=Math.min(a.row,b.row);r<=Math.max(a.row,b.row);r++)
        for(let c=Math.min(a.col,b.col);c<=Math.max(a.col,b.col);c++)
          add(s.name,address(r,c));
    }
    if(n.t==='bin'){walk(n.left);walk(n.right);}
    if(n.t==='un')walk(n.x);
    if(n.t==='fn')n.args.forEach(walk);
  }
  walk(ast);return dependencies;
}
export class ArcsideWorkbook {
  constructor(snapshot){
    this.sheets=[];this.cache=new Map();this.ast=new Map();
    this.deps=new Map();this.reverse=new Map();
    this.seq=0;this.activeId='';
    if(snapshot)this.load(snapshot);
    else this.addSheet('Sheet1');
  }
  get active(){return this.sheets.find(s=>s.id===this.activeId)||this.sheets[0];}
  getSheet(nameOrId){return this.sheets.find(s=>s.name===nameOrId||s.id===nameOrId)||null;}
  addSheet(name){
    let chosen=(name||'Sheet'+(this.sheets.length+1)).slice(0,40);
    if(this.getSheet(chosen)) {
      let n=2;while(this.getSheet(chosen+' ('+n+')'))n++;
      chosen+=' ('+n+')';
    }
    const sheet={id:'s'+(++this.seq),name:chosen,cells:{},styles:{},widths:{}};
    this.sheets.push(sheet);this.activeId=sheet.id;return sheet;
  }
  renameSheet(id,name){
    const s=this.getSheet(id);
    if(!s)return false;
    const trimmed=String(name).trim().slice(0,40);
    if(!trimmed||this.sheets.some(x=>x.id!==id&&x.name===trimmed))return false;
    s.name=trimmed;this._rebuild();return true;
  }
  deleteSheet(id){
    if(this.sheets.length<=1)return false;
    this.sheets=this.sheets.filter(s=>s.id!==id);
    if(this.activeId===id)this.activeId=this.sheets[0].id;
    this._rebuild();return true;
  }
  load(snapshot){
    if(!snapshot||!Array.isArray(snapshot.sheets)||!snapshot.sheets.length)
      throw new SpreadsheetError('#VALUE!');
    this.sheets=snapshot.sheets.slice(0,64).map((s,i)=>({
      id:String(s.id||'s'+(i+1)),name:String(s.name||'Sheet'+(i+1)).slice(0,40),
      cells:typeof s.cells==='object'&&s.cells?s.cells:{},
      styles:typeof s.styles==='object'&&s.styles?s.styles:{},
      widths:typeof s.widths==='object'&&s.widths?s.widths:{},
    }));
    this.seq=this.sheets.length;
    this.activeId=this.getSheet(snapshot.activeId)?.id||this.sheets[0].id;
    this._rebuild();
  }
  snapshot(){
    return {format:'arcside-spreadsheet-1',activeId:this.activeId,
      sheets:this.sheets.map(s=>({id:s.id,name:s.name,
        cells:{...s.cells},styles:{...s.styles},widths:{...s.widths}}))};
  }
  key(id,ref){return id+'!'+parseAddress(ref).ref;}
  getRaw(id,ref){return this.getSheet(id)?.cells[parseAddress(ref).ref]??'';}
  getStyle(id,ref){return this.getSheet(id)?.styles[parseAddress(ref).ref]||{};}
  setStyle(id,ref,style){
    const s=this.getSheet(id);if(!s)throw new SpreadsheetError('#REF!');
    const name=parseAddress(ref).ref;
    s.styles[name]={...this.getStyle(id,name),...style};
  }
  setRaw(id,ref,input){
    const sheet=this.getSheet(id);if(!sheet)throw new SpreadsheetError('#REF!');
    const name=parseAddress(ref).ref,key=this.key(sheet.id,name);
    const raw=String(input??'');
    if(raw.length>100000)throw new SpreadsheetError('#VALUE!');
    if(!raw)delete sheet.cells[name];else sheet.cells[name]=raw;
    this._updateFormula(key,sheet,raw);
    this._invalidate(key);
  }
  _updateFormula(key,sheet,raw){
    for(const before of this.deps.get(key)||[])
      this.reverse.get(before)?.delete(key);
    this.deps.delete(key);this.ast.delete(key);
    if(!raw.startsWith('='))return;
    try{
      const tree=formulaAst(raw.slice(1));
      this.ast.set(key,tree);
      const deps=allRefs(tree,sheet,name=>this.getSheet(name));
      this.deps.set(key,deps);
      for(const dep of deps){
        if(!this.reverse.has(dep))this.reverse.set(dep,new Set());
        this.reverse.get(dep).add(key);
      }
    }catch(error){this.ast.set(key,{t:'error',code:error.code||'#ERROR!'});}
  }
  _rebuild(){
    this.cache.clear();this.ast.clear();this.deps.clear();this.reverse.clear();
    for(const s of this.sheets)
      for(const [ref,raw] of Object.entries(s.cells))
        this._updateFormula(this.key(s.id,ref),s,String(raw));
  }
  _invalidate(key){
    const queued=[key],seen=new Set();
    while(queued.length){
      const current=queued.shift();
      if(seen.has(current))continue;
      seen.add(current);this.cache.delete(current);
      for(const child of this.reverse.get(current)||[])queued.push(child);
    }
  }
  getValue(id,ref){return this._calculate(this.key(id,ref),new Set(),0);}
  _calculate(key,visiting,depth){
    if(this.cache.has(key))return this.cache.get(key);
    if(depth>128||visiting.has(key))throw new SpreadsheetError('#CIRC!');
    const marker=key.indexOf('!'),id=key.slice(0,marker),ref=key.slice(marker+1);
    const sheet=this.getSheet(id);
    if(!sheet)throw new SpreadsheetError('#REF!');
    const raw=sheet.cells[ref];
    if(raw===undefined||raw==='')return '';
    if(!String(raw).startsWith('=')){
      const n=Number(raw);const result=String(raw).trim()!==''&&Number.isFinite(n)?n:raw;
      this.cache.set(key,result);return result;
    }
    visiting.add(key);
    let result;
    try{
      const ast=this.ast.get(key);
      if(!ast)throw new SpreadsheetError('#ERROR!');
      result=this._eval(ast,sheet,visiting,depth+1);
    }catch(error){result=error instanceof SpreadsheetError?error.code:'#ERROR!';}
    visiting.delete(key);
    this.cache.set(key,result);return result;
  }
  _resolved(id,ref,visiting,depth){
    const value=this._calculate(this.key(id,ref),visiting,depth+1);
    if(typeof value==='string'&&/^#(?:REF!|CIRC!|DIV\/0!|NUM!|VALUE!|NAME\?|ERROR!|N\/A)/.test(value))
      throw new SpreadsheetError(value);
    return value;
  }
  _range(node,sheet,visiting,depth){
    const src=this.getSheet(node.sheet||sheet.name);
    if(!src)throw new SpreadsheetError('#REF!');
    const a=parseAddress(node.from),b=parseAddress(node.to);
    const width=Math.abs(a.col-b.col)+1,height=Math.abs(a.row-b.row)+1;
    if(width*height>15000)throw new SpreadsheetError('#NUM!');
    const out=[];
    for(let row=Math.min(a.row,b.row);row<=Math.max(a.row,b.row);row++){
      const line=[];
      for(let col=Math.min(a.col,b.col);col<=Math.max(a.col,b.col);col++)
        line.push(this._resolved(src.id,address(row,col),visiting,depth));
      out.push(line);
    }
    return out;
  }
  _eval(ast,sheet,visiting,depth){
    if(depth>128)throw new SpreadsheetError('#NUM!');
    if(ast.t==='error')throw new SpreadsheetError(ast.code);
    if(ast.t==='literal')return ast.v;
    if(ast.t==='ref'){
      const src=this.getSheet(ast.sheet||sheet.name);
      if(!src)throw new SpreadsheetError('#REF!');
      return this._resolved(src.id,ast.ref,visiting,depth);
    }
    if(ast.t==='range')return this._range(ast,sheet,visiting,depth);
    if(ast.t==='un'){
      const v=numeric(this._eval(ast.x,sheet,visiting,depth+1));
      return ast.op==='-'?-v:v;
    }
    if(ast.t==='bin'){
      const a=this._eval(ast.left,sheet,visiting,depth+1);
      const b=this._eval(ast.right,sheet,visiting,depth+1);
      switch(ast.op){
        case '+':return numeric(a)+numeric(b);
        case '-':return numeric(a)-numeric(b);
        case '*':return numeric(a)*numeric(b);
        case '/':if(numeric(b)===0)throw new SpreadsheetError('#DIV/0!');
          return numeric(a)/numeric(b);
        case '^':return Math.pow(numeric(a),numeric(b));
        case '&':return String(a)+String(b);
        case '=':return a==b;
        case '<>':return a!=b;
        case '<':return a<b;
        case '>':return a>b;
        case '<=':return a<=b;
        case '>=':return a>=b;
      }
    }
    if(ast.t==='fn'){
      const fn=ast.name,args=ast.args;
      const at=i=>args[i]?this._eval(args[i],sheet,visiting,depth+1):'';
      if(fn==='IF')return at(0)?at(1):at(2);
      if(fn==='IFERROR'){
        try{const value=at(0);return value;}catch(_){return at(1);}
      }
      if(fn==='AND')return args.every((_,i)=>Boolean(at(i)));
      if(fn==='OR')return args.some((_,i)=>Boolean(at(i)));
      if(fn==='NOT')return !at(0);
      const values=args.map((_,i)=>at(i));
      const flat=flatten(values);
      const numbers=flat.filter(v=>v!==''&&v!==null&&v!==undefined)
        .filter(v=>Number.isFinite(Number(v))).map(Number);
      switch(fn){
        case 'SUM':return numbers.reduce((a,b)=>a+b,0);
        case 'AVERAGE':case 'AVG':
          return numbers.length?numbers.reduce((a,b)=>a+b,0)/numbers.length:
            (()=>{throw new SpreadsheetError('#DIV/0!');})();
        case 'MIN':return numbers.length?Math.min(...numbers):0;
        case 'MAX':return numbers.length?Math.max(...numbers):0;
        case 'COUNT':return numbers.length;
        case 'COUNTA':return flat.filter(v=>v!==''&&v!==null&&v!==undefined).length;
        case 'MEDIAN':{
          if(!numbers.length)throw new SpreadsheetError('#NUM!');
          numbers.sort((a,b)=>a-b);const i=Math.floor(numbers.length/2);
          return numbers.length%2?numbers[i]:(numbers[i-1]+numbers[i])/2;
        }
        case 'ABS':return Math.abs(numeric(values[0]));
        case 'SQRT':return Math.sqrt(numeric(values[0]));
        case 'POWER':return Math.pow(numeric(values[0]),numeric(values[1]));
        case 'ROUND':{
          const scale=Math.pow(10,numeric(values[1]??0));
          return Math.round(numeric(values[0])*scale)/scale;
        }
        case 'ROUNDUP':{
          const scale=Math.pow(10,numeric(values[1]??0));
          return Math.ceil(numeric(values[0])*scale)/scale;
        }
        case 'ROUNDDOWN':{
          const scale=Math.pow(10,numeric(values[1]??0));
          return Math.trunc(numeric(values[0])*scale)/scale;
        }
        case 'MOD':return numeric(values[0])%numeric(values[1]);
        case 'INT':return Math.floor(numeric(values[0]));
        case 'LEN':return String(values[0]??'').length;
        case 'LOWER':return String(values[0]??'').toLowerCase();
        case 'UPPER':return String(values[0]??'').toUpperCase();
        case 'TRIM':return String(values[0]??'').trim().replace(/\s+/g,' ');
        case 'LEFT':return String(values[0]??'').slice(0,numeric(values[1]??1));
        case 'RIGHT':return String(values[0]??'').slice(-numeric(values[1]??1));
        case 'CONCAT':case 'CONCATENATE':return flat.join('');
        case 'TODAY':return Math.floor(Date.now()/86400000)+25569;
        case 'NOW':return Date.now()/86400000+25569;
        case 'INDEX':{
          const rows=Array.isArray(values[0])?values[0]:[[values[0]]];
          const ri=numeric(values[1])-1,ci=numeric(values[2]??1)-1;
          if(!rows[ri]||rows[ri][ci]===undefined)
            throw new SpreadsheetError('#REF!');
          return rows[ri][ci];
        }
        case 'VLOOKUP':{
          const rows=Array.isArray(values[1])?values[1]:[[values[1]]];
          const col=numeric(values[2])-1;
          if(col<0)throw new SpreadsheetError('#REF!');
          const exact=values[3]!==false;
          const row=rows.find(r=>Array.isArray(r)&&
            (exact?r[0]==values[0]:r[0]<=values[0]));
          if(!row||row[col]===undefined)throw new SpreadsheetError('#N/A');
          return row[col];
        }
        case 'COUNTIF':case 'SUMIF':{
          const source=Array.isArray(values[0])?flatten(values[0]):[values[0]];
          const rule=values[1];const match=v=>{
            const text=String(rule);
            const m=/^(>=|<=|<>|>|<|=)(.*)$/.exec(text);
            if(!m)return String(v)===text;
            const target=m[2],a=Number(v),b=Number(target);
            const numericCompare=Number.isFinite(a)&&Number.isFinite(b);
            const left=numericCompare?a:String(v),right=numericCompare?b:target;
            switch(m[1]){
              case '>':return left>right;case '<':return left<right;
              case '>=':return left>=right;case '<=':return left<=right;
              case '<>':return left!=right;default:return left==right;
            }
          };
          const sumRange=values[2]===undefined?source:
            Array.isArray(values[2])?flatten(values[2]):[values[2]];
          let result=0;
          source.forEach((v,i)=>{if(match(v))result+=fn==='COUNTIF'?1:
            (Number(sumRange[i])||0);});
          return result;
        }
        default:throw new SpreadsheetError('#NAME?');
      }
    }
    throw new SpreadsheetError('#ERROR!');
  }
  display(id,ref){
    let value;
    try{value=this.getValue(id,ref);}catch(e){value=e.code||'#ERROR!';}
    if(value===null||value===undefined)return '';
    if(typeof value==='boolean')return value?'TRUE':'FALSE';
    const style=this.getStyle(id,ref);
    if(typeof value==='number'){
      if(!Number.isFinite(value))return '#NUM!';
      if(style.format==='percent')return (value*100).toFixed(1)+'%';
      if(style.format==='currency')return '$'+value.toLocaleString('en-US',
        {minimumFractionDigits:2,maximumFractionDigits:2});
      if(style.format==='number')return value.toLocaleString('en-US',
        {maximumFractionDigits:2});
      return Number(value.toPrecision(12)).toString();
    }
    return String(value);
  }
}
