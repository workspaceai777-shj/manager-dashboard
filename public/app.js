const $ = id => document.getElementById(id);
let password = '';
const num = n => (Number(n)||0).toLocaleString('en-US',{maximumFractionDigits:2});
const money = n => 'AED '+num(n);
const esc = s => String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const set = (id,v) => $(id).textContent = v;
function initialDates(){const now = new Date(); const end=new Date(now.getTime()-now.getTimezoneOffset()*60000).toISOString().slice(0,10); const first=end.slice(0,8)+'01';$('from').value=first;$('to').value=end;}
function bar(name,value,max,subtitle,cls=''){const pct=max?Math.max(0,Math.min(100,value/max*100)):0;return `<div><div class="bar-head"><span>${esc(name)}</span><span>${esc(subtitle)}</span></div><div class="track"><div class="fill ${cls}" style="width:${pct}%"></div></div></div>`;}
function render(s,generatedAt){
  set('reports',num(s.recordCount));set('prepared',num(s.prepared));set('updated',num(s.updated));set('collections',money(s.collections));set('task-hours',num(s.totalHours)+' h');set('work-hours',num(s.hoursReported)+' h');set('registrations',num(s.patientRegistrations));set('appointments',num(s.appointments));
  set('time-note',`Reported task hours: ${num(s.totalHours)} h. Daily working hours submitted: ${num(s.hoursReported)} h. Differences appear in data quality notes.`);
  const rows=s.employeeRows;
  $('employee-body').innerHTML=rows.length?rows.map(e=>{const a=e.achievement;return `<tr><td><b>${esc(e.name)}</b></td><td>${num(e.days)}</td><td>${num(e.prepared)} / ${num(e.targetPrepared)}</td><td>${num(e.updated)} / ${num(e.targetUpdated)}</td><td>${num(e.target)}</td><td><span class="achieve ${a===null?'missing':a<.8?'low':''}">${a===null?'Not assigned':num(a*100)+'%'}</span></td><td>${e.minutesPerLedger===null?'—':num(e.minutesPerLedger)+' min'}</td><td>${num(e.collections)}</td></tr>`}).join(''):'<tr><td colspan="8" class="empty">No staff reports in selected dates.</td></tr>';
  $('ledger-bars').innerHTML=rows.length?rows.map(e=>bar(e.name,e.prepared+e.updated,Math.max(e.target,e.prepared+e.updated,1),`${num(e.prepared+e.updated)} actual / ${num(e.target)} target`)).join(''):'<p class="empty">No reports for selected dates.</p>';
  const tasks=s.activities.filter(t=>t.unit!=='AED');
  const ranked=[...tasks].filter(t=>t.quantity>0).sort((a,b)=>b.quantity-a.quantity).slice(0,10);
  const rankedH=[...tasks].filter(t=>t.hours>0).sort((a,b)=>b.hours-a.hours).slice(0,10);
  $('task-bars').innerHTML=ranked.length?ranked.map(t=>bar(t.name,t.quantity,ranked[0].quantity,num(t.quantity)+' done')).join(''):'<p class="empty">No task counts yet.</p>';
  $('hours-bars').innerHTML=rankedH.length?rankedH.map(t=>bar(t.name,t.hours,rankedH[0].hours,num(t.hours)+' h','teal')).join(''):'<p class="empty">No task hours yet.</p>';
  $('activities-body').innerHTML=s.activities.map(t=>`<tr><td>${esc(t.section)}</td><td>${esc(t.name)}</td><td>${num(t.quantity)}${t.unit==='AED'?' AED':''}</td><td>${num(t.hours)}</td><td>${t.perHour===null?'—':num(t.perHour)}</td></tr>`).join('');
  const w=s.warnings||[];$('warnings-panel').classList.toggle('hidden',!w.length);$('warnings').innerHTML=w.map(x=>'<li>'+esc(x)+'</li>').join('');
  lineChart(s.daily);set('updated-at','Updated '+new Date(generatedAt).toLocaleString());
}
function lineChart(rows){const el=$('trend-chart');if(!rows.length){el.innerHTML='<p class="empty">No report dates in range.</p>';return;}
  const W=960,H=260,L=45,T=20,B=42,R=15,max=Math.max(1,...rows.flatMap(r=>[r.prepared,r.updated]));
  const X=i=>L+(rows.length===1?(W-L-R)/2:i*(W-L-R)/(rows.length-1));const Y=v=>T+(H-T-B)*(1-v/max);
  const poly=key=>rows.map((r,i)=>`${X(i)},${Y(r[key])}`).join(' ');
  const ticks=Array.from({length:5},(_,i)=>{const v=max*i/4;const y=Y(v);return `<line x1="${L}" x2="${W-R}" y1="${y}" y2="${y}" stroke="#e6ebf2"/><text x="${L-10}" y="${y+4}" text-anchor="end" fill="#9babbd" font-size="11">${num(v)}</text>`}).join('');
  const step=Math.max(1,Math.ceil(rows.length/8));const labels=rows.map((r,i)=>i%step===0||i===rows.length-1?`<text x="${X(i)}" y="${H-12}" font-size="11" text-anchor="middle" fill="#8093aa">${esc(r.date.slice(5))}</text>`:'').join('');
  const lines=['prepared','updated'].map((k,i)=>`<polyline points="${poly(k)}" fill="none" stroke="${i?'#1db1a7':'#367de9'}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round"/>`).join('');
  el.innerHTML=`<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Ledgers prepared and updated by report date">${ticks}${lines}${labels}</svg>`;
}
async function load(){if(!password)return;const from=$('from').value,to=$('to').value;if(from>to){$('error').textContent='From date must not be after To date.';$('error').classList.remove('hidden');return;}
  $('error').classList.add('hidden');set('status','● Loading…');$('status').classList.remove('ok');$('refresh').disabled=true;
  try{const response=await fetch(`/api/report?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,{headers:{'x-dashboard-password':password},cache:'no-store'});const data=await response.json();if(!response.ok)throw Error(data.error||'Unable to load dashboard');render(data.summary,data.generatedAt);set('status','● Connected');$('status').classList.add('ok');$('auth-modal').classList.add('hidden');$('auth-error').textContent='';}
  catch(e){$('error').textContent=e.message;$('error').classList.remove('hidden');set('status','● Connection error');if(/password/i.test(e.message)){$('auth-modal').classList.remove('hidden');$('auth-error').textContent='Incorrect password. Please try again.';password='';}}
  finally{$('refresh').disabled=false;}
}
$('auth-form').addEventListener('submit',event=>{event.preventDefault();password=$('password').value;$('password').value='';load();});$('apply').addEventListener('click',load);$('refresh').addEventListener('click',load);initialDates();
