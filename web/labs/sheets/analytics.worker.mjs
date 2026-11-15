import {buildPivot,filterTable} from './analytics.mjs';

self.onmessage=event=>{
  const {id,kind,matrix,config}=event.data??{};
  try{
    const result=kind==='filter'?{matrix:filterTable(matrix,config)}
      :buildPivot(matrix,config);
    self.postMessage({id,ok:true,result});
  }catch(error){
    self.postMessage({id,ok:false,error:String(error.message??error)});
  }
};
