-- REVISAR. Primera parte de solo lectura; ejecutar como postgres en SQL Editor.
select c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname like 'recovery_%' order by c.relname;
select schemaname,tablename,policyname,roles,cmd,qual,with_check from pg_policies
where schemaname='public' and tablename like 'recovery_%' order by tablename,policyname;
select grantee,table_name,privilege_type from information_schema.role_table_grants
where table_schema='public' and table_name like 'recovery_%' and grantee in ('anon','authenticated');
select p.proname,p.prosecdef,p.proconfig,p.proacl from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','encuentralo_private') and (p.proname like 'encuentralo_%recovery' or p.proname in ('encuentralo_send_message','encuentralo_block_user','encuentralo_report_abuse','participant','can_chat','close_unavailable'));
select pubname,schemaname,tablename from pg_publication_tables
where pubname='supabase_realtime' and tablename like 'recovery_%';

-- Sustituye los tres UUID por cuentas existentes, confirmadas y distintas.
-- Simula identidades authenticated para probar RLS; no basta usar postgres.
-- TODO se revierte. Si ocurre un error o se interrumpe, ejecuta ROLLBACK.
begin;
select set_config('recovery.test_a','REEMPLAZA_UUID_A',true);
select set_config('recovery.test_b','REEMPLAZA_UUID_B',true);
select set_config('recovery.test_c','REEMPLAZA_UUID_C',true);
do $$ begin
  if (select count(distinct id) from auth.users where id in (current_setting('recovery.test_a')::uuid,
    current_setting('recovery.test_b')::uuid,current_setting('recovery.test_c')::uuid))<>3 then
    raise exception 'Usa tres UUID diferentes que existan en Auth.';
  end if;
end $$;
select set_config('recovery.item',gen_random_uuid()::text,true);
select set_config('recovery.prefecture',gen_random_uuid()::text,true);
select set_config('recovery.request_b',gen_random_uuid()::text,true);
select set_config('recovery.request_c',gen_random_uuid()::text,true);
insert into public.found_items(id,finder_id,title,category,description,found_on,zone,custody) values
  (current_setting('recovery.item')::uuid,current_setting('recovery.test_a')::uuid,'Prueba recuperación','other','Hallazgo sintético para prueba con rollback',current_date-1,'Explanada','student'),
  (current_setting('recovery.prefecture')::uuid,current_setting('recovery.test_a')::uuid,'Prueba Prefectura','other','Hallazgo sintético en Prefectura con rollback',current_date-1,'Biblioteca','prefecture');

set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('recovery.test_b'),true);
do $$ begin
  perform public.encuentralo_request_recovery(auth.uid(),current_setting('recovery.request_b')::uuid,
    current_setting('recovery.item')::uuid,'Característica sintética privada de B');
  begin
    perform public.encuentralo_request_recovery(auth.uid(),gen_random_uuid(),current_setting('recovery.prefecture')::uuid,'Característica sintética de Prefectura');
    raise exception 'FALLO: Prefectura admitió solicitud.';
  exception when raise_exception then
    if sqlerrm<>'El hallazgo ya no admite solicitudes.' then raise; end if;
  end;
end $$;
select set_config('request.jwt.claim.sub',current_setting('recovery.test_c'),true);
do $$ begin
  perform public.encuentralo_request_recovery(auth.uid(),current_setting('recovery.request_c')::uuid,
    current_setting('recovery.item')::uuid,'Característica sintética privada de C');
  if exists(select 1 from public.recovery_requests where id=current_setting('recovery.request_b')::uuid) then
    raise exception 'FALLO: C leyó evidencia de B.';
  end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('recovery.test_a'),true);
do $$ begin
  if (select count(*) from public.recovery_requests where item_id=current_setting('recovery.item')::uuid)<>2 then
    raise exception 'FALLO: A no puede revisar ambas solicitudes.';
  end if;
  perform public.encuentralo_manage_recovery(auth.uid(),current_setting('recovery.request_b')::uuid,'accept',1);
end $$;
select set_config('recovery.conversation',(select id::text from public.recovery_conversations where request_id=current_setting('recovery.request_b')::uuid),true);
do $$ begin
  perform public.encuentralo_send_message(auth.uid(),gen_random_uuid(),current_setting('recovery.conversation')::uuid,'Mensaje sintético de A');
end $$;
select set_config('request.jwt.claim.sub',current_setting('recovery.test_b'),true);
do $$ begin
  perform public.encuentralo_send_message(auth.uid(),gen_random_uuid(),current_setting('recovery.conversation')::uuid,'Mensaje sintético de B');
  if (select count(*) from public.recovery_messages where conversation_id=current_setting('recovery.conversation')::uuid)<>2 then
    raise exception 'FALLO: B no puede leer la conversación compartida.';
  end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('recovery.test_c'),true);
do $$ begin
  if exists(select 1 from public.recovery_messages where conversation_id=current_setting('recovery.conversation')::uuid) then
    raise exception 'FALLO: C leyó mensajes de A/B.';
  end if;
  begin
    perform public.encuentralo_send_message(auth.uid(),gen_random_uuid(),current_setting('recovery.conversation')::uuid,'Mensaje ajeno');
    raise exception 'FALLO: C envió un mensaje al chat A/B.';
  exception when insufficient_privilege then null;
  end;
end $$;
select set_config('request.jwt.claim.sub',current_setting('recovery.test_b'),true);
do $$ begin
  perform public.encuentralo_manage_recovery(auth.uid(),current_setting('recovery.request_b')::uuid,'confirm',2);
  if (select status from public.found_items where id=current_setting('recovery.item')::uuid)<>'active' then
    raise exception 'FALLO: una confirmación resolvió el hallazgo.';
  end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('recovery.test_a'),true);
do $$ begin
  perform public.encuentralo_manage_recovery(auth.uid(),current_setting('recovery.request_b')::uuid,'confirm',3);
  if (select status from public.found_items where id=current_setting('recovery.item')::uuid)<>'returned' then
    raise exception 'FALLO: ambas confirmaciones no resolvieron el hallazgo.';
  end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('recovery.test_c'),true);
do $$ begin
  if (select status from public.recovery_requests where id=current_setting('recovery.request_c')::uuid)<>'closed' then
    raise exception 'FALLO: la solicitud de C no fue cerrada.';
  end if;
  begin
    perform public.encuentralo_request_recovery(auth.uid(),gen_random_uuid(),current_setting('recovery.item')::uuid,'Nueva petición sintética después de devolver');
    raise exception 'FALLO: el hallazgo devuelto admitió una solicitud.';
  exception when raise_exception then
    if sqlerrm<>'El hallazgo ya no admite solicitudes.' then raise; end if;
  end;
  raise notice 'OK: flujo SQL A/B/C, privacidad, Prefectura y doble confirmación.';
end $$;
rollback;
