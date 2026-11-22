import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const A='aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa', B='bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb', C='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const ITEM='11111111-1111-4111-8111-111111111111', PREF='22222222-2222-4222-8222-222222222222';
const R='33333333-3333-4333-8333-333333333333', S='44444444-4444-4444-8444-444444444444', M='55555555-5555-4555-8555-555555555555';
const evidence='Marca privada dentro de la tapa del termo';
let passed=0;
async function as(uid,sql) {
  await db.exec(`reset role; set local role ${uid ? 'authenticated' : 'anon'}; select set_config('request.jwt.claim.sub','${uid ?? ''}',true)`);
  return db.query(sql);
}
async function request(uid=B,id=R,item=ITEM) {
  return (await as(uid,`select public.encuentralo_request_recovery('${uid ?? B}','${id}','${item}','${evidence}') as result`)).rows[0].result;
}
async function manage(uid,action,id=R,version=1,extra='') {
  return (await as(uid,`select public.encuentralo_manage_recovery('${uid}','${id}','${action}',${version}${extra}) as result`)).rows[0].result;
}
async function denied(action,code='42501') {
  await db.exec('savepoint denial');
  await assert.rejects(action,error=>error.code===code);
  await db.exec('rollback to savepoint denial; release savepoint denial');
}
async function conversation() { return (await db.query(`select id from public.recovery_conversations where request_id='${R}'`)).rows[0].id; }
async function send(uid,conv,id=M,body='Mi mensaje privado de prueba') {
  return (await as(uid,`select public.encuentralo_send_message('${uid}','${id}','${conv}','${body}') as result`)).rows[0].result;
}
async function test(name,action) {
  await db.exec('begin');
  try { await action(); passed++; console.log(`PASS ${name}`); }
  finally { await db.exec('rollback'); }
}
try {
  await db.exec(`create role anon nologin; create role authenticated nologin;
    create schema auth; create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema public,auth to anon,authenticated; grant execute on function auth.uid() to anon,authenticated;
    insert into auth.users values('${A}'),('${B}'),('${C}');`);
  for(const file of ['202611180001_create_found_items.sql','202611210001_recovery_requests_chat.sql']) {
    await db.exec(await readFile(new URL(`../../supabase/migrations/${file}`,import.meta.url),'utf8'));
  }
  await db.exec(`insert into public.found_items(id,finder_id,title,category,description,found_on,zone,custody) values
    ('${ITEM}','${A}','Termo azul','bottles','Termo azul de prueba',current_date-1,'Biblioteca','student'),
    ('${PREF}','${A}','Llaves rojas','keys','Llaves de prueba',current_date-1,'Explanada','prefecture')`);
  await test('RLS activado y sin escritura directa en las seis tablas privadas',async()=>{
    for(const table of ['recovery_requests','recovery_conversations','recovery_messages','recovery_events','recovery_blocks','recovery_abuse_reports']) {
      assert.equal((await db.query(`select relrowsecurity from pg_class where oid='public.${table}'::regclass`)).rows[0].relrowsecurity,true);
      await denied(()=>as(B,`delete from public.${table}`));
      await denied(()=>as(B,`update public.${table} set created_at=now()`));
      await denied(()=>as(null,`select * from public.${table}`));
    }
  });
  await test('B y C crean solicitudes independientes; evidencia solo para participantes',async()=>{
    await request(); await request(C,S);
    assert.equal((await as(A,'select * from public.recovery_requests')).rows.length,2);
    const b=(await as(B,'select * from public.recovery_requests')).rows;
    assert.equal(b.length,1); assert.equal(b[0].id,R); assert.equal(b[0].evidence,evidence);
    assert.equal((await as(C,`select * from public.recovery_requests where id='${R}'`)).rows.length,0);
    assert.equal((await as(C,`select * from public.recovery_events where request_id='${R}'`)).rows.length,0);
  });
  await test('rechaza solicitud propia, Prefectura, evidencia corta y anon',async()=>{
    await denied(()=>request(A)); await denied(()=>request(B,R,PREF),'P0001');
    await denied(()=>as(B,`select public.encuentralo_request_recovery('${B}','${R}','${ITEM}','corta')`),'23514');
    await denied(()=>request(null));
  });
  await test('rechaza publicaciones retiradas y devueltas',async()=>{
    await db.exec(`update public.found_items set status='withdrawn' where id='${ITEM}'`);
    await denied(()=>request(),'P0001');
    await db.exec(`reset role; update public.found_items set status='returned' where id='${ITEM}'`);
    await denied(()=>request(),'P0001');
  });
  await test('UUID estable idempotente y una solicitud activa por usuario/objeto',async()=>{
    const first=await request(); assert.deepEqual(await request(),first);
    await denied(()=>request(B,S),'23505'); await denied(()=>request(C,R));
    assert.equal((await as(A,'select * from public.recovery_events')).rows.length,1);
  });
  await test('rechazo y cancelación son terminales y limitan repetición',async()=>{
    await request(); await manage(A,'reject');
    await denied(()=>manage(A,'accept',R,2),'P0001');
    await denied(()=>request(B,S),'P0001');
  });
  await test('solo encontrador acepta/rechaza; solicitante cancela; C no actúa',async()=>{
    await request();
    await denied(()=>manage(B,'accept')); await denied(()=>manage(C,'reject')); await denied(()=>manage(A,'cancel'));
    assert.equal((await manage(B,'cancel')).status,'cancelled');
    assert.equal((await manage(B,'cancel')).status,'cancelled');
  });
  await test('sin chat pendiente; aceptación crea solo una conversación',async()=>{
    await request(); assert.equal((await as(B,'select * from public.recovery_conversations')).rows.length,0);
    await manage(A,'accept'); await manage(A,'accept');
    assert.equal((await as(B,'select * from public.recovery_conversations')).rows.length,1);
    assert.equal((await as(C,'select * from public.recovery_conversations')).rows.length,0);
  });
  await test('mensajes A/B privados, idempotentes, sin suplantación ni acceso de C',async()=>{
    await request(); await manage(A,'accept'); const conv=await conversation();
    const msg=await send(B,conv); assert.equal(msg.sender_id,B); assert.deepEqual(await send(B,conv),msg);
    await send(A,conv,S,'Respuesta del encontrador');
    assert.equal((await as(B,'select * from public.recovery_messages')).rows.length,2);
    assert.equal((await as(C,'select * from public.recovery_messages')).rows.length,0);
    await denied(()=>send(C,conv)); await denied(()=>send(A,conv,M));
    await denied(()=>as(B,`insert into public.recovery_messages(id,conversation_id,sender_id,body) values('${R}','${conv}','${A}','suplantación')`));
  });
  await test('mensajes validan longitud y limitan envío repetido',async()=>{
    await request(); await manage(A,'accept'); const conv=await conversation();
    await denied(()=>send(B,conv,M,''),'23514'); await send(B,conv);
    await denied(()=>send(B,conv,S,'Segundo mensaje inmediato'),'P0001');
  });
  await test('una confirmación no resuelve; dos confirman y cierran otras solicitudes',async()=>{
    await request(); await request(C,S); await manage(A,'accept'); await manage(A,'accept',S);
    let r=await manage(A,'confirm',R,2); assert.equal(r.status,'accepted');
    assert.equal((await as(B,`select status from public.found_items where id='${ITEM}'`)).rows[0].status,'active');
    await denied(()=>manage(B,'confirm',R,2),'40001');
    r=await manage(B,'confirm',R,3); assert.equal(r.close_reason,'returned');
    assert.deepEqual(await manage(B,'confirm',R,3),r);
    assert.equal((await as(A,`select status from public.found_items where id='${ITEM}'`)).rows[0].status,'returned');
    assert.equal((await as(C,`select close_reason from public.recovery_requests where id='${S}'`)).rows[0].close_reason,'item_returned');
    assert.equal((await as(B,'select * from public.recovery_messages')).rows.length,0);
    await denied(()=>request(C,M),'P0001');
  });
  await test('tercero no confirma y cliente no marca returned directamente',async()=>{
    await request(); await manage(A,'accept');
    await denied(()=>manage(C,'confirm',R,2));
    await denied(()=>as(A,`update public.found_items set status='returned' where id='${ITEM}'`));
    await denied(()=>as(B,`update public.recovery_requests set status='closed' where id='${R}'`));
  });
  for(const [change,reason] of [["custody='prefecture'",'prefecture'],["status='withdrawn'",'item_withdrawn']]) {
    await test(`${reason} cierra solicitudes y chat sin permitir mensajes posteriores`,async()=>{
      await request(); await manage(A,'accept'); const conv=await conversation(); await send(B,conv);
      await as(A,`update public.found_items set ${change} where id='${ITEM}'`);
      const r=(await as(B,`select * from public.recovery_requests where id='${R}'`)).rows[0];
      assert.equal(r.status,'closed'); assert.equal(r.close_reason,reason);
      assert.equal((await as(B,'select * from public.recovery_messages')).rows.length,0);
      await denied(()=>send(B,conv,S)); await denied(()=>manage(B,'confirm',R,r.version),'P0001');
    });
  }
  await test('acuerdo privado, versión obsoleta y acuerdo congelado al confirmar',async()=>{
    await request(); await manage(A,'accept');
    await denied(()=>manage(B,'meeting',R,2,",'Fuera del campus',clock_timestamp()+interval '1 day'"),'P0001');
    const extra=",'Explanada',clock_timestamp()+interval '1 day'";
    const r=await manage(B,'meeting',R,2,extra); assert.equal(r.meeting_point,'Explanada');
    await denied(()=>manage(A,'meeting',R,2,extra),'40001');
    await manage(A,'confirm',R,3);
    await denied(()=>manage(B,'meeting',R,4,extra),'P0001');
    await denied(()=>manage(B,'cancel',R,4));
  });
  await test('bloqueo cierra, impide contacto y solo bloqueador puede consultar/desbloquear',async()=>{
    await request(); await manage(A,'accept'); const conv=await conversation();
    await as(B,`select public.encuentralo_block_user('${B}','${A}',true)`);
    assert.equal((await as(B,'select * from public.recovery_blocks')).rows.length,1);
    assert.equal((await as(A,'select * from public.recovery_blocks')).rows.length,0);
    await denied(()=>send(A,conv)); await denied(()=>request(B,S));
    await as(A,`select public.encuentralo_block_user('${A}','${B}',false)`);
    assert.equal((await as(B,'select * from public.recovery_blocks')).rows.length,1);
    await as(B,`select public.encuentralo_block_user('${B}','${A}',false)`);
    assert.equal((await as(B,'select * from public.recovery_blocks')).rows.length,0);
  });
  await test('reporte de abuso privado, idempotente y restringido a participantes',async()=>{
    await request();
    await as(B,`select public.encuentralo_report_abuse('${B}','${M}','${R}','Mensaje intimidante de prueba')`);
    await as(B,`select public.encuentralo_report_abuse('${B}','${M}','${R}','Mensaje intimidante de prueba')`);
    assert.equal((await as(B,'select * from public.recovery_abuse_reports')).rows.length,1);
    assert.equal((await as(A,'select * from public.recovery_abuse_reports')).rows.length,0);
    await denied(()=>as(C,`select public.encuentralo_report_abuse('${C}','${S}','${R}','Reporte de usuario ajeno')`));
  });
  await test('actor de origen obligatorio: cambio de cuenta no envía evidencia, acciones o mensajes',async()=>{
    await denied(()=>as(C,`select public.encuentralo_request_recovery('${B}','${R}','${ITEM}','${evidence}')`));
    await request(); await manage(A,'accept'); const conv=await conversation();
    await denied(()=>as(B,`select public.encuentralo_manage_recovery('${A}','${R}','confirm',2)`));
    await denied(()=>as(B,`select public.encuentralo_manage_recovery('${B}','${R}','confirm',null)`),'40001');
    await denied(()=>as(B,`select public.encuentralo_send_message('${A}','${M}','${conv}','mensaje suplantado')`));
    await denied(()=>as(B,`select public.encuentralo_block_user('${A}','${B}',true)`));
    await denied(()=>as(B,`select public.encuentralo_report_abuse('${A}','${M}','${R}','reporte suplantado')`));
  });
  await test('máximo diez solicitudes al día incluso sobre distintos hallazgos',async()=>{
    for(let i=0;i<11;i++) {
      const item=`77777777-7777-4777-8777-${String(i).padStart(12,'0')}`;
      const req=`88888888-8888-4888-8888-${String(i).padStart(12,'0')}`;
      await db.exec(`reset role; insert into public.found_items(id,finder_id,title,category,description,found_on,zone,custody)
        values('${item}','${A}','Termo de prueba','bottles','Termo azul de prueba',current_date-1,'Biblioteca','student')`);
      if(i<10) await request(B,req,item); else await denied(()=>request(B,req,item),'P0001');
    }
  });
  await test('máximo tres intentos por hallazgo aunque transcurran 24 horas',async()=>{
    for(let i=0;i<3;i++) {
      const req=`88888888-8888-4888-8888-${String(i).padStart(12,'0')}`;
      await request(B,req); await manage(B,'cancel',req);
      await db.exec(`reset role; update public.recovery_requests set created_at=created_at-interval '2 days' where id='${req}'`);
    }
    await denied(()=>request(B,R),'P0001');
  });
  const manual=(await readFile(new URL('../../supabase/verify_recovery.sql',import.meta.url),'utf8'))
    // Usa siempre fixtures locales, incluso si el usuario personalizó el script.
    .replace(/(set_config\('recovery\.test_a',)'[^']*'/,`$1'${A}'`)
    .replace(/(set_config\('recovery\.test_b',)'[^']*'/,`$1'${B}'`)
    .replace(/(set_config\('recovery\.test_c',)'[^']*'/,`$1'${C}'`);
  await db.exec(manual); passed++;
  console.log('PASS script SQL manual A/B/C con rollback');
  console.log(`${passed} pruebas PostgreSQL Fase 4 aprobadas. Local en memoria; no prueba HTTP/Realtime remoto ni concurrencia de conexiones reales.`);
} finally { await db.close(); }
