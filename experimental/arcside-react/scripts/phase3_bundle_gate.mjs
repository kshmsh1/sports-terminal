// CI bundle regression: a route-only module must not rejoin the entry chunk.
// This is a static transfer-size guard, NOT an interactive performance claim.
import {readdir,readFile,stat} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../dist/assets');
const names=await readdir(root);
const js=names.filter(n=>n.endsWith('.js'));
const entries=js.filter(n=>/^index-[\w-]+\.js$/.test(n));
if(entries.length!==1)throw Error('Expected one Vite entry chunk; found '+entries.length);
const initialBytes=(await stat(path.join(root,entries[0]))).size;
if(initialBytes>500000)throw Error('React initial JS bundle regressed above 500 kB: '+initialBytes);
if(js.length<6)throw Error('Expected route-specific lazy chunks, found '+js.length);
const entry=await readFile(path.join(root,entries[0]),'utf8');
if(entry.includes('ECharts')&&entry.includes('dataZoom'))throw Error('Chart implementation appears embedded in initial JS');
console.log(JSON.stringify({status:'PASS',entry:entries[0],entryBytes:initialBytes,
 deferredChunkCount:js.length-1,scope:'entry bundle only; not total JS, chart GPU or runtime latency'},null,2));
