-- Fase 5: inspección de solo lectura. Aplicar primero la migración revisada.
select c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('notifications','notification_preferences');
select tablename,policyname,roles,cmd,qual from pg_policies
where schemaname='public' and tablename in ('notifications','notification_preferences');
select table_name,grantee,privilege_type from information_schema.role_table_grants
where table_schema='public' and table_name in ('notifications','notification_preferences');
select n.nspname,p.proname,p.prosecdef,p.proconfig,p.proacl from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where p.proname in ('record_notification','notify_recovery_event','notify_private_message','notify_publication_edit',
  'encuentralo_read_notifications','encuentralo_save_notification_preferences','encuentralo_complete_tutorial');
select * from pg_publication_tables where pubname='supabase_realtime'
and tablename in ('notifications','notification_preferences');

-- Prueba transaccional A/B/C. Reemplazar los tres UUID por cuentas confirmadas.
-- Ejecutar TODO el bloque. Si se interrumpe o falla, ejecutar ROLLBACK.
begin;
select set_config('notifications.test_a','REEMPLAZA_UUID_A',true);
select set_config('notifications.test_b','REEMPLAZA_UUID_B',true);
select set_config('notifications.test_c','REEMPLAZA_UUID_C',true);
select set_config('notifications.item',gen_random_uuid()::text,true);
select set_config('notifications.request',gen_random_uuid()::text,true);
do $$ begin
  if (select count(distinct id) from auth.users where id in (current_setting('notifications.test_a')::uuid,
    current_setting('notifications.test_b')::uuid,current_setting('notifications.test_c')::uuid))<>3 then
    raise exception 'Se necesitan tres cuentas de prueba diferentes.';
  end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('notifications.test_a'),true);
insert into public.found_items(id,finder_id,title,category,description,found_on,zone,custody)
values(current_setting('notifications.item')::uuid,auth.uid(),'Termo de prueba','bottles','Publicación sintética para verificar avisos',
  current_date-1,'Biblioteca','student');
select public.encuentralo_save_notification_preferences(auth.uid(),false,false,false,false);
select set_config('request.jwt.claim.sub',current_setting('notifications.test_b'),true);
select public.encuentralo_request_recovery(auth.uid(),current_setting('notifications.request')::uuid,
  current_setting('notifications.item')::uuid,'Características sintéticas privadas de prueba');
select set_config('request.jwt.claim.sub',current_setting('notifications.test_a'),true);
do $$ begin
  if (select count(*) from public.notifications where request_id=current_setting('notifications.request')::uuid)<>1 then
    raise exception 'FALLO: falta el aviso persistente para A.';
  end if;
  if exists(select 1 from public.notifications where request_id=current_setting('notifications.request')::uuid and alert_enabled) then
    raise exception 'FALLO: A había silenciado solicitudes.';
  end if;
  perform public.encuentralo_manage_recovery(auth.uid(),current_setting('notifications.request')::uuid,'accept',1);
end $$;
select set_config('notifications.conversation',(select id::text from public.recovery_conversations
  where request_id=current_setting('notifications.request')::uuid),true);
select set_config('request.jwt.claim.sub',current_setting('notifications.test_b'),true);
select public.encuentralo_send_message(auth.uid(),gen_random_uuid(),current_setting('notifications.conversation')::uuid,
  'Contenido privado que no debe aparecer en la notificación');
select set_config('request.jwt.claim.sub',current_setting('notifications.test_c'),true);
do $$ begin
  if exists(select 1 from public.notifications where request_id=current_setting('notifications.request')::uuid) then
    raise exception 'FALLO: C puede leer avisos de A/B.';
  end if;
  if exists(select 1 from public.notification_preferences where user_id=current_setting('notifications.test_a')::uuid) then
    raise exception 'FALLO: C puede leer preferencias de A.';
  end if;
  begin
    perform public.encuentralo_complete_tutorial(current_setting('notifications.test_a')::uuid);
    raise exception 'FALLO: C modificó la cuenta de A.';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.notifications(recipient_id,kind,title,body,event_key,alert_enabled)
      values(auth.uid(),'private_message','Falso','Falso','arbitrario',true);
    raise exception 'FALLO: cliente creó un aviso arbitrario.';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub',current_setting('notifications.test_a'),true);
do $$ begin
  if not exists(select 1 from public.notifications where request_id=current_setting('notifications.request')::uuid and kind='private_message') then
    raise exception 'FALLO: falta el aviso de mensaje para A.';
  end if;
  if exists(select 1 from public.notifications where request_id=current_setting('notifications.request')::uuid
    and (body like '%Contenido privado%' or body like '%Características sintéticas%')) then
    raise exception 'FALLO: aviso incluye contenido privado.';
  end if;
  perform public.encuentralo_read_notifications(auth.uid(),null,clock_timestamp());
  if exists(select 1 from public.notifications where request_id=current_setting('notifications.request')::uuid and read_at is null) then
    raise exception 'FALLO: no se guardó la lectura.';
  end if;
  perform public.encuentralo_complete_tutorial(auth.uid());
  if not exists(select 1 from public.notification_preferences where user_id=auth.uid() and tutorial_version=1 and not recovery_requests) then
    raise exception 'FALLO: tutorial sobrescribió preferencias.';
  end if;
  raise notice 'OK: notificaciones, privacidad A/B/C, preferencias y tutorial.';
end $$;
rollback;
