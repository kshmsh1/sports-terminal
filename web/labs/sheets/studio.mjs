import {pivotTable,filterTable,chartData} from './analytics.mjs';

const NS='http://www.w3.org/2000/svg';
const COLORS=['#4e90eb','#30c4b6','#f2aa51','#b48de8','#d36e93','#78c678','#6cc9f7'];
const element=(tag,className='',text='')=>{
  const n=document.createElement(tag);if(className)n.className=className;
  if(text)n.textContent=text;
  return n;
};
function fieldSelect(headers,{optional=false,value=null}={}){
  const select=element('select');
  if(optional){const o=element('option','','(none)');o.value='';select.append(o);}
  headers.forEach((h,i)=>{
    const o=element('option','',String(h));o.value=String(i);select.append(o);
  });
  if(value!==null)select.value=String(value);
  return select;
}
function line(label,control){
  const row=element('label','studio-field');
  row.append(element('span','',label),control);
  return row;
}
function optionSelect(options,selected=options[0]){
  const select=element('select');
  for(const value of options){const o=element('option','',value);o.value=value;select.append(o);}
  select.value=selected;return select;
}
export async function runAnalytics(action,rows,options){
  if(typeof Worker==='undefined'){
    if(action==='pivot')return pivotTable(rows,options);
    if(action==='filter')return filterTable(rows,options.filters??[]);
    if(action==='chart')return chartData(rows,options);
    throw Error('Unsupported analysis operation');
  }
  return new Promise((resolve,reject)=>{
    const worker=new Worker(new URL('./analytics.worker.mjs',import.meta.url),{type:'module'});
    const timer=setTimeout(()=>{worker.terminate();reject(Error('Analytics worker exceeded 30 seconds'));},30000);
    function finish(){clearTimeout(timer);worker.terminate();}
    worker.onmessage=({data})=>{
      if(data.id!==1)return;
      finish();
      if(data.ok)resolve(data.result);else reject(Error(data.error));
    };
    worker.onerror=e=>{finish();reject(Error(e.message||'Analytics worker failed'));};
    worker.postMessage({id:1,action,rows,options});
  });
}
export function pivotDesigner(rows,{onCreate,initial}={}) {
  const headers=rows[0].map((v,i)=>String(v)||'Field '+(i+1));
  const wrap=element('div','studio');
  const intro=element('p','studio-intro',
    'Group by multiple fields, optionally split into columns, and summarize a measure. Calculations run in a Web Worker.');
  wrap.append(intro);
  const controls=element('div','studio-controls');
  const row=fieldSelect(headers,{value:initial?.rows?.[0]??0});
  const second=fieldSelect(headers,{optional:true,value:initial?.rows?.[1]??''});
  const column=fieldSelect(headers,{optional:true,value:initial?.column??''});
  const value=fieldSelect(headers,{value:initial?.metrics?.[0]?.field??1});
  const aggregate=optionSelect(['sum','count','average','min','max','median','stdev','distinctCount'],
    initial?.metrics?.[0]?.aggregate??'sum');
  const filterField=fieldSelect(headers,{optional:true,value:initial?.filters?.[0]?.field??''});
  const filterOp=optionSelect(['equals','notEquals','contains','startsWith','greater','greaterOrEqual','less','lessOrEqual','notBlank'],
    initial?.filters?.[0]?.op??'equals');
  const filterValue=element('input');filterValue.placeholder='Optional filter value';
  filterValue.value=initial?.filters?.[0]?.value??'';
  for(const [labelText,control] of [
    ['Row field',row],['Second row field',second],['Pivot column',column],
    ['Numeric measure',value],['Aggregate',aggregate],
    ['Filter field',filterField],['Filter operator',filterOp],['Filter value',filterValue],
  ])controls.append(line(labelText,control));
  wrap.append(controls);
  const actions=element('div','studio-actions');
  const create=element('button','primary',initial?'Refresh pivot sheet':'Create pivot sheet');
  const status=element('span','','Ready');
  actions.append(create,status);wrap.append(actions);
  const sample=element('div','studio-preview');wrap.append(sample);
  async function preview(){
    const opts=options();
    if(opts.rows.includes('')||opts.rows.length===0)return;
    try{
      const result=await runAnalytics('pivot',rows.slice(0,1000),opts);
      const table=element('table','studio-preview-table');
      for(const [index,r] of result.matrix.slice(0,8).entries()){
        const tr=element('tr');
        for(const value of r.slice(0,9))tr.append(element(index===0?'th':'td','',String(value??'')));
        table.append(tr);
      }
      sample.replaceChildren(table);
      status.textContent='Preview: '+result.groupCount+' group(s)';
    }catch(e){sample.textContent='Preview: '+e.message;}
  }
  function options(){
    const filters=filterField.value===''?[]:[{
      field:Number(filterField.value),op:filterOp.value,value:filterValue.value,
    }];
    return {
      rows:[Number(row.value),...(second.value===''?[]:[Number(second.value)])],
      column:column.value===''?null:Number(column.value),
      metrics:[{field:Number(value.value),aggregate:aggregate.value}],
      filters,totals:true,
    };
  }
  for(const control of controls.querySelectorAll('input,select'))
    control.addEventListener('change',()=>void preview());
  create.onclick=async()=>{
    create.disabled=true;status.textContent='Aggregating table…';
    try{
      const opts=options();
      const result=await runAnalytics('pivot',rows,opts);
      await onCreate(result,opts);
      status.textContent='Pivot saved · '+result.groupCount+' group(s)';
    }catch(e){status.textContent='Error: '+e.message;}
    finally{create.disabled=false;}
  };
  void preview();
  return wrap;
}
function svgChild(svg,tag,attributes={},text){
  const node=document.createElementNS(NS,tag);
  for(const [key,value] of Object.entries(attributes))node.setAttribute(key,String(value));
  if(text!==undefined)node.textContent=String(text);
  svg.append(node);return node;
}
export function drawChart(svg,chart){
  svg.replaceChildren();svg.setAttribute('viewBox','0 0 760 390');
  svg.classList.add('chart');
  const labels=chart.labels.slice(0,80),series=chart.series.slice(0,8);
  svgChild(svg,'rect',{width:760,height:390,fill:'#13243a',rx:6});
  svgChild(svg,'text',{x:20,y:28,fill:'#e7f2ff','font-size':16,'font-weight':'bold'},chart.title);
  if(!labels.length||!series.length)return;
  if(chart.type==='pie'){
    const values=series[0].values.slice(0,labels.length).map(n=>Math.max(0,n??0));
    const total=values.reduce((s,n)=>s+n,0);
    if(!total)return;
    let start=-Math.PI/2;
    values.forEach((v,i)=>{
      if(!v)return;
      const end=start+(v/total)*2*Math.PI;
      const x1=285+130*Math.cos(start),y1=200+130*Math.sin(start);
      const x2=285+130*Math.cos(end),y2=200+130*Math.sin(end);
      if(v===total)svgChild(svg,'circle',{cx:285,cy:200,r:130,fill:COLORS[i%COLORS.length]});
      else svgChild(svg,'path',{
        d:'M 285 200 L '+x1+' '+y1+' A 130 130 0 '+(end-start>Math.PI?1:0)+' 1 '+x2+' '+y2+' Z',
        fill:COLORS[i%COLORS.length],
      });
      start=end;
    });
    labels.slice(0,10).forEach((name,i)=>{
      svgChild(svg,'rect',{x:510,y:65+i*24,width:12,height:12,fill:COLORS[i%COLORS.length]});
      svgChild(svg,'text',{x:529,y:75+i*24,fill:'#d4e3f6','font-size':12},
        name+' · '+values[i]);
    });
    return;
  }
  const all=series.flatMap(s=>s.values).filter(v=>v!==null&&Number.isFinite(v));
  const min=Math.min(0,...all),max=Math.max(1,...all),span=max-min;
  const left=60,top=60,width=640,height=260,baseY=top+(max/span)*height;
  const scaleY=value=>top+(max-value)/span*height;
  svgChild(svg,'line',{x1:left,y1:baseY,x2:left+width,y2:baseY,stroke:'#819bb6'});
  svgChild(svg,'line',{x1:left,y1:top,x2:left,y2:top+height,stroke:'#5c7897'});
  const step=width/labels.length;
  series.forEach((item,si)=>{
    const points=[];
    item.values.slice(0,labels.length).forEach((v,i)=>{
      if(v===null||!Number.isFinite(v))return;
      const x=left+(i+0.5)*step,y=scaleY(v);
      points.push([x,y]);
      if(chart.type==='bar'){
        const groupWidth=step*.78,barWidth=groupWidth/series.length;
        svgChild(svg,'rect',{
          x:left+i*step+step*.11+si*barWidth,y:Math.min(y,baseY),
          width:Math.max(1,barWidth-1),height:Math.max(1,Math.abs(baseY-y)),
          fill:COLORS[si%COLORS.length],
        });
      }else if(chart.type==='scatter'){
        svgChild(svg,'circle',{cx:x,cy:y,r:4,fill:COLORS[si%COLORS.length]});
      }else{
        svgChild(svg,'circle',{cx:x,cy:y,r:3,fill:COLORS[si%COLORS.length]});
      }
    });
    if(['line','area'].includes(chart.type)&&points.length){
      const locations=points.map(([x,y])=>x+','+y).join(' ');
      if(chart.type==='area'){
        const first=points[0][0],last=points.at(-1)[0];
        svgChild(svg,'polygon',{points:locations+' '+last+','+baseY+' '+first+','+baseY,
          fill:COLORS[si%COLORS.length],opacity:.2});
      }
      svgChild(svg,'polyline',{points:locations,fill:'none',
        stroke:COLORS[si%COLORS.length],'stroke-width':2.5});
    }
  });
  labels.forEach((label,i)=>{
    if(labels.length>24&&i%Math.ceil(labels.length/24)!==0)return;
    svgChild(svg,'text',{x:left+(i+.5)*step,y:343,fill:'#9fb9d6',
      'font-size':10,'text-anchor':'middle'},String(label).slice(0,12));
  });
  for(let tick=0;tick<=4;tick++){
    const value=min+(max-min)*tick/4;
    svgChild(svg,'text',{x:52,y:scaleY(value)+3,fill:'#9fb9d6',
      'font-size':10,'text-anchor':'end'},Number(value.toPrecision(3)));
  }
  series.forEach((series,i)=>{
    svgChild(svg,'circle',{cx:60+i*110,cy:374,r:5,fill:COLORS[i%COLORS.length]});
    svgChild(svg,'text',{x:70+i*110,y:378,fill:'#c8dcf3','font-size':11},
      series.name.slice(0,14));
  });
}
export function chartDesigner(rows,{initial,onSave}={}) {
  const headers=rows[0].map((v,i)=>String(v)||'Field '+(i+1));
  const root=element('div','studio');
  const fields=element('div','studio-controls');
  const title=element('input');title.value=initial?.title??'Arcside analysis';
  const kind=optionSelect(['bar','line','area','scatter','pie'],initial?.type??'bar');
  const category=fieldSelect(headers,{value:initial?.category??0});
  const seriesBox=element('div','chart-series-options');
  const checks=[];
  headers.forEach((header,index)=>{
    if(index===0&&headers.length>1)return;
    const label=element('label');
    const checkbox=document.createElement('input');checkbox.type='checkbox';
    checkbox.value=String(index);
    checkbox.checked=(initial?.series??[1]).includes(index);
    checks.push(checkbox);
    label.append(checkbox,element('span','',header));seriesBox.append(label);
  });
  for(const [labelText,control] of [
    ['Title',title],['Chart type',kind],['Category',category],['Series (select multiple)',seriesBox],
  ])fields.append(line(labelText,control));
  const chart=document.createElementNS(NS,'svg');
  chart.classList.add('chart');
  const actions=element('div','studio-actions');
  const save=element('button','primary',initial?'Update saved chart':'Save chart to workbook');
  const status=element('span','','');
  actions.append(save,status);
  root.append(fields,chart,actions);
  function config(){
    const chosen=checks.filter(c=>c.checked).map(c=>Number(c.value));
    return {title:title.value.trim()||'Chart',type:kind.value,
      category:Number(category.value),series:chosen.length?chosen:[1]};
  }
  const redraw=()=>{
    try{drawChart(chart,chartData(rows,config()));status.textContent='';}
    catch(e){status.textContent=e.message;}
  };
  fields.addEventListener('change',redraw);
  title.addEventListener('input',redraw);
  save.onclick=()=>{try{onSave(config());status.textContent='Chart definition saved';}catch(e){status.textContent=e.message;}};
  redraw();
  return root;
}
export function formatDesigner(rules,{range,onAdd,onDelete}={}) {
  const root=element('div','studio'),fields=element('div','studio-controls');
  const kind=optionSelect(['greaterThan','lessThan','equalTo','between','contains','notBlank','dataBar','colorScale']);
  const threshold=element('input');threshold.placeholder='Threshold or text';threshold.value='0';
  const second=element('input');second.placeholder='Upper bound';second.value='100';
  const color=document.createElement('input');color.type='color';color.value='#186c51';
  fields.append(line('Rule',kind),line('Value',threshold),line('Second value',second),
    line('Highlight color',color));
  const add=element('button','primary','Add formatting rule'),existing=element('div','rules-list');
  add.onclick=()=>{
    onAdd({kind:kind.value,value:threshold.value,second:second.value,
      color:color.value,range:{...range}});
    showExisting();
  };
  function showExisting(){
    existing.replaceChildren();
    for(const [i,rule] of rules().entries()){
      const row=element('div','rule-entry',rule.sheet+' · '+rule.kind+' '+(rule.value??''));
      const remove=element('button','','Remove');
      remove.onclick=()=>{onDelete(i);showExisting();};
      row.append(remove);existing.append(row);
    }
  }
  root.append(element('p','studio-intro','Rules are saved with the workbook and applied to visible cells.'),
    fields,add,existing);
  showExisting();
  return root;
}
