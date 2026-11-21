// PostgreSQL en memoria: no usa red, credenciales ni el Supabase del usuario.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const db = new PGlite();
const A = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const B = 'bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';
const ITEM = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const RETIRED = '33333333-3333-4333-8333-333333333333';
const RETURNED = '44444444-4444-4444-8444-444444444444';
const PHOTO = `${A}/${ITEM}/55555555-5555-4555-8555-555555555555.jpg`;
let passed = 0;
try {
  await db.exec(`
    create role anon nologin; create role authenticated nologin;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema public,auth,storage to anon,authenticated;
    grant execute on function auth.uid() to authenticated,anon;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text,unique(bucket_id,name));
    alter table storage.objects enable row level security;
    grant select,insert,update,delete on storage.objects to authenticated;
    grant select on storage.objects to anon;
    -- Una política heredada amplia NO debe abrir el nuevo bucket privado.
    create policy legacy_broad_storage_policy on storage.objects for all
      to authenticated,anon using(true) with check(true);
    create function storage.foldername(text) returns text[] language sql immutable as
      $$ select (string_to_array($1,'/'))[1:array_length(string_to_array($1,'/'),1)-1] $$;
    insert into auth.users values ('${A}'),('${B}');
  `);
  for (const filename of ['202611180001_create_found_items.sql','202611180002_found_item_photos.sql']) {
    await db.exec(await readFile(new URL(`../../supabase/migrations/${filename}`,import.meta.url),'utf8'));
  }
  await db.exec(`insert into public.found_items(id,finder_id,title,category,description,found_on,zone,custody,status) values
    ('${ITEM}','${A}','Termo azul','bottles','Termo azul de prueba',current_date-1,'Biblioteca','student','active'),
    ('${OTHER}','${B}','Llaves rojas','keys','Llaves rojas de prueba',current_date-1,'Edificio 1','student','active'),
    ('${RETIRED}','${A}','Termo retirado','bottles','Termo azul retirado',current_date-1,'Biblioteca','student','withdrawn'),
    ('${RETURNED}','${A}','Termo devuelto','bottles','Termo azul devuelto',current_date-1,'Biblioteca','student','returned');
    insert into storage.objects(bucket_id,name) values ('found-item-photos','${PHOTO}');
    update public.found_items set photo_path='${PHOTO}' where id='${ITEM}';`);

  async function test(name,uid,action,role='authenticated') {
    await db.exec(`begin; set local role ${role}; select set_config('request.jwt.claim.sub','${uid}',true);`);
    try { await action(); passed++; console.log(`PASS ${name}`); }
    finally { await db.exec('rollback'); }
  }
  async function denied(sql,code='42501') {
    await assert.rejects(db.exec(sql),error => error.code === code);
  }
  async function rows(sql,count) { assert.equal((await db.query(sql)).rows.length,count); }
  const insertion = `insert into public.found_items(title,category,description,found_on,zone,custody)
    values ('Nuevo termo','bottles','Termo nuevo de prueba',current_date-1,'Biblioteca','student') returning finder_id`;
  const bucket = (await db.query(`select * from storage.buckets where id='found-item-photos'`)).rows[0];
  assert.equal(bucket.public,false);
  assert.equal(Number(bucket.file_size_limit),3145728);
  assert.deepEqual(bucket.allowed_mime_types,['image/jpeg','image/png','image/webp']);
  passed++;
  console.log('PASS bucket privado con límite de 3 MiB y MIME JPEG/PNG/WebP');
  await test('A ve catálogo y sus estados privados',A,() => rows('select * from public.found_items',4));
  await test('B no ve retiradas ni devueltas de A',B,() => rows('select * from public.found_items',2));
  await test('autor lo fija auth.uid',A,async () => assert.equal((await db.query(insertion)).rows[0].finder_id,A));
  await test('sin SELECT para anon','',() => denied('select * from public.found_items'),'anon');
  await test('sin INSERT para anon','',() => denied(insertion),'anon');
  await test('B no edita publicación de A',B,() => rows(`update public.found_items set title='Título ajeno' where id='${ITEM}' returning id`,0));
  await test('B no retira publicación de A',B,() => rows(`update public.found_items set status='withdrawn' where id='${ITEM}' returning id`,0));
  await test('Mis hallazgos de B incluye solo sus publicaciones',B,async () => {
    const mine = (await db.query(`select * from public.found_items where finder_id=auth.uid()`)).rows;
    assert.equal(mine.length,1);
    assert.ok(mine.every(item => item.finder_id === B));
  });
  await test('no puede asignar autor al crear',A,() => denied(`insert into public.found_items(finder_id,title,category,description,found_on,zone,custody) values ('${B}','Otro termo','bottles','Descripción de prueba',current_date-1,'Biblioteca','student')`));
  await test('no puede alterar propiedad',A,() => denied(`update public.found_items set finder_id='${B}' where id='${ITEM}'`));
  await test('no puede alterar fechas de auditoría',A,() => denied(`update public.found_items set created_at=now()-interval '2 days' where id='${ITEM}'`));
  await test('no puede crear devolución confirmada',A,() => denied(`insert into public.found_items(title,category,description,found_on,zone,custody,status) values ('Otro termo','bottles','Descripción de prueba',current_date-1,'Biblioteca','student','returned')`));
  await test('no puede confirmar devolución',A,() => denied(`update public.found_items set status='returned' where id='${ITEM}'`));
  await test('no reactiva devolución confirmada',A,() => rows(`update public.found_items set status='active' where id='${RETURNED}' returning id`,0));
  await test('no reactiva retirada',A,() => rows(`update public.found_items set status='active' where id='${RETIRED}' returning id`,0));
  await test('no DELETE de publicaciones',A,() => denied(`delete from public.found_items where id='${ITEM}'`));
  await test('custodia solo alumno o Prefectura',A,() => denied(`update public.found_items set custody='Gobierno' where id='${ITEM}'`,'23514'));
  await test('rechaza categoría inválida',A,() => denied(`update public.found_items set category='inventada' where id='${ITEM}'`,'23514'));
  await test('rechaza fecha futura',A,() => denied(`update public.found_items set found_on=current_date+1 where id='${ITEM}'`,'23514'));
  await test('rechaza ruta de foto ajena',A,() => denied(`update public.found_items set photo_path='${B}/${ITEM}/55555555-5555-4555-8555-555555555555.jpg' where id='${ITEM}'`,'23514'));
  await test('Prefectura conserva estado activo y bloquea reversión',A,async () => {
    const changed = await db.query(`update public.found_items set custody='prefecture' where id='${ITEM}' returning status`);
    assert.equal(changed.rows[0].status,'active');
    await denied(`update public.found_items set custody='student' where id='${ITEM}'`);
  });
  await test('B puede leer la foto vinculada visible',B,() => rows('select * from storage.objects',1));
  await test('anon no lee fotos privadas','',() => rows('select * from storage.objects',0),'anon');
  await test('B no sube a carpeta ajena',B,() => denied(`insert into storage.objects(bucket_id,name) values ('found-item-photos','${A}/${OTHER}/66666666-6666-4666-8666-666666666666.jpg')`));
  await test('A sube y consulta una foto provisional propia',A,async () => {
    const path = `${A}/${ITEM}/66666666-6666-4666-8666-666666666666.webp`;
    await rows(`insert into storage.objects(bucket_id,name) values ('found-item-photos','${path}') returning id`,1);
    await rows(`select * from storage.objects where name='${path}'`,1);
  });
  await test('A no sube extensiones fuera del modelo',A,() => denied(`insert into storage.objects(bucket_id,name) values ('found-item-photos','${A}/${ITEM}/66666666-6666-4666-8666-666666666666.svg')`));
  await test('B no sobrescribe una foto de A',B,() => rows(`update storage.objects set name=name where name='${PHOTO}' returning id`,0));
  await test('B no elimina una foto de A aunque esté desvinculada',A,async () => {
    await db.exec(`update public.found_items set photo_path=null where id='${ITEM}'; select set_config('request.jwt.claim.sub','${B}',true)`);
    await rows(`delete from storage.objects where name='${PHOTO}' returning id`,0);
  });
  await test('restricciones no bloquean otros buckets',B,async () => {
    // La política heredada de la preparación permite este bucket independiente.
    // La restricción de Fase 3 debe limitarse a found-item-photos.
    await db.exec('reset role');
    await db.exec(`insert into storage.buckets(id,name,public) values ('unrelated','unrelated',false); set local role authenticated`);
    await rows(`insert into storage.objects(bucket_id,name) values ('unrelated','legacy.png') returning id`,1);
  });
  await test('ningún cliente sobrescribe fotos',A,() => rows(`update storage.objects set name=name where name='${PHOTO}' returning id`,0));
  await test('no elimina foto vinculada',A,() => rows(`delete from storage.objects where name='${PHOTO}' returning id`,0));
  await test('elimina foto propia después de desvincular',A,async () => {
    await db.exec(`update public.found_items set photo_path=null where id='${ITEM}'`);
    await rows(`delete from storage.objects where name='${PHOTO}' returning id`,1);
  });
  await test('foto provisional no aparece a B',A,async () => {
    const path = `${A}/${ITEM}/66666666-6666-4666-8666-666666666666.png`;
    await db.exec(`insert into storage.objects(bucket_id,name) values ('found-item-photos','${path}'); select set_config('request.jwt.claim.sub','${B}',true)`);
    await rows(`select * from storage.objects where name='${path}'`,0);
  });
  await test('retirar oculta publicación y foto a B',A,async () => {
    await db.exec(`update public.found_items set status='withdrawn' where id='${ITEM}'; select set_config('request.jwt.claim.sub','${B}',true)`);
    await rows(`select * from public.found_items where id='${ITEM}'`,0);
    await rows(`select * from storage.objects where name='${PHOTO}'`,0);
  });
  const manualVerification = (await readFile(new URL('../../supabase/verify_found_items.sql',import.meta.url),'utf8'))
    .replaceAll('REEMPLAZA_UUID_A',A).replaceAll('REEMPLAZA_UUID_B',B);
  await db.exec(manualVerification);
  passed++;
  console.log('PASS script de verificación manual con dos identidades y rollback');
  console.log(`${passed} pruebas PostgreSQL aprobadas. Entorno local en memoria; no verifica Storage HTTP remoto.`);
} finally { await db.close(); }
