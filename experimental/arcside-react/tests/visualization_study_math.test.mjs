import test from 'node:test';
import assert from 'node:assert/strict';
import {evaluateVisualizationStudy} from '../scripts/visualization_study_math.mjs';
const sample=()=>{
 const raw=[];
 for(const app of ['Flutter','React'])for(let trial=1;trial<=12;trial++){
  const ms=app==='Flutter'?trial<=2?390:290:
   trial===12?879:trial<=2?420:280;
  raw.push({app,trial,cold:trial<=2,ms,passed:true,operatorVerified:true,
   frameProbe:{p95GapMs:9,gapsOver50Ms:0}});
 }
 return {kind:'ARCSIDE_VISUALIZATION_MATCHED_TASKS_V2',
  protocol:'VISUALIZATION_CHART_V2_MATCHED_2_COLD_10_WARM',
  source:'ACTUAL_LOCAL_V5_CORPUS',operatorConfirmed:true,raw,
  by:{Flutter:{medianMs:290,p95Ms:290},React:{medianMs:280,p95Ms:879}},
  p95ReactOverFlutter:879/290};
};
test('a single warm tail anomaly remains in registered p95 even with smooth frame scheduling',()=>{
 const a=evaluateVisualizationStudy(sample());
 assert.equal(a.status,'BENCHMARK_FAILED_REQUIRES_INVESTIGATION');
 assert.equal(a.by.React.warmP95Ms,879);
 assert.equal(a.by.React.allTrialP95Ms,420);
 assert.equal(a.suspectPairs.length,1);
 assert.equal(a.suspectPairs[0].trial,12);
});
test('warm-only percentile calculation is checked rather than incorrectly comparing twelve',()=>{
 const s=sample();s.by.React.p95Ms=420;
 const a=evaluateVisualizationStudy(s);
 assert.equal(a.status,'INVALID_STUDY');
 assert.match(a.calculationErrors.join(' '),/WARM-only/);
});
test('missing or falsely passed attempts cannot be excluded from the denominator',()=>{
 const s=sample();s.raw.find(x=>x.app==='React'&&x.trial===12).passed=false;
 assert.equal(evaluateVisualizationStudy(s).status,'INVALID_STUDY');
 const t=sample();t.raw.pop();
 assert.equal(evaluateVisualizationStudy(t).status,'INVALID_STUDY');
});
test('clean warm trials yield passing gate without changing thresholds',()=>{
 const s=sample();s.raw.find(x=>x.app==='React'&&x.trial===12).ms=280;
 s.by.React.p95Ms=280;s.p95ReactOverFlutter=280/290;
 assert.equal(evaluateVisualizationStudy(s).status,'BENCHMARK_PASSED');
});
