-- REVISAR Y EJECUTAR MANUALMENTE después de ambas migraciones de fase 3.
-- Primero: inspección de estructura. El SQL Editor como postgres omite RLS.
select c.relname, c.relrowsecurity from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='found_items';
select schemaname,tablename,policyname,roles,cmd,qual,with_check
from pg_policies where (schemaname='public' and tablename='found_items')
or (schemaname='storage' and tablename='objects' and policyname like 'found_photos_%');
select grantee,privilege_type,column_name from information_schema.column_privileges
where table_schema='public' and table_name='found_items' and grantee in ('anon','authenticated')
order by grantee,privilege_type,column_name;
select id,public,file_size_limit,allowed_mime_types from storage.buckets where id='found-item-photos';

-- Sustituye A y B por UUID de DOS cuentas existentes y confirmadas en Auth.
-- Este bloque crea filas temporales de prueba, comprueba RLS como authenticated
-- y revierte TODO. Si se interrumpe, ejecuta ROLLBACK antes de continuar.
begin;
select set_config('encuentralo.test_a','REEMPLAZA_UUID_A',true);
select set_config('encuentralo.test_b','REEMPLAZA_UUID_B',true);
do $$ begin
  if current_setting('encuentralo.test_a')::uuid = current_setting('encuentralo.test_b')::uuid then
    raise exception 'Usa dos cuentas distintas.';
  end if;
  if (select count(*) from auth.users where id in (current_setting('encuentralo.test_a')::uuid,current_setting('encuentralo.test_b')::uuid)) <> 2 then
    raise exception 'Ambos UUID deben existir en Auth.';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('encuentralo.test_a'),true);
insert into public.found_items(id,title,category,description,found_on,zone,custody)
values ('00000000-0000-4000-8000-000000001001','Prueba RLS A','other','Publicación temporal de prueba A',current_date-1,'Biblioteca','student');

select set_config('request.jwt.claim.sub',current_setting('encuentralo.test_b'),true);
insert into public.found_items(id,title,category,description,found_on,zone,custody)
values ('00000000-0000-4000-8000-000000001002','Prueba RLS B','other','Publicación temporal de prueba B',current_date-1,'Biblioteca','student');
do $$ declare affected integer; begin
  if (select count(*) from public.found_items where id in ('00000000-0000-4000-8000-000000001001','00000000-0000-4000-8000-000000001002')) <> 2 then
    raise exception 'FALLO: B no puede leer las dos publicaciones visibles.';
  end if;
  update public.found_items set title='Cambio ajeno' where id='00000000-0000-4000-8000-000000001001';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'FALLO: B modificó una publicación de A.'; end if;
end $$;

select set_config('request.jwt.claim.sub',current_setting('encuentralo.test_a'),true);
do $$ begin
  begin
    update public.found_items set finder_id=current_setting('encuentralo.test_b')::uuid where id='00000000-0000-4000-8000-000000001001';
    raise exception 'FALLO: fue posible cambiar autoría.';
  exception when insufficient_privilege then raise notice 'OK: autoría protegida.';
  end;
  begin
    update public.found_items set status='returned' where id='00000000-0000-4000-8000-000000001001';
    raise exception 'FALLO: fue posible confirmar devolución como alumno.';
  exception when insufficient_privilege then raise notice 'OK: confirmación de devolución protegida.';
  end;
  begin
    delete from public.found_items where id='00000000-0000-4000-8000-000000001001';
    raise exception 'FALLO: DELETE concedido al alumno.';
  exception when insufficient_privilege then raise notice 'OK: sin DELETE.';
  end;
end $$;
update public.found_items set custody='prefecture' where id='00000000-0000-4000-8000-000000001001';
do $$ begin
  if (select status from public.found_items where id='00000000-0000-4000-8000-000000001001') <> 'active' then
    raise exception 'FALLO: declarar Prefectura cambió el estado de publicación.';
  end if;
  begin
    update public.found_items set custody='student' where id='00000000-0000-4000-8000-000000001001';
    raise exception 'FALLO: se revirtió Prefectura.';
  exception when insufficient_privilege then raise notice 'OK: entrega declarada no reversible.';
  end;
end $$;
update public.found_items set status='withdrawn' where id='00000000-0000-4000-8000-000000001001';
select set_config('request.jwt.claim.sub',current_setting('encuentralo.test_b'),true);
do $$ begin
  if exists(select 1 from public.found_items where id='00000000-0000-4000-8000-000000001001') then
    raise exception 'FALLO: B ve una publicación retirada de A.';
  end if;
end $$;
-- Solo como servidor se simula el estado futuro. No se concede RPC al alumno.
reset role;
update public.found_items set status='returned' where id='00000000-0000-4000-8000-000000001001';
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('encuentralo.test_a'),true);
do $$ declare affected integer; begin
  update public.found_items set status='active' where id='00000000-0000-4000-8000-000000001001';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'FALLO: se reactivó una devolución confirmada.'; end if;
end $$;
reset role;
set local role anon;
do $$ begin
  begin
    perform 1 from public.found_items;
    raise exception 'FALLO: anon pudo consultar publicaciones.';
  exception when insufficient_privilege then raise notice 'OK: anon sin acceso al catálogo.';
  end;
end $$;
rollback;
