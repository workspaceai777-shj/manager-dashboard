import admin from 'firebase-admin';
import { google } from 'googleapis';

const SHEET_ID = process.env.GOOGLE_SHEET_ID || '1Zr7W7P7JUTUR43nDmR1YWmvqYsdctdzmMfM7Px-q7lo';
const TAB_USERS = 'App_Users', TAB_ASSIGN = 'App_Assignments', TAB_ENTRIES = 'App_Entries';
const allowedBranches = ['ONT-BB','ONT-BR1'];
const allowedCategories = ['FRONT DESK','INSURANCE USER'];

if (!admin.apps.length && process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)) });
}

function sheetClient() {
  if (!process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL || !process.env.GOOGLE_PRIVATE_KEY) {
    throw new Error('Google Sheet service-account configuration is missing');
  }
  const auth = new google.auth.JWT({
    email: process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL,
    key: process.env.GOOGLE_PRIVATE_KEY.replace(/\\n/g, '\n'),
    scopes: ['https://www.googleapis.com/auth/spreadsheets']
  });
  return google.sheets({ version: 'v4', auth });
}
const headers = {
  [TAB_USERS]: ['uid','email','name','role','active'],
  [TAB_ASSIGN]: ['uid','branch','category','active'],
  [TAB_ENTRIES]: ['id','createdAt','uid','employeeName','date','branch','category','taskId','emr','remarks','quantity','hours']
};
async function readTab(sheets,tab) {
  try {
    const r=await sheets.spreadsheets.values.get({spreadsheetId:SHEET_ID,range:`'${tab}'!A1:Z20000`});
    const values=r.data.values||[];
    if(!values.length)return [];
    const cols=values[0];
    return values.slice(1).filter(r=>r[0]).map(row=>Object.fromEntries(cols.map((col,i)=>[col,row[i]??''])));
  }catch(e){
    if(e.code===400 && /Unable to parse range/i.test(e.message))throw new Error('Initialize app database tabs first');
    throw e;
  }
}
async function append(sheets,tab,rows) {
  await sheets.spreadsheets.values.append({spreadsheetId:SHEET_ID,range:`'${tab}'!A1`,valueInputOption:'RAW',
    insertDataOption:'INSERT_ROWS',requestBody:{values:rows}});
}
const baseReception=[
['registrations','Patient Registrations (including treatment chart and case sheet)'],
['appointments','Appointments Booked'],['calls','Calls Attended'],['whatsapp','WhatsApp Enquiries Replied'],
['confirmations','Confirmation Messages Sent'],['consultations','Consultations Coordinated'],
['enquiries','Enquiries Handled'],['registration_excel','Patient Registration Excel updated']
];
const brLedger=[['ledger_prepared','Individual Ledgers Prepared (EMR-wise)'],['ledger_updated','Ledgers Updated (R4)'],
['patient_cards','Patient Cards Prepared'],['charts','Charts Prepared'],['patient_documents','Patient Documents Updated'],
['emr_updated','EMR Records Updated'],['appointment_excel','Appointment Excel Records Updated'],
['due_checked','Next Day Appointment Due Checked']];
const bbTasks=[
['registrations','New patient registration and cards prepared'],['whatsapp','WhatsApp messages checked and responded'],
['therapist_schedule','Therapist schedule arranged and posted'],['reminders','Next-day WhatsApp reminders sent'],
['billing_excel','Billing and daily collection Excel prepared'],['registration_excel','New registration Excel updated'],
['appointments','Appointments, arrival and reporting vouchers'],['collection','Daily collection (AED)'],
['card_details','Card date/time, therapist and treatment entered'],['ledger_updated','Next-day individual ledgers updated'],
['cards_arranged','Next-day cards arranged'],['ledger_prepared','Individual Ledgers Prepared (EMR-wise)']
];
const insurance=[['insurance_invoices','Insurance Invoices Prepared'],['insurance_documents','Insurance Documents Sent'],
['insurance_datewise','Insurance Datewise Updated'],['insurance_emrwise','Insurance EMRwise Updated']];
const activities=(branch,cat)=>{
  const x=cat==='INSURANCE USER'?insurance:branch==='ONT-BB'?bbTasks:[...baseReception,...brLedger,['collection','Daily Collection (AED)']];
  return x.map(([id,name])=>({id,name}));
};
function validDate(v) {return /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(v));}
const result=(res,status,data)=>res.status(status).json(data);

export default async function handler(req,res){
  if(req.method!=='POST')return result(res,405,{error:'POST required'});
  try{
    if(!admin.apps.length)return result(res,503,{error:'Firebase Admin credentials not configured'});
    const token=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!token)return result(res,401,{error:'Not authenticated'});
    const verified=await admin.auth().verifyIdToken(token,true);
    const uid=verified.uid;
    const body=req.body||{};
    const sheets=sheetClient();
    const users=await readTab(sheets,TAB_USERS);
    const me=users.find(u=>u.uid===uid && String(u.active).toLowerCase()==='true');
    if(!me)return result(res,403,{error:'No active staff account. Ask an administrator.'});
    const assignments=(await readTab(sheets,TAB_ASSIGN)).filter(a=>a.uid===uid && String(a.active).toLowerCase()==='true');
    const manager=['ADMIN','MANAGER'].includes(me.role);
    const check=(branch,category)=> allowedBranches.includes(branch)&&allowedCategories.includes(category)&&(
      me.role==='ADMIN'||assignments.some(a=>a.branch===branch&&a.category===category));
    if(body.action==='bootstrap')return result(res,200,{profile:me,assignments:me.role==='ADMIN'?
      allowedBranches.flatMap(branch=>allowedCategories.map(category=>({branch,category}))):assignments});
    if(body.action==='tasks'){
      if(!check(body.branch,body.category))return result(res,403,{error:'Category not assigned'});
      return result(res,200,{tasks:activities(body.branch,body.category)});
    }
    if(body.action==='save') {
      if(!check(body.branch,body.category))return result(res,403,{error:'Category not assigned'});
      if(!validDate(body.date)||!Array.isArray(body.entries)||body.entries.length>150)return result(res,400,{error:'Invalid date or entries'});
      const allowed=new Set(activities(body.branch,body.category).map(t=>t.id));
      const rows=[];
      const seenLedger=new Set();
      for(const e of body.entries){
        const task=String(e.taskId??'');
        const quantity=Number(e.quantity),hours=Number(e.hours);
        if(!allowed.has(task)||!Number.isFinite(quantity)||!Number.isFinite(hours)||quantity<0||hours<0||hours>24||quantity>100000)
          return result(res,400,{error:'Invalid task quantity or hours'});
        if(task!=='collection'&&!Number.isInteger(quantity))return result(res,400,{error:'Quantities must be whole numbers'});
        const emr=String(e.emr??'').trim(),remarks=String(e.remarks??'').trim();
        if(emr.length>70||remarks.length>500)return result(res,400,{error:'EMR or remarks too long'});
        if(task==='ledger_prepared'){
          if(!emr||quantity!==1||hours<=0)return result(res,400,{error:'Each prepared ledger needs an EMR and positive time'});
          if(seenLedger.has(emr))return result(res,400,{error:'Duplicate EMR in submission'});
          seenLedger.add(emr);
        } else if(emr) return result(res,400,{error:'EMR is only accepted for ledger preparation'});
        rows.push([crypto.randomUUID(),new Date().toISOString(),uid,me.name,body.date,body.branch,body.category,task,emr,remarks,quantity,hours]);
      }
      if(!rows.length)return result(res,400,{error:'No tasks entered'});
      await append(sheets,TAB_ENTRIES,rows);
      return result(res,200,{saved:rows.length});
    }
    if(body.action==='dashboard'){
      if(!manager)return result(res,403,{error:'Manager access required'});
      const all=await readTab(sheets,TAB_ENTRIES);
      const from=validDate(body.from)?body.from:'0000-01-01',to=validDate(body.to)?body.to:'9999-12-31';
      const permitted=me.role==='ADMIN'?null:new Set(assignments.map(a=>a.branch+'|'+a.category));
      return result(res,200,{entries:all.filter(e=>e.date>=from&&e.date<=to && (!permitted||permitted.has(e.branch+'|'+e.category)))});
    }
    if(body.action==='users'){
      if(me.role!=='ADMIN')return result(res,403,{error:'Admin access required'});
      const allAssign=await readTab(sheets,TAB_ASSIGN);
      return result(res,200,{users:users.flatMap(u=>allAssign.filter(a=>a.uid===u.uid).map(a=>({...u,branch:a.branch,category:a.category})))});
    }
    if(body.action==='upsertUser'){
      if(me.role!=='ADMIN')return result(res,403,{error:'Admin access required'});
      const {uid:target,name,email,role,branch,category}=body;
      if(!target||!name||!email||!check(branch,category))return result(res,400,{error:'Missing user or assignment'});
      if(!['ADMIN','MANAGER','STAFF'].includes(role))return result(res,400,{error:'Invalid role'});
      const firebaseUser=await admin.auth().getUser(String(target));
      if(firebaseUser.email?.toLowerCase()!==String(email).toLowerCase())return result(res,400,{error:'Firebase UID/email mismatch'});
      const existing=users.find(x=>x.uid===target);
      if(existing && (existing.name!==name||existing.role!==role))return result(res,409,{error:'Existing user changes require a separate review/update operation'});
      if(!existing)await append(sheets,TAB_USERS,[[target,email,name,role,true]]);
      const allAssign=await readTab(sheets,TAB_ASSIGN);
      if(!allAssign.some(x=>x.uid===target&&x.branch===branch&&x.category===category))await append(sheets,TAB_ASSIGN,[[target,branch,category,true]]);
      return result(res,200,{ok:true});
    }
    return result(res,400,{error:'Unknown action'});
  }catch(e){
    console.error('App API error',e?.message);
    return result(res,500,{error:'Backend request failed. Check server configuration and logs.'});
  }
}
