import test from 'node:test';
import assert from 'node:assert/strict';
import {finalModules,assessFinalVisual} from '../scripts/phase3_final_review_manifest.mjs';
const sample=()=>finalModules.map(m=>({id:m.id,status:'PASS',
 details:'Verified original Flutter and React controls, rows and visual consistency for '+m.title,
 flutterUrl:'http://127.0.0.1:8768/',reactUrl:'http://127.0.0.1:4173/',
 flutterScreenshotSha256:'abc',reactScreenshotSha256:'def'}));
test('review cannot certify migration, even with all module samples marked pass',()=>{
 const a=assessFinalVisual({checks:sample(),manifestSha256:'hash',realManifestSha256:'hash'});
 assert.equal(a.status,'OPERATOR_VISUAL_SAMPLE_PASS_ONLY');
 assert.equal(a.ownerMigrationSignoff,false);
 assert.equal(a.fullFunctionalParityCertified,false);
});
test('fifteen distinct complete module checks are required',()=>{
 const a=assessFinalVisual({checks:sample().slice(1),manifestSha256:'hash',realManifestSha256:'hash'});
 assert.equal(a.status,'INVALID_EVIDENCE');
});
test('fail or blocked modules cannot be converted to a pass',()=>{
 const s=sample();s[5].status='FAIL';const a=assessFinalVisual({checks:s,manifestSha256:'hash',realManifestSha256:'hash'});
 assert.equal(a.status,'GAPS_OBSERVED');
 assert.equal(a.failures[0].id,'trade');
});
test('pass without observed screenshots, notes or real source fails',()=>{
 const s=sample();s[0].details='yes';s[1].reactScreenshotSha256='';
 const a=assessFinalVisual({checks:s,manifestSha256:'old',realManifestSha256:'new'});
 assert.equal(a.status,'INVALID_EVIDENCE');
 assert.equal(a.errors.length,3);
});
