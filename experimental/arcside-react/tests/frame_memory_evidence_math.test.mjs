import test from 'node:test';
import assert from 'node:assert/strict';
import {auditFrameMemory} from '../scripts/frame_memory_evidence_math.mjs';
const make=()=>{
 const raw=['Flutter','React'].flatMap(app=>[1,2].map(trial=>({
  app,trial,valid:true,frames:120,events:{wheel:2,pointermove:13}
 })));
 return {kind:'ARCSIDE_PAIRED_FRAME_MEMORY_V1',source:'ACTUAL_LOCAL_V5_CORPUS',
 manifestSha256:'matching',samplesPerApp:2,raw,status:'MATCHED_OPERATOR_RAF_HEAP_OBSERVED'};
};
test('complete pair with observed gestures qualifies browser scheduling only',()=>{
 const r=auditFrameMemory(make(),'matching');
 assert.equal(r.status,'RAF_JS_HEAP_SAMPLING_QUALIFIED');
 assert.match(r.caveat,/does NOT validate GPU/i);
});
test('no observed user gestures are reported, not silently counted',()=>{
 const a=make();a.raw[1].valid=false;a.raw[1].events={wheel:0,pointermove:0};
 const r=auditFrameMemory(a,'matching');
 assert.equal(r.status,'CAPTURE_INCOMPLETE');
 assert.equal(r.invalid[0].trial,2);
});
test('missing samples and tampered status fail validation',()=>{
 const a=make();a.raw.pop();
 assert.equal(auditFrameMemory(a,'matching').status,'INVALID_EVIDENCE');
 const b=make();b.raw[0].valid=true;b.raw[0].frames=3;
 assert.equal(auditFrameMemory(b,'matching').status,'INVALID_EVIDENCE');
 assert.equal(auditFrameMemory(make(),'wrong').status,'INVALID_EVIDENCE');
});
