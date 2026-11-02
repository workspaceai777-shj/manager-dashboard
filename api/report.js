import crypto from 'node:crypto';

const SHEET_ID = process.env.GOOGLE_SHEET_ID || '1Zr7W7P7JUTUR43nDmR1YWmvqYsdctdzmMfM7Px-q7lo';
const TASKS = {
  'Reception & Patient Management': [
    'Patient Registrations (including treatment chart preparation, case sheet printing etc)',
    'Appointments Booked', 'Calls Attended', 'WhatsApp Enquiries Replied',
    'Confirmation Messages Sent', 'Consultations Coordinated', 'Enquiries Handled',
    'Patient Registration Excel updated'
  ],
  'Ledger & Documentation': [
    'Ledgers Prepared (New, convert from R3 to R4)',
    'Ledgers Updated (updating the R4 format)', 'Patient Cards Prepared',
    'Charts Prepared', 'Patient Documents Updated', 'EMR Records Updated',
    'Appointment Excel Records Updated', 'Next Day Appointment Due Checked'
  ],
  'Insurance & Finance': [
    'Insurance Invoices Prepared', 'Insurance Documents Sent', 'Daily Collection (AED)',
    'Insurance Datewise Updated', 'Insurance EMRwise Updated'
  ]
};
const PREPARED = TASKS['Ledger & Documentation'][0];
const UPDATED = TASKS['Ledger & Documentation'][1];
const TARGETS = {
  Prince: { prepared: 6, updated: 15 },
  Farsana: { prepared: 5, updated: 0 },
  Stanly: { prepared: 0, updated: 18 }
};
function base64url(input) { return Buffer.from(input).toString('base64url'); }
async function accessToken() {
  const email = process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL;
  const raw = process.env.GOOGLE_PRIVATE_KEY;
  if (!email || !raw) throw new Error('Missing Google service account credentials in Vercel environment settings');
  const key = raw.replace(/\\n/g, '\n');
  const now = Math.floor(Date.now()/1000);
  const head = base64url(JSON.stringify({alg:'RS256', typ:'JWT'}));
  const payload = base64url(JSON.stringify({iss:email,scope:'https://www.googleapis.com/auth/spreadsheets.readonly',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3500}));
  const content = `${head}.${payload}`;
  const signature = crypto.sign('RSA-SHA256',Buffer.from(content),key).toString('base64url');
  const form = new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:`${content}.${signature}`});
  const res = await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:form});
  const json = await res.json();
  if (!res.ok) throw new Error(`Google authentication failed: ${json.error || res.status}`);
  return json.access_token;
}
async function readRows(token){
  const base=`https://sheets.googleapis.com/v4/spreadsheets/${encodeURIComponent(SHEET_ID)}`;
  const headers={Authorization:`Bearer ${token}`};
  const metaRes=await fetch(`${base}?fields=sheets.properties.title`,{headers});
  if(!metaRes.ok) throw new Error(`Cannot access spreadsheet (${metaRes.status}). Share it with your service account.`);
  const meta=await metaRes.json();
  const configured=process.env.RESPONSES_TAB;
  const names=configured?[configured]:(meta.sheets||[]).map(s=>s.properties.title).filter(t=>/form responses/i.test(t));
  for(const name of names){
    const range=`'${name.replace(/'/g,"''")}'!A1:CZ20000`;
    const r=await fetch(`${base}/values/${encodeURIComponent(range)}?valueRenderOption=FORMATTED_VALUE`,{headers});
    if(!r.ok) continue;
    const v=(await r.json()).values || [];
    const header=v[0]||[];
    if(header.includes('Employee Name')&&header.includes('Reporting Date')) return v;
  }
  throw new Error('Form response tab not found. Set RESPONSES_TAB to its exact tab name.');
}
const n = value => { const x=Number(String(value??'').replace(/,/g,'').trim()); return Number.isFinite(x)&&x>=0?x:0; };
function parseDate(value){
  const s=String(value||'').trim();
  if(/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0,10);
  const m=s.match(/^(\d{1,2})[\/-](\d{1,2})[\/-](\d{4})$/);
  if(m){const a=+m[1],b=+m[2];const mode=(process.env.DATE_FORMAT||'DMY').toUpperCase(); const d=mode==='MDY'?b:a;const mo=mode==='MDY'?a:b;return `${m[3]}-${String(mo).padStart(2,'0')}-${String(d).padStart(2,'0')}`;}
  return '';
}
function parseRows(values){
  const headers=(values[0]||[]).map(x=>String(x).trim());
  const index=new Map(headers.map((h,i)=>[h,i]));
  const get=(row,h)=>row[index.get(h)]??'';
  const tasks=Object.entries(TASKS).flatMap(([section,names])=>names.map(name=>({section,name,unit:name==='Daily Collection (AED)'?'AED':'quantity'})));
  const records=[];
  for (const row of values.slice(1)) {
    const staff=String(get(row,'Employee Name')).trim();
    const date=parseDate(get(row,'Reporting Date'));
    if(!staff||!date)continue;
    const record={staff,date,timestamp:get(row,'Timestamp'),hoursReported:n(get(row,'Total Working Hours')),remarks:get(row,'Remarks / Pending Work'),tasks:{}};
    for(const task of tasks){
      record.tasks[task.name]={quantity:n(get(row,task.name+(task.unit==='AED'?'':' - Quantity'))),hours:n(get(row,task.name+' - Hours Spent'))};
    }
    record.hoursTaskSum=Object.values(record.tasks).reduce((sum,v)=>sum+v.hours,0);
    records.push(record);
  }
  return {records,tasks};
}
function summarize(records,tasks){
  const summary={recordCount:records.length,employeeCount:new Set(records.map(r=>r.staff)).size,totalQuantity:0,totalHours:0,hoursReported:0,collections:0,prepared:0,updated:0,patientRegistrations:0,appointments:0,employeeRows:[],activities:[],daily:[],warnings:[]};
  const byStaff={};const byDate={};const taskAgg=Object.fromEntries(tasks.map(t=>[t.name,{...t,quantity:0,hours:0}]));
  for(const r of records){
    if(!byStaff[r.staff])byStaff[r.staff]={name:r.staff,reports:0,days:0,totalHours:0,reportedHours:0,collections:0,prepared:0,updated:0,activityCount:0,preparedHours:0,updatedHours:0};
    const e=byStaff[r.staff];e.reports++;e.days++;e.totalHours+=r.hoursTaskSum;e.reportedHours+=r.hoursReported;
    summary.totalHours+=r.hoursTaskSum;summary.hoursReported+=r.hoursReported;
    if(Math.abs(r.hoursTaskSum-r.hoursReported)>0.25) summary.warnings.push(`${r.staff} · ${r.date}: sum of task hours (${r.hoursTaskSum.toFixed(2)}) differs from reported working hours (${r.hoursReported.toFixed(2)}).`);
    if(r.hoursTaskSum>24)summary.warnings.push(`${r.staff} · ${r.date}: more than 24 task hours entered.`);
    if(!byDate[r.date])byDate[r.date]={date:r.date,prepared:0,updated:0,hours:0,collections:0};
    byDate[r.date].hours+=r.hoursTaskSum;
    for(const t of tasks){
      const v=r.tasks[t.name];const a=taskAgg[t.name];a.quantity+=v.quantity;a.hours+=v.hours;
      if(t.unit==='AED'){e.collections+=v.quantity;summary.collections+=v.quantity;byDate[r.date].collections+=v.quantity;}
      else {summary.totalQuantity+=v.quantity;e.activityCount+=v.quantity;}
    }
    const p=r.tasks[PREPARED],u=r.tasks[UPDATED];
    e.prepared+=p.quantity;e.updated+=u.quantity;e.preparedHours+=p.hours;e.updatedHours+=u.hours;
    summary.prepared+=p.quantity;summary.updated+=u.quantity;
    byDate[r.date].prepared+=p.quantity;byDate[r.date].updated+=u.quantity;
  }
  summary.patientRegistrations=taskAgg[TASKS['Reception & Patient Management'][0]].quantity;
  summary.appointments=taskAgg['Appointments Booked'].quantity;
  summary.employeeRows=Object.values(byStaff).sort((a,b)=>a.name.localeCompare(b.name)).map(e=>{
    const t=TARGETS[e.name]||{prepared:0,updated:0};
    const targetPrepared=e.days*t.prepared,targetUpdated=e.days*t.updated;
    const target=targetPrepared+targetUpdated;
    return {...e,targetPrepared,targetUpdated,target,achievement:target>0?(e.prepared+e.updated)/target:null,minutesPerLedger:(e.prepared+e.updated)>0?(e.preparedHours+e.updatedHours)*60/(e.prepared+e.updated):null};
  });
  summary.activities=Object.values(taskAgg).map(a=>({...a,perHour:a.hours>0&&a.unit!=='AED'?a.quantity/a.hours:null}));
  summary.daily=Object.values(byDate).sort((a,b)=>a.date.localeCompare(b.date));
  summary.warnings=summary.warnings.slice(0,40);
  return summary;
}
export default async function handler(req,res){
  res.setHeader('Cache-Control','no-store');
  if(req.method!=='GET')return res.status(405).json({error:'Method not allowed'});
  if(!process.env.DASHBOARD_PASSWORD) return res.status(503).json({error:'DASHBOARD_PASSWORD is not configured'});
  const sent=req.headers['x-dashboard-password'];
  const expected=process.env.DASHBOARD_PASSWORD;
  const a=Buffer.from(String(sent||''));const b=Buffer.from(expected);
  if(a.length!==b.length||!crypto.timingSafeEqual(a,b))return res.status(401).json({error:'Invalid dashboard password'});
  const from=String(req.query.from||'');const to=String(req.query.to||'');
  if(from&&!/^\d{4}-\d{2}-\d{2}$/.test(from)||to&&!/^\d{4}-\d{2}-\d{2}$/.test(to))return res.status(400).json({error:'Invalid date filter'});
  try{
    const token=await accessToken();const raw=await readRows(token);const parsed=parseRows(raw);
    // For duplicate employee + date submissions, keep the latest row and warn in UI.
    const unique=new Map();let duplicates=0;
    for(const r of parsed.records){const key=r.staff+'|'+r.date;if(unique.has(key))duplicates++;unique.set(key,r);}
    const filtered=[...unique.values()].filter(r=>(!from||r.date>=from)&&(!to||r.date<=to));
    const summary=summarize(filtered,parsed.tasks);
    if(duplicates)summary.warnings.unshift(`${duplicates} duplicate employee/date submission(s) were excluded; latest response kept.`);
    return res.status(200).json({summary,targets:TARGETS,from,to,generatedAt:new Date().toISOString()});
  }catch(err){console.error(err);return res.status(500).json({error:'Unable to read Google Sheets. Check Vercel configuration and sheet sharing.',detail:process.env.NODE_ENV==='development'?String(err.message):undefined});}
}
