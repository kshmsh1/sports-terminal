// Inspect an immutable operator study; NEVER delete outliers or change the gate.
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {evaluateVisualizationStudy} from './visualization_study_math.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
const home=path.resolve(here,'..'),input=process.argv[2]??path.join(home,'evidence/visualization/visualization-guided-timings-v2.json');
const source=await readFile(input);
const report=JSON.parse(source);
const audit=evaluateVisualizationStudy(report);
audit.originalReportSha256=createHash('sha256').update(source).digest('hex');
audit.originalFile=input;
const dir=path.join(home,'evidence/visualization');await mkdir(dir,{recursive:true});
const dest=path.join(dir,'visualization-tail-diagnostic.json');
await writeFile(dest,JSON.stringify(audit,null,2)+'\n');
console.log(JSON.stringify({status:audit.status,p95:audit.by,
 p95WarmRatio:audit.warmP95ReactOverFlutter,suspectPairs:audit.suspectPairs,
 calculationErrors:audit.calculationErrors,report:dest},null,2));
if(audit.status==='INVALID_STUDY')process.exitCode=1;
