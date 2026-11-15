/**
 * Declarative Excel-style conditional formatting (no executable formulas).
 * Each rule applies to a fixed grid rectangle and evaluates the displayed
 * cell value. Rules are applied in order, later matches overriding earlier.
 */
export const OPERATORS=[
  'greaterThan','lessThan','greaterOrEqual','lessOrEqual','equals',
  'notEquals','between','textContains','isBlank','isNotBlank','isError'
];
function number(value){
  if(value===null||value===undefined||value==='')return null;
  const parsed=Number(value);
  return Number.isFinite(parsed)?parsed:null;
}
export function matchesRule(value,rule){
  if(!rule||!OPERATORS.includes(rule.operator))return false;
  const raw=String(value??''),expected=String(rule.value??'');
  const actualNumber=number(value),targetNumber=number(rule.value);
  const n1=targetNumber===null?NaN:targetNumber;
  switch(rule.operator){
    case 'isBlank':return raw==='';
    case 'isNotBlank':return raw!=='';
    case 'isError':return /^#(?:REF!|DIV\/0!|VALUE!|NUM!|NAME\?|N\/A|CYCLE!|ERROR!)$/.test(raw);
    case 'textContains':return raw.toLowerCase().includes(expected.toLowerCase())&&expected.length>0;
    case 'between':{
      const n2=number(rule.value2);
      return actualNumber!==null&&Number.isFinite(n1)&&n2!==null&&actualNumber>=Math.min(n1,n2)&&actualNumber<=Math.max(n1,n2);
    }
    case 'greaterThan':return actualNumber!==null&&Number.isFinite(n1)&&actualNumber>n1;
    case 'lessThan':return actualNumber!==null&&Number.isFinite(n1)&&actualNumber<n1;
    case 'greaterOrEqual':return actualNumber!==null&&Number.isFinite(n1)&&actualNumber>=n1;
    case 'lessOrEqual':return actualNumber!==null&&Number.isFinite(n1)&&actualNumber<=n1;
    case 'equals':return actualNumber!==null&&Number.isFinite(n1)
      ?actualNumber===n1:raw.toLowerCase()===expected.toLowerCase();
    case 'notEquals':return actualNumber!==null&&Number.isFinite(n1)
      ?actualNumber!==n1:raw.toLowerCase()!==expected.toLowerCase();
    default:return false;
  }
}
export function conditionalStyle(rules,row,col,value){
  let patch=null;
  for(const rule of rules??[]){
    const bounds=rule.range;
    if(!bounds||row<bounds.a||row>bounds.b||col<bounds.l||col>bounds.r)continue;
    if(matchesRule(value,rule)){
      patch={...(patch??{}),fill:rule.fill??undefined,color:rule.color??undefined};
    }
  }
  return patch;
}
export function validateRule(rule){
  if(!rule||!OPERATORS.includes(rule.operator))throw Error('Invalid conditional formatting operator');
  const b=rule.range;
  if(!b||![b.a,b.b,b.l,b.r].every(Number.isInteger)||
      b.a<1||b.b>b.a+100000||b.a>b.b||b.l<1||b.l>b.r||b.r>256||
      b.b>100000)throw Error('Invalid conditional format range');
  for(const color of [rule.fill,rule.color]){
    if(color!==undefined&&!/^#[a-fA-F0-9]{6}$/.test(String(color)))
      throw Error('Conditional formatting colors must be hex RGB');
  }
  if(String(rule.value??'').length>256||String(rule.value2??'').length>256)
    throw Error('Conditional formatting threshold too long');
  return {range:{a:b.a,b:b.b,l:b.l,r:b.r},operator:rule.operator,
          value:rule.value??'',value2:rule.value2??'',
          fill:rule.fill??'#164e37',color:rule.color??'#adf4d0'};
}
