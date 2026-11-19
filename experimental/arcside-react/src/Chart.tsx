import {useEffect,useMemo,useRef,useState} from 'react';
import * as echarts from 'echarts';
import type {RateBasis} from './data';
import type {MetricKey,Row} from './engine';
import {formatMetric,metrics,scatterKeys} from './engine';

type ChartSettings={x:MetricKey;y:MetricKey;pan:boolean;regression:boolean;selected:string};
const storeKey='arcside.phase3.chart.v1';
const defaultSettings:ChartSettings={x:'ast',y:'pts',pan:false,regression:false,selected:''};
const colorPalette=['#6db6ff','#d2a8ff','#6fd3b2','#f4b77d','#fc8aa8','#9cbbf8','#e4d16b','#7ad4dc'];
function teamColor(value:string):string {
 let hash=0;for(let i=0;i<value.length;i++)hash=(hash*31+value.charCodeAt(i))|0;
 return colorPalette[Math.abs(hash)%colorPalette.length];
}
function restore():ChartSettings {
 try {
  const saved=JSON.parse(localStorage.getItem(storeKey)??'null') as Partial<ChartSettings>|null;
  if(saved && scatterKeys.includes(saved.x as MetricKey) && scatterKeys.includes(saved.y as MetricKey)){
   return {...defaultSettings,...saved,pan:!!saved.pan,regression:!!saved.regression};
  }
 }catch{/* no user data is deleted */}
 return defaultSettings;
}
export function Chart({rows,basis}:{rows:Row[];basis:RateBasis}) {
 const [settings,setSettings]=useState(restore);
 const [hover,setHover]=useState<string>('');
 const [reset,setReset]=useState(0);
 const host=useRef<HTMLDivElement>(null);
 const chart=useRef<echarts.ECharts|null>(null);
 const settingsRef=useRef(settings);settingsRef.current=settings;
 const update=(patch:Partial<ChartSettings>)=>setSettings(s=>({...s,...patch}));
 useEffect(()=>{try{localStorage.setItem(storeKey,JSON.stringify(settings));}catch{/* private mode */}},[settings]);
 const dataset=useMemo(()=>rows.filter(r=>r.values[settings.x]!==null&&r.values[settings.y]!==null),
  [rows,settings.x,settings.y]);
 const chosen=dataset.find(r=>r.id===settings.selected);
 const metricLabel=(key:MetricKey)=>metrics.find(m=>m.key===key)?.label??key;
 useEffect(()=>{
  if(!host.current)return;
  const instance=echarts.init(host.current,undefined,{renderer:'canvas'});
  chart.current=instance;
  const resize=new ResizeObserver(()=>instance.resize());
  resize.observe(host.current);
  instance.on('click',(evt)=>{
   const data=evt.data as {id?:string}|undefined;
   if(data?.id)update({selected:data.id});
  });
  instance.on('mouseover',(evt)=>{
   const data=evt.data as {id?:string;name?:string}|undefined;
   if(data?.id)setHover(data.name??'');
  });
  instance.on('mouseout',()=>setHover(''));
  return ()=>{resize.disconnect();chart.current=null;instance.dispose();};
 },[]);
 useEffect(()=>{
  const points=dataset.map(r=>({
   id:r.id,name:r.player,team:r.team,
   value:[r.values[settings.x],r.values[settings.y]],
   itemStyle:{color:teamColor(r.team),borderColor:r.id===settings.selected?'#fff':'transparent',
    borderWidth:r.id===settings.selected?3:0},
   symbolSize:r.id===settings.selected?17:10
  }));
  const numeric=dataset.map(r=>[r.values[settings.x]!,r.values[settings.y]!]);
  const n=numeric.length,sx=numeric.reduce((s,p)=>s+p[0],0),sy=numeric.reduce((s,p)=>s+p[1],0);
  const sxx=numeric.reduce((s,p)=>s+p[0]*p[0],0),sxy=numeric.reduce((s,p)=>s+p[0]*p[1],0);
  const denominator=n*sxx-sx*sx;
  const slope=n>1&&Math.abs(denominator)>1e-12?(n*sxy-sx*sy)/denominator:null;
  const intercept=slope===null?null:(sy-slope*sx)/n;
  const minX=Math.min(...numeric.map(p=>p[0])),maxX=Math.max(...numeric.map(p=>p[0]));
  const line=slope===null||!Number.isFinite(minX)||!Number.isFinite(maxX)?[]:
   [[minX,slope*minX+intercept!],[maxX,slope*maxX+intercept!]];
  const option={
   backgroundColor:'transparent',
   textStyle:{color:'#c4d4e6'},
   animation:false,
   grid:{left:72,right:30,top:32,bottom:68,containLabel:false},
   xAxis:{type:'value' as const,name:metricLabel(settings.x),nameLocation:'middle' as const,nameGap:38,
    axisLine:{lineStyle:{color:'#526780'}},axisLabel:{color:'#9fb2c9'},splitLine:{lineStyle:{color:'#253449'}}},
   yAxis:{type:'value' as const,name:metricLabel(settings.y),nameLocation:'middle' as const,nameGap:50,
    axisLine:{lineStyle:{color:'#526780'}},axisLabel:{color:'#9fb2c9'},splitLine:{lineStyle:{color:'#253449'}}},
   tooltip:{trigger:'item' as const,confine:true,formatter:(p:any)=>{
    if(p.seriesName!=='Players')return '';
    const d=p.data as {name:string;team:string;value:[number,number]};
    const safe=(v:string)=>v.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
    return '<b>'+safe(d.name)+'</b> · '+safe(d.team)+'<br/>'+
      safe(metricLabel(settings.x))+': '+formatMetric(settings.x,d.value[0])+'<br/>'+
      safe(metricLabel(settings.y))+': '+formatMetric(settings.y,d.value[1]);
   }},
   dataZoom:[{type:'inside' as const,xAxisIndex:0,zoomOnMouseWheel:!settings.pan,
     moveOnMouseMove:settings.pan,moveOnMouseWheel:false},
    {type:'inside' as const,yAxisIndex:0,zoomOnMouseWheel:!settings.pan,
     moveOnMouseMove:settings.pan,moveOnMouseWheel:false}],
   series:[
    {name:'Players',type:'scatter' as const,large:false,data:points,emphasis:{focus:'self' as const}},
    ...(settings.regression&&line.length?[
     {name:'Linear reference',type:'line' as const,data:line,symbol:'none',silent:true,
      lineStyle:{type:'dashed' as const,color:'#eecb83',width:2}}]:[])
   ]
  };
  chart.current?.setOption(option,true);
 },[dataset,settings.x,settings.y,settings.pan,settings.regression,settings.selected,reset]);
 return <section className="panel" aria-labelledby="visual-title">
  <div className="panel-title">
   <div><p className="eyebrow">VISUALIZATION STUDIO / EXPERIMENT</p><h2 id="visual-title">Player scatter explorer</h2>
    <p className="subtle">Source-backed season rows only · {dataset.length.toLocaleString()} plotted · {basis}</p></div>
   <div className="row-wrap">
    <button className={settings.pan?'active-control':''} onClick={()=>update({pan:false})} aria-pressed={!settings.pan}>Wheel zoom</button>
    <button className={settings.pan?'active-control':''} onClick={()=>update({pan:true})} aria-pressed={settings.pan}>Drag pan</button>
    <button onClick={()=>setReset(x=>x+1)}>Reset view</button>
   </div>
  </div>
  <div className="toolbar">
   <label>X metric<select value={settings.x} onChange={e=>update({x:e.target.value as MetricKey})}>
    {scatterKeys.map(k=><option key={k} value={k}>{metricLabel(k)}</option>)}</select></label>
   <label>Y metric<select value={settings.y} onChange={e=>update({y:e.target.value as MetricKey})}>
    {scatterKeys.map(k=><option key={k} value={k}>{metricLabel(k)}</option>)}</select></label>
   <label className="check"><input type="checkbox" checked={settings.regression}
    onChange={e=>update({regression:e.target.checked})}/> Linear reference</label>
   <span className="hint">Click a point to persist the selected player. Scroll to zoom or drag to pan.</span>
  </div>
  {dataset.length?<div ref={host} className="chart" role="img" aria-label={'Scatter plot of '+metricLabel(settings.x)+' against '+metricLabel(settings.y)+', '+dataset.length+' players'}/>:
   <div className="empty chart-empty">No players have both selected source-backed metrics for these filters.</div>}
  {dataset.length===0&&<div ref={host} className="chart-offscreen" aria-hidden="true"/>}
  <div className="chart-footer">
   <span role="status">{chosen?'Selected: '+chosen.player+' · '+chosen.team: hover?'Hover: '+hover:'No selected player'}</span>
   <span>Selection and settings persist in this browser only.</span>
  </div>
  <div className="chart-accessible">
   <h3>Accessible data readout</h3>
   <table><thead><tr><th>Player</th><th>Team</th><th>{metricLabel(settings.x)}</th><th>{metricLabel(settings.y)}</th></tr></thead>
    <tbody>{dataset.slice(0,20).map(r=><tr key={r.id}>
     <td><button className="text-button" onClick={()=>update({selected:r.id})}>{r.player}</button></td>
     <td>{r.team}</td><td>{formatMetric(settings.x,r.values[settings.x])}</td>
     <td>{formatMetric(settings.y,r.values[settings.y])}</td></tr>)}</tbody></table>
   <p className="subtle">First 20 available plotted rows. The scatter remains exploratory and is not a complete screen-reader alternative.</p>
  </div>
 </section>;
}
