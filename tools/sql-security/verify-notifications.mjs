import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const A='aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa', B='bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb', C='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const ITEM='11111111-1111-4111-8111-111111111111', R='33333333-3333-4333-8333-333333333333', S='44444444-4444-4444-8444-444444444444', M='55555555-5555-4555-8555-555555555555';
let passed=0;
async function as(uid,sql) {
  await db.exec(`reset role; set local role ${uid?'authenticated':'anon'}; select set_config('request.jwt.claim.sub','${uid??''}',true)`);
  return (await db.query(sql)).rows;
}
async function denied(action,code='42501') {
  await db.exec('savepoint denial');
  await assert.rejects(action,e=>e.code===code);
  await db.exec('rollback to savepoint denial; release savepoint denial');
}
async function request(uid=B,id=R) { return (await as(uid,`select public.encuentralo_request_recovery('${uid}','${id}','${ITEM}','Marca privada dentro de la tapa del termo') r`))[0].r; }
async function manage(uid,action,version=1,id=R) {return (await as(uid,`select public.encuentralo_manage_recovery('${uid}','${id}','${action}',${version}) r`))[0].r;}
async function notices(uid) {return as(uid,'select * from public.notifications order by created_at,id');}
async function accept() {
  await request(); await manage(A,'accept');
  return (await as(B,`select id from public.recovery_conversations where request_id='${R}'`))[0].id;
}
async function send(conversation,id=M) {return as(B,`select public.encuentralo_send_message('${B}','${id}','${conversation}','Mensaje secreto que nunca debe aparecer en el aviso')`);}
async function mute(uid,requests=false,messages=false,status=false) {
  return as(uid,`select public.encuentralo_save_notification_preferences('${uid}',${requests},${messages},${status},false)`);
}
async function test(name,action) {
  await db.exec('begin');
  try {await action();passed++;console.log(`PASS ${name}`);}
  finally {await db.exec('rollback');}
}
try {
  await db.exec(`create role anon nologin; create role authenticated nologin;
    create schema auth; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema public,auth to anon,authenticated;
    insert into auth.users values('${A}'),('${B}'),('${C}');`);
  for(const file of ['202611180001_create_found_items.sql','202611210001_recovery_requests_chat.sql','202611210002_notifications_help.sql']) {
    await db.exec(await readFile(new URL(`../../supabase/migrations/${file}`,import.meta.url),'utf8'));
  }
  await db.exec(`insert into public.found_items(id,finder_id,title,category,description,found_on,zone,custody)
    values('${ITEM}','${A}','Termo azul','bottles','Termo azul de prueba',current_date-1,'Biblioteca','student')`);
  await test('RLS, privilegios mínimos y sin escritura directa',async()=>{
    for(const table of ['notifications','notification_preferences']) {
      assert.equal((await db.query(`select relrowsecurity from pg_class where oid='public.${table}'::regclass`)).rows[0].relrowsecurity,true);
      await denied(()=>as(null,`select * from public.${table}`));
      for(const sql of [`delete from public.${table}`,`update public.${table} set ${table==='notifications'?'title':'user_id'}=null`,`insert into public.${table} default values`]) await denied(()=>as(B,sql));
    }
  });
  await test('solicitud genera un aviso para el encontrador, sin autoaviso ni datos privados',async()=>{
    await request(); const rows=await notices(A);
    assert.equal(rows.length,1);assert.equal(rows[0].kind,'recovery_request');assert.equal(rows[0].request_id,R);
    assert.equal(rows[0].alert_enabled,true);assert.equal(rows[0].read_at,null);
    assert.equal((await notices(B)).length,0);assert.equal((await notices(C)).length,0);
    assert.doesNotMatch(JSON.stringify(rows),/Marca privada|Termo azul|evidence|sender_id/);
  });
  await test('reintentos de solicitud y aceptación no duplican avisos',async()=>{
    await request();await request();await manage(A,'accept');await manage(A,'accept');
    assert.equal((await notices(A)).length,1);assert.equal((await notices(B)).length,1);
    assert.equal((await notices(B))[0].title,'Solicitud aceptada');
  });
  await test('rechazo y cancelación avisan únicamente al otro participante',async()=>{
    await request();await request(C,S);await manage(A,'reject');await manage(C,'cancel',1,S);
    assert.equal((await notices(B))[0].title,'Solicitud rechazada');
    assert.equal((await notices(C)).length,0);
    assert.equal((await notices(A)).filter(n=>n.title==='Solicitud cancelada').length,1);
  });
  await test('mensaje privado enlaza chat, omite contenido y es idempotente',async()=>{
    const conv=await accept();await send(conv);await send(conv);
    const rows=(await notices(A)).filter(n=>n.kind==='private_message');
    assert.equal(rows.length,1);assert.equal(rows[0].conversation_id,conv);assert.equal(rows[0].request_id,R);
    assert.doesNotMatch(JSON.stringify(rows),/Mensaje secreto/);
    assert.equal((await notices(C)).length,0);assert.equal((await notices(B)).filter(n=>n.kind==='private_message').length,0);
  });
  await test('C no puede leer avisos conocidos ni generar eventos arbitrarios',async()=>{
    await request(); const id=(await notices(A))[0].id;
    assert.equal((await as(C,`select * from public.notifications where id='${id}'`)).length,0);
    await denied(()=>as(C,`select encuentralo_private.record_notification('${C}','inventado','request_status','falso','falso','${ITEM}','${R}',null)`));
    await denied(()=>as(C,`select public.encuentralo_manage_recovery('${C}','${R}','accept',1)`));
    assert.equal((await notices(C)).length,0);
  });
  await test('preferencias privadas y ligadas a la sesión; anon sin RPC',async()=>{
    await mute(A);
    assert.equal((await as(A,'select * from public.notification_preferences')).length,1);
    assert.equal((await as(B,'select * from public.notification_preferences')).length,0);
    await denied(()=>as(B,`select public.encuentralo_save_notification_preferences('${A}',true,true,true,true)`));
    await denied(()=>as(null,`select public.encuentralo_complete_tutorial('${A}')`));
    await denied(()=>as(B,`select public.encuentralo_complete_tutorial('${A}')`));
  });
  await test('silenciar conserva solicitudes, mensajes y estados sin contarlos como avisos',async()=>{
    await mute(A);await mute(B);
    const conv=await accept();await send(conv);
    assert.equal((await notices(A)).length,2);assert.equal((await notices(B)).length,1);
    assert.ok((await notices(A)).every(n=>!n.alert_enabled&&n.read_at===null));
    assert.equal((await as(A,'select count(*)::int c from public.notifications where read_at is null and alert_enabled'))[0].c,0);
  });
  await test('categorías independientes y cambios de preferencia solo para eventos futuros',async()=>{
    await mute(A,false,true,false);await request();const first=(await notices(A))[0];
    assert.equal(first.alert_enabled,false);await manage(A,'accept');
    const conv=(await as(B,'select id from public.recovery_conversations'))[0].id;await send(conv);
    assert.equal((await notices(A)).find(n=>n.kind==='private_message').alert_enabled,true);
    await mute(A,true,true,true);assert.equal((await notices(A)).find(n=>n.id===first.id).alert_enabled,false);
  });
  await test('marcar leído es privado, idempotente y la fecha la fija el servidor',async()=>{
    await request();const id=(await notices(A))[0].id;
    await as(B,`select public.encuentralo_read_notifications('${B}','${id}')`);
    assert.equal((await notices(A))[0].read_at,null);
    await denied(()=>as(B,`select public.encuentralo_read_notifications('${A}','${id}')`));
    await as(A,`select public.encuentralo_read_notifications('${A}','${id}')`);const first=(await notices(A))[0].read_at;
    assert.ok(first);await as(A,`select public.encuentralo_read_notifications('${A}','${id}')`);
    assert.equal((await notices(A))[0].read_at.getTime(),first.getTime());
  });
  await test('marcar todo usa límite temporal y no toca otros usuarios o eventos posteriores',async()=>{
    await request();const before=(await notices(A))[0].created_at.toISOString();
    await request(C,S);await manage(A,'accept');
    await as(A,`select public.encuentralo_read_notifications('${A}',null,'${before}')`);
    const rows=await notices(A);assert.ok(rows[0].read_at);assert.equal(rows[1].read_at,null);
    assert.equal((await notices(B))[0].read_at,null);
    await denied(()=>as(A,`select public.encuentralo_read_notifications('${A}')`),'22023');
  });
  await test('tutorial omitido o terminado persiste sin sobrescribir preferencias',async()=>{
    await mute(A);await as(A,`select public.encuentralo_complete_tutorial('${A}')`);
    await as(A,`select public.encuentralo_complete_tutorial('${A}')`);
    let p=(await as(A,'select * from public.notification_preferences'))[0];
    assert.equal(p.tutorial_version,1);assert.equal(p.private_messages,false);
    await mute(A,true,true,true);p=(await as(A,'select * from public.notification_preferences'))[0];assert.equal(p.tutorial_version,1);
  });
  await test('ambas confirmaciones notifican devolución final a A y B una sola vez',async()=>{
    await accept();await request(C,S);await manage(A,'confirm',2);await manage(B,'confirm',3);await manage(B,'confirm',3);
    for(const uid of [A,B]) assert.equal((await notices(uid)).filter(n=>n.kind==='return_confirmed').length,1);
    assert.equal((await notices(C)).filter(n=>n.kind==='publication_changed').length,1);
    assert.equal((await notices(B)).filter(n=>n.title==='Entrega confirmada por el encontrador').length,1);
  });
  for(const [update,title] of [["status='withdrawn'",'Publicación retirada'],["custody='prefecture'",'Entrega declarada a Prefectura']]) {
    await test(`${title}: cierre genera aviso persistente consultable sin acceso público al hallazgo`,async()=>{
      await accept();await as(A,`update public.found_items set ${update} where id='${ITEM}'`);
      const rows=await notices(B);assert.equal(rows.filter(n=>n.title===title).length,1);
      assert.equal(rows.find(n=>n.title===title).kind,'publication_changed');
    });
  }
  await test('edición relevante notifica al solicitante activo; no-op y metadatos no duplican',async()=>{
    await request();await as(A,`update public.found_items set title='Termo corregido' where id='${ITEM}'`);
    await as(A,`update public.found_items set title='Termo corregido' where id='${ITEM}'`);
    const rows=await notices(B);assert.equal(rows.length,1);assert.equal(rows[0].kind,'publication_changed');assert.equal(rows[0].item_id,ITEM);
    assert.equal((await as(C,`update public.found_items set title='Edición ajena' where id='${ITEM}' returning 1`)).length,0);
    assert.equal((await notices(B)).length,1);
  });
  await test('funciones definer con search_path vacío y helpers privados sin EXECUTE',async()=>{
    const rows=(await db.query(`select p.proname,p.proconfig,p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where (n.nspname='encuentralo_private' and p.proname like '%notif%') or (n.nspname='public' and p.proname in ('encuentralo_read_notifications','encuentralo_complete_tutorial','encuentralo_save_notification_preferences'))`)).rows;
    assert.ok(rows.length>=7);for(const row of rows) {assert.equal(row.prosecdef,true);assert.ok(row.proconfig.some(s=>s==='search_path=""'));}
  });
  const manual=(await readFile(new URL('../../supabase/verify_notifications.sql',import.meta.url),'utf8'))
    .replace(/(set_config\('notifications\.test_a',)'[^']*'/,`$1'${A}'`)
    .replace(/(set_config\('notifications\.test_b',)'[^']*'/,`$1'${B}'`)
    .replace(/(set_config\('notifications\.test_c',)'[^']*'/,`$1'${C}'`);
  await db.exec(manual);passed++;console.log('PASS script manual de notificaciones A/B/C con rollback');
  console.log(`${passed} pruebas PostgreSQL Fase 5 aprobadas. Solo entorno local; no prueba WebSocket remoto.`);
} finally {await db.close();}
