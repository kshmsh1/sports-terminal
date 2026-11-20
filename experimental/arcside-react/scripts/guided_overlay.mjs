// Browser-side task timer. Playwright installs this with page.addInitScript BEFORE
// navigation, so a page reload cannot silently remove its controls or bindings.
// Real user confirmation is required for Finish; no script invents UI success.
export function installGuidedOverlay(options) {
 const {binding,title,instructions}=options;
 let frames=[],last=0,raf=0,active=false;
 const id='arcside-guided-overlay';
 const callback=(event,frame=null)=>{
  const bridge=window[binding];
  if(typeof bridge!=='function') {
   const notice=document.getElementById(id+'-notice');
   if(notice)notice.textContent='Bridge unavailable: stop and resume the benchmark; do not certify this trial.';
   return;
  }
  bridge({event,frame});
 };
 const mark=event=>{
  if(event==='start') {
   if(active)return;
   active=true;frames=[];last=0;cancelAnimationFrame(raf);
   const tick=t=>{
    if(last&&frames.length<10000)frames.push(t-last);
    last=t;raf=requestAnimationFrame(tick);
   };
   raf=requestAnimationFrame(tick);
   callback('start');
  }else {
   if(!active)return;
   active=false;cancelAnimationFrame(raf);
   const sorted=[...frames].sort((a,b)=>a-b);
   callback(event,{observations:sorted.length,
    p95GapMs:sorted[Math.max(0,Math.ceil(sorted.length*.95)-1)]??null,
    maxGapMs:sorted.at(-1)??null,
    gapsOver50Ms:sorted.filter(x=>x>50).length,
    samplesCapped:frames.length>=10000,
    caveat:'rAF intervals are only browser scheduling proxies, not confirmed GPU drops'});
  }
 };
 const mount=()=>{
  if(!document.body||document.getElementById(id))return;
  const panel=document.createElement('div');panel.id=id;
  panel.setAttribute('role','group');panel.setAttribute('aria-label','Arcside matched-task benchmark');
  panel.style.cssText='position:fixed;right:12px;bottom:12px;z-index:2147483647;max-width:310px;padding:12px;background:#172036;color:white;border:2px solid #ffda82;border-radius:9px;font:13px system-ui;box-shadow:0 3px 18px #0008';
  const heading=document.createElement('strong');heading.textContent=title;panel.append(heading);
  const description=document.createElement('p');description.textContent=instructions;panel.append(description);
  for(const [name,event] of [['Start','start'],['Finish ✓','finish'],['Fail ✕','fail']]){
   const button=document.createElement('button');
   button.type='button';button.textContent=name;button.dataset.arcsideAction=event;
   button.style.cssText='margin:2px;padding:5px 8px;cursor:pointer';
   button.addEventListener('click',()=>mark(event));panel.append(button);
  }
  const notice=document.createElement('p');notice.id=id+'-notice';notice.setAttribute('role','status');
  notice.style.cssText='margin:5px 0 0;font-size:11px';
  notice.textContent='Ctrl+Shift+8 Start · 9 Finish · 0 Fail. Reload before Start is safe.';
  panel.append(notice);document.body.append(panel);
 };
 window.addEventListener('keydown',event=>{
  const action=event.ctrlKey&&event.shiftKey?
   {Digit8:'start',Digit9:'finish',Digit0:'fail'}[event.code]:null;
  if(!action)return;
  event.preventDefault();event.stopImmediatePropagation();mark(action);
 },true);
 const begin=()=>{
  mount();
  new MutationObserver(()=>{
   if(!document.getElementById(id))mount();
  }).observe(document.documentElement,{childList:true,subtree:true});
 };
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',begin,{once:true});
 else begin();
}
