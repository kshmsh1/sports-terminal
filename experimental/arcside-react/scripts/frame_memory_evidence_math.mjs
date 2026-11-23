// Diagnose existing evidence only; NEVER convert an invalid operator run to PASS.
export function auditFrameMemory(report,sourceHash){
 const problems=[];
 if(report?.kind!=='ARCSIDE_PAIRED_FRAME_MEMORY_V1'||
 report?.source!=='ACTUAL_LOCAL_V5_CORPUS'||report?.manifestSha256!==sourceHash)
  problems.push('Wrong source manifest, report kind or original-data contract');
 const samples=report?.samplesPerApp??0,raw=report?.raw??[];
 if(!Number.isInteger(samples)||samples<2||samples>20||!Array.isArray(raw))
  problems.push('Invalid number of samples or missing raw array');
 const checks=[];
 if(Array.isArray(raw))for(const app of ['Flutter','React']){
  for(let i=1;i<=samples;i++){
   const entries=raw.filter(x=>x.app===app&&x.trial===i);
   if(entries.length!==1){
    problems.push('Missing or duplicate '+app+' trial '+i);
    continue;
   }
   const row=entries[0];
   const frames=row.frames??0,wheel=row.events?.wheel??0,
    pointerMoves=row.events?.pointermove??0;
   const reason=frames<60?'Insufficient frame observations ('+frames+' < 60)':
    wheel===0&&pointerMoves<10?
    'No wheel gestures or ten pointer moves captured ('+wheel+' wheel, '+pointerMoves+' pointer moves)':null;
   checks.push({app,trial:i,valid:reason===null,recordedValid:row.valid,
    frames,wheel,pointerMoves,reason});
   if(row.valid!==(reason===null))problems.push('Recorded validity disagrees with raw events on '+app+' '+i);
  }
 }
 const invalid=checks.filter(x=>!x.valid);
 const status=problems.length?'INVALID_EVIDENCE':invalid.length?'CAPTURE_INCOMPLETE':
  'RAF_JS_HEAP_SAMPLING_QUALIFIED';
 return {kind:'ARCSIDE_FRAME_MEMORY_FORENSIC_AUDIT_V1',status,errors:problems,
  invalid,qualifiedRows:checks.length-invalid.length,expectedRows:samples*2,
  originalStatus:report?.status??null,originalErrors:report?.errors??[],
  caveat:'Qualification reflects recorded browser rAF/JS heap and input gestures only; does NOT validate GPU compositor, total native RAM, physical Windows/Safari, rendering parity, or an architectural migration.'};
}
