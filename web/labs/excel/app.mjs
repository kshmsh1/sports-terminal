import {ArcsideWorkbook, address, parseAddress, colLabel} from './engine.mjs';
const $=id=>document.getElementById(id);
const STORAGE='arcside.excel.workspace.v1';
const ROW_H=27,MAX_ROWS=100000,MAX_COLS=512,DEFAULT_W=126;
let book=new ArcsideWorkbook(),selected={row:0,col:0},anchor={row:0,col:0};
let undo=[],redo=[],editing=false,dragging=false,raf=null;
let filteredRows=new Set(),chartKind='bar',chartVisible=false,saveTimer=null;
let name='Untitled workbook';
function toast(msg){const e=$('toast');e.textContent=msg;e.style.display='block';clearTimeout(toast.id);toast.id=setTimeout(()=>e.style.display='none',3000);}
function persist(){
  clearTimeout(saveTimer);saveTimer=setTimeout(()=>{
    try{
      const data=JSON.stringify({book:book.snapshot(),name});
      if(data.length>4_000_000){toast('Local browser storage limit. Export your workbook.');return;}
      localStorage.setItem(STORAGE,data);
    }catch(_){toast('Browser storage is full. Export a workbook copy.');}
  },450);
}
function restore(){
  try{
    const saved=JSON.parse(localStorage.getItem(STORAGE)||'null');
    if(saved&&saved.book){book=new ArcsideWorkbook(saved.book);name=String(saved.name||name);}
  }catch(_){}
  $('workbookName').value=name;
}
function checkpoint(){
  undo.push(JSON.stringify(book.snapshot()));
  if(undo.length>70)undo.shift();
  redo.length=0;
}
function updateBook(snapshot){
  book.load(typeof snapshot==='string'?JSON.parse(snapshot):snapshot);
  filteredRows.clear();renderAll();persist();
}
function undoAction(){
  if(!undo.length)return;
  redo.push(JSON.stringify(book.snapshot()));updateBook(undo.pop());
}
function redoAction(){
  if(!redo.length)return;
  undo.push(JSON.stringify(book.snapshot()));updateBook(redo.pop());
}
function widthAt(col){return book.active.widths[col]||DEFAULT_W;}
function xAt(col){
  let x=0;for(let i=0;i<col;i++)x+=widthAt(i);
  return x;
}
function colAt(x){
  let pos=0;
  for(let c=0;c<MAX_COLS;c++){
    pos+=widthAt(c);if(x<pos)return c;
  }
  return MAX_COLS-1;
}
function sheetCell(ref){return book.getRaw(book.active.id,ref);}
function safeDisplay(ref){
  try{return book.display(book.active.id,ref);}
  catch(e){return e.code||'#ERROR!';}
}
function setCell(ref,value){
  book.setRaw(book.active.id,ref,value);
}
function rangeBounds(){
  return {r1:Math.min(anchor.row,selected.row),
    r2:Math.max(anchor.row,selected.row),
    c1:Math.min(anchor.col,selected.col),
    c2:Math.max(anchor.col,selected.col)};
}
function selectedAddress(){return address(selected.row,selected.col);}
function choose(row,col,extend=false,scroll=false){
  selected={row:Math.max(0,Math.min(MAX_ROWS-1,row)),
    col:Math.max(0,Math.min(MAX_COLS-1,col))};
  if(!extend)anchor={...selected};
  syncFormula();drawGrid();
  if(scroll)scrollToSelected();
}
function syncFormula(){
  $('nameBox').value=selectedAddress();
  $('formulaInput').value=sheetCell(selectedAddress());
  $('selectedInfo').textContent=book.active.name+' · '+selectedAddress();
  const st=book.getStyle(book.active.id,selectedAddress());
  $('bold').classList.toggle('active',!!st.bold);
  $('italic').classList.toggle('active',!!st.italic);
  $('format').value=st.format||'general';
}
function scrollToSelected(){
  const viewport=$('gridViewport'),x=xAt(selected.col),w=widthAt(selected.col);
  if(x<viewport.scrollLeft)viewport.scrollLeft=x;
  else if(x+w>viewport.scrollLeft+viewport.clientWidth)
    viewport.scrollLeft=x+w-viewport.clientWidth;
  const top=selected.row*ROW_H;
  if(top<viewport.scrollTop)viewport.scrollTop=top;
  else if(top+ROW_H>viewport.scrollTop+viewport.clientHeight)
    viewport.scrollTop=top+ROW_H-viewport.clientHeight;
}
function drawGrid(){
  const view=$('gridViewport'),y=view.scrollTop,x=view.scrollLeft;
  const top=Math.max(0,Math.floor(y/ROW_H)-2);
  const bottom=Math.min(MAX_ROWS-1,Math.ceil((y+view.clientHeight)/ROW_H)+2);
  const left=Math.max(0,colAt(x)-1);
  const right=Math.min(MAX_COLS-1,colAt(x+view.clientWidth)+1);
  const layer=$('cellsLayer'),cols=$('colHeaders'),rows=$('rowHeaders');
  layer.replaceChildren();cols.replaceChildren();rows.replaceChildren();
  const bounds=rangeBounds();
  const fragment=document.createDocumentFragment();
  for(let c=left;c<=right;c++){
    const h=document.createElement('div');h.className='ch'+(c===selected.col?' active':'');
    h.style.left=(xAt(c)-x)+'px';h.style.width=widthAt(c)+'px';
    h.textContent=colLabel(c);
    h.onmousedown=e=>{if(e.target.classList.contains('resize'))return;
      choose(selected.row,c,false,false);};
    const resize=document.createElement('div');resize.className='resize';
    resize.onmousedown=e=>{
      e.preventDefault();e.stopPropagation();
      const start=e.clientX,original=widthAt(c);
      const move=event=>{
        book.active.widths[c]=Math.max(44,Math.min(600,original+event.clientX-start));
        updateDimensions();drawGrid();
      };
      const up=()=>{window.removeEventListener('mousemove',move);window.removeEventListener('mouseup',up);
        checkpoint();persist();};
      window.addEventListener('mousemove',move);window.addEventListener('mouseup',up);
    };
    h.append(resize);cols.append(h);
  }
  for(let r=top;r<=bottom;r++){
    const h=document.createElement('div');h.className='rh'+(r===selected.row?' active':'');
    h.style.top=(r*ROW_H-y)+'px';h.textContent=r+1;
    h.onmousedown=()=>choose(r,selected.col,false,false);
    rows.append(h);
    for(let c=left;c<=right;c++){
      const ref=address(r,c);
      const cell=document.createElement('div');
      cell.className='cell';
      if(r===selected.row&&c===selected.col)cell.classList.add('selected');
      else if(r>=bounds.r1&&r<=bounds.r2&&c>=bounds.c1&&c<=bounds.c2)cell.classList.add('range');
      const st=book.getStyle(book.active.id,ref);
      if(st.bold)cell.classList.add('bold');
      if(st.italic)cell.classList.add('italic');
      if(st.align)cell.classList.add(st.align);
      const value=filteredRows.has(r)?'':safeDisplay(ref);
      if(value.startsWith('#'))cell.classList.add('error');
      if(!Number.isNaN(Number(value))&&value.trim()!=='')cell.classList.add('number');
      cell.textContent=value;
      cell.title=value.length>24?value:'';
      cell.style.left=xAt(c)+'px';cell.style.top=r*ROW_H+'px';
      cell.style.width=widthAt(c)+'px';
      cell.dataset.row=r;cell.dataset.col=c;
      cell.onmousedown=e=>{
        if(e.button!==0)return;
        e.preventDefault();dragging=true;
        choose(r,c,e.shiftKey);$('gridViewport').focus();
      };
      cell.onmouseenter=()=>{
        if(dragging)choose(r,c,true);
      };
      cell.ondblclick=()=>editCell();
      fragment.append(cell);
    }
  }
  layer.append(fragment);drawSelection();
  if(editing)placeEditor();
}
function drawSelection(){
  const box=$('selection');
  const b=rangeBounds(),view=$('gridViewport');
  const x1=xAt(b.c1)-view.scrollLeft+49;
  const y1=b.r1*ROW_H-view.scrollTop+27;
  const width=xAt(b.c2+1)-xAt(b.c1);
  const height=(b.r2-b.r1+1)*ROW_H;
  box.style.left=x1+'px';box.style.top=y1+'px';
  box.style.width=width+'px';box.style.height=height+'px';
  box.style.display=(width>0&&height>0)?'block':'none';
}
function updateDimensions(){
  $('spacer').style.width=xAt(MAX_COLS)+'px';
  $('spacer').style.height=(MAX_ROWS*ROW_H)+'px';
}
function scheduleDraw(){
  if(raf!==null)return;
  raf=requestAnimationFrame(()=>{raf=null;drawGrid();});
}
function editCell(initial){
  if(editing)return;
  editing=true;
  const editor=$('cellEdit');
  editor.value=initial===undefined?sheetCell(selectedAddress()):initial;
  editor.style.display='block';placeEditor();editor.focus();
  editor.setSelectionRange(editor.value.length,editor.value.length);
}
function placeEditor(){
  if(!editing)return;
  const e=$('cellEdit'),v=$('gridViewport');
  e.style.left=(49+xAt(selected.col)-v.scrollLeft)+'px';
  e.style.top=(27+selected.row*ROW_H-v.scrollTop)+'px';
  e.style.width=Math.max(125,widthAt(selected.col))+'px';
}
function finishEdit(keep=true,movement){
  if(!editing)return;
  const raw=$('cellEdit').value;
  editing=false;$('cellEdit').style.display='none';
  if(keep&&sheetCell(selectedAddress())!==raw){
    checkpoint();setCell(selectedAddress(),raw);persist();
  }
  if(movement)choose(selected.row+movement[0],selected.col+movement[1],false,true);
  else{syncFormula();drawGrid();}
  $('gridViewport').focus();
}
function commitFormula(){
  const value=$('formulaInput').value;
  if(value!==sheetCell(selectedAddress())){
    checkpoint();setCell(selectedAddress(),value);persist();renderAll();
  }
  $('gridViewport').focus();
}
function getTsv(){
  const b=rangeBounds(),data=[];
  for(let r=b.r1;r<=b.r2;r++){
    const row=[];
    for(let c=b.c1;c<=b.c2;c++)
      row.push(safeDisplay(address(r,c)));
    data.push(row.join('\t'));
  }
  return data.join('\n');
}
function pasteTsv(text){
  if(text.length>2_000_000){toast('Paste limit: 2 MB');return;}
  const lines=text.replace(/\r/g,'').trimEnd().split('\n');
  const values=lines.map(line=>line.split('\t'));
  checkpoint();
  for(let r=0;r<values.length;r++)
    for(let c=0;c<values[r].length;c++){
      const row=selected.row+r,col=selected.col+c;
      if(row<MAX_ROWS&&col<MAX_COLS)setCell(address(row,col),values[r][c]);
    }
  choose(selected.row+values.length-1,selected.col+(values[0]?.length||1)-1,true);
  persist();
}
async function copy(){
  const tsv=getTsv();
  try{await navigator.clipboard.writeText(tsv);toast('Copied selected cells');}
  catch(_){toast('Use Ctrl+C to copy cells');}
}
async function paste(){
  try{pasteTsv(await navigator.clipboard.readText());}
  catch(_){toast('Use Ctrl+V to paste cells');}
}
function applyStyle(change){
  checkpoint();const b=rangeBounds();
  for(let r=b.r1;r<=b.r2;r++)
    for(let c=b.c1;c<=b.c2;c++)
      book.setStyle(book.active.id,address(r,c),change);
  drawGrid();syncFormula();persist();
}
function insertRow(){
  checkpoint();const s=book.active,out={},styles={};
  for(const [ref,value] of Object.entries(s.cells)){
    const p=parseAddress(ref),target=p.row>=selected.row?address(p.row+1,p.col):ref;
    if(p.row+1<MAX_ROWS)out[target]=value;
  }
  for(const [ref,style] of Object.entries(s.styles)){
    const p=parseAddress(ref),target=p.row>=selected.row?address(p.row+1,p.col):ref;
    if(p.row+1<MAX_ROWS)styles[target]=style;
  }
  s.cells=out;s.styles=styles;book.load(book.snapshot());
  renderAll();persist();toast('Row inserted. Formula references are not rewritten yet.');
}
function insertColumn(){
  checkpoint();const s=book.active,out={},styles={},widths={};
  for(const [ref,value] of Object.entries(s.cells)){
    const p=parseAddress(ref),target=p.col>=selected.col?address(p.row,p.col+1):ref;
    if(p.col+1<MAX_COLS)out[target]=value;
  }
  for(const [ref,style] of Object.entries(s.styles)){
    const p=parseAddress(ref),target=p.col>=selected.col?address(p.row,p.col+1):ref;
    if(p.col+1<MAX_COLS)styles[target]=style;
  }
  for(const [col,width] of Object.entries(s.widths))
    widths[Number(col)>=selected.col?Number(col)+1:Number(col)]=width;
  s.cells=out;s.styles=styles;s.widths=widths;book.load(book.snapshot());
  updateDimensions();renderAll();persist();
  toast('Column inserted. Formula references are not rewritten yet.');
}
function sortRows(ascending){
  const b=rangeBounds();
  if(b.r1===b.r2){toast('Select at least two rows to sort');return;}
  const s=book.active,rows=[];
  for(let r=b.r1;r<=b.r2;r++){
    const cells=[],styles=[];
    for(let c=b.c1;c<=b.c2;c++){
      cells.push(sheetCell(address(r,c)));
      styles.push(book.getStyle(s.id,address(r,c)));
    }
    rows.push({cells,styles,order:r});
  }
  rows.sort((a,b)=>{
    const x=a.cells[0],y=b.cells[0],na=Number(x),nb=Number(y);
    const compare=Number.isFinite(na)&&Number.isFinite(nb)?
      na-nb:String(x).localeCompare(String(y),undefined,{numeric:true});
    return (ascending?compare:-compare)||(a.order-b.order);
  });
  checkpoint();
  for(let r=b.r1;r<=b.r2;r++)
    for(let c=b.c1;c<=b.c2;c++){
      const ref=address(r,c),row=rows[r-b.r1],offset=c-b.c1;
      setCell(ref,row.cells[offset]);book.setStyle(s.id,ref,row.styles[offset]);
    }
  renderAll();persist();
  toast('Sorted selection. Relative formula references were not rewritten.');
}
function filterRows(){
  if(filteredRows.size){filteredRows.clear();drawGrid();toast('Filter cleared');return;}
  const b=rangeBounds();
  const term=prompt('Only show rows containing what text in '+colLabel(b.c1)+'?');
  if(term===null)return;
  for(let r=b.r1;r<=b.r2;r++){
    if(!safeDisplay(address(r,b.c1)).toLowerCase().includes(term.toLowerCase()))
      filteredRows.add(r);
  }
  drawGrid();toast('Filter applied: hidden values retain their row positions.');
}
function autoSum(){
  const c=colLabel(selected.col),r=selected.row;
  const from=r===0?2:1,to=r===0?10:r;
  checkpoint();setCell(selectedAddress(),'=SUM('+c+from+':'+c+to+')');
  renderAll();persist();
}
function chartData(){
  const b=rangeBounds();const labels=[],values=[];
  const valueCol=b.c2>b.c1?b.c1+1:b.c1;
  for(let r=b.r1;r<=Math.min(b.r2,b.r1+150);r++){
    const value=Number(book.getValue(book.active.id,address(r,valueCol)));
    if(!Number.isFinite(value))continue;
    labels.push(b.c2>b.c1?safeDisplay(address(r,b.c1)):String(r+1));
    values.push(value);
  }
  return {labels,values};
}
function chart(type){
  chartKind=type;chartVisible=true;
  $('chartType').value=type;$('chartPanel').style.display='block';
  drawChart();
}
function drawChart(){
  const canvas=$('chart'),ctx=canvas.getContext('2d');
  const W=canvas.width,H=canvas.height;
  ctx.fillStyle='white';ctx.fillRect(0,0,W,H);
  const {labels,values}=chartData();
  if(!values.length){
    ctx.fillStyle='#697586';ctx.font='30px Arial';
    ctx.fillText('Select numeric cells for a chart',90,220);return;
  }
  const colors=['#107c41','#3e75bd','#e19636','#b05fa6','#cf5959',
    '#55a4a7','#916cc1','#758250'];
  if(chartKind==='pie'){
    const positives=values.map(v=>Math.max(0,v)),sum=positives.reduce((a,b)=>a+b,0);
    if(!sum)return;
    let angle=-Math.PI/2;
    positives.forEach((v,i)=>{
      const next=angle+2*Math.PI*v/sum;
      ctx.beginPath();ctx.moveTo(400,250);ctx.arc(400,250,190,angle,next);
      ctx.closePath();ctx.fillStyle=colors[i%colors.length];ctx.fill();
      angle=next;
    });
  }else{
    const min=Math.min(0,...values),max=Math.max(...values);
    const span=max-min||1,baseY=H-75;
    ctx.strokeStyle='#dce2e6';ctx.lineWidth=2;
    ctx.beginPath();ctx.moveTo(65,40);ctx.lineTo(65,baseY);ctx.lineTo(W-30,baseY);ctx.stroke();
    const count=values.length,available=W-130;
    const xAtIndex=i=>80+i*available/Math.max(1,count);
    const yAtValue=v=>baseY-(v-min)/span*(H-140);
    if(chartKind==='line'){
      ctx.strokeStyle=colors[0];ctx.lineWidth=5;ctx.beginPath();
      values.forEach((v,i)=>i?ctx.lineTo(xAtIndex(i),yAtValue(v)):
        ctx.moveTo(xAtIndex(i),yAtValue(v)));ctx.stroke();
    }else if(chartKind==='scatter'){
      values.forEach((v,i)=>{
        ctx.fillStyle=colors[i%colors.length];ctx.beginPath();
        ctx.arc(xAtIndex(i),yAtValue(v),7,0,Math.PI*2);ctx.fill();
      });
    }else{
      values.forEach((v,i)=>{
        const w=Math.max(2,available/count*.7);
        ctx.fillStyle=colors[i%colors.length];
        const y=yAtValue(v);
        ctx.fillRect(xAtIndex(i),Math.min(y,baseY),w,Math.max(1,Math.abs(baseY-y)));
      });
    }
    ctx.font='21px Arial';ctx.fillStyle='#536072';
    const step=Math.max(1,Math.ceil(values.length/10));
    for(let i=0;i<count;i+=step)ctx.fillText(labels[i].slice(0,10),xAtIndex(i),H-36);
  }
}
function exportCsv(){
  const s=book.active,cells=Object.keys(s.cells);
  if(!cells.length)return '';
  const positions=cells.map(parseAddress),maxR=Math.min(10000,Math.max(...positions.map(p=>p.row)));
  const maxC=Math.min(150,Math.max(...positions.map(p=>p.col)));
  const escape=v=>{
    const text=String(v);
    return /[,"\n]/.test(text)?'"'+text.replaceAll('"','""')+'"':text;
  };
  const lines=[];
  for(let r=0;r<=maxR;r++){
    const row=[];
    for(let c=0;c<=maxC;c++)row.push(escape(safeDisplay(address(r,c))));
    lines.push(row.join(','));
  }
  return lines.join('\r\n');
}
function readCsv(content){
  const rows=[],row=[];let part='',quote=false;
  for(let i=0;i<content.length;i++){
    const c=content[i];
    if(quote){
      if(c==='"'&&content[i+1]==='"'){part+='"';i++;}
      else if(c==='"')quote=false;
      else part+=c;
    }else if(c==='"')quote=true;
    else if(c===','){row.push(part);part='';}
    else if(c==='\n'){row.push(part.replace(/\r$/,''));rows.push(row.splice(0));part='';}
    else part+=c;
  }
  if(part||row.length){row.push(part);rows.push(row);}
  return rows;
}
function download(filename,value,mime){
  const url=URL.createObjectURL(new Blob([value],{type:mime||'text/plain'}));
  const a=document.createElement('a');a.href=url;a.download=filename;a.click();
  setTimeout(()=>URL.revokeObjectURL(url),1500);
}
function exportXlsx(){
  if(!window.XLSX){toast('XLSX library unavailable. Use CSV or JSON.');return;}
  const wb=window.XLSX.utils.book_new();
  for(const s of book.sheets){
    const ws={};
    for(const [ref,raw] of Object.entries(s.cells)){
      if(raw.startsWith('=')){
        let result;
        try{result=book.getValue(s.id,ref);}catch(_){result='';}
        ws[ref]={f:raw.slice(1),t:typeof result==='number'?'n':'s',
          v:typeof result==='number'?result:''};
      }else{
        const n=Number(raw);
        ws[ref]=raw.trim()!==''&&Number.isFinite(n)?
          {t:'n',v:n}:{t:'s',v:raw};
      }
    }
    ws['!cols']=Array.from({length:Math.min(50,MAX_COLS)},(_,i)=>
      ({wch:Math.round((s.widths[i]||DEFAULT_W)/7)}));
    window.XLSX.utils.book_append_sheet(wb,ws,s.name.slice(0,31));
  }
  window.XLSX.writeFile(wb,(name||'Arcside workbook')+'.xlsx');
}
async function importFile(file){
  if(!file)return;
  if(file.size>15_000_000){toast('Maximum import file size is 15 MB');return;}
  checkpoint();
  try{
    const lower=file.name.toLowerCase();
    if(lower.endsWith('.json')){
      const parsed=JSON.parse(await file.text());
      book=new ArcsideWorkbook(parsed.book||parsed);
      name=parsed.name||'Imported workbook';
    }else if(lower.endsWith('.csv')||lower.endsWith('.tsv')){
      const text=await file.text();
      const rows=lower.endsWith('.tsv')?
        text.trimEnd().split(/\r?\n/).map(r=>r.split('\t')):readCsv(text);
      book=new ArcsideWorkbook();name=file.name;
      for(let r=0;r<Math.min(10000,rows.length);r++)
        for(let c=0;c<Math.min(MAX_COLS,rows[r].length);c++)
          book.setRaw(book.active.id,address(r,c),rows[r][c]);
    }else if(lower.endsWith('.xlsx')||lower.endsWith('.xls')){
      if(!window.XLSX)throw new Error('XLSX converter did not load; use CSV instead');
      const data=await file.arrayBuffer();
      const parsed=window.XLSX.read(data,{type:'array',cellFormula:true});
      book=new ArcsideWorkbook();book.sheets=[];book.seq=0;
      for(const label of parsed.SheetNames.slice(0,50)){
        const sheet=book.addSheet(label),raw=parsed.Sheets[label];
        for(const [ref,cell] of Object.entries(raw)){
          if(ref.startsWith('!')||!cell||typeof cell!=='object')continue;
          try{
            parseAddress(ref);
            book.setRaw(sheet.id,ref,cell.f?'='+cell.f:String(cell.v??''));
          }catch(_){}
        }
      }
      name=file.name;
    }
    undo.length=0;redo.length=0;selected={row:0,col:0};anchor={...selected};
    $('workbookName').value=name;
    updateDimensions();renderAll();persist();
    toast('Workbook loaded');
  }catch(error){toast('Import failed: '+error.message);}
}
function tabs(){
  const root=$('sheetTabs');root.replaceChildren();
  for(const s of book.sheets){
    const tab=document.createElement('button');
    tab.className=s.id===book.activeId?'active':'';
    tab.textContent=s.name;
    tab.onclick=()=>{
      book.activeId=s.id;selected={row:0,col:0};anchor={...selected};
      filteredRows.clear();renderAll();persist();
    };
    root.append(tab);
  }
}
function renderAll(){tabs();syncFormula();drawGrid();if(chartVisible)drawChart();}
function bind(){
  $('gridViewport').addEventListener('scroll',scheduleDraw);
  window.addEventListener('mouseup',()=>dragging=false);
  $('gridViewport').onkeydown=e=>{
    if(editing)return;
    const mod=e.ctrlKey||e.metaKey;
    if(mod&&e.key.toLowerCase()==='z'){e.preventDefault();undoAction();return;}
    if(mod&&e.key.toLowerCase()==='y'){e.preventDefault();redoAction();return;}
    if(mod&&e.key.toLowerCase()==='d'){
      e.preventDefault();const b=rangeBounds(),first=sheetCell(address(b.r1,b.c1));
      checkpoint();for(let r=b.r1+1;r<=b.r2;r++)
        for(let c=b.c1;c<=b.c2;c++)setCell(address(r,c),first);
      renderAll();persist();return;
    }
    if(mod&&e.key.toLowerCase()==='f'){
      e.preventDefault();const query=prompt('Find value');
      if(query){for(const ref of Object.keys(book.active.cells)){
        if(safeDisplay(ref).toLowerCase().includes(query.toLowerCase())){
          const p=parseAddress(ref);choose(p.row,p.col,false,true);break;
        }
      }}return;
    }
    if(e.key==='Delete'||e.key==='Backspace'){
      e.preventDefault();checkpoint();const b=rangeBounds();
      for(let r=b.r1;r<=b.r2;r++)
        for(let c=b.c1;c<=b.c2;c++)setCell(address(r,c),'');
      renderAll();persist();return;
    }
    if(e.key==='F2'){e.preventDefault();editCell();return;}
    if(e.key==='ArrowDown'||e.key==='ArrowUp'||e.key==='ArrowLeft'||
      e.key==='ArrowRight'||e.key==='Tab'||e.key==='Enter'){
      e.preventDefault();
      const move=e.key==='ArrowDown'||e.key==='Enter'?[1,0]:
        e.key==='ArrowUp'?[-1,0]:
        e.key==='ArrowLeft'?[0,-1]:[0,1];
      if(e.key==='Tab'&&e.shiftKey)move[1]=-1;
      choose(selected.row+move[0],selected.col+move[1],e.shiftKey,true);return;
    }
    if(e.key.length===1&&!mod&&!e.altKey){
      e.preventDefault();editCell(e.key);
    }
  };
  $('gridViewport').addEventListener('copy',e=>{
    e.preventDefault();e.clipboardData.setData('text/plain',getTsv());
  });
  $('gridViewport').addEventListener('paste',e=>{
    e.preventDefault();pasteTsv(e.clipboardData.getData('text/plain'));
  });
  $('cellEdit').onkeydown=e=>{
    if(e.key==='Enter'){e.preventDefault();finishEdit(true,[e.shiftKey?-1:1,0]);}
    else if(e.key==='Tab'){e.preventDefault();finishEdit(true,[0,e.shiftKey?-1:1]);}
    else if(e.key==='Escape'){e.preventDefault();finishEdit(false);}
  };
  $('cellEdit').onblur=()=>{if(editing)finishEdit(true);};
  $('formulaInput').onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();commitFormula();}};
  $('nameBox').onkeydown=e=>{
    if(e.key!=='Enter')return;
    try{const p=parseAddress($('nameBox').value);choose(p.row,p.col,false,true);}
    catch(_){toast('Invalid cell reference');}
    $('gridViewport').focus();
  };
  $('workbookName').oninput=e=>{name=e.target.value;persist();};
  $('undo').onclick=undoAction;$('redo').onclick=redoAction;
  $('bold').onclick=()=>applyStyle({bold:!book.getStyle(book.active.id,selectedAddress()).bold});
  $('italic').onclick=()=>applyStyle({italic:!book.getStyle(book.active.id,selectedAddress()).italic});
  $('align').onclick=()=>{
    const old=book.getStyle(book.active.id,selectedAddress()).align;
    applyStyle({align:old==='center'?'right':old==='right'?'left':'center'});
  };
  $('format').onchange=e=>applyStyle({format:e.target.value});
  $('sum').onclick=autoSum;
  $('insertRow').onclick=insertRow;$('insertColumn').onclick=insertColumn;
  $('sortAsc').onclick=()=>sortRows(true);$('sortDesc').onclick=()=>sortRows(false);
  $('filter').onclick=filterRows;
  $('barChart').onclick=()=>chart('bar');
  $('lineChart').onclick=()=>chart('line');
  $('pieChart').onclick=()=>chart('pie');
  $('chartType').onchange=e=>chart(e.target.value);
  $('closeChart').onclick=()=>{$('chartPanel').style.display='none';chartVisible=false;};
  $('downloadChart').onclick=()=>{
    $('chart').toBlob(blob=>{
      if(blob){const url=URL.createObjectURL(blob),a=document.createElement('a');
        a.href=url;a.download='arcside-chart.png';a.click();
        setTimeout(()=>URL.revokeObjectURL(url),1000);}
    });
  };
  $('copy').onclick=copy;$('paste').onclick=paste;
  $('addSheet').onclick=()=>{
    checkpoint();book.addSheet();renderAll();persist();
  };
  $('renameSheet').onclick=()=>{
    const next=prompt('Rename sheet',book.active.name);
    if(next){checkpoint();if(!book.renameSheet(book.active.id,next))
      toast('Invalid or duplicate sheet name');renderAll();persist();}
  };
  $('deleteSheet').onclick=()=>{
    if(book.sheets.length===1)return;
    if(confirm('Delete '+book.active.name+'?')){
      checkpoint();book.deleteSheet(book.active.id);renderAll();persist();
    }
  };
  $('import').onclick=()=>$('fileInput').click();
  $('fileInput').onchange=e=>{void importFile(e.target.files[0]);e.target.value='';};
  $('export').onclick=()=>{
    const type=prompt('Export as: XLSX, CSV, or JSON?','XLSX');
    if(!type)return;
    if(type.toLowerCase()==='xlsx')exportXlsx();
    else if(type.toLowerCase()==='csv')
      download((name||'Arcside')+'.csv',exportCsv(),'text/csv');
    else download((name||'Arcside')+'.json',
      JSON.stringify({name,book:book.snapshot()},null,2),'application/json');
  };
  for(const tab of document.querySelectorAll('[data-menu]')){
    tab.onclick=()=>{
      document.querySelectorAll('[data-menu]').forEach(x=>x.classList.toggle(
        'active',x===tab));
      if(tab.dataset.menu==='Insert')toast('Use chart and insert tools on the ribbon');
      if(tab.dataset.menu==='Formulas')toast('Formulas use Excel syntax, including SUM, IF, VLOOKUP');
      if(tab.dataset.menu==='Data')toast('Use Sort and Filter on the ribbon');
    };
  }
  window.addEventListener('keydown',e=>{
    if((e.ctrlKey||e.metaKey)&&!editing&&
      !['INPUT','TEXTAREA'].includes(document.activeElement?.tagName)){
      if(e.key.toLowerCase()==='z'){e.preventDefault();undoAction();}
      if(e.key.toLowerCase()==='y'){e.preventDefault();redoAction();}
    }
  });
}
restore();bind();updateDimensions();renderAll();$('gridViewport').focus();
