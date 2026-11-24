import {columnIndex,columnName} from './core.mjs';

/**
 * Copy/move a spreadsheet formula while honoring Excel's $ column/row anchors.
 * Text literals and quoted sheet names are never rewritten.
 *
 * =A1+$B2+C$3+$D$4 shifted down 2 / right 1
 * becomes =B3+$B4+D$3+$D$4.
 *
 * Does not implement Excel structured references or external workbooks.
 */
export function rebaseFormula(source, rowDelta=0, colDelta=0) {
  const raw=String(source??'');
  if(!raw.startsWith('=')||(rowDelta===0&&colDelta===0))return raw;
  const move=(chunk)=>chunk.replace(
    /(?<![A-Z0-9_])(\$?)([A-Z]{1,4})(\$?)([1-9]\d*)(?![A-Z0-9_!])/gi,
    (whole, colFixed, letters, rowFixed, number)=>{
      const origCol=columnIndex(letters),origRow=Number(number);
      const col=origCol+(colFixed?0:colDelta),row=origRow+(rowFixed?0:rowDelta);
      if(col<1||col>16384||row<1||row>1048576)return '#REF!';
      return colFixed+columnName(col)+rowFixed+row;
    });
  let result='',i=0,chunk='';
  const flush=()=>{if(chunk){result+=move(chunk);chunk='';}};
  while(i<raw.length){
    const ch=raw[i];
    if(ch!=='"'&&ch!=="'"){chunk+=ch;i++;continue;}
    flush();
    const quote=ch;
    result+=quote;i++;
    while(i<raw.length){
      const letter=raw[i];result+=letter;i++;
      if(letter===quote){
        if(raw[i]===quote){result+=quote;i++;continue;}
        break;
      }
    }
  }
  flush();
  return result;
}
