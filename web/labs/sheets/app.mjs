import {Workbook,parseRef,columnName,columnIndex,parseCsv,stringifyCsv,sampleWorkbook,expandRange} from './core.mjs';
import {importXlsx,exportXlsx} from './xlsx.mjs';
import {rebaseFormula} from './references.mjs';
import {buildPivot,filterTable} from './analytics.mjs';
import {loadWorkbook,storeWorkbook} from './storage.mjs';

const $=id=>document.getElementById(id);
const ROW_HEIGHT=28, HEADER_HEIGHT=28, DEFAULT_WIDTH=112, MAX_ROWS=100000, MAX_COLS=256;
const STORAGE='arcside.sheets.v1';
let book, name='Analysis Workbook', selected={r:1,c:1}, anchor={r:1,c:1};
let edit=false, dragging=false, history=[], future=[], raf=false, dirty=false;
let internalClipboard=null;
function restore() {
  try {
    const data=JSON.parse(localStorage.getItem(STORAGE));
    if(data?.workbook) { book=new Workbook(data.workbook); name=data.name??name; return; }
  } catch(e) { console.warn('Saved workbook could not be loaded',e); }
  book=sampleWorkbook();
}
restore();
$('workbookName').value=name;
let editRevision=0,saveRevision=0,saveQueue=Promise.resolve();
async function loadDurableWorkbook(){
  try{
    const data=await loadWorkbook();
    if(!data?.workbook||editRevision!==0)return;
    book=new Workbook(data.workbook);
    name=data.name??name;
    $('workbookName').value=name;
    requestRender();
  }catch(error){console.warn('IndexedDB restore unavailable; using local workbook',error);}
}
void loadDurableWorkbook();
function persist() {
  const revision=++saveRevision;
  const state={name,workbook:book.toJSON()};
  let fallback=false;
  try{
    const serialized=JSON.stringify(state);
    if(serialized.length<=2500000){
      localStorage.setItem(STORAGE,serialized);
      fallback=true;
    }else localStorage.removeItem(STORAGE);
  }catch(error){console.warn('Local storage is full; relying on IndexedDB',error);}
  saveQueue=saveQueue.catch(()=>{}).then(()=>storeWorkbook(state)).then(()=>{
    if(revision===saveRevision)$('saveStatus').textContent='Saved locally · IndexedDB';
  }).catch(error=>{
    console.warn('IndexedDB save unavailable',error);
    if(revision===saveRevision)$('saveStatus').textContent=fallback?'Saved locally · limited storage':'Storage full — export workbook';
  });
  return saveQueue;
}
let saveTimer;
function changed() {
  editRevision++;
  dirty=true;$('saveStatus').textContent='Saving…';
  clearTimeout(saveTimer);saveTimer=setTimeout(persist,350);requestRender();
}
function snapshot() {
  const current=JSON.stringify(book.toJSON());
  history.push(current);
  const budget=current.length>6000000?4:current.length>1000000?12:60;
  while(history.length>budget)history.shift();
  future=[];
  $('undo').disabled=false;$('redo').disabled=true;
}
function restoreHistory(target,other) {
  if(!target.length)return;
  other.push(JSON.stringify(book.toJSON()));
  book=new Workbook(JSON.parse(target.pop()));
  $('undo').disabled=!history.length;$('redo').disabled=!future.length;
  changed();
}
$('undo').onclick=()=>restoreHistory(history,future);
$('redo').onclick=()=>restoreHistory(future,history);
$('undo').disabled=true;$('redo').disabled=true;
$('workbookName').onchange=e=>{name=e.target.value.trim()||'Untitled workbook'; changed();};
function colWidth(c) {return book.sheets.get(book.active)?.widths?.[columnName(c)]??DEFAULT_WIDTH;}
function columnMetrics() {
  const offsets=[0];
  for(let c=1;c<=MAX_COLS;c++) offsets[c]=offsets[c-1]+colWidth(c);
  return offsets;
}
const scroll=$('gridScroll'), layer=$('cells'), columns=$('columnHeaders'), rows=$('rowHeaders');
function bounds() {
  return {a:Math.min(anchor.r,selected.r),b:Math.max(anchor.r,selected.r),
    l:Math.min(anchor.c,selected.c),r:Math.max(anchor.c,selected.c)};
}
function ref(r,c) {return columnName(c)+r;}
function selectedRef() {return ref(selected.r,selected.c);}
function valueText(r,c) {
  const id=ref(r,c), txt=book.display(book.active,id);
  const format=book.sheets.get(book.active)?.styles[id]?.numberFormat;
  const numeric=Number(txt);
  if(!txt || !format || !Number.isFinite(numeric)||txt[0]==='#')return txt;
  switch(format) {
    case 'currency':return numeric.toLocaleString(undefined,{style:'currency',currency:'USD'});
    case 'number':return numeric.toLocaleString(undefined,{maximumFractionDigits:3});
    case 'percent':return (numeric*100).toFixed(2)+'%';
    default:return txt;
  }
}
function requestRender() {
  if(raf)return; raf=true;
  requestAnimationFrame(()=>{raf=false;render();});
}
function render() {
  const metrics=columnMetrics(), firstRow=Math.max(1,Math.floor(scroll.scrollTop/ROW_HEIGHT)+1),
    lastRow=Math.min(MAX_ROWS,firstRow+Math.ceil(scroll.clientHeight/ROW_HEIGHT)+3);
  const x=scroll.scrollLeft;
  let firstCol=1;
  while(firstCol<MAX_COLS&&metrics[firstCol]<x)firstCol++;
  let lastCol=firstCol;
  while(lastCol<MAX_COLS&&metrics[lastCol-1]<x+scroll.clientWidth+DEFAULT_WIDTH)lastCol++;
  $('gridSize').style.width=metrics[MAX_COLS]+'px';
  $('gridSize').style.height=MAX_ROWS*ROW_HEIGHT+'px';
  const chosen=bounds(), cellFragment=document.createDocumentFragment(), colFragment=document.createDocumentFragment(), rowFragment=document.createDocumentFragment();
  for(let c=firstCol;c<=lastCol;c++) {
    const item=document.createElement('div');item.className='column-head'+(c===selected.c?' active':'');
    item.style.left=(metrics[c-1]-x)+'px';item.style.width=colWidth(c)+'px';item.style.height=HEADER_HEIGHT+'px';
    item.textContent=columnName(c);
    item.addEventListener('click',()=>select(1,c));
    const grip=document.createElement('div');grip.className='resize';grip.title='Drag to resize column';
    grip.addEventListener('pointerdown',event=>{
      event.stopPropagation(); event.preventDefault();
      const startX=event.clientX,startWidth=colWidth(c);
      const move=e=>{book.sheets.get(book.active).widths[columnName(c)]=Math.max(55,Math.min(420,startWidth+e.clientX-startX));requestRender();};
      const up=()=>{window.removeEventListener('pointermove',move);window.removeEventListener('pointerup',up);changed();};
      window.addEventListener('pointermove',move);window.addEventListener('pointerup',up);
    });
    item.appendChild(grip);colFragment.appendChild(item);
  }
  for(let r=firstRow;r<=lastRow;r++) {
    const header=document.createElement('div');header.className='row-head'+(r===selected.r?' active':'');
    header.style.top=((r-1)*ROW_HEIGHT-scroll.scrollTop)+'px';
    header.style.width='52px';header.style.height=ROW_HEIGHT+'px';header.textContent=r;
    header.onclick=()=>select(r,1);rowFragment.appendChild(header);
    for(let c=firstCol;c<=lastCol;c++) {
      const id=ref(r,c),text=valueText(r,c),style=book.sheets.get(book.active).styles[id]??{};
      const item=document.createElement('div');
      item.className='grid-cell'+(r===selected.r&&c===selected.c?' selected':r>=chosen.a&&r<=chosen.b&&c>=chosen.l&&c<=chosen.r?' range':'');
      if(text[0]==='#')item.classList.add('error');
      if(!isNaN(Number(text))&&text!=='')item.classList.add('num');
      item.style.left=metrics[c-1]+'px';item.style.top=(r-1)*ROW_HEIGHT+'px';
      item.style.width=colWidth(c)+'px';item.style.height=ROW_HEIGHT+'px';
      if(style.bold)item.style.fontWeight='800';
      if(style.italic)item.style.fontStyle='italic';
      if(style.fill)item.style.backgroundColor=style.fill;
      if(style.color)item.style.color=style.color;
      if(style.align)item.style.justifyContent=style.align;
      item.textContent=text;item.title=book.get(book.active,id)||id;
      item.addEventListener('pointerdown',event=>{
        if(event.button!==0)return;
        dragging=true;select(r,c,event.shiftKey);scroll.focus({preventScroll:true});
      });
      item.addEventListener('pointerenter',()=>{if(dragging)select(r,c,true);});
      item.addEventListener('dblclick',()=>startEdit());
      cellFragment.appendChild(item);
    }
  }
  layer.replaceChildren(cellFragment);
  columns.replaceChildren(colFragment);
  rows.replaceChildren(rowFragment);
  renderTabs();
  $('nameBox').textContent=(chosen.a===chosen.b&&chosen.l===chosen.r)?selectedRef():ref(chosen.a,chosen.l)+':'+ref(chosen.b,chosen.r);
  if(document.activeElement!==$('formulaInput')&&!edit)$('formulaInput').value=book.get(book.active,selectedRef());
  const count=(chosen.b-chosen.a+1)*(chosen.r-chosen.l+1);
  let sum=0,n=0;
  if(count<=10000)for(let r=chosen.a;r<=chosen.b;r++)for(let c=chosen.l;c<=chosen.r;c++) {
    try {const value=book.value(book.active,ref(r,c));if(typeof value==='number'&&isFinite(value)){sum+=value;n++;}}catch{}
  }
  $('selectionStatus').textContent=count===1?'Cell '+selectedRef():count+' cells'+(n?'  ·  Sum: '+sum.toLocaleString()+'  ·  Avg: '+(sum/n).toLocaleString():'');
}
function select(r,c,extend=false) {
  selected={r:Math.min(MAX_ROWS,Math.max(1,r)),c:Math.min(MAX_COLS,Math.max(1,c))};
  if(!extend)anchor={...selected};
  requestRender();
}
window.addEventListener('pointerup',()=>dragging=false);
scroll.addEventListener('scroll',requestRender,{passive:true});
new ResizeObserver(requestRender).observe(scroll);
function ensureVisible() {
  const metrics=columnMetrics(),left=metrics[selected.c-1],right=metrics[selected.c],top=(selected.r-1)*ROW_HEIGHT,bottom=top+ROW_HEIGHT;
  if(left<scroll.scrollLeft)scroll.scrollLeft=left;
  if(right>scroll.scrollLeft+scroll.clientWidth)scroll.scrollLeft=right-scroll.clientWidth;
  if(top<scroll.scrollTop)scroll.scrollTop=top;
  if(bottom>scroll.scrollTop+scroll.clientHeight)scroll.scrollTop=bottom-scroll.clientHeight;
}
function move(dr,dc,extend=false) {
  select(selected.r+dr,selected.c+dc,extend);ensureVisible();scroll.focus({preventScroll:true});
}
function commit(raw) {
  const id=selectedRef();
  if(book.get(book.active,id)!==raw) {snapshot();book.set(book.active,id,raw);changed();}
  $('cellEditor').hidden=true;edit=false;requestRender();
}
function startEdit(initial) {
  if(edit)return;
  edit=true;const input=$('cellEditor'),metrics=columnMetrics();
  input.hidden=false;input.style.left=(52+metrics[selected.c-1]-scroll.scrollLeft)+'px';
  input.style.top=(HEADER_HEIGHT+(selected.r-1)*ROW_HEIGHT-scroll.scrollTop)+'px';
  input.style.width=colWidth(selected.c)+'px';input.style.height=ROW_HEIGHT+'px';
  input.value=initial??book.get(book.active,selectedRef());
  input.focus();input.select();
}
$('cellEditor').addEventListener('keydown',e=>{
  if(e.key==='Escape'){edit=false;$('cellEditor').hidden=true;scroll.focus();e.preventDefault();}
  if(e.key==='Enter'||e.key==='Tab'){
    const key=e.key;commit(e.target.value);move(key==='Tab'?0:1,key==='Tab'?1:0);e.preventDefault();
  }
});
$('cellEditor').addEventListener('blur',e=>{if(edit)commit(e.target.value);});
$('formulaInput').addEventListener('keydown',e=>{
  if(e.key==='Enter'){commit(e.target.value);scroll.focus();e.preventDefault();}
  if(e.key==='Escape'){e.target.value=book.get(book.active,selectedRef());scroll.focus();}
});
function isInput(el) {return el?.tagName==='INPUT'||el?.tagName==='TEXTAREA'||el?.tagName==='SELECT';}
document.addEventListener('keydown',e=>{
  const cmd=e.ctrlKey||e.metaKey;
  if(cmd&&e.key.toLowerCase()==='s'){e.preventDefault();persist();return;}
  if(cmd&&e.key.toLowerCase()==='z'){e.preventDefault();restoreHistory(e.shiftKey?future:history,e.shiftKey?history:future);return;}
  if(cmd&&e.key.toLowerCase()==='y'){e.preventDefault();restoreHistory(future,history);return;}
  if(cmd&&e.key.toLowerCase()==='d'&&!isInput(e.target)){e.preventDefault();fillRange('down');return;}
  if(cmd&&e.key.toLowerCase()==='r'&&!isInput(e.target)){e.preventDefault();fillRange('right');return;}
  if(cmd&&e.key.toLowerCase()==='b'&&!isInput(e.target)){e.preventDefault();applyStyle({bold:!book.sheets.get(book.active).styles[selectedRef()]?.bold});return;}
  if(isInput(e.target)||e.altKey||cmd)return;
  const navigation={ArrowUp:[-1,0],ArrowDown:[1,0],ArrowLeft:[0,-1],ArrowRight:[0,1],Enter:[1,0],Tab:[0,1]};
  if(navigation[e.key]){const [r,c]=navigation[e.key];move(e.shiftKey?-r:r,e.shiftKey?-c:c,e.shiftKey);e.preventDefault();return;}
  if(e.key==='Delete'||e.key==='Backspace'){snapshot();forSelection((r,c)=>book.set(book.active,ref(r,c),''));changed();e.preventDefault();return;}
  if(e.key==='F2'){startEdit();e.preventDefault();return;}
  if(e.key.length===1&&!e.ctrlKey&&!e.metaKey){startEdit(e.key);e.preventDefault();}
});
function forSelection(callback) {
  const b=bounds(); if((b.b-b.a+1)*(b.r-b.l+1)>100000)throw new Error('Selection is too large');
  for(let r=b.a;r<=b.b;r++)for(let c=b.l;c<=b.r;c++)callback(r,c);
}
function selectionMatrix(raw=false) {
  const b=bounds(),result=[];
  if((b.b-b.a+1)*(b.r-b.l+1)>100000)throw new Error('Selection is too large');
  for(let r=b.a;r<=b.b;r++) {
    const row=[];for(let c=b.l;c<=b.r;c++)row.push(raw?book.get(book.active,ref(r,c)):book.display(book.active,ref(r,c)));
    result.push(row);
  }
  return result;
}
document.addEventListener('copy',e=>{
  if(isInput(e.target))return;
  const text=selectionMatrix(true).map(r=>r.join('\t')).join('\n');
  internalClipboard={text,source:bounds(),sheet:book.active};
  e.clipboardData.setData('text/plain',text);e.preventDefault();
});
document.addEventListener('paste',e=>{
  if(isInput(e.target))return;
  const content=e.clipboardData.getData('text/plain');if(!content)return;
  const matrix=content.replace(/\r\n/g,'\n').split('\n').map(line=>line.split('\t'));
  if(matrix.length&&matrix[matrix.length-1].length===1&&matrix[matrix.length-1][0]==='')matrix.pop();
  const from=internalClipboard?.text===content ? internalClipboard.source:null;
  snapshot();
  matrix.forEach((row,ri)=>row.forEach((raw,ci)=>{
    if(selected.r+ri>MAX_ROWS||selected.c+ci>MAX_COLS)return;
    const rebased=from ? rebaseFormula(raw,selected.r+ri-from.a,selected.c+ci-from.l):raw;
    book.set(book.active,ref(selected.r+ri,selected.c+ci),rebased);
  }));
  changed();e.preventDefault();
});
function fillRange(direction) {
  const b=bounds();
  if((direction==='down'&&b.a===b.b)||(direction==='right'&&b.l===b.r))return;
  const area=(b.b-b.a+1)*(b.r-b.l+1);
  if(area>100000){alert('Selection is too large to fill');return;}
  const original=new Map();
  if(direction==='down'){
    for(let c=b.l;c<=b.r;c++)original.set(c,book.get(book.active,ref(b.a,c)));
  }else{
    for(let row=b.a;row<=b.b;row++)original.set(row,book.get(book.active,ref(row,b.l)));
  }
  snapshot();
  for(let row=b.a;row<=b.b;row++)for(let c=b.l;c<=b.r;c++){
    if(direction==='down'&&row>b.a)
      book.set(book.active,ref(row,c),rebaseFormula(original.get(c),row-b.a,0));
    if(direction==='right'&&c>b.l)
      book.set(book.active,ref(row,c),rebaseFormula(original.get(row),0,c-b.l));
  }
  changed();
}
function applyStyle(patch) {
  snapshot();forSelection((r,c)=>book.setStyle(book.active,ref(r,c),patch));changed();
}
$('fillColor').oninput=e=>applyStyle({fill:e.target.value});
$('textColor').oninput=e=>applyStyle({color:e.target.value});
$('numberFormat').onchange=e=>applyStyle({numberFormat:e.target.value});
function renderTabs() {
  const target=$('sheetTabs');target.replaceChildren();
  for(const sheet of book.sheets.keys()) {
    const b=document.createElement('button');b.className='sheet-tab'+(sheet===book.active?' active':'');
    b.textContent=sheet;b.title='Double-click to rename; right-click to delete';
    b.onclick=()=>{book.active=sheet;select(1,1);changed();};
    b.ondblclick=()=>{const next=prompt('Rename sheet',sheet);if(next&&next!==sheet){try{snapshot();book.renameSheet(sheet,next);changed();}catch(e){alert(e.message);}}};
    b.oncontextmenu=e=>{e.preventDefault();if(confirm('Delete '+sheet+'?')){try{snapshot();book.deleteSheet(sheet);changed();}catch(e){alert(e.message);}}};
    target.appendChild(b);
  }
  const add=document.createElement('button');add.textContent='＋';add.title='Add sheet';add.onclick=addSheet;
  target.appendChild(add);
}
function addSheet() {
  const next=prompt('New sheet name','Sheet'+(book.sheets.size+1));if(!next)return;
  try{snapshot();book.addSheet(next);select(1,1);changed();}catch(e){alert(e.message);}
}
function download(filename,text,mime) {
  const blob=new Blob([text],{type:mime}),url=URL.createObjectURL(blob);
  const a=document.createElement('a');a.href=url;a.download=filename;a.click();
  setTimeout(()=>URL.revokeObjectURL(url),2000);
}
function safeFilename(s){return s.replace(/[^a-z0-9_-]+/gi,'_').slice(0,80);}
function usedExtent() {
  let r=1,c=1;
  for(const id of Object.keys(book.sheets.get(book.active).cells)){
    const parsed=parseRef(id);r=Math.max(r,parsed.row);c=Math.max(c,parsed.col);
  }
  return {r:Math.min(r,50000),c:Math.min(c,256)};
}
function exportCsv() {
  const ext=usedExtent(),lines=[];
  for(let r=1;r<=ext.r;r++) {
    const row=[];for(let c=1;c<=ext.c;c++)row.push(book.display(book.active,ref(r,c)));
    lines.push(row);
  }
  download(safeFilename(name)+'_'+safeFilename(book.active)+'.csv',stringifyCsv(lines),'text/csv;charset=utf-8');
}
$('exportButton').onclick=exportCsv;
$('xlsxExport').onclick=async()=>{
  const button=$('xlsxExport');button.disabled=true;
  $('saveStatus').textContent='Preparing XLSX…';
  try{
    const bytes=await exportXlsx(book);
    download(safeFilename(name)+'.xlsx',bytes,'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    $('saveStatus').textContent='XLSX exported';
  }catch(e){alert('XLSX export failed: '+e.message);$('saveStatus').textContent='XLSX unavailable';}
  finally{button.disabled=false;}
};
$('importButton').onclick=()=>$('filePicker').click();
$('filePicker').onchange=async e=>{
  const file=e.target.files?.[0];if(!file)return;
  try {
    snapshot();
    if(file.name.toLowerCase().endsWith('.xlsx')){
      $('saveStatus').textContent='Importing XLSX…';
      book=await importXlsx(await file.arrayBuffer());
      name=file.name.replace(/\.xlsx$/i,'');$('workbookName').value=name;
    } else if(file.name.toLowerCase().endsWith('.json')){
      const data=JSON.parse(await file.text());book=new Workbook(data.workbook??data);
      name=data.name??file.name.replace(/\.json$/,'');$('workbookName').value=name;
    } else {
      const text=await file.text();
      const matrix=file.name.toLowerCase().endsWith('.tsv')
        ? text.replace(/\r\n/g,'\n').split('\n').map(row=>row.split('\t')):parseCsv(text);
      const newName='Import'+(book.sheets.size+1);book.addSheet(newName);
      for(let r=0;r<Math.min(matrix.length,MAX_ROWS);r++)
        for(let c=0;c<Math.min(matrix[r].length,MAX_COLS);c++)
          if(matrix[r][c])book.set(newName,ref(r+1,c+1),matrix[r][c]);
    }
    select(1,1);changed();
  } catch(err){alert('Import failed: '+err.message);}
  e.target.value='';
};
function modal(title,content) {
  $('modalTitle').textContent=title;
  $('modalBody').replaceChildren();
  if(typeof content==='string')$('modalBody').textContent=content;
  else $('modalBody').appendChild(content);
  $('modal').hidden=false;
}
$('closeModal').onclick=()=>$('modal').hidden=true;
$('modal').addEventListener('click',e=>{if(e.target===$('modal'))$('modal').hidden=true;});
function makeChart() {
  const b=bounds();
  const extent=(b.a===b.b&&b.l===b.r)?{a:1,b:Math.min(20,usedExtent().r),l:1,r:Math.min(2,usedExtent().c)}:b;
  if(extent.r-extent.l<1) {alert('Select labels and at least one numeric column to chart.');return;}
  const data=[];
  for(let r=extent.a+1;r<=extent.b&&data.length<80;r++){
    const label=book.display(book.active,ref(r,extent.l));
    const value=Number(book.display(book.active,ref(r,extent.l+1)));
    if(label&&Number.isFinite(value))data.push({label,value});
  }
  if(!data.length){alert('Select a range with a header row, labels, and numeric values.');return;}
  const wrap=document.createElement('div');
  const chooser=document.createElement('select');for(const type of ['Bar','Line','Pie']){const op=document.createElement('option');op.value=type.toLowerCase();op.textContent=type;chooser.appendChild(op);}
  wrap.appendChild(chooser);
  const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
  svg.setAttribute('viewBox','0 0 700 340');svg.classList.add('chart');wrap.appendChild(svg);
  const NS='http://www.w3.org/2000/svg';
  function el(tag,attributes,text) {
    const e=document.createElementNS(NS,tag);
    for(const [key,value] of Object.entries(attributes))e.setAttribute(key,String(value));
    if(text!==undefined)e.textContent=text;
    svg.appendChild(e);return e;
  }
  const colors=['#4e90eb','#30c4b6','#f2aa51','#b48de8','#d36e93','#78c678'];
  function draw(type) {
    svg.replaceChildren();
    const max=Math.max(1,...data.map(d=>Math.abs(d.value))),width=610,height=265;
    if(type==='pie'){
      const positives=data.filter(d=>d.value>0),total=positives.reduce((s,d)=>s+d.value,0);let angle=-Math.PI/2;
      positives.forEach((d,i)=>{
        const next=angle+(d.value/total)*Math.PI*2;
        const x1=350+105*Math.cos(angle),y1=151+105*Math.sin(angle),x2=350+105*Math.cos(next),y2=151+105*Math.sin(next);
        const large=next-angle>Math.PI?1:0;
        el('path',{d:'M 350 151 L '+x1+' '+y1+' A 105 105 0 '+large+' 1 '+x2+' '+y2+' Z',fill:colors[i%colors.length]});
        angle=next;
      });
    } else {
      el('line',{x1:53,y1:280,x2:680,y2:280,stroke:'#66819d'});
      const step=width/data.length;
      const pts=[];
      data.forEach((d,i)=>{
        const x=63+i*step+step/2,y=280-(Math.max(0,d.value)/max)*height;
        if(type==='bar')el('rect',{x:x-step*.34,y,width:step*.68,height:Math.max(1,280-y),fill:colors[i%colors.length],rx:2});
        else{pts.push(x+','+y);el('circle',{cx:x,cy:y,r:4,fill:'#5ab7f7'});}
        if(data.length<=20)el('text',{x,y:298,fill:'#a8bbd0','font-size':11,'text-anchor':'middle'},d.label.slice(0,10));
      });
      if(type==='line')el('polyline',{points:pts.join(' '),fill:'none',stroke:'#5ab7f7','stroke-width':3});
    }
    el('text',{x:20,y:20,fill:'#dceafa','font-size':13},'Data from '+book.active+' · '+ref(extent.a,extent.l)+':'+ref(extent.b,extent.r));
  }
  chooser.onchange=()=>draw(chooser.value);draw('bar');modal('Insert chart',wrap);
}

function sourceMatrix(spec){
  const {sourceSheet,range}=spec;
  if(!book.sheets.has(sourceSheet))throw Error('Source sheet is missing');
  const {a,b,l,r}=range;
  const count=(b-a+1)*(r-l+1);
  if(count>480000||b-a>100000||r-l>255)throw Error('Select fewer than 480,000 source cells');
  const matrix=[];
  for(let row=a;row<=b;row++){
    const values=[];
    for(let col=l;col<=r;col++){
      const id=ref(row,col);
      try{values.push(book.value(sourceSheet,id));}
      catch{values.push(book.display(sourceSheet,id));}
    }
    matrix.push(values);
  }
  return matrix;
}
async function workerAnalysis(kind,matrix,config){
  if(typeof Worker==='undefined'){
    return kind==='filter'?{matrix:filterTable(matrix,config)}:buildPivot(matrix,config);
  }
  return new Promise((resolve,reject)=>{
    const worker=new Worker('./analytics.worker.mjs',{type:'module'});
    const timer=setTimeout(()=>{worker.terminate();reject(Error('Analysis exceeded 60 seconds'));},60000);
    worker.onmessage=({data})=>{
      clearTimeout(timer);worker.terminate();
      if(data.ok)resolve(data.result);
      else reject(Error(data.error??'Analysis failed'));
    };
    worker.onerror=error=>{clearTimeout(timer);worker.terminate();reject(Error(error.message??'Analysis worker failed'));};
    worker.postMessage({id:1,kind,matrix,config});
  });
}
function pivotSourceRange(){
  const selectedBounds=bounds(),single=selectedBounds.a===selectedBounds.b&&selectedBounds.l===selectedBounds.r;
  if(!single)return selectedBounds;
  const extent=usedExtent();
  return {a:1,b:Math.max(2,extent.r),l:1,r:Math.min(24,Math.max(2,extent.c))};
}
function selectField(title,fields,defaultIndex=0,empty=false){
  const wrap=document.createElement('label');wrap.className='pivot-field';wrap.textContent=title;
  const input=document.createElement('select');input.setAttribute('aria-label',title);
  if(empty){const opt=document.createElement('option');opt.value='-1';opt.textContent='(none)';input.append(opt);}
  for(const [i,field] of fields.entries()){
    const option=document.createElement('option');option.value=String(i);option.textContent=(i+1)+'. '+String(field||('Column '+(i+1)));
    input.append(option);
  }
  input.value=String(defaultIndex);wrap.append(input);
  return {wrap,input};
}
function writeAnalysisResult(name,result,kind,spec){
  const data=result.matrix;
  if(!Array.isArray(data)||!data.length||data.length>100000||data[0].length>256)throw Error('Invalid analysis output');
  snapshot();
  const sheet=name||('Pivot'+(book.sheets.size+1));
  if(!name)book.addSheet(sheet);
  const target=book.sheets.get(sheet);
  if(!target)throw Error('Output sheet was deleted');
  for(const cell of Object.keys(target.cells))book.set(sheet,cell,'');
  for(let ri=0;ri<data.length;ri++)for(let ci=0;ci<data[ri].length;ci++){
    const value=data[ri][ci];
    if(value!==null&&value!==undefined&&value!=='')book.set(sheet,ref(ri+1,ci+1),value);
    if(ri===0)book.setStyle(sheet,ref(ri+1,ci+1),{bold:true,fill:'#284a71'});
  }
  book.analytics[sheet]={...spec,kind};
  book.active=sheet;select(1,1);changed();
  $('modal').hidden=true;
}
function pivotDesigner(){
  const range=pivotSourceRange(),sourceSheet=book.active;
  const baseSpec={sourceSheet,range};
  const row0=sourceMatrix({...baseSpec,range:{...range,b:range.a}})[0];
  if(row0.length<2){alert('Select data with multiple columns and a header row.');return;}
  const names=row0.map((v,i)=>v==null||v===''?'Column '+(i+1):String(v));
  const root=document.createElement('div');root.className='pivot-builder';
  const description=document.createElement('p');
  description.textContent='Choose row groups, an optional column dimension, a measure, and aggregation. Source: '+sourceSheet+'!'+ref(range.a,range.l)+':'+ref(range.b,range.r);
  root.append(description);
  const grid=document.createElement('div');grid.className='pivot-fields';
  const row1=selectField('Row field',names,0),
        row2=selectField('Additional row field',names,-1,true),
        col=selectField('Column dimension',names,-1,true),
        val=selectField('Value field',names,Math.min(1,names.length-1)),
        filterCol=selectField('Filter field',names,-1,true);
  for(const control of [row1,row2,col,val,filterCol])grid.append(control.wrap);
  const aggregate=document.createElement('label');aggregate.className='pivot-field';aggregate.textContent='Aggregation';
  const aggInput=document.createElement('select');aggInput.id='pivotAggregate';
  for(const name of ['sum','count','countDistinct','average','min','max','median']){
    const option=document.createElement('option');option.value=name;option.textContent=name;aggInput.append(option);
  }
  aggregate.append(aggInput);grid.append(aggregate);
  const filterMode=document.createElement('label');filterMode.className='pivot-field';filterMode.textContent='Filter condition';
  const filterModeInput=document.createElement('select');
  for(const item of ['equals','notEquals','contains','notBlank']){
    const option=document.createElement('option');option.value=item;option.textContent=item;filterModeInput.append(option);
  }
  filterMode.append(filterModeInput);grid.append(filterMode);
  const filterValue=document.createElement('label');filterValue.className='pivot-field';filterValue.textContent='Filter value';
  const filterInput=document.createElement('input');filterInput.placeholder='Optional exact value or substring';
  filterValue.append(filterInput);grid.append(filterValue);
  root.append(grid);
  const controls=document.createElement('div');controls.className='pivot-actions';
  const previewButton=document.createElement('button');previewButton.id='previewPivot';previewButton.textContent='Preview';
  const createButton=document.createElement('button');createButton.id='createPivot';createButton.textContent='Create pivot sheet';
  createButton.className='primary';controls.append(previewButton,createButton);root.append(controls);
  const output=document.createElement('div');output.id='pivotPreview';output.className='pivot-preview';
  root.append(output);
  function config(){
    const rows=[Number(row1.input.value)];
    if(Number(row2.input.value)>=0&&!rows.includes(Number(row2.input.value)))rows.push(Number(row2.input.value));
    return {rows,column:Number(col.input.value)<0?null:Number(col.input.value),
      value:Number(val.input.value),aggregate:aggInput.value,grandTotal:true,
      filter:Number(filterCol.input.value)<0?null:
        {field:Number(filterCol.input.value),mode:filterModeInput.value,value:filterInput.value}};
  }
  async function generate(commit=false){
    for(const button of [previewButton,createButton])button.disabled=true;
    output.textContent='Calculating in a background worker…';
    try{
      const cfg=config(),spec={...baseSpec,config:cfg};
      const result=await workerAnalysis('pivot',sourceMatrix(baseSpec),cfg);
      if(commit){writeAnalysisResult(null,result,'pivot',spec);return;}
      const table=document.createElement('table');table.className='preview-table';
      for(const [i,row] of result.matrix.slice(0,24).entries()){
        const tr=document.createElement('tr');
        for(const value of row.slice(0,16)){
          const cell=document.createElement(i===0?'th':'td');
          cell.textContent=value===null?'':String(value);tr.append(cell);
        }
        table.append(tr);
      }
      output.replaceChildren(table);
      const note=document.createElement('div');note.className='message';
      note.textContent=result.meta.records+' source rows · '+result.meta.groups+' groups · '+result.matrix.length+' output rows';
      output.append(note);
    }catch(e){output.textContent='Analysis error: '+e.message;}
    finally{for(const button of [previewButton,createButton])button.disabled=false;}
  }
  previewButton.onclick=()=>generate(false);createButton.onclick=()=>generate(true);
  modal('Pivot table designer',root);
}
async function refreshAnalysis(){
  const sheet=book.active,spec=book.analytics[sheet];
  if(!spec){alert('Current sheet is not a generated pivot/filter report.');return;}
  try{
    $('saveStatus').textContent='Refreshing report…';
    const result=await workerAnalysis(spec.kind,sourceMatrix(spec),spec.config);
    writeAnalysisResult(sheet,result,spec.kind,spec);
  }catch(e){alert('Cannot refresh: '+e.message);$('saveStatus').textContent='Refresh failed';}
}
function filterDesigner(){
  const range=pivotSourceRange(),sourceSheet=book.active,source={sourceSheet,range};
  const names=sourceMatrix({...source,range:{...range,b:range.a}})[0].map((x,i)=>String(x??'Field '+(i+1)));
  const root=document.createElement('div');root.className='pivot-builder';
  const field=selectField('Column to filter',names,0);
  const mode=document.createElement('select');mode.id='filterMode';
  for(const x of ['contains','equals','notEquals','notBlank']){
    const option=document.createElement('option');option.value=x;option.textContent=x;mode.append(option);
  }
  const term=document.createElement('input');term.id='filterValue';term.placeholder='Match text';
  const sort=document.createElement('select');sort.id='filterSort';
  for(const x of ['none','asc','desc']){const option=document.createElement('option');option.value=x;option.textContent=x;sort.append(option);}
  const action=document.createElement('button');action.id='applyFilter';action.textContent='Create filtered table';action.className='primary';
  root.append(field.wrap,mode,term,sort,action);
  action.onclick=async()=>{
    action.disabled=true;
    try{
      const config={field:Number(field.input.value),mode:mode.value,value:term.value,sort:sort.value};
      const result=await workerAnalysis('filter',sourceMatrix(source),config);
      writeAnalysisResult(null,result,'filter',{...source,config});
    }catch(e){alert('Filter failed: '+e.message);}
    finally{action.disabled=false;}
  };
  modal('Filter and sort data',root);
}
function createPivot(){pivotDesigner();}
function sortSelection() {
  const b=bounds();
  if(b.a===b.b){alert('Select multiple rows to sort.');return;}
  const matrix=selectionMatrix(true);
  const direction=confirm('Sort ascending by the first selected column? (Cancel sorts descending)')?1:-1;
  const records=matrix.slice(1).map((row,i)=>({
    row,sourceRow:b.a+i+1,key:book.display(book.active,ref(b.a+i+1,b.l)),
  }));
  records.sort((left,right)=>String(left.key).localeCompare(String(right.key),undefined,{numeric:true})*direction);
  const output=[{row:matrix[0],sourceRow:b.a},...records];
  snapshot();
  output.forEach(({row,sourceRow},i)=>row.forEach((value,ci)=>{
    book.set(book.active,ref(b.a+i,b.l+ci),rebaseFormula(value,b.a+i-sourceRow,0));
  }));
  changed();
}
for(const button of document.querySelectorAll('[data-action]'))button.onclick=()=>{
  const action=button.dataset.action;
  if(action==='new'){if(!confirm('Start a new workbook? Download the current one first if needed.'))return;snapshot();book=new Workbook();name='Untitled workbook';$('workbookName').value=name;changed();}
  if(action==='addSheet')addSheet();
  if(action==='bold')applyStyle({bold:!book.sheets.get(book.active).styles[selectedRef()]?.bold});
  if(action==='italic')applyStyle({italic:!book.sheets.get(book.active).styles[selectedRef()]?.italic});
  if(['left','center','right'].includes(action))applyStyle({align:{left:'flex-start',center:'center',right:'flex-end'}[action]});
  if(action==='exportWorkbook')download(safeFilename(name)+'.arcside.json',JSON.stringify({name,workbook:book.toJSON()},null,2),'application/json');
  if(action==='chart')makeChart();
  if(action==='pivot')createPivot();
  if(action==='refreshPivot')void refreshAnalysis();
  if(action==='filterTable')filterDesigner();
  if(action==='sort')sortSelection();
  if(action==='fillDown')fillRange('down');
  if(action==='fillRight')fillRange('right');
  if(action==='find'){
    const q=prompt('Find a value in '+book.active);if(!q)return;
    const lower=q.toLowerCase(),cells=book.sheets.get(book.active).cells;
    const found=Object.keys(cells).find(id=>book.display(book.active,id).toLowerCase().includes(lower));
    if(found){const pos=parseRef(found);select(pos.row,pos.col);ensureVisible();}else alert('No match');
  }
  if(action==='help')modal('Formula reference',
    'Supported: +, -, *, /, ^, &, comparisons, parentheses; cell references such as A1, $B$2 and other sheets such as Sheet2!A1. Functions: SUM, SUMIF, SUMIFS, AVERAGE, AVERAGEIF, COUNT, COUNTIF, COUNTIFS, COUNTA, MIN, MAX, MEDIAN, STDEV, PRODUCT, VLOOKUP (exact), XLOOKUP (exact), INDEX, MATCH (exact), IF, IFERROR, IFNA, ROUND, ROUNDUP, ROUNDDOWN, ABS, SQRT, POWER, MOD, AND, OR, NOT, LEN, LEFT, RIGHT, MID, FIND, SEARCH, SUBSTITUTE, UPPER, LOWER, TRIM, CONCAT. Circular references show #CYCLE!. Charts and pivot summaries are created from the current selection. Import/export: CSV, TSV, Arcside JSON.');
};
document.addEventListener('visibilitychange',()=>{if(document.hidden)persist();});
window.addEventListener('beforeunload',persist);
requestRender();
