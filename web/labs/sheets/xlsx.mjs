// Optional XLSX interoperability. ExcelJS is MIT licensed and is loaded
// only on the user's explicit XLSX import/export action.
import {Workbook,columnName,parseRef} from './core.mjs';

const EXCELJS_CDN='https://cdnjs.cloudflare.com/ajax/libs/exceljs/4.4.0/exceljs.min.js';
let loader;
export async function loadExcelJS() {
  if(window.ExcelJS)return window.ExcelJS;
  if(!loader)loader=new Promise((resolve,reject)=>{
    const script=document.createElement('script');
    script.src=EXCELJS_CDN;script.async=true;
    script.onload=()=>window.ExcelJS?resolve(window.ExcelJS):reject(Error('ExcelJS did not initialize'));
    script.onerror=()=>reject(Error('XLSX library unavailable. Check network access.'));
    document.head.appendChild(script);
  }).catch(error=>{loader=null;throw error;});
  return loader;
}
function rawCellValue(cell){
  const value=cell.value;
  if(value===null||value===undefined)return '';
  if(value instanceof Date)return value.toISOString().slice(0,10);
  if(typeof value==='object'){
    if(typeof value.formula==='string')return '='+value.formula;
    if(typeof value.sharedFormula==='string'&&typeof cell.formula==='string')return '='+cell.formula;
    if(value.richText)return value.richText.map(t=>t.text??'').join('');
    if(value.text!==undefined)return String(value.text);
    if(value.result!==undefined)return String(value.result);
    return '';
  }
  return String(value);
}
function sanitizeName(name,existing) {
  let candidate=String(name||'Sheet1').replace(/[!]/g,'_').slice(0,48).trim()||'Sheet1';
  const base=candidate;let i=1;
  while(existing.has(candidate))candidate=(base.slice(0,42)+'_'+(++i)).slice(0,48);
  return candidate;
}
export async function importXlsx(arrayBuffer) {
  const ExcelJS=await loadExcelJS();
  const external=new ExcelJS.Workbook();
  await external.xlsx.load(arrayBuffer);
  const result=new Workbook(),names=new Set();
  result.sheets.clear();
  let count=0;
  for(const worksheet of external.worksheets){
    const name=sanitizeName(worksheet.name,names);names.add(name);
    result._addRaw(name,{});
    worksheet.eachRow({includeEmpty:false},(row,rowNum)=>{
      row.eachCell({includeEmpty:false},(cell,colNum)=>{
        if(rowNum>100000||colNum>256)return;
        const raw=rawCellValue(cell);
        if(raw==='')return;
        if(++count>250000)throw Error('XLSX exceeds the 250,000-cell import limit');
        result.set(name,columnName(colNum)+rowNum,raw);
        const fill=cell.fill?.fgColor?.argb;
        if(fill&&fill.length>=6)result.setStyle(name,columnName(colNum)+rowNum,{fill:'#'+fill.slice(-6)});
        if(cell.font?.bold)result.setStyle(name,columnName(colNum)+rowNum,{bold:true});
        if(cell.font?.italic)result.setStyle(name,columnName(colNum)+rowNum,{italic:true});
        if(cell.numFmt==='0.00%')result.setStyle(name,columnName(colNum)+rowNum,{numberFormat:'percent'});
        if(cell.numFmt?.includes('$'))result.setStyle(name,columnName(colNum)+rowNum,{numberFormat:'currency'});
      });
    });
    worksheet.columns.forEach((column,index)=>{
      if(column.width&&index<256)result.sheets.get(name).widths[columnName(index+1)]=
        Math.min(420,Math.max(55,Math.round(column.width*8)));
    });
  }
  if(!result.sheets.size)result._addRaw('Sheet1',{});
  result.active=result.sheets.keys().next().value;
  result._rebuild();
  return result;
}
export async function exportXlsx(book) {
  const ExcelJS=await loadExcelJS();
  const external=new ExcelJS.Workbook();
  external.creator='Arcside Sheets';
  for(const data of book.sheets.values()){
    const sheet=external.addWorksheet(data.name.slice(0,31),{views:[{state:'frozen',ySplit:1}]});
    for(const [ref,raw] of Object.entries(data.cells)){
      const cell=sheet.getCell(ref);
      if(raw.startsWith('=')){
        let computed;
        try{computed=book.value(data.name,ref);}catch{}
        // Excel recalculates formulas on open; only include safe scalar cache.
        const result=typeof computed==='number'&&Number.isFinite(computed)
          ?computed:typeof computed==='string'&&computed[0]!=='#'?computed:undefined;
        cell.value=result===undefined?{formula:raw.slice(1)}:{formula:raw.slice(1),result};
      }else if(/^[+-]?(?:\d+(?:\.\d+)?|\.\d+)$/.test(raw)){
        cell.value=Number(raw);
      }else if(raw==='TRUE'||raw==='FALSE'){
        cell.value=raw==='TRUE';
      }else cell.value=raw;
      const style=data.styles[ref];
      if(!style)continue;
      if(style.bold||style.italic||style.color){
        cell.font={bold:!!style.bold,italic:!!style.italic,
          color:style.color?{argb:'FF'+style.color.slice(-6).toUpperCase()}:undefined};
      }
      if(style.fill)cell.fill={type:'pattern',pattern:'solid',
        fgColor:{argb:'FF'+style.fill.slice(-6).toUpperCase()}};
      if(style.numberFormat==='currency')cell.numFmt='"$"#,##0.00';
      if(style.numberFormat==='percent')cell.numFmt='0.00%';
      if(style.numberFormat==='number')cell.numFmt='#,##0.000';
      if(style.align)cell.alignment={horizontal:style.align==='center'?'center':style.align==='flex-end'?'right':'left'};
    }
    for(const [col,width] of Object.entries(data.widths)){
      const index=parseRef(col+'1').col;
      sheet.getColumn(index).width=Math.max(7,Math.round(Number(width)/8));
    }
  }
  external.calcProperties.fullCalcOnLoad=true;
  return external.xlsx.writeBuffer();
}
