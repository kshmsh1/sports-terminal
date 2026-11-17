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


// Named local workbooks coexist with the existing automatic active-workbook
// recovery. All data stays in IndexedDB; nothing is sent to collaboration
// unless the user explicitly creates or joins a shared room.
const NAMED_PREFIX='named:';
function namedKey(id){
  if(!/^[0-9a-f-]{36}$/.test(id))throw Error('Invalid workbook ID');
  return NAMED_PREFIX+id;
}
export async function listNamedWorkbooks(){
  const db=await openDatabase();
  return new Promise((resolve,reject)=>{
    const request=db.transaction(STORE,'readonly').objectStore(STORE).getAll();
    request.onsuccess=()=>{
      const values=(request.result??[]).filter(v=>v?.kind==='arcside-named-workbook');
      resolve(values.map(v=>({
        id:v.id,title:v.title,createdAt:v.createdAt,updatedAt:v.updatedAt,
        sheets:v.state?.workbook?.sheets?.length??0,
      })).sort((a,b)=>b.updatedAt-a.updatedAt));
    };
    request.onerror=()=>reject(request.error??Error('Workbook list failed'));
  });
}
export async function saveNamedWorkbook(id,title,state){
  const db=await openDatabase(),recordId=id||crypto.randomUUID();
  const key=namedKey(recordId);
  if(!title||title.length>120)throw Error('Workbook title must contain 1-120 characters');
  const now=Date.now();
  return new Promise((resolve,reject)=>{
    const tx=db.transaction(STORE,'readwrite'),store=tx.objectStore(STORE);
    const request=store.get(key);
    request.onsuccess=()=>{
      const old=request.result;
      store.put({
        kind:'arcside-named-workbook',id:recordId,title,
        state,createdAt:old?.createdAt??now,updatedAt:now,
      },key);
    };
    tx.oncomplete=()=>resolve(recordId);
    tx.onerror=()=>reject(tx.error??Error('Workbook write failed'));
    tx.onabort=()=>reject(tx.error??Error('Workbook save aborted'));
  });
}
export async function loadNamedWorkbook(id){
  const db=await openDatabase();
  return new Promise((resolve,reject)=>{
    const request=db.transaction(STORE,'readonly').objectStore(STORE).get(namedKey(id));
    request.onsuccess=()=>resolve(request.result?.state??null);
    request.onerror=()=>reject(request.error??Error('Workbook read failed'));
  });
}
export async function deleteNamedWorkbook(id){
  const db=await openDatabase();
  return new Promise((resolve,reject)=>{
    const tx=db.transaction(STORE,'readwrite');
    tx.objectStore(STORE).delete(namedKey(id));
    tx.oncomplete=resolve;
    tx.onerror=()=>reject(tx.error??Error('Workbook delete failed'));
  });
}
