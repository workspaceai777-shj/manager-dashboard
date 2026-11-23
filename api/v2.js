import admin from 'firebase-admin';
import { google } from 'googleapis';
import {
  isSupabaseConfigured,
  readSupabaseTable,
  insertSupabaseRows,
  deleteSupabaseRows,
} from './supabaseClient.js';

const SHEET_ID = process.env.GOOGLE_SHEET_ID || '1Zr7W7P7JUTUR43nDmR1YWmvqYsdctdzmMfM7Px-q7lo';
const TAB_USERS = 'App_Users', TAB_ASSIGN = 'App_Assignments', TAB_ENTRIES = 'App_Entries';
const allowedBranches = ['ONT-BB','ONT-BR1'];
const canonicalCategories = ['FRONT DESK','INSURANCE USER','ACCOUNTS',"DOCTOR'S ZONE"];
const allowedCategories = [...canonicalCategories,"Doctor's Zone"];

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
  [TAB_ENTRIES]: ['id','createdAt','uid','employeeName','date','branch','category','taskId','emr','remarks','quantity','hours','Task Date']
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
// Entries carry a dedicated "Task Date" column (the date the work was done, chosen by the
// staff member) separate from createdAt (when the row was saved). Existing sheets get the
// header added and their rows back-filled from the legacy `date` column exactly once.
let taskDateReady=false;
async function ensureTaskDateColumn(sheets) {
  if(taskDateReady)return;
  const head=await sheets.spreadsheets.values.get({spreadsheetId:SHEET_ID,range:`'${TAB_ENTRIES}'!A1:M1`});
  const cols=(head.data.values||[[]])[0]||[];
  if(cols[12]!=='Task Date'){
    const dates=await sheets.spreadsheets.values.get({spreadsheetId:SHEET_ID,range:`'${TAB_ENTRIES}'!E2:E20000`});
    const col=(dates.data.values||[]).map(r=>[r[0]??'']);
    await sheets.spreadsheets.values.update({spreadsheetId:SHEET_ID,range:`'${TAB_ENTRIES}'!M1`,
      valueInputOption:'RAW',requestBody:{values:[['Task Date']]}});
    if(col.length)await sheets.spreadsheets.values.update({spreadsheetId:SHEET_ID,range:`'${TAB_ENTRIES}'!M2`,
      valueInputOption:'RAW',requestBody:{values:col}});
  }
  taskDateReady=true;
}
function normalizeEntryDate(value) {
  const s = String(value || '').trim();
  if (!s) return '';
  if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
  const m = s.match(/^(\d{1,2})[\/-](\d{1,2})[\/-](\d{4})$/);
  if (m) {
    const d = String(m[1]).padStart(2, '0');
    const mo = String(m[2]).padStart(2, '0');
    const y = m[3];
    return `${y}-${mo}-${d}`;
  }
  return s;
}

// Task Date is authoritative for every report/dashboard filter; falls back to legacy date.
const readEntries=async(sheets)=>(await readTab(sheets,TAB_ENTRIES)).map(r=>{
  const td = normalizeEntryDate(r['Task Date']);
  const d = normalizeEntryDate(r.date);
  const effective = td || d;
  return effective ? {...r, date: effective, 'Task Date': td || effective} : r;
});
async function append(sheets,tab,rows) {
  await sheets.spreadsheets.values.append({spreadsheetId:SHEET_ID,range:`'${tab}'!A1`,valueInputOption:'RAW',
    insertDataOption:'INSERT_ROWS',requestBody:{values:rows}});
}

// -----------------------------------------------------------------------------
// Unified Database Abstraction (Supabase primary, Google Sheets fallback)
// -----------------------------------------------------------------------------
let cachedUsers = null;
let cachedUsersTime = 0;
let cachedAssignments = null;
let cachedAssignmentsTime = 0;
const CACHE_TTL_MS = 60 * 1000;

function invalidateCache() {
  cachedUsers = null;
  cachedUsersTime = 0;
  cachedAssignments = null;
  cachedAssignmentsTime = 0;
}

async function dbGetUsers(sheets) {
  if (isSupabaseConfigured()) {
    const now = Date.now();
    if (cachedUsers && now - cachedUsersTime < CACHE_TTL_MS) {
      return cachedUsers;
    }
    const list = await readSupabaseTable('app_users', 'select=uid,email,name,role,active');
    cachedUsers = list.map(u => ({ uid: u.uid, email: u.email, name: u.name, role: u.role, active: String(u.active) }));
    cachedUsersTime = now;
    return cachedUsers;
  }
  return await readTab(sheets, TAB_USERS);
}

async function dbGetAssignments(sheets) {
  if (isSupabaseConfigured()) {
    const now = Date.now();
    if (cachedAssignments && now - cachedAssignmentsTime < CACHE_TTL_MS) {
      return cachedAssignments;
    }
    const list = await readSupabaseTable('app_assignments', 'select=uid,branch,category,active');
    cachedAssignments = list.map(a => ({ uid: a.uid, branch: a.branch, category: a.category, active: String(a.active) }));
    cachedAssignmentsTime = now;
    return cachedAssignments;
  }
  return await readTab(sheets, TAB_ASSIGN);
}

const TIMED_TASKS = new Set(['enquiry_detail', 'ledger_prepared', 'insurance_ledger_emr']);
function isoOrNull(v) {
  if (v === null || v === undefined || v === '') return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}
// Returns {start,end} ISO strings/null, or null when invalid.
function parseTimes(e) {
  const out = [];
  for (const k of ['startTime', 'endTime']) {
    const v = e[k];
    if (v === undefined || v === null || v === '') { out.push(null); continue; }
    if (typeof v !== 'string' || v.length > 40 || !/^\d{4}-\d{2}-\d{2}/.test(v)) return null;
    const d = new Date(v);
    if (Number.isNaN(d.getTime())) return null;
    out.push(d.toISOString());
  }
  if (out[0] && out[1] && new Date(out[1]) < new Date(out[0])) return null;
  return { start: out[0], end: out[1] };
}

async function dbGetActiveEntries(sheets, filters = {}) {
  if (isSupabaseConfigured()) {
    const params = [];
    if (filters.date) {
      params.push(`task_date=eq.${encodeURIComponent(filters.date)}`);
    } else {
      if (filters.from && filters.from !== '0000-01-01') {
        params.push(`task_date=gte.${encodeURIComponent(filters.from)}`);
      }
      if (filters.to && filters.to !== '9999-12-31') {
        params.push(`task_date=lte.${encodeURIComponent(filters.to)}`);
      }
    }
    if (filters.uid) {
      params.push(`uid=eq.${encodeURIComponent(filters.uid)}`);
    }
    if (filters.branch) {
      params.push(`branch=eq.${encodeURIComponent(filters.branch)}`);
    }
    if (filters.category) {
      params.push(`category=eq.${encodeURIComponent(filters.category)}`);
    }
    params.push('order=seq.asc');
    const query = params.join('&');

    let list;
    try {
      list = await readSupabaseTable('app_entries', query);
    } catch (e) {
      console.warn('app_entries query failed, falling back to created_at:', e?.message);
      const fallbackQuery = params.filter(p => !p.startsWith('order=')).concat('order=created_at.asc,id.asc').join('&');
      list = await readSupabaseTable('app_entries', fallbackQuery);
    }
    return activeEntries(list.map(e => {
      const date = normalizeEntryDate(e.task_date || e.date);
      return {
        id: e.id,
        createdAt: e.created_at,
        uid: e.uid,
        employeeName: e.employee_name,
        date,
        branch: e.branch,
        category: e.category,
        taskId: e.task_id,
        emr: e.emr || '',
        remarks: e.remarks || '',
        quantity: String(e.quantity ?? 0),
        hours: String(e.hours ?? 0),
        callerName: e.caller_name || '',
        callStatus: e.call_status || '',
        callerPhone: e.caller_phone || '',
        ...(TIMED_TASKS.has(e.task_id) ? { startTime: isoOrNull(e.start_time), endTime: isoOrNull(e.end_time) } : {}),
        'Task Date': date,
      };
    }));
  }
  return activeEntries(await readEntries(sheets));
}

async function dbSaveEntries(sheets, markerRow, dataRows) {
  if (isSupabaseConfigured()) {
    const toInsert = [];
    const toRecord = (r) => {
      const rec = {
        id: r[0],
        created_at: r[1],
        uid: r[2],
        employee_name: r[3],
        date: r[4],
        branch: r[5],
        category: r[6],
        task_id: r[7],
        emr: r[8] || '',
        remarks: r[9] || '',
        quantity: Number(r[10]) || 0,
        hours: Number(r[11]) || 0,
        task_date: r[12] || r[4],
      };
      // All rows in a PostgREST bulk insert must have the exact same keys (PGRST102).
      if (hasEnquiryCols) {
        rec.caller_name = r[7] === 'enquiry_detail' ? (r[13] || '') : '';
        rec.call_status = r[7] === 'enquiry_detail' ? (r[14] || '') : '';
        rec.caller_phone = r[7] === 'enquiry_detail' ? (r[15] || '') : '';
      }
      if (hasTimedCols) {
        rec.start_time = (TIMED_TASKS.has(r[7]) && r[16]) ? r[16] : null;
        rec.end_time = (TIMED_TASKS.has(r[7]) && r[17]) ? r[17] : null;
      }
      return rec;
    };
    const allInputRows = markerRow ? [markerRow, ...dataRows] : dataRows;
    const hasEnquiryCols = allInputRows.some(r => r[7] === 'enquiry_detail');
    const hasTimedCols = allInputRows.some(r => TIMED_TASKS.has(r[7]) && (r[16] || r[17]));
    for (const r of allInputRows) toInsert.push(toRecord(r));
    if (toInsert.length) {
      await insertSupabaseRows('app_entries', toInsert, false, true);
    }
    return;
  }
  await ensureTaskDateColumn(sheets);
  if (markerRow) {
    await append(sheets, TAB_ENTRIES, [markerRow, ...dataRows]);
  } else if (dataRows.length) {
    await append(sheets, TAB_ENTRIES, dataRows);
  }
}

const baseReception=[
['registrations','Patient Registrations (including treatment chart and case sheet)'],
['appointments','Appointments Booked'],['calls','Calls Attended'],['whatsapp','WhatsApp Enquiries Replied'],
['confirmations','Confirmation Messages Sent'],['consultations','Consultations Coordinated'],
['enquiries','Enquiries Handled'],['registration_excel','Patient Registration Excel updated']
];
const brLedger=[
  ['ledger_prepared','Individual Ledgers Prepared (EMR-wise)'],
  ['ledger_updated','Individual Ledger Updated (R4) (including for insurance)'],
  ['patient_cards','Arrival, Treatment Charts & Reporting Voucher preparation'],
  ['charts','Charts prepared for next day including session & rearranged all cards.'],
  ['patient_documents','Patient Doc Folder Updated'],
  ['due_checked','Next Day Appointment Due Checked'],
  ['room_chore_inspection','Room Chore Inspection'],
  ['daily_task_updation','Daily Task Updation']
];
const bbTasks=[
  ['registrations','New patient registration and cards prepared'],
  ['whatsapp','WhatsApp messages checked and responded'],
  ['therapist_schedule','Therapist schedule arranged and posted'],
  ['reminders','Next-day WhatsApp reminders sent'],
  ['billing_excel','Billing and daily collection Excel prepared'],
  ['registration_excel','New registration Excel updated'],
  ['appointments','Appointment bookings (in software/excel) & attending calls for appointments'],
  ['collection','Daily collection (AED)'],
  ['card_details','Card date/time, therapist and treatment entered'],
  ['patient_cards','Arrival, Treatment Charts & Reporting Voucher preparation'],
  ['charts','Charts prepared for next day including session & rearranged all cards.'],
  ['ledger_updated','Individual Ledger Updated (R4) (including for insurance)'],
  ['room_chore_inspection','Room Chore Inspection'],
  ['daily_task_updation','Daily Task Updation'],
  ['ledger_prepared','Individual Ledgers Prepared (EMR-wise)']
];
const insurance=[
  ['insurance_claims_prepared','Insurance Claims Prepared'],
  ['insurance_invoices','Insurance Invoices Prepared'],
  ['insurance_documents','Insurance Documents Sent'],
  ['insurance_datewise','Insurance Datewise Updated'],
  ['insurance_emrwise','Insurance EMRwise Updated'],
  ['insurance_ledger_emr','Insurance EMR-wise Entry']
];
const accounts=[
  ['accounts_collection_check','Daily Collections Checked — White Fox and Ontario'],
  ['accounts_dha_attendance','DHA Attendance Records Updated'],
  ['accounts_insurance_ledgers','Individual ledgers for insurance showed'],
  ['accounts_month_end','Month-End Collection Closing and Bank Deposit Handover'],
  ['accounts_reception','Reception Duties and Reporting Vouchers'],
  ['accounts_zoho_updation','Zoho updation'],
  ['accounts_vat_excel_ontario','Vat excel entry Ontario'],
  ['accounts_vat_filing_ontario','Vat filing Ontario'],
  ['accounts_vat_excel_whitefox','Vat excel updation White fox'],
  ['accounts_vat_filing_whitefox','Vat filing White fox'],
  ['accounts_cash_in_hand_checking','Cash in hand checking'],
  ['accounts_staff_attendance','Staff attendance Ontario and Whitefox'],
  ['accounts_towel_import_invoice','Towel import invoice preparation, cash collect from customer and excel update'],
  ['accounts_medicine_collect_whitefox','Medicine collect from supplier for whitefox and invoice updated'],
  ['accounts_month_end_closing_deposit','Travel collection closing and cash handover for deposit'],
  ['accounts_whitefox_consignment_sale','White fox Consignment basis sale checking and update'],
  ['accounts_petty_cash_voucher_entry','Petty cash voucher entry and filing'],
  ['accounts_petty_cash_excel','Petty cash excel'],
  ['accounts_monthly_collection_excel','Monthly collection excel'],
  ['accounts_purchase_request_month','Purchase request for one month']
];
const doctorsZone=[
  ['doctors_consultations','Number of Consultations'],
  ['doctors_follow_ups','Number of Follow-ups'],
  ['doctors_treatments_supervised','Number of Treatments Supervised']
];
const activities=(branch,cat)=>{
  const c=String(cat||'').toUpperCase();
  const x=c==="DOCTOR'S ZONE"?doctorsZone:c==='ACCOUNTS'?accounts:c==='INSURANCE USER'?insurance:branch==='ONT-BB'?bbTasks:[...baseReception,...brLedger,['collection','Daily Collection (AED)']];
  return x.map(([id,name])=>({id,name}));
};
// A replacement is append-only: older submissions remain available for audit,
// while reads expose only rows after the latest replacement marker for each
// employee / date / branch / category. No other employee's rows are overwritten.
const REPLACE_MARKER = '__report_replace__';
const reportKey = (e) => [e.uid,e.date,e.branch,e.category].join('\u001f');
function activeEntries(records) {
  const current = new Map();
  for (const row of records) {
    const key = reportKey(row);
    if (row.taskId === REPLACE_MARKER) {
      current.set(key, []);
    } else {
      if (!current.has(key)) current.set(key, []);
      current.get(key).push(row);
    }
  }
  return [...current.values()].flat();
}
function validDate(v) {return /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(v));}
const result=(res,status,data)=>res.status(status).json(data);

export default async function handler(req,res){
  // Flutter Web uses a cross-origin Authorization header, which requires
  // browsers to perform an OPTIONS preflight before the authenticated POST.
  const origin = req.headers.origin;
  const defaultOrigins = ['https://tasklog-web.vercel.app', 'https://tasklog-web-ambu7.vercel.app'];
  const configuredOrigins = (process.env.ALLOWED_WEB_ORIGINS || '')
    .split(',').map(v => v.trim()).filter(Boolean);
  const localDevelopment = /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin || '');
  const isVercelOrigin = /^https:\/\/(tasklog|tasklog-[a-z0-9-]+)\.vercel\.app$/.test(origin || '') ||
                        /^https:\/\/tasklog-[a-z0-9-]+-ambu7\.vercel\.app$/.test(origin || '');
  const trustedOrigin = !!origin && (localDevelopment || defaultOrigins.includes(origin) || configuredOrigins.includes(origin) || isVercelOrigin);
  res.setHeader('Vary', 'Origin');
  if (trustedOrigin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    res.setHeader('Access-Control-Max-Age', '600');
  }
  if (origin && !trustedOrigin) return result(res,403,{error:'Origin not allowed'});
  if (req.method === 'OPTIONS') return res.status(204).end();
  if(req.method!=='POST')return result(res,405,{error:'POST required'});
  try{
    if(!admin.apps.length)return result(res,503,{error:'Firebase Admin credentials not configured'});
    const token=(req.headers.authorization||'').replace(/^Bearer\s+/i,'');
    if(!token)return result(res,401,{error:'Not authenticated'});
    const verified=await admin.auth().verifyIdToken(token);
    const uid=verified.uid;
    const body=req.body||{};
    const useSupabase = isSupabaseConfigured();
    const sheets = useSupabase ? null : sheetClient();
    const [users, allAssignments] = await Promise.all([
      dbGetUsers(sheets),
      dbGetAssignments(sheets),
    ]);
    const me=users.find(u=>u.uid===uid && String(u.active).toLowerCase()==='true');
    if(!me)return result(res,403,{error:'No active staff account. Ask an administrator.'});
    const assignments=allAssignments.filter(a=>a.uid===uid && String(a.active).toLowerCase()==='true');
    const check=(branch,category)=> allowedBranches.includes(branch)&&allowedCategories.includes(category)&&(
      me.role==='ADMIN'||assignments.some(a=>a.branch===branch&&a.category===category));
    if(body.action==='bootstrap')return result(res,200,{profile:me,assignments:me.role==='ADMIN'?
      allowedBranches.flatMap(branch=>canonicalCategories.map(category=>({branch,category}))):assignments});
    if(body.action==='tasks'){
      if(!check(body.branch,body.category))return result(res,403,{error:'Category not assigned'});
      return result(res,200,{tasks:activities(body.branch,body.category)});
    }
    if(body.action==='report'&&body.date===undefined&&(body.from!==undefined||body.to!==undefined)){
      // Range report: ADMIN sees all staff (optional branch/category/uid filters);
      // everyone else is forced to their own uid regardless of request fields.
      if(!validDate(body.from)||!validDate(body.to)||body.from>body.to)return result(res,400,{error:'Invalid date range'});
      if((Date.parse(body.to)-Date.parse(body.from))/86400000>730)return result(res,400,{error:'Date range too large (max 730 days)'});
      const isAdmin=me.role==='ADMIN';
      const fb=body.branch==null||body.branch===''?null:String(body.branch);
      const fc=body.category==null||body.category===''?null:String(body.category);
      const fu=body.uid==null||body.uid===''?null:String(body.uid);
      if((fb&&!allowedBranches.includes(fb))||(fc&&!allowedCategories.includes(fc)))return result(res,400,{error:'Invalid branch or category'});
      const all=await dbGetActiveEntries(sheets, {
        from: body.from,
        to: body.to,
        uid: isAdmin ? fu : uid,
        branch: fb,
        category: fc,
      });
      const out=all.filter(e=>e.date>=body.from&&e.date<=body.to&&
        (isAdmin?(!fu||e.uid===fu):e.uid===uid)&&
        (!fb||e.branch===fb)&&(!fc||e.category===fc)&&
        (isAdmin||check(e.branch,e.category)))
        .sort((a,b)=>a.date<b.date?-1:a.date>b.date?1:(String(a.createdAt)<String(b.createdAt)?-1:String(a.createdAt)>String(b.createdAt)?1:0));
      return result(res,200,{entries:out,from:body.from,to:body.to,count:out.length});
    }
    if(body.action==='report'){
      if(!check(body.branch,body.category))return result(res,403,{error:'Category not assigned'});
      if(!validDate(body.date))return result(res,400,{error:'Invalid reporting date'});
      const all=await dbGetActiveEntries(sheets, {
        date: body.date,
        uid,
        branch: body.branch,
        category: body.category,
      });
      const mine=all.filter(e=>e.uid===uid&&e.branch===body.branch&&
        e.category===body.category&&e.date===body.date);
      return result(res,200,{entries:mine});
    }
    if(body.action==='save'||body.action==='saveReport') {
      if(!check(body.branch,body.category))return result(res,403,{error:'Category not assigned'});
      if(!validDate(body.date)||!Array.isArray(body.entries)||body.entries.length>150)return result(res,400,{error:'Invalid date or entries'});
      const allowed=new Set(activities(body.branch,body.category).map(t=>t.id));
      allowed.add('other_tasks');
      allowed.add('cards_arranged');
      // Per-call detail rows only belong under the "Enquiries Handled" activity.
      if(allowed.has('enquiries'))allowed.add('enquiry_detail');
      const rows=[];
      const seenLedger=new Set();
      const isAccounts=body.category==='ACCOUNTS';
      const maxOther=isAccounts?5:1;
      const otherSlots=new Set();
      for(const e of body.entries){
        const task=String(e.taskId??'');
        const rawQty=(e.quantity===''||e.quantity===null||e.quantity===undefined)?0:Number(e.quantity);
        const rawHours=(e.hours===''||e.hours===null||e.hours===undefined)?0:Number(e.hours);
        const quantity=Number.isFinite(rawQty)?rawQty:NaN;
        const hours=Number.isFinite(rawHours)?rawHours:NaN;
        if(!allowed.has(task)||!Number.isFinite(quantity)||!Number.isFinite(hours)||quantity<0||hours<0||hours>100000||quantity>100000)
          return result(res,400,{error:`Invalid task quantity or hours (task: ${task.slice(0,60)||'none'}${allowed.has(task)?'':', not allowed for this category'})`});
        const emr=String(e.emr??'').trim(),remarks=String(e.remarks??'').trim();
        let times={start:null,end:null};
        if(TIMED_TASKS.has(task)){
          times=parseTimes(e);
          if(!times)return result(res,400,{error:'Invalid startTime or endTime'});
        }
        if(task==='enquiry_detail'){
          // One row per enquiry call: number (stored in `emr`), caller, status,
          // remarks and minutes. Reporting treats these as a breakdown only —
          // they never add to the activity's quantity or to worked hours.
          const callerName=String(e.callerName??'').trim(),callStatus=String(e.callStatus??'').trim();
          const callerPhone=String(e.callerPhone??'').trim();
          if(callerPhone.length>30||!/^[0-9+\-() ]*$/.test(callerPhone))
            return result(res,400,{error:'Invalid caller phone'});
          if(!emr&&!callerName&&!callStatus&&!callerPhone&&!remarks&&hours===0)continue;
          if(emr.length>20||callerName.length>120||callStatus.length>60||remarks.length>1000)
            return result(res,400,{error:'Enquiry details too long'});
          rows.push([crypto.randomUUID(),new Date().toISOString(),uid,me.name,body.date,body.branch,body.category,task,emr,remarks,1,hours,body.date,callerName,callStatus,callerPhone,times.start,times.end]);
          continue;
        }
        if(quantity===0&&hours===0&&task!=='ledger_prepared'&&task!=='insurance_ledger_emr'&&!(task==='other_tasks'&&remarks))continue;
        const normalizedQuantity=task==='collection'?quantity:Math.round(quantity);
        if(emr.length>70||remarks.length>1000)return result(res,400,{error:'EMR or remarks too long'});
        if(task==='other_tasks'){
          if(remarks.length>500)return result(res,400,{error:'Other task description too long (max 500)'});
          if(otherSlots.size>=maxOther)return result(res,400,{error:'Too many other tasks'});
          // ACCOUNTS: emr carries the slot '1'..'5' ('' = slot 1). Others: no slot.
          let slot='';
          if(isAccounts){
            slot=emr===''?'1':emr;
            if(!/^[1-5]$/.test(slot))return result(res,400,{error:'Invalid other task slot (1-5)'});
          } else if(emr) return result(res,400,{error:'EMR is only accepted for EMR-wise preparation'});
          if(otherSlots.has(slot))return result(res,400,{error:'Duplicate other task slot'});
          otherSlots.add(slot);
          rows.push([crypto.randomUUID(),new Date().toISOString(),uid,me.name,body.date,body.branch,body.category,task,slot,remarks,normalizedQuantity,hours,body.date]);
          continue;
        }
        if(task==='ledger_prepared'||task==='insurance_ledger_emr'){
          if(!emr)continue;
          const ledgerKey=`${task}:${emr}`;
          if(seenLedger.has(ledgerKey))return result(res,400,{error:'Duplicate EMR in submission'});
          seenLedger.add(ledgerKey);
        } else if(emr) return result(res,400,{error:'EMR is only accepted for EMR-wise preparation'});
        rows.push([crypto.randomUUID(),new Date().toISOString(),uid,me.name,body.date,body.branch,body.category,task,emr,remarks,normalizedQuantity,hours,body.date,...(times.start||times.end?['','','',times.start,times.end]:[])]);
      }
      if(body.action==='saveReport'){
        const marker=[crypto.randomUUID(),new Date().toISOString(),uid,me.name,
          body.date,body.branch,body.category,REPLACE_MARKER,'','',0,0,body.date];
        await dbSaveEntries(sheets, marker, rows);
      } else {
        await dbSaveEntries(sheets, null, rows);
      }
      const savedEntries = rows.map(r => ({
        id: r[0],
        createdAt: r[1],
        uid: r[2],
        employeeName: r[3],
        date: r[4],
        branch: r[5],
        category: r[6],
        taskId: r[7],
        emr: r[8] || '',
        remarks: r[9] || '',
        quantity: String(r[10] ?? 0),
        hours: String(r[11] ?? 0),
        callerName: r[13] || '',
        callStatus: r[14] || '',
        callerPhone: r[15] || '',
        ...(TIMED_TASKS.has(r[7]) ? { startTime: isoOrNull(r[16]), endTime: isoOrNull(r[17]) } : {}),
        'Task Date': r[12] || r[4],
      }));
      return result(res,200,{saved:rows.length,entries:savedEntries});
    }
    if(body.action==='dashboard'||body.action==='myDashboard'){
      if(body.action==='dashboard'&&me.role!=='ADMIN')
        return result(res,403,{error:'Administrator access required'});
      const adminUids=new Set(users.filter(u=>u.role==='ADMIN').map(u=>u.uid));
      const from=validDate(body.from)?body.from:'0000-01-01';
      const to=validDate(body.to)?body.to:'9999-12-31';
      if(validDate(body.from)&&validDate(body.to)&&(Date.parse(to)-Date.parse(from))/86400000>730)
        return result(res,400,{error:'Date range too large (max 730 days)'});
      const mine=body.action==='myDashboard';
      const all=await dbGetActiveEntries(sheets, {
        from: validDate(body.from) ? body.from : undefined,
        to: validDate(body.to) ? body.to : undefined,
        uid: mine ? uid : undefined,
      });
      return result(res,200,{entries:all.filter(e=>
        e.date>=from&&e.date<=to&&(mine?e.uid===uid:(!adminUids.has(e.uid)&&String(e.employeeName||'').trim().toLowerCase()!=='administrator')))});
    }
    if(body.action==='users'){
      if(me.role!=='ADMIN')return result(res,403,{error:'Admin access required'});
      return result(res,200,{users:users.flatMap(u=>allAssignments.filter(a=>a.uid===u.uid).map(a=>({...u,branch:a.branch,category:a.category})))});
    }

    if(body.action==='createStaff'){
      if(me.role!=='ADMIN')return result(res,403,{error:'Admin access required'});
      const email=String(body.email||'').trim().toLowerCase();
      const name=String(body.name||'').trim();
      const password=String(body.password||'');
      const role=String(body.role||'STAFF');
      const selected=Array.isArray(body.assignments)?body.assignments:[];
      if(!email.includes('@')||name.length<2||name.length>120||password.length<12||
        !['STAFF','MANAGER','ADMIN'].includes(role)||selected.length<1||selected.length>allowedBranches.length*allowedCategories.length||
        selected.some(a=>!allowedBranches.includes(a.branch)||!allowedCategories.includes(a.category))||
        new Set(selected.map(a=>a.branch+'|'+a.category)).size!==selected.length)
        return result(res,400,{error:'Invalid user details, password, or assignments'});
      const created=await admin.auth().createUser({email,password,displayName:name,emailVerified:false,disabled:false});
      try{
        if (useSupabase) {
          await insertSupabaseRows('app_users', [{ uid: created.uid, email, name, role, active: true }]);
          await insertSupabaseRows('app_assignments', selected.map(a => ({ uid: created.uid, branch: a.branch, category: a.category, active: true })));
        } else {
          await append(sheets,TAB_USERS,[[created.uid,email,name,role,true]]);
          await append(sheets,TAB_ASSIGN,selected.map(a=>[created.uid,a.branch,a.category,true]));
        }
        invalidateCache();
      }catch(e){
        // Avoid leaving a valid sign-in account without a matching staff role.
        await admin.auth().updateUser(created.uid,{disabled:true}).catch(()=>{});
        throw e;
      }
      return result(res,200,{ok:true,uid:created.uid});
    }
    if(body.action==='replaceAssignments'){
      if(me.role!=='ADMIN')return result(res,403,{error:'Admin access required'});
      const target=String(body.uid||'');
      const selected=Array.isArray(body.assignments)?body.assignments:[];
      if(!target||selected.length>allowedBranches.length*allowedCategories.length||selected.some(a=>!allowedBranches.includes(a.branch)||
        !allowedCategories.includes(a.category))||
        new Set(selected.map(a=>a.branch+'|'+a.category)).size!==selected.length)
        return result(res,400,{error:'Invalid assignments'});
      if(!users.some(u=>u.uid===target))return result(res,404,{error:'Unknown user'});
      if(target===uid && selected.length===0)return result(res,400,{error:'Cannot revoke your own last assignment'});
      if (useSupabase) {
        await deleteSupabaseRows('app_assignments', `uid=eq.${encodeURIComponent(target)}`);
        if (selected.length) {
          await insertSupabaseRows('app_assignments', selected.map(a => ({ uid: target, branch: a.branch, category: a.category, active: true })));
        }
      } else {
        const existing=await readTab(sheets,TAB_ASSIGN);
        const next=existing.filter(a=>a.uid!==target).map(a=>[a.uid,a.branch,a.category,a.active]);
        next.push(...selected.map(a=>[target,a.branch,a.category,true]));
        await sheets.spreadsheets.values.clear({spreadsheetId:SHEET_ID,range:"'App_Assignments'!A2:D20000"});
        if(next.length)await sheets.spreadsheets.values.update({spreadsheetId:SHEET_ID,
          range:"'App_Assignments'!A2",valueInputOption:'RAW',requestBody:{values:next}});
      }
      invalidateCache();
      return result(res,200,{ok:true});
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
      if (useSupabase) {
        if (!existing) {
          await insertSupabaseRows('app_users', [{ uid: target, email, name, role, active: true }]);
        }
        const existingAssignments = await readSupabaseTable('app_assignments', `uid=eq.${encodeURIComponent(target)}&branch=eq.${encodeURIComponent(branch)}&category=eq.${encodeURIComponent(category)}`);
        if (!existingAssignments || existingAssignments.length === 0) {
          await insertSupabaseRows('app_assignments', [{ uid: target, branch, category, active: true }]);
        }
      } else {
        if(!existing)await append(sheets,TAB_USERS,[[target,email,name,role,true]]);
        const allAssign=await readTab(sheets,TAB_ASSIGN);
        if(!allAssign.some(x=>x.uid===target&&x.branch===branch&&x.category===category))await append(sheets,TAB_ASSIGN,[[target,branch,category,true]]);
      }
      invalidateCache();
      return result(res,200,{ok:true});
    }
    return result(res,400,{error:'Unknown action'});
  }catch(e){
    console.error('App API error',e?.message);
    return result(res,500,{error:'Backend request failed. Check server configuration and logs.'});
  }
}
