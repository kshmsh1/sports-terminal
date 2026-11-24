import {pivotTable,filterTable,chartData} from './analytics.mjs';

// Heavy pivot/filter calculations run outside the UI thread; no DOM or eval.
self.onmessage=({data})=>{
  const {id,action,rows,options}=data;
  try {
    let result;
    if(action==='pivot')result=pivotTable(rows,options);
    else if(action==='filter')result=filterTable(rows,options?.filters??[]);
    else if(action==='chart')result=chartData(rows,options);
    else throw Error('Unknown analytics operation');
    self.postMessage({id,ok:true,result});
  }catch(error){self.postMessage({id,ok:false,error:String(error.message??error)});}
};
