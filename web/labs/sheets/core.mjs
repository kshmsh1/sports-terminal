// Arcside Sheets core: no eval(), dynamic code execution, or external formula service.
// Storage and rendering are deliberately separate from the calculation engine.
export class CellError extends Error {
  constructor(code) { super(code); this.code = code; }
}
const LIMIT = 250000;
const ID = /^\$?([A-Z]{1,4})\$?([1-9]\d*)$/i;
export function columnName(n) {
  if (!Number.isInteger(n) || n < 1) throw new Error('Invalid column');
  let out = '';
  while (n) { n--; out = String.fromCharCode(65 + n % 26) + out; n = Math.floor(n / 26); }
  return out;
}
export function columnIndex(s) {
  let n = 0;
  for (const ch of s.toUpperCase()) n = n * 26 + ch.charCodeAt(0) - 64;
  return n;
}
export function parseRef(raw) {
  const m = ID.exec(String(raw).toUpperCase());
  if (!m) throw new CellError('#REF!');
  const row = Number(m[2]), col = columnIndex(m[1]);
  if (row > 100000 || col > 16384) throw new CellError('#REF!');
  return {row, col, ref: columnName(col) + row};
}
export function expandRange(a, b) {
  const x = parseRef(a), y = parseRef(b);
  const count = (Math.abs(x.row - y.row) + 1) * (Math.abs(x.col - y.col) + 1);
  if (count > LIMIT) throw new CellError('#REF!');
  const refs = [];
  for (let r = Math.min(x.row,y.row); r <= Math.max(x.row,y.row); r++)
    for (let c = Math.min(x.col,y.col); c <= Math.max(x.col,y.col); c++)
      refs.push(columnName(c) + r);
  return refs;
}
function lex(input) {
  const tokens = [], source = input.trim();
  let i = 0;
  while (i < source.length) {
    const rest = source.slice(i);
    if (/^\s/.test(rest)) { i++; continue; }
    let m;
    if ((m = /^'(?:[^']|'')+'!\$?[A-Za-z]{1,4}\$?[1-9]\d*/.exec(rest)) ||
        (m = /^[A-Za-z_][A-Za-z_0-9]*!\$?[A-Za-z]{1,4}\$?[1-9]\d*/.exec(rest))) {
      tokens.push({type:'ref', text:m[0]}); i += m[0].length; continue;
    }
    if ((m = /^\$?[A-Za-z]{1,4}\$?[1-9]\d*/.exec(rest))) {
      tokens.push({type:'ref',text:m[0]}); i += m[0].length; continue;
    }
    if ((m = /^\d+(?:\.\d+)?(?:[Ee][+-]?\d+)?|^\.\d+(?:[Ee][+-]?\d+)?/.exec(rest))) {
      tokens.push({type:'number',value:Number(m[0])}); i += m[0].length; continue;
    }
    if (rest[0] === '"') {
      let s = '', j = i + 1, closed = false;
      while (j < source.length) {
        if (source[j] === '"' && source[j+1] === '"') { s += '"'; j+=2; continue; }
        if (source[j] === '"') { j++; closed = true; break; }
        s += source[j++];
      }
      if (!closed) throw new CellError('#ERROR!');
      tokens.push({type:'string', value:s}); i = j; continue;
    }
    if ((m = /^[A-Za-z_][A-Za-z_0-9]*/.exec(rest))) {
      tokens.push({type:'identifier',value:m[0].toUpperCase()}); i += m[0].length; continue;
    }
    if (['>=','<=','<>'].includes(rest.slice(0,2))) {
      tokens.push({type:rest.slice(0,2)}); i+=2; continue;
    }
    if ('+-*/^&=><(),:'.includes(rest[0])) { tokens.push({type:rest[0]}); i++; continue; }
    throw new CellError('#ERROR!');
  }
  tokens.push({type:'end'});
  return tokens;
}
function splitSheetRef(text) {
  const pos = text.lastIndexOf('!');
  if (pos < 0) return {sheet:null,ref:parseRef(text).ref};
  let sheet = text.slice(0,pos);
  if (sheet[0] === "'") sheet = sheet.slice(1,-1).replace(/''/g,"'");
  return {sheet,ref:parseRef(text.slice(pos+1)).ref};
}
const PRECEDENCE = {'=':1,'<>':1,'>':1,'<':1,'>=':1,'<=':1,'&':2,'+':3,'-':3,'*':4,'/':4,'^':5};
export function parseFormula(source) {
  const tokens = lex(source), cursor = {i:0};
  const peek = () => tokens[cursor.i];
  const take = (type) => {
    if (peek().type !== type) throw new CellError('#ERROR!');
    return tokens[cursor.i++];
  };
  function atom() {
    const t = tokens[cursor.i++];
    if (t.type === 'number' || t.type === 'string') return {kind:'literal',value:t.value};
    if (t.type === 'ref') {
      const first = splitSheetRef(t.text);
      if (peek().type === ':') {
        take(':');
        const second = splitSheetRef(take('ref').text);
        if (first.sheet && second.sheet && first.sheet !== second.sheet) throw new CellError('#REF!');
        return {kind:'range',sheet:first.sheet ?? second.sheet,from:first.ref,to:second.ref};
      }
      return {kind:'ref',...first};
    }
    if (t.type === 'identifier') {
      if (t.value === 'TRUE' || t.value === 'FALSE') return {kind:'literal',value:t.value === 'TRUE'};
      if (peek().type !== '(') throw new CellError('#NAME?');
      take('(');
      const args = [];
      if (peek().type !== ')') {
        do { args.push(expression()); if (peek().type !== ',') break; take(','); } while(true);
      }
      take(')');
      return {kind:'call',name:t.value,args};
    }
    if (t.type === '+' || t.type === '-') return {kind:'unary',op:t.type,value:expression(5)};
    if (t.type === '(') { const child = expression(); take(')'); return child; }
    throw new CellError('#ERROR!');
  }
  function expression(min=0) {
    let left = atom();
    while (PRECEDENCE[peek().type] !== undefined && PRECEDENCE[peek().type] >= min) {
      const op = tokens[cursor.i++].type;
      const right = expression(PRECEDENCE[op] + (op === '^' ? 0 : 1));
      left = {kind:'binary',op,left,right};
    }
    return left;
  }
  const tree = expression();
  if (peek().type !== 'end') throw new CellError('#ERROR!');
  return tree;
}
function collect(node,sheet,output) {
  if (node.kind === 'ref') output.add((node.sheet ?? sheet) + '!' + node.ref);
  if (node.kind === 'range') for (const ref of expandRange(node.from,node.to))
    output.add((node.sheet ?? sheet) + '!' + ref);
  if (node.kind === 'unary') collect(node.value,sheet,output);
  if (node.kind === 'binary') { collect(node.left,sheet,output); collect(node.right,sheet,output); }
  if (node.kind === 'call') for (const arg of node.args) collect(arg,sheet,output);
}
const flatten = (values) => values.flat(Infinity);
const numbers = (values) => flatten(values).filter(v => v !== '' && v !== null && v !== undefined && v !== false && v !== true && !isNaN(Number(v))).map(Number);
function num(value) {
  if (Array.isArray(value)) throw new CellError('#VALUE!');
  if (value === null || value === '') return 0;
  if (typeof value === 'boolean') return value ? 1 : 0;
  const n = Number(value);
  if (!Number.isFinite(n)) throw new CellError('#VALUE!');
  return n;
}
function truth(value) { return Array.isArray(value) ? value.length > 0 : Boolean(value); }
function assertFinite(n) { if (!Number.isFinite(n)) throw new CellError('#NUM!'); return n; }
function aggregate(name,args) {
  const arr=flatten(args), ns=numbers(args);
  switch(name) {
    case 'SUM': return ns.reduce((a,b)=>a+b,0);
    case 'AVERAGE': case 'AVG': return ns.length ? ns.reduce((a,b)=>a+b,0)/ns.length : new CellError('#DIV/0!');
    case 'MIN': return ns.length ? ns.reduce((a,b)=>a<b?a:b) : 0;
    case 'MAX': return ns.length ? ns.reduce((a,b)=>a>b?a:b) : 0;
    case 'COUNT': return ns.length;
    case 'PRODUCT': return ns.reduce((a,b)=>a*b,1);
    case 'COUNTA': return arr.filter(v=>v!==null && v!=='').length;
    case 'MEDIAN': {
      if (!ns.length) return new CellError('#NUM!');
      ns.sort((a,b)=>a-b);
      const m=Math.floor(ns.length/2);
      return ns.length%2 ? ns[m] : (ns[m-1]+ns[m])/2;
    }
    case 'STDEV': {
      if(ns.length<2) return new CellError('#DIV/0!');
      const mean=ns.reduce((a,b)=>a+b,0)/ns.length;
      return Math.sqrt(ns.reduce((a,b)=>a+(b-mean)**2,0)/(ns.length-1));
    }
    default: throw new CellError('#NAME?');
  }
}
function isMatch(value,criteria) {
  const raw=String(criteria??'');
  const m=/^(<=|>=|<>|=|<|>)(.*)$/.exec(raw);
  const op=m?.[1]??'=',target=m?m[2]:raw;
  const numeric=(v)=>v!==null&&v!==''&&!isNaN(Number(v));
  let left=value,right=target;
  if(numeric(left)&&numeric(right)) {
    left=Number(left);right=Number(right);
  }else{
    left=String(left??'').toLowerCase();
    right=String(right??'').toLowerCase();
    if((target.includes('*')||target.includes('?'))&&(op==='='||op==='<>')) {
      const escaped=target.replace(/[.+^$()|[\]\\]/g,'\\function resolve(node, book, sheet, stack) {')
        .replace(/\*/g,'.*').replace(/\?/g,'.');
      const hit=new RegExp('^'+escaped+'
  switch(node.kind) {
    case 'literal': return node.value;
    case 'ref': return book.value(node.sheet ?? sheet,node.ref,stack);
    case 'range': return expandRange(node.from,node.to).map(ref=>book.value(node.sheet ?? sheet,ref,stack));
    case 'unary': return node.op === '-' ? -num(resolve(node.value,book,sheet,stack)) : num(resolve(node.value,book,sheet,stack));
    case 'binary': {
      const a=resolve(node.left,book,sheet,stack), b=resolve(node.right,book,sheet,stack);
      switch(node.op) {
        case '+': return assertFinite(num(a)+num(b));
        case '-': return assertFinite(num(a)-num(b));
        case '*': return assertFinite(num(a)*num(b));
        case '/': if(num(b)===0) throw new CellError('#DIV/0!'); return num(a)/num(b);
        case '^': return assertFinite(num(a)**num(b));
        case '&': return String(a ?? '') + String(b ?? '');
        case '=': return a==b; // Spreadsheet-style numeric/string coercion.
        case '<>': return a!=b;
        case '>': return a>b; case '<': return a<b;
        case '>=': return a>=b; case '<=': return a<=b;
      }
      throw new CellError('#ERROR!');
    }
    case 'call': {
      const name=node.name;
      if(name==='IF') return truth(resolve(node.args[0],book,sheet,stack))
        ? (node.args[1] ? resolve(node.args[1],book,sheet,stack) : true)
        : (node.args[2] ? resolve(node.args[2],book,sheet,stack) : false);
      if(name==='IFERROR'||name==='IFNA') {
        try { return resolve(node.args[0],book,sheet,stack); }
        catch(e) { if(name==='IFNA'&&e?.code!=='#N/A')throw e;
          return node.args[1] ? resolve(node.args[1],book,sheet,stack) : ''; }
      }
      if(name==='AND') return node.args.every(x=>truth(resolve(x,book,sheet,stack)));
      if(name==='OR') return node.args.some(x=>truth(resolve(x,book,sheet,stack)));
      if(name==='NOT') return !truth(resolve(node.args[0],book,sheet,stack));
      const a=node.args.map(x=>resolve(x,book,sheet,stack));
      if(['COUNTIF','SUMIF','AVERAGEIF','COUNTIFS','SUMIFS'].includes(name)){
        const value=criteriaAggregate(name,a);
        if(value instanceof CellError)throw value;
        return value;
      }
      if(['SUM','AVERAGE','AVG','MIN','MAX','COUNT','COUNTA','MEDIAN','STDEV','PRODUCT'].includes(name)) {
        const result=aggregate(name,a);
        if(result instanceof CellError) throw result;
        return result;
      }
      switch(name) {
        case 'ABS': return Math.abs(num(a[0]));
        case 'ROUND': return roundExcel(a[0],a[1]??0);
        case 'ROUNDUP': return roundExcel(a[0],a[1]??0,'up');
        case 'ROUNDDOWN': return roundExcel(a[0],a[1]??0,'down');
        case 'SQRT': return assertFinite(Math.sqrt(num(a[0])));
        case 'POWER': return assertFinite(num(a[0])**num(a[1]));
        case 'MOD': if(num(a[1])===0) throw new CellError('#DIV/0!'); return num(a[0])%num(a[1]);
        case 'LEN': return String(a[0]??'').length;
        case 'LEFT': return String(a[0]??'').slice(0,Math.max(0,num(a[1]??1)));
        case 'RIGHT': { const length=Math.max(0,num(a[1]??1));return length?String(a[0]??'').slice(-length):''; }
        case 'UPPER': return String(a[0]??'').toUpperCase();
        case 'LOWER': return String(a[0]??'').toLowerCase();
        case 'TRIM': return String(a[0]??'').trim().replace(/\s+/g,' ');
        case 'CONCAT': case 'CONCATENATE': return flatten(a).map(v=>String(v??'')).join('');
        case 'MID': return String(a[0]??'').slice(Math.max(0,num(a[1])-1),Math.max(0,num(a[1])-1)+Math.max(0,num(a[2])));
        case 'FIND': { const pos=String(a[1]??'').indexOf(String(a[0]??''),Math.max(0,num(a[2]??1)-1));if(pos<0)throw new CellError('#VALUE!');return pos+1; }
        case 'SEARCH': {const pos=String(a[1]??'').toLowerCase().indexOf(String(a[0]??'').toLowerCase(),Math.max(0,num(a[2]??1)-1));return pos<0?new CellError('#VALUE!'):pos+1;}
        case 'SUBSTITUTE': return String(a[0]??'').split(String(a[1]??'')).join(String(a[2]??''));
        case 'VALUE': return num(a[0]);
        case 'ISNUMBER': return typeof a[0]==='number';
        case 'ISTEXT': return typeof a[0]==='string';
        case 'ISBLANK': return a[0]===null||a[0]==='';
        case 'NA': throw new CellError('#N/A');
        case 'MATCH':{
          if(a[2]!==undefined&&num(a[2])!==0)throw new CellError('#N/A');
          const entries=requireArray(a[1]),found=entries.findIndex(v=>sameValue(v,a[0]));
          if(found<0)throw new CellError('#N/A');
          return found+1;
        }
        case 'INDEX':{
          const entries=requireArray(a[0]),dim=dimension(node.args[0]);
          const row=num(a[1]),col=num(a[2]??1);
          if(row<1||col<1||row>dim.rows||col>dim.cols)throw new CellError('#REF!');
          return entries[(row-1)*dim.cols+col-1];
        }
        case 'VLOOKUP':{
          if(a[3]!==undefined&&truth(a[3]))throw new CellError('#N/A');
          const entries=requireArray(a[1]),dim=dimension(node.args[1]);
          const col=num(a[2]);
          if(col<1||col>dim.cols)throw new CellError('#REF!');
          for(let row=0;row<dim.rows;row++){
            if(sameValue(entries[row*dim.cols],a[0]))return entries[row*dim.cols+col-1];
          }
          throw new CellError('#N/A');
        }
        case 'XLOOKUP':{
          const lookup=requireArray(a[1]),results=requireArray(a[2]);
          if(lookup.length!==results.length)throw new CellError('#VALUE!');
          const found=lookup.findIndex(v=>sameValue(v,a[0]));
          if(found>=0)return results[found];
          if(a.length>3)return a[3];
          throw new CellError('#N/A');
        }
        default: throw new CellError('#NAME?');
      }
    }
  }
  throw new CellError('#ERROR!');
}
function toPrimitive(raw) {
  if(raw==='') return null;
  if (/^(true|false)$/i.test(raw)) return raw.toLowerCase()==='true';
  if (/^[+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?$/i.test(raw)) return Number(raw);
  return raw;
}
export class Workbook {
  constructor(data) {
    this.sheets=new Map(); this.cache=new Map(); this.deps=new Map(); this.reverse=new Map(); this.trees=new Map();
    this.active='';
    const input=data && data.version===1 && Array.isArray(data.sheets) ? data.sheets : [{name:'Sheet1',cells:{},styles:{},widths:{}}];
    for(const item of input) this._addRaw(item.name,item);
    if(!this.sheets.size) this._addRaw('Sheet1',{});
    this.active=this.sheets.has(data?.active) ? data.active : this.sheets.keys().next().value;
    this._rebuild();
  }
  _addRaw(name,record) {
    if(!name || this.sheets.has(name) || name.includes('!') || name.length>48) return;
    const cells={},styles={},widths={};
    for(const [ref,raw] of Object.entries(record.cells??{})) {
      try { const key=parseRef(ref).ref; if(String(raw).length<=10000) cells[key]=String(raw); } catch {}
    }
    for(const [ref,value] of Object.entries(record.styles??{})) styles[ref]={...value};
    for(const [col,width] of Object.entries(record.widths??{})) if(Number(width)>=55 && Number(width)<=420) widths[col]=Number(width);
    this.sheets.set(name,{name,cells,styles,widths});
  }
  _key(sheet,ref) { return sheet+'!'+parseRef(ref).ref; }
  _rebuild() {
    this.cache.clear(); this.deps.clear(); this.reverse.clear(); this.trees.clear();
    for(const [sheet,data] of this.sheets) for(const [ref,raw] of Object.entries(data.cells))
      this._link(this._key(sheet,ref),raw,sheet);
  }
  _link(key,raw,sheet) {
    const previous=this.deps.get(key)??new Set();
    for(const dep of previous) this.reverse.get(dep)?.delete(key);
    this.deps.delete(key); this.trees.delete(key);
    if(!raw.startsWith('=')) return;
    try {
      const tree=parseFormula(raw.slice(1)), deps=new Set();
      collect(tree,sheet,deps); this.trees.set(key,tree); this.deps.set(key,deps);
      for(const dep of deps) {
        if(!this.reverse.has(dep)) this.reverse.set(dep,new Set());
        this.reverse.get(dep).add(key);
      }
    } catch(e) { this.trees.set(key,e instanceof CellError ? e : new CellError('#ERROR!')); }
  }
  _invalidate(key) {
    const pending=[key],seen=new Set();
    while(pending.length) {
      const id=pending.pop();
      if(seen.has(id)) continue;
      seen.add(id); this.cache.delete(id);
      for(const dependent of this.reverse.get(id)??[]) pending.push(dependent);
    }
  }
  addSheet(name) {
    name=String(name).trim();
    if(!name || name.includes('!') || this.sheets.has(name) || this.sheets.size>=32) throw new Error('Invalid or duplicate sheet name');
    this._addRaw(name,{}); this.active=name; return name;
  }
  renameSheet(oldName,newName) {
    newName=String(newName).trim();
    if(!this.sheets.has(oldName) || !newName || newName.includes('!') || this.sheets.has(newName)) throw new Error('Invalid sheet name');
    const item=this.sheets.get(oldName);
    this.sheets.delete(oldName); item.name=newName; this.sheets.set(newName,item);
    if(this.active===oldName) this.active=newName;
    // Text formulas referencing renamed sheets must also change.
    const escaped=oldName.replace(/[.*+?^$()|[\]{}\\]/g,'\\$&');
    const direct=new RegExp('\\b'+escaped+'!', 'gi');
    const quoted=new RegExp("'"+escaped.replace(/'/g,"''")+"'!",'gi');
    for(const data of this.sheets.values()) for(const [ref,raw] of Object.entries(data.cells)) {
      if(raw.startsWith('=')) data.cells[ref]=raw.replace(quoted,"'"+newName.replace(/'/g,"''")+"'!")
        .replace(direct,(newName.includes(' ') ? "'"+newName+"'" : newName)+'!');
    }
    this._rebuild();
  }
  deleteSheet(name) {
    if(this.sheets.size<=1) throw new Error('At least one sheet is required');
    this.sheets.delete(name);
    if(this.active===name) this.active=this.sheets.keys().next().value;
    this._rebuild();
  }
  get(sheet,ref) { return this.sheets.get(sheet)?.cells[parseRef(ref).ref]??''; }
  set(sheet,ref,raw) {
    const data=this.sheets.get(sheet);
    if(!data) throw new CellError('#REF!');
    const id=parseRef(ref).ref, value=String(raw??'');
    if(value.length>10000) throw new Error('Cell content too large');
    if(value) data.cells[id]=value;
    else delete data.cells[id];
    const key=this._key(sheet,id);
    this._link(key,value,sheet); this._invalidate(key);
  }
  value(sheet,ref,stack=new Set()) {
    const key=this._key(sheet,ref);
    if(!this.sheets.has(sheet)) throw new CellError('#REF!');
    if(stack.has(key)) throw new CellError('#CYCLE!');
    if(this.cache.has(key)) {
      const hit=this.cache.get(key); if(hit instanceof CellError) throw hit;
      return hit;
    }
    const raw=this.get(sheet,ref);
    if(!raw.startsWith('=')) { const out=toPrimitive(raw); this.cache.set(key,out); return out; }
    stack.add(key);
    try {
      const tree=this.trees.get(key) ?? parseFormula(raw.slice(1));
      if(tree instanceof Error) throw tree;
      const value=resolve(tree,this,sheet,stack);
      this.cache.set(key,value); return value;
    } catch(e) {
      const error=e instanceof CellError ? e : new CellError('#ERROR!');
      this.cache.set(key,error); throw error;
    } finally { stack.delete(key); }
  }
  display(sheet,ref) {
    try {
      const value=this.value(sheet,ref);
      if(value===null) return '';
      if(typeof value==='boolean') return value?'TRUE':'FALSE';
      if(typeof value==='number') return Number.isInteger(value)?String(value):Number(value.toPrecision(11)).toString();
      return String(value);
    } catch(e) { return e instanceof CellError ? e.code : '#ERROR!'; }
  }
  setStyle(sheet,ref,patch) {
    const data=this.sheets.get(sheet); if(!data) return;
    const id=parseRef(ref).ref;
    data.styles[id]={...(data.styles[id]??{}),...patch};
  }
  toJSON() {
    return {version:1,active:this.active,sheets:[...this.sheets.values()].map(s=>({
      name:s.name,cells:{...s.cells},styles:{...s.styles},widths:{...s.widths}
    }))};
  }
}
export function parseCsv(text) {
  const rows=[]; let row=[],cell='',quoted=false;
  for(let i=0;i<text.length;i++) {
    const ch=text[i];
    if(ch==='"') {
      if(quoted && text[i+1]==='"') { cell+='"'; i++; } else quoted=!quoted;
    } else if(ch===',' && !quoted) { row.push(cell);cell=''; }
    else if((ch==='\r'||ch==='\n') && !quoted) {
      if(ch==='\r' && text[i+1]==='\n') i++;
      row.push(cell); rows.push(row); row=[];cell='';
    } else cell+=ch;
  }
  if(cell.length || row.length) { row.push(cell); rows.push(row); }
  return rows;
}
export function stringifyCsv(rows) {
  return rows.map(row=>row.map(v=>{
    const s=String(v??'');
    return /[,"\n\r]/.test(s) ? '"'+s.replace(/"/g,'""')+'"' : s;
  }).join(',')).join('\r\n');
}
export function sampleWorkbook() {
  const wb=new Workbook(); wb.renameSheet('Sheet1','Analysis');
  const rows=[
    ['Company','Revenue','Cost','Profit','Margin'],
    ['Alpha',120000,82000,'=B2-C2','=IFERROR(D2/B2,0)'],
    ['Beta',98500,60300,'=B3-C3','=IFERROR(D3/B3,0)'],
    ['Gamma',156000,112000,'=B4-C4','=IFERROR(D4/B4,0)'],
    ['Delta',81000,47500,'=B5-C5','=IFERROR(D5/B5,0)'],
    ['TOTAL','=SUM(B2:B5)','=SUM(C2:C5)','=SUM(D2:D5)','=IFERROR(D6/B6,0)']
  ];
  rows.forEach((row,r)=>row.forEach((v,c)=>wb.set('Analysis',columnName(c+1)+(r+1),v)));
  for(let c=1;c<=5;c++) wb.setStyle('Analysis',columnName(c)+'1',{bold:true,fill:'#1d384e',color:'#ffffff'});
  for(let c=1;c<=5;c++) wb.setStyle('Analysis',columnName(c)+'6',{bold:true,fill:'#1a342b',color:'#a7f3d0'});
  wb.sheets.get('Analysis').widths.A=160;
  return wb;
}
,'i').test(String(value??''));
      return op==='='?hit:!hit;
    }
  }
  switch(op){
    case '=':return left===right;
    case '<>':return left!==right;
    case '>':return left>right;
    case '<':return left<right;
    case '>=':return left>=right;
    case '<=':return left<=right;
    default:return false;
  }
}
function sameValue(a,b){
  if(typeof a==='string'&&typeof b==='string')return a.toLowerCase()===b.toLowerCase();
  return a===b||(a!==null&&b!==null&&a!==''&&b!==''&&!isNaN(Number(a))&&!isNaN(Number(b))&&Number(a)===Number(b));
}
function requireArray(v){
  if(!Array.isArray(v))throw new CellError('#VALUE!');
  return flatten(v);
}
function dimension(node){
  if(node?.kind!=='range')return {rows:1,cols:1};
  const a=parseRef(node.from),b=parseRef(node.to);
  return {rows:Math.abs(a.row-b.row)+1,cols:Math.abs(a.col-b.col)+1};
}
function roundExcel(value,places=0,mode='nearest'){
  const n=num(value),digits=num(places);
  if(Math.abs(digits)>15)throw new CellError('#NUM!');
  const factor=10**digits,absolute=Math.abs(n)*factor;
  const epsilon=Math.max(1,absolute)*1e-12;
  const rounded=mode==='up'?Math.ceil(absolute-epsilon):mode==='down'
    ?Math.floor(absolute+epsilon):Math.floor(absolute+0.5+epsilon);
  return assertFinite(Math.sign(n)*rounded/factor);
}
function criteriaAggregate(name,args){
  if(name==='COUNTIF'||name==='SUMIF'||name==='AVERAGEIF'){
    const criterionArray=requireArray(args[0]),criterion=args[1];
    const values=name==='COUNTIF'?criterionArray:requireArray(args[2]??args[0]);
    if(values.length!==criterionArray.length)throw new CellError('#VALUE!');
    let count=0,sum=0;
    for(let i=0;i<criterionArray.length;i++){
      if(!isMatch(criterionArray[i],criterion))continue;
      if(name==='COUNTIF'){count++;continue;}
      const value=values[i];
      if(value!==null&&value!==''&&!isNaN(Number(value))){sum+=Number(value);count++;}
    }
    return name==='COUNTIF'?count:name==='SUMIF'?sum:count?sum/count:new CellError('#DIV/0!');
  }
  const sum=name==='SUMIFS';
  const start=sum?1:0;
  if(args.length<=start||(args.length-start)%2!==0)throw new CellError('#VALUE!');
  const columns=[],criteria=[];
  for(let i=start;i<args.length;i+=2){
    columns.push(requireArray(args[i]));criteria.push(args[i+1]);
  }
  const total=columns[0].length;
  if(columns.some(v=>v.length!==total))throw new CellError('#VALUE!');
  const amounts=sum?requireArray(args[0]):[];
  if(sum&&amounts.length!==total)throw new CellError('#VALUE!');
  let result=0;
  for(let i=0;i<total;i++){
    if(!columns.every((column,j)=>isMatch(column[i],criteria[j])))continue;
    if(sum){
      const v=amounts[i];if(v!==null&&v!==''&&!isNaN(Number(v)))result+=Number(v);
    }else result++;
  }
  return result;
}
function resolve(node, book, sheet, stack) {
  switch(node.kind) {
    case 'literal': return node.value;
    case 'ref': return book.value(node.sheet ?? sheet,node.ref,stack);
    case 'range': return expandRange(node.from,node.to).map(ref=>book.value(node.sheet ?? sheet,ref,stack));
    case 'unary': return node.op === '-' ? -num(resolve(node.value,book,sheet,stack)) : num(resolve(node.value,book,sheet,stack));
    case 'binary': {
      const a=resolve(node.left,book,sheet,stack), b=resolve(node.right,book,sheet,stack);
      switch(node.op) {
        case '+': return assertFinite(num(a)+num(b));
        case '-': return assertFinite(num(a)-num(b));
        case '*': return assertFinite(num(a)*num(b));
        case '/': if(num(b)===0) throw new CellError('#DIV/0!'); return num(a)/num(b);
        case '^': return assertFinite(num(a)**num(b));
        case '&': return String(a ?? '') + String(b ?? '');
        case '=': return a==b; // Spreadsheet-style numeric/string coercion.
        case '<>': return a!=b;
        case '>': return a>b; case '<': return a<b;
        case '>=': return a>=b; case '<=': return a<=b;
      }
      throw new CellError('#ERROR!');
    }
    case 'call': {
      const name=node.name;
      if(name==='IF') return truth(resolve(node.args[0],book,sheet,stack))
        ? (node.args[1] ? resolve(node.args[1],book,sheet,stack) : true)
        : (node.args[2] ? resolve(node.args[2],book,sheet,stack) : false);
      if(name==='IFERROR') {
        try { return resolve(node.args[0],book,sheet,stack); }
        catch(e) { return node.args[1] ? resolve(node.args[1],book,sheet,stack) : ''; }
      }
      if(name==='AND') return node.args.every(x=>truth(resolve(x,book,sheet,stack)));
      if(name==='OR') return node.args.some(x=>truth(resolve(x,book,sheet,stack)));
      if(name==='NOT') return !truth(resolve(node.args[0],book,sheet,stack));
      const a=node.args.map(x=>resolve(x,book,sheet,stack));
      if(['SUM','AVERAGE','AVG','MIN','MAX','COUNT','COUNTA','MEDIAN','STDEV'].includes(name)) {
        const result=aggregate(name,a);
        if(result instanceof CellError) throw result;
        return result;
      }
      switch(name) {
        case 'ABS': return Math.abs(num(a[0]));
        case 'ROUND': { const pow=10**num(a[1]??0); return Math.round(num(a[0])*pow)/pow; }
        case 'ROUNDUP': { const pow=10**num(a[1]??0); return Math.ceil(num(a[0])*pow)/pow; }
        case 'ROUNDDOWN': { const pow=10**num(a[1]??0); return Math.floor(num(a[0])*pow)/pow; }
        case 'SQRT': return assertFinite(Math.sqrt(num(a[0])));
        case 'POWER': return assertFinite(num(a[0])**num(a[1]));
        case 'MOD': if(num(a[1])===0) throw new CellError('#DIV/0!'); return num(a[0])%num(a[1]);
        case 'LEN': return String(a[0]??'').length;
        case 'LEFT': return String(a[0]??'').slice(0,Math.max(0,num(a[1]??1)));
        case 'RIGHT': return String(a[0]??'').slice(-Math.max(0,num(a[1]??1)));
        case 'UPPER': return String(a[0]??'').toUpperCase();
        case 'LOWER': return String(a[0]??'').toLowerCase();
        case 'TRIM': return String(a[0]??'').trim().replace(/\s+/g,' ');
        case 'CONCAT': return flatten(a).map(v=>String(v??'')).join('');
        default: throw new CellError('#NAME?');
      }
    }
  }
  throw new CellError('#ERROR!');
}
function toPrimitive(raw) {
  if(raw==='') return null;
  if (/^(true|false)$/i.test(raw)) return raw.toLowerCase()==='true';
  if (/^[+-]?(?:\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?$/i.test(raw)) return Number(raw);
  return raw;
}
export class Workbook {
  constructor(data) {
    this.sheets=new Map(); this.cache=new Map(); this.deps=new Map(); this.reverse=new Map(); this.trees=new Map();
    this.active='';
    const input=data && data.version===1 && Array.isArray(data.sheets) ? data.sheets : [{name:'Sheet1',cells:{},styles:{},widths:{}}];
    for(const item of input) this._addRaw(item.name,item);
    if(!this.sheets.size) this._addRaw('Sheet1',{});
    this.active=this.sheets.has(data?.active) ? data.active : this.sheets.keys().next().value;
    this._rebuild();
  }
  _addRaw(name,record) {
    if(!name || this.sheets.has(name) || name.includes('!') || name.length>48) return;
    const cells={},styles={},widths={};
    for(const [ref,raw] of Object.entries(record.cells??{})) {
      try { const key=parseRef(ref).ref; if(String(raw).length<=10000) cells[key]=String(raw); } catch {}
    }
    for(const [ref,value] of Object.entries(record.styles??{})) styles[ref]={...value};
    for(const [col,width] of Object.entries(record.widths??{})) if(Number(width)>=55 && Number(width)<=420) widths[col]=Number(width);
    this.sheets.set(name,{name,cells,styles,widths});
  }
  _key(sheet,ref) { return sheet+'!'+parseRef(ref).ref; }
  _rebuild() {
    this.cache.clear(); this.deps.clear(); this.reverse.clear(); this.trees.clear();
    for(const [sheet,data] of this.sheets) for(const [ref,raw] of Object.entries(data.cells))
      this._link(this._key(sheet,ref),raw,sheet);
  }
  _link(key,raw,sheet) {
    const previous=this.deps.get(key)??new Set();
    for(const dep of previous) this.reverse.get(dep)?.delete(key);
    this.deps.delete(key); this.trees.delete(key);
    if(!raw.startsWith('=')) return;
    try {
      const tree=parseFormula(raw.slice(1)), deps=new Set();
      collect(tree,sheet,deps); this.trees.set(key,tree); this.deps.set(key,deps);
      for(const dep of deps) {
        if(!this.reverse.has(dep)) this.reverse.set(dep,new Set());
        this.reverse.get(dep).add(key);
      }
    } catch(e) { this.trees.set(key,e instanceof CellError ? e : new CellError('#ERROR!')); }
  }
  _invalidate(key) {
    const pending=[key],seen=new Set();
    while(pending.length) {
      const id=pending.pop();
      if(seen.has(id)) continue;
      seen.add(id); this.cache.delete(id);
      for(const dependent of this.reverse.get(id)??[]) pending.push(dependent);
    }
  }
  addSheet(name) {
    name=String(name).trim();
    if(!name || name.includes('!') || this.sheets.has(name) || this.sheets.size>=32) throw new Error('Invalid or duplicate sheet name');
    this._addRaw(name,{}); this.active=name; return name;
  }
  renameSheet(oldName,newName) {
    newName=String(newName).trim();
    if(!this.sheets.has(oldName) || !newName || newName.includes('!') || this.sheets.has(newName)) throw new Error('Invalid sheet name');
    const item=this.sheets.get(oldName);
    this.sheets.delete(oldName); item.name=newName; this.sheets.set(newName,item);
    if(this.active===oldName) this.active=newName;
    // Text formulas referencing renamed sheets must also change.
    const escaped=oldName.replace(/[.*+?^$()|[\]{}\\]/g,'\\$&');
    const direct=new RegExp('\\b'+escaped+'!', 'gi');
    const quoted=new RegExp("'"+escaped.replace(/'/g,"''")+"'!",'gi');
    for(const data of this.sheets.values()) for(const [ref,raw] of Object.entries(data.cells)) {
      if(raw.startsWith('=')) data.cells[ref]=raw.replace(quoted,"'"+newName.replace(/'/g,"''")+"'!")
        .replace(direct,(newName.includes(' ') ? "'"+newName+"'" : newName)+'!');
    }
    this._rebuild();
  }
  deleteSheet(name) {
    if(this.sheets.size<=1) throw new Error('At least one sheet is required');
    this.sheets.delete(name);
    if(this.active===name) this.active=this.sheets.keys().next().value;
    this._rebuild();
  }
  get(sheet,ref) { return this.sheets.get(sheet)?.cells[parseRef(ref).ref]??''; }
  set(sheet,ref,raw) {
    const data=this.sheets.get(sheet);
    if(!data) throw new CellError('#REF!');
    const id=parseRef(ref).ref, value=String(raw??'');
    if(value.length>10000) throw new Error('Cell content too large');
    if(value) data.cells[id]=value;
    else delete data.cells[id];
    const key=this._key(sheet,id);
    this._link(key,value,sheet); this._invalidate(key);
  }
  value(sheet,ref,stack=new Set()) {
    const key=this._key(sheet,ref);
    if(!this.sheets.has(sheet)) throw new CellError('#REF!');
    if(stack.has(key)) throw new CellError('#CYCLE!');
    if(this.cache.has(key)) {
      const hit=this.cache.get(key); if(hit instanceof CellError) throw hit;
      return hit;
    }
    const raw=this.get(sheet,ref);
    if(!raw.startsWith('=')) { const out=toPrimitive(raw); this.cache.set(key,out); return out; }
    stack.add(key);
    try {
      const tree=this.trees.get(key) ?? parseFormula(raw.slice(1));
      if(tree instanceof Error) throw tree;
      const value=resolve(tree,this,sheet,stack);
      this.cache.set(key,value); return value;
    } catch(e) {
      const error=e instanceof CellError ? e : new CellError('#ERROR!');
      this.cache.set(key,error); throw error;
    } finally { stack.delete(key); }
  }
  display(sheet,ref) {
    try {
      const value=this.value(sheet,ref);
      if(value===null) return '';
      if(typeof value==='boolean') return value?'TRUE':'FALSE';
      if(typeof value==='number') return Number.isInteger(value)?String(value):Number(value.toPrecision(11)).toString();
      return String(value);
    } catch(e) { return e instanceof CellError ? e.code : '#ERROR!'; }
  }
  setStyle(sheet,ref,patch) {
    const data=this.sheets.get(sheet); if(!data) return;
    const id=parseRef(ref).ref;
    data.styles[id]={...(data.styles[id]??{}),...patch};
  }
  toJSON() {
    return {version:1,active:this.active,sheets:[...this.sheets.values()].map(s=>({
      name:s.name,cells:{...s.cells},styles:{...s.styles},widths:{...s.widths}
    }))};
  }
}
export function parseCsv(text) {
  const rows=[]; let row=[],cell='',quoted=false;
  for(let i=0;i<text.length;i++) {
    const ch=text[i];
    if(ch==='"') {
      if(quoted && text[i+1]==='"') { cell+='"'; i++; } else quoted=!quoted;
    } else if(ch===',' && !quoted) { row.push(cell);cell=''; }
    else if((ch==='\r'||ch==='\n') && !quoted) {
      if(ch==='\r' && text[i+1]==='\n') i++;
      row.push(cell); rows.push(row); row=[];cell='';
    } else cell+=ch;
  }
  if(cell.length || row.length) { row.push(cell); rows.push(row); }
  return rows;
}
export function stringifyCsv(rows) {
  return rows.map(row=>row.map(v=>{
    const s=String(v??'');
    return /[,"\n\r]/.test(s) ? '"'+s.replace(/"/g,'""')+'"' : s;
  }).join(',')).join('\r\n');
}
export function sampleWorkbook() {
  const wb=new Workbook(); wb.renameSheet('Sheet1','Analysis');
  const rows=[
    ['Company','Revenue','Cost','Profit','Margin'],
    ['Alpha',120000,82000,'=B2-C2','=IFERROR(D2/B2,0)'],
    ['Beta',98500,60300,'=B3-C3','=IFERROR(D3/B3,0)'],
    ['Gamma',156000,112000,'=B4-C4','=IFERROR(D4/B4,0)'],
    ['Delta',81000,47500,'=B5-C5','=IFERROR(D5/B5,0)'],
    ['TOTAL','=SUM(B2:B5)','=SUM(C2:C5)','=SUM(D2:D5)','=IFERROR(D6/B6,0)']
  ];
  rows.forEach((row,r)=>row.forEach((v,c)=>wb.set('Analysis',columnName(c+1)+(r+1),v)));
  for(let c=1;c<=5;c++) wb.setStyle('Analysis',columnName(c)+'1',{bold:true,fill:'#1d384e',color:'#ffffff'});
  for(let c=1;c<=5;c++) wb.setStyle('Analysis',columnName(c)+'6',{bold:true,fill:'#1a342b',color:'#a7f3d0'});
  wb.sheets.get('Analysis').widths.A=160;
  return wb;
}
