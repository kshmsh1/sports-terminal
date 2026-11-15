// Persistent, offline-local browser workbook store. No network calls.
const DATABASE='arcside-sheet-workspaces';
const STORE='workbooks';
let connection;
function openDatabase(){
  if(connection)return connection;
  connection=new Promise((resolve,reject)=>{
    if(typeof indexedDB==='undefined'){reject(Error('IndexedDB unavailable'));return;}
    const request=indexedDB.open(DATABASE,1);
    request.onupgradeneeded=()=>{
      const db=request.result;
      if(!db.objectStoreNames.contains(STORE))db.createObjectStore(STORE);
    };
    request.onerror=()=>reject(request.error??Error('Cannot open workbook database'));
    request.onsuccess=()=>{
      const db=request.result;
      db.onversionchange=()=>{db.close();connection=undefined;};
      resolve(db);
    };
  }).catch(error=>{connection=undefined;throw error;});
  return connection;
}
export async function loadWorkbook(){
  const db=await openDatabase();
  return new Promise((resolve,reject)=>{
    const tx=db.transaction(STORE,'readonly');
    const request=tx.objectStore(STORE).get('active');
    request.onerror=()=>reject(request.error??Error('Workbook read failed'));
    request.onsuccess=()=>resolve(request.result??null);
  });
}
export async function storeWorkbook(value){
  const db=await openDatabase();
  return new Promise((resolve,reject)=>{
    const tx=db.transaction(STORE,'readwrite');
    tx.objectStore(STORE).put(value,'active');
    tx.oncomplete=()=>resolve();
    tx.onerror=()=>reject(tx.error??Error('Workbook save failed'));
    tx.onabort=()=>reject(tx.error??Error('Workbook save aborted'));
  });
}
