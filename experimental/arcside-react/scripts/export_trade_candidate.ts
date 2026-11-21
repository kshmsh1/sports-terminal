import {writeFile,mkdir} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {originalCbaFixtureCandidate} from './trade_fixtures.ts';
const here=path.dirname(fileURLToPath(import.meta.url));
const out=path.resolve(here,'../evidence/trade/react-trade-candidate.json');
await mkdir(path.dirname(out),{recursive:true});
const report=originalCbaFixtureCandidate();
await writeFile(out,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({path:out,implementationSource:report.implementationSource,
 kind:report.kind,cases:Object.keys(report.cases)},null,2));