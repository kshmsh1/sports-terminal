import {useEffect,useMemo,useRef,useState} from 'react';
import * as echarts from 'echarts';
import type {RateBasis,SeasonType} from './data';
import type {MetricKey,Row} from './engine';
import {formatMetric,metrics,scatterKeys} from './engine';
import {correlationLabel,histogram,linearStats,quantile,rowTeams,selectVisualizationRows,
 scatterPopulationSizes,visualizationKinds} from './visualization_math';
import type {ChartKind,ColorBy,LabelDensity} from './visualization_math';

type Settings={
 x:MetricKey;y:MetricKey;size:MetricKey;pan:boolean;regression:boolean;selected:string;
 kind:ChartKind;colorBy:ColorBy;minGames:number;population:number;rankingSize:number;
 filter:string;labels:boolean;means:boolean;grid:boolean;zero:boolean;
 density:LabelDensity;bins:number;radarCompare:string;
};
type SavedPreset={name:string;settings:Settings};
const settingsKey='arcside.phase3.chart.v2',presetsKey='arcside.phase3.chart.presets.v1';
const defaults:Settings={
 x:'ast',y:'pts',size:'reb',pan:false,regression:true,selected:'',
 kind:'scatter',colorBy:'Team',minGames:50,population:40,rankingSize:20,
 filter:'',labels:true,means:false,grid:true,zero:false,density:'More',bins:12,radarCompare:''
};
const palette=['#6db6ff','#d2a8ff','#6fd3b2','#f4b77d','#fc8aa8','#9cbbf8','#e4d16b','#7ad4dc'];
const teamColors:Record<string,string>={ATL:'#E03A3E',BOS:'#007A33',BKN:'#8C8C8C',BRK:'#8C8C8C',CHA:'#1D8E9F',CHI:'#CE1141',CLE:'#860038',DAL:'#2D7DC1',DEN:'#F0B323',DET:'#C8102E',GSW:'#1D70B7',HOU:'#CE1141',IND:'#FDBB30',LAC:'#C8102E',LAL:'#8A63D2',MEM:'#6C8EBF',MIA:'#B6264F',MIL:'#2F8B57',MIN:'#5D87B5',NOP:'#C79A4A',NYK:'#F58426',OKC:'#4AA3DF',ORL:'#5AA7D9',PHI:'#3D78C5',PHO:'#E56020',POR:'#E03A3E',SAC:'#7B61A8',SAS:'#A6A6A6',TOR:'#D43B5E',UTA:'#6B63B5',WAS:'#56789A'};
const positionColors:Record<string,string>={PG:'#5C8FDB',SG:'#4FB6A8',SF:'#7DBA57',PF:'#E1A74F',C:'#9B73D2',G:'#4FA2C6',F:'#D17C5E'};
function teamColor(value:string){
 let hash=0;for(let i=0;i<value.length;i++)hash=(hash*31+value.charCodeAt(i))|0;
 return teamColors[value]??positionColors[value]??palette[Math.abs(hash)%palette.length];
}
function validSettings(candidate:unknown):Settings {
 if(!candidate||typeof candidate!=='object')return {...defaults};
 const s=candidate as Partial<Settings>;
 const metric=(v:unknown,fallback:MetricKey):MetricKey=>
  scatterKeys.includes(v as MetricKey)?v as MetricKey:fallback;
 const allowed=(v:unknown,choices:readonly string[],fallback:string)=>
  typeof v==='string'&&choices.includes(v)?v:fallback;
 const number=(v:unknown,min:number,max:number,fallback:number)=>
  typeof v==='number'&&Number.isFinite(v)?Math.min(max,Math.max(min,v)):fallback;
 return {
  ...defaults,x:metric(s.x,'ast'),y:metric(s.y,'pts'),size:metric(s.size,'reb'),
  kind:allowed(s.kind,visualizationKinds.map(v=>v.value),'scatter') as ChartKind,
  colorBy:allowed(s.colorBy,['Team','Position','None'],'Team') as ColorBy,
  density:allowed(s.density,['Selective','More','All'],'More') as LabelDensity,
  population:scatterPopulationSizes.includes(s.population as 0)?s.population!:40,
  rankingSize:s.rankingSize===10?10:20,
  minGames:number(s.minGames,0,82,50),bins:number(s.bins,8,20,12),
  labels:s.labels!==false,regression:s.regression!==false,pan:s.pan===true,
  means:s.means===true,grid:s.grid!==false,zero:s.zero===true,
  selected:typeof s.selected==='string'?s.selected:'',
  filter:typeof s.filter==='string'&&/^(team|player):/.test(s.filter)?s.filter:'',
  radarCompare:typeof s.radarCompare==='string'?s.radarCompare:''
 };
}
function restore():Settings {
 try{
  const saved=localStorage.getItem(settingsKey);
  if(saved)return validSettings(JSON.parse(saved));
  const old=localStorage.getItem('arcside.phase3.chart.v1');
  if(old)return validSettings({...defaults,...JSON.parse(old)});
 }catch{/* no storage available */}
 return {...defaults};
}
function readPresets():SavedPreset[]{
 try{
  const data=JSON.parse(localStorage.getItem(presetsKey)??'[]');
  return Array.isArray(data)?data.filter(x=>x&&typeof x.name==='string'&&
   x.name.length<=80&&x.settings&&typeof x.settings==='object').slice(-10)
   .map(x=>({name:x.name,settings:validSettings(x.settings)})):[];
 }catch{return [];}
}
const fmt=(v:number)=>Number.isFinite(v)?v.toFixed(3):'—';
const chartLabel=(key:MetricKey)=>metrics.find(m=>m.key===key)?.label??key;
const escapeHtml=(s:string)=>s.replaceAll('&','&amp;').replaceAll('<','&lt;')
 .replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#39;');

export function Chart({rows,basis,segment='regular'}:{
 rows:Row[];basis:RateBasis;segment?:SeasonType;
}){
 const [settings,setSettings]=useState(restore);
 const [presets,setPresets]=useState<SavedPreset[]>(readPresets);
 const [presetName,setPresetName]=useState('');
 const [activePreset,setActivePreset]=useState('');
 const [search,setSearch]=useState('');
 const [hover,setHover]=useState('');
 const [reset,setReset]=useState(0);
 const host=useRef<HTMLDivElement>(null),chart=useRef<echarts.ECharts|null>(null);
 const viewport=useRef<{rows:Row[];basis:RateBasis;kind:ChartKind;x:MetricKey;y:MetricKey;
  size:MetricKey;filter:string;population:number;minGames:number;reset:number}|null>(null);
 const update=(patch:Partial<Settings>)=>setSettings(s=>({...s,...patch}));
 useEffect(()=>{update({minGames:segment==='playoffs'?4:50,filter:''});setSearch('');},[segment]);
 useEffect(()=>{try{localStorage.setItem(settingsKey,JSON.stringify(settings));}catch{/* no storage */}},[settings]);
 const selected=useMemo(()=>selectVisualizationRows(rows,{
  x:settings.x,y:settings.y,size:settings.size,kind:settings.kind,
  minGames:settings.minGames,filter:settings.filter,
  population:settings.population,rankingSize:settings.rankingSize,basis
 }),[rows,settings.x,settings.y,settings.size,settings.kind,settings.minGames,
     settings.filter,settings.population,settings.rankingSize]);
 const {plotted,eligible,matching,ranked}=selected;
 const analytics=useMemo(()=>['scatter','bubble'].includes(settings.kind)?
  linearStats(plotted,settings.x,settings.y):null,
  [plotted,settings.kind,settings.x,settings.y]);
 const choices=useMemo(()=>{
  const teams=[...new Set(rows.flatMap(rowTeams))].sort().map(team=>({
   key:'team:'+team,label:team,kind:'Team'}));
  const players=rows.map(r=>({key:'player:'+r.id,label:r.player,kind:'Player'}));
  return [...teams,...players].filter(choice=>
   !search||choice.label.toLowerCase().includes(search.trim().toLowerCase())).slice(0,12);
 },[rows,search]);
 const selectedPlayer=plotted.find(r=>r.id===settings.selected);
 const selectedFilter=settings.filter?settings.filter.startsWith('team:')?
  'Team '+settings.filter.slice(5):rows.find(r=>r.id===settings.filter.slice(7))?.player??'Player':null;
 const metricLabel=(key:MetricKey)=>chartLabel(key);
 const axesChange=(patch:Partial<Settings>)=>{update(patch);setReset(x=>x+1);};
 function savePreset(name:string,replace=false){
  const title=name.trim().slice(0,80);if(!title)return;
  setPresets(current=>{
   const saved=[...current.filter(p=>p.name!==title),{name:title,settings:{...settings}}].slice(-10);
   try{localStorage.setItem(presetsKey,JSON.stringify(saved));}catch{/* no storage */}
   return saved;
  });
  setActivePreset(title);if(!replace)setPresetName('');
 }
 function loadPreset(name:string){
  const entry=presets.find(p=>p.name===name);if(!entry)return;
  setSettings(validSettings(entry.settings));setActivePreset(name);setReset(n=>n+1);
 }
 useEffect(()=>{
  if(!host.current)return;
  const instance=echarts.init(host.current,undefined,{renderer:'canvas'});
  chart.current=instance;
  const ro=new ResizeObserver(()=>instance.resize());ro.observe(host.current);
  instance.on('click',evt=>{
   const data=evt.data as {id?:string}|undefined;
   if(data?.id)update({selected:data.id});
  });
  instance.on('mouseover',evt=>{
   const data=evt.data as {name?:string}|undefined;
   setHover(data?.name??'');
  });
  instance.on('mouseout',()=>setHover(''));
  return ()=>{ro.disconnect();chart.current=null;viewport.current=null;instance.dispose();};
 },[]);
 useEffect(()=>{
  if(!chart.current)return;
  const metricX=metricLabel(settings.x),metricY=metricLabel(settings.y);
  const previous=viewport.current;
  const preserve=previous?.rows===rows&&previous.basis===basis&&previous.kind===settings.kind&&
   previous.x===settings.x&&previous.y===settings.y&&previous.size===settings.size&&
   previous.filter===settings.filter&&previous.population===settings.population&&
   previous.minGames===settings.minGames&&previous.reset===reset;
  const prior=preserve?chart.current.getOption().dataZoom as {start?:number;end?:number}[]|undefined:undefined;
  const color=(r:Row)=>settings.colorBy==='None'?'#7db8ff':
   teamColor(settings.colorBy==='Position'?r.position:r.team);
  const xy=plotted.filter(r=>r.values[settings.x]!==null&&r.values[settings.y]!==null);
  const line=analytics?[[analytics.minX,analytics.slope*analytics.minX+analytics.intercept],
   [analytics.maxX,analytics.slope*analytics.maxX+analytics.intercept]]:[];
  const labelLimit=settings.density==='Selective'?8:settings.density==='More'?20:Infinity;
  const points=xy.map((r,i)=>({
   id:r.id,name:r.player,team:r.team,
   value:[r.values[settings.x],r.values[settings.y],r.values[settings.size]??0],
   symbolSize:settings.kind==='bubble'?
    10+18*Math.sqrt(Math.max(0,r.values[settings.size]??0)/
      Math.max(1,...xy.map(p=>p.values[settings.size]??0))):
    r.id===settings.selected?17:10,
   label:{show:settings.labels&&i<labelLimit,
    formatter:r.player.length>14?r.player.split(' ').map(v=>v.slice(0,1)+'.').join(' '):r.player,
    position:'right' as const,color:'#c4d4e6',fontSize:10,
    backgroundColor:'#0a111dd9',padding:[2,3],borderRadius:2},
   itemStyle:{color:color(r),borderColor:r.id===settings.selected?'#fff':'transparent',
    borderWidth:r.id===settings.selected?3:0}
  }));
  const common={backgroundColor:'transparent',animation:false,
   textStyle:{color:'#c4d4e6'},
   tooltip:{trigger:'item' as const,confine:true,formatter:(p:any)=>{
    if(!p?.data?.name)return '';
    const d=p.data as {name:string;team:string;value:number[]};
    return '<b>'+escapeHtml(d.name)+'</b> · '+escapeHtml(d.team)+
     '<br/>'+escapeHtml(metricX)+': '+formatMetric(settings.x,d.value[0])+
     '<br/>'+escapeHtml(metricY)+': '+formatMetric(settings.y,d.value[1]);
   }}};
  const axisStyle={axisLine:{lineStyle:{color:'#526780'}},
   axisLabel:{color:'#9fb2c9'},splitLine:{show:settings.grid,lineStyle:{color:'#253449'}}};
  const xAxis={type:'value' as const,name:metricX,nameLocation:'middle' as const,nameGap:38,
   ...axisStyle},yAxis={type:'value' as const,name:metricY,nameLocation:'middle' as const,
   nameGap:50,...axisStyle};
  let option:Record<string,unknown>={...common,
   grid:{left:68,right:30,top:36,bottom:66},
   xAxis,yAxis,
   dataZoom:[{type:'inside',xAxisIndex:0,zoomOnMouseWheel:!settings.pan,
    moveOnMouseMove:settings.pan,moveOnMouseWheel:false,
    start:prior?.[0]?.start??0,end:prior?.[0]?.end??100},
    {type:'inside',yAxisIndex:0,zoomOnMouseWheel:!settings.pan,
     moveOnMouseMove:settings.pan,moveOnMouseWheel:false,
     start:prior?.[1]?.start??0,end:prior?.[1]?.end??100}],
   series:[{name:'Players',type:'scatter',data:points,emphasis:{focus:'self'},
    markLine:{silent:true,symbol:'none',label:{show:false},
     lineStyle:{color:'#9aa6c4',type:'dashed',width:1},
     data:[...(settings.means&&analytics?[{xAxis:analytics.meanX},{yAxis:analytics.meanY}]:[]),
      ...(settings.zero?[{xAxis:0},{yAxis:0}]:[])]}},
    ...(settings.regression&&line.length?[{
     name:'Linear reference',type:'line',data:line,symbol:'none',silent:true,
     lineStyle:{color:'#edbad0',width:2}
    }]:[])]
  };
  if(settings.kind==='bubble')option={...option,series:[
   {...(option.series as Record<string,unknown>[])[0],type:'scatter',name:'Players'},
   ...(settings.regression&&line.length?(option.series as unknown[]).slice(1):[])
  ]};
  if(settings.kind==='bar'){
   const data=[...plotted].reverse();
   option={...common,grid:{left:170,right:35,top:20,bottom:40},
    xAxis:{type:'value',name:metricY,...axisStyle},
    yAxis:{type:'category',data:data.map(r=>r.player),axisLabel:{color:'#9fb2c9',width:155,overflow:'truncate'}},
    series:[{type:'bar',name:'Players',data:data.map(r=>({
     id:r.id,name:r.player,team:r.team,value:r.values[settings.y],
     itemStyle:{color:color(r)}}))}]};
  }else if(settings.kind==='histogram'){
   const bins=histogram(eligible.map(r=>r.values[settings.y]).filter((v):v is number=>v!==null),settings.bins);
   option={...common,tooltip:{trigger:'axis'},grid:{left:60,right:20,top:30,bottom:62},
    xAxis:{type:'category',name:metricY,data:bins.map(x=>x.min.toFixed(1)+'–'+x.max.toFixed(1)),...axisStyle,
     axisLabel:{color:'#9fb2c9',interval:Math.max(0,Math.floor(bins.length/6)-1),rotate:30}},
    yAxis:{type:'value',name:'Players',...axisStyle},
    series:[{type:'bar',data:bins.map(x=>x.count),itemStyle:{color:'#7db8ff'}}]};
  }else if(settings.kind==='cumulative'){
   const sorted=eligible.map(r=>r.values[settings.y]).filter((v):v is number=>v!==null).sort((a,b)=>a-b);
   option={...common,tooltip:{trigger:'axis'},grid:{left:65,right:25,top:30,bottom:60},
    xAxis:{type:'value',name:metricY,nameLocation:'middle',nameGap:35,...axisStyle},
    yAxis:{type:'value',name:'Cumulative %',min:0,max:100,...axisStyle},
    series:[{type:'line',showSymbol:false,areaStyle:{opacity:.15},
     lineStyle:{color:'#7db8ff'},data:sorted.map((v,i)=>[v,(i+1)/sorted.length*100])}]};
  }else if(settings.kind==='box'){
   const positions=[...new Set(eligible.map(r=>r.position))].sort();
   const boxes=positions.map(p=>{
    const values=eligible.filter(r=>r.position===p).map(r=>r.values[settings.y])
     .filter((v):v is number=>v!==null).sort((a,b)=>a-b);
    return values.length?[values[0],quantile(values,.25),quantile(values,.5),
     quantile(values,.75),values[values.length-1]]:[0,0,0,0,0];
   });
   option={...common,grid:{left:75,right:20,top:30,bottom:60},
    xAxis:{type:'category',name:'Position',data:positions,...axisStyle},
    yAxis:{type:'value',name:metricY,...axisStyle},
    series:[{type:'boxplot',name:metricY,data:boxes,
     itemStyle:{color:'#6283aa',borderColor:'#9fc8ff'}}]};
  }else if(settings.kind==='radar'){
   const keys=['pts','reb','ast','stl','blk','ts_pct'] as MetricKey[];
   const first=ranked.find(r=>r.id===settings.selected)??ranked[0];
   const second=ranked.find(r=>r.id===settings.radarCompare&&r.id!==first?.id);
   const source=[first,second].filter((r):r is Row=>!!r);
   const max=keys.map(key=>Math.max(1,...eligible.map(r=>r.values[key]??0)));
   option={...common,legend:{show:true,top:8,textStyle:{color:'#c4d4e6'}},
    radar:{indicator:keys.map((k,i)=>({name:chartLabel(k),max:max[i]})),
     splitLine:{lineStyle:{color:'#33485f'}},axisName:{color:'#c4d4e6'}},
    series:[{type:'radar',data:source.map(r=>({
     name:r.player,value:keys.map(k=>r.values[k]??0),itemStyle:{color:color(r)},
     areaStyle:{opacity:.15}}))}]};
  }
  chart.current.setOption(option,true);
  viewport.current={rows,basis,kind:settings.kind,x:settings.x,y:settings.y,size:settings.size,
   filter:settings.filter,population:settings.population,minGames:settings.minGames,reset};
 },[rows,basis,plotted,eligible,ranked,analytics,settings,reset]);
 const xyChart=settings.kind==='scatter'||settings.kind==='bubble';
 const fullPopulation=['histogram','box','cumulative'].includes(settings.kind);
 const displayRows=fullPopulation?ranked:plotted;
 return <section className="panel studio" aria-labelledby="visual-title">
  <div className="studio-heading">
   <div><p className="eyebrow">VISUALIZATION STUDIO / EXPERIMENT</p>
    <h2 id="visual-title">Player scatter explorer</h2>
    <p className="subtle">Explore relationships, rankings, distributions, and player profiles · original NBA v5</p></div>
   <div className="row-wrap">
    <button onClick={()=>{setSettings({...defaults,minGames:segment==='playoffs'?4:50});setSearch('');setReset(n=>n+1);}}>Reset studio</button>
    <button onClick={()=>axesChange({x:settings.y,y:settings.x})}>Swap axes</button>
   </div>
  </div>
  <div className="studio-grid">
   <aside className="studio-rail" aria-label="Visualization Studio configuration">
    <h3>BUILD</h3>
    <label>Chart<select aria-label="Chart type" value={settings.kind}
     onChange={e=>axesChange({kind:e.target.value as ChartKind})}>
     {visualizationKinds.map(x=><option key={x.value} value={x.value}>{x.label}</option>)}</select></label>
    <label>X metric<select value={settings.x} onChange={e=>axesChange({x:e.target.value as MetricKey})}>
     {scatterKeys.map(k=><option key={k} value={k}>{metricLabel(k)}</option>)}</select></label>
    <label>Y metric<select value={settings.y} onChange={e=>axesChange({y:e.target.value as MetricKey})}>
     {scatterKeys.map(k=><option key={k} value={k}>{metricLabel(k)}</option>)}</select></label>
    {settings.kind==='bubble'&&<label>Bubble size metric<select value={settings.size}
     onChange={e=>axesChange({size:e.target.value as MetricKey})}>
     {scatterKeys.map(k=><option key={k} value={k}>{metricLabel(k)}</option>)}</select></label>}
    <label>Color by<select value={settings.colorBy}
     onChange={e=>update({colorBy:e.target.value as ColorBy})}>
     {['Team','Position','None'].map(v=><option key={v}>{v}</option>)}</select></label>
    <h3>POPULATION</h3>
    <p className="subtle" role="status">{eligible.length} eligible · {matching.length} match filters · {rows.length} season players</p>
    <label>Filter by team or player<input value={search} placeholder="Find player or team"
     onChange={e=>setSearch(e.target.value)}/></label>
    {search&&<div className="studio-filter-choices" role="group" aria-label="Matching population choices">
      {choices.map(choice=><button key={choice.key} onClick={()=>{
       update({filter:choice.key});setSearch('');setReset(n=>n+1);
      }}>{choice.kind}: {choice.label}</button>)}
     </div>}
    {selectedFilter&&<button className="studio-clear" onClick={()=>{update({filter:''});setReset(n=>n+1);}}>
     Clear filter: {selectedFilter}</button>}
    <label className="studio-slider-label">Minimum games <strong>{settings.minGames}</strong>
     <input type="range" min={0} max={segment==='playoffs'?28:82} step={1}
      aria-label="Minimum games" value={settings.minGames}
      onChange={e=>update({minGames:Number(e.target.value)})}/></label>
    {!fullPopulation&&settings.kind!=='radar'&&<label>Population size
      <select value={settings.kind==='bar'?settings.rankingSize:settings.population}
       onChange={e=>axesChange(settings.kind==='bar'?{rankingSize:Number(e.target.value)}:
        {population:Number(e.target.value)})}>
       {(settings.kind==='bar'?[10,20]:scatterPopulationSizes).map(n=>
        <option key={n} value={n}>{n===0?'All eligible players':'Top '+n+' by '+metricLabel(settings.y)}</option>)}
      </select></label>}
    {xyChart&&<><h3>DISPLAY</h3>
     {([
      ['Player labels','labels'],['Best-fit line','regression'],
      ['Mean reference lines','means'],['Gridlines','grid'],
      ['Zero reference lines','zero']
     ] as const).map(([label,key])=><label className="studio-switch" key={key}>
      <span>{label}</span><input type="checkbox" checked={settings[key]}
       onChange={e=>update({[key]:e.target.checked})}/></label>)}
     {settings.labels&&<label>Label density
      <select value={settings.density} onChange={e=>update({density:e.target.value as LabelDensity})}>
       <option value="Selective">Selective</option>
       <option value="More">More (recommended)</option>
       <option value="All">All (where space permits)</option>
      </select></label>}
    </>}
    {settings.kind==='histogram'&&<label>Histogram bins<select value={settings.bins}
     onChange={e=>update({bins:Number(e.target.value)})}>
      {[8,10,12,16,20].map(n=><option key={n} value={n}>{n}</option>)}
     </select></label>}
    {settings.kind==='radar'&&<label>Compare player<select value={settings.radarCompare}
     onChange={e=>update({radarCompare:e.target.value})}>
      <option value="">No comparison</option>
      {ranked.filter(r=>r.id!==settings.selected).slice(0,100).map(r=>
       <option key={r.id} value={r.id}>{r.player}</option>)}
     </select></label>}
    <h3>PRESETS</h3>
    <label>Saved presets<select value={activePreset}
     onChange={e=>loadPreset(e.target.value)}>
      <option value="">Choose preset</option>
      {presets.map(p=><option key={p.name} value={p.name}>{p.name}</option>)}
     </select></label>
    <label>Preset name<input aria-label="Preset name" value={presetName}
     onChange={e=>setPresetName(e.target.value)} maxLength={80}/></label>
    <div className="row-wrap">
     <button onClick={()=>savePreset(activePreset,true)} disabled={!activePreset}>Save</button>
     <button onClick={()=>savePreset(presetName)}>Save as</button>
    </div>
   </aside>
   <div className="studio-workspace">
    <div className="studio-chart-title">
     <div><h3>{metricLabel(settings.y)} vs {metricLabel(settings.x)}</h3>
      <p className="subtle">{plotted.length} plotted from {eligible.length} eligible · ranked by {metricLabel(settings.y)}</p></div>
     <span className="subtle">Color: {settings.colorBy}</span>
    </div>
    {xyChart&&<div className="studio-analytics" aria-label="Linear regression statistics">
      <div><small>PAIRED</small><strong>{analytics?.count??'—'}</strong><span>plotted sample</span></div>
      <div><small>CORRELATION</small><strong>{analytics?fmt(analytics.r):'—'}</strong>
       <span>{analytics?correlationLabel(analytics.r):'insufficient data'}</span></div>
      <div><small>R²</small><strong>{analytics?fmt(analytics.rSquared):'—'}</strong><span>variance explained</span></div>
      <div className="studio-fit"><small>BEST FIT</small>
       <strong>{analytics?metricLabel(settings.y)+' = '+analytics.slope.toFixed(2)+'×'+metricLabel(settings.x)+
        (analytics.intercept<0?' − ':' + ')+Math.abs(analytics.intercept).toFixed(2):'—'}</strong>
       <span>linear model</span></div>
     </div>}
    {xyChart&&<div className="studio-chart-actions">
      <button className={!settings.pan?'active-control':''} onClick={()=>update({pan:false})}
       aria-pressed={!settings.pan}>Wheel zoom</button>
      <button className={settings.pan?'active-control':''} onClick={()=>update({pan:true})}
       aria-pressed={settings.pan}>Drag pan</button>
      <button onClick={()=>setReset(n=>n+1)}>Reset view</button>
     </div>}
    <div ref={host} className="chart studio-chart" role="img"
     aria-label={'Scatter plot of '+metricLabel(settings.x)+' against '+metricLabel(settings.y)+', '+plotted.length+' players'}/>
    {!plotted.length&&<div className="empty">No players meet the selected source-backed metrics and filters.</div>}
    <div className="chart-footer">
     <span role="status">{selectedPlayer?'Selected: '+selectedPlayer.player+' · '+selectedPlayer.team:
      hover?'Hover: '+hover:'No selected player'}</span>
     <span>Settings persist in this browser.</span>
    </div>
    <div className="chart-accessible">
     <div className="studio-underlying-title"><h3>UNDERLYING DATA</h3><span>Showing {displayRows.length}</span></div>
     <table><thead><tr><th>Player</th><th>Team</th>
      <th>{metricLabel(settings.x)}</th><th>{metricLabel(settings.y)}</th></tr></thead>
      <tbody>{displayRows.map(r=><tr key={r.id}>
       <td><button className="text-button" onClick={()=>update({selected:r.id})}>{r.player}</button></td>
       <td>{r.team}</td>
       <td>{formatMetric(settings.x,r.values[settings.x])}</td>
       <td>{formatMetric(settings.y,r.values[settings.y])}</td>
      </tr>)}</tbody></table>
     <p className="subtle">Original-source player rows, deterministic population selection. This readout does not replace full assistive technology acceptance.</p>
    </div>
   </div>
  </div>
 </section>;
}
