-- Fase 5. Aplicar MANUALMENTE después de Fase 4. No envía push ni email.
begin;

create table public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  recovery_requests boolean not null default true,
  private_messages boolean not null default true,
  status_returns boolean not null default true,
  matches boolean not null default true,
  tutorial_version integer not null default 0 check (tutorial_version between 0 and 1),
  updated_at timestamptz not null default clock_timestamp()
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('recovery_request','request_status','private_message','return_confirmed','publication_changed')),
  title text not null,
  body text not null,
  item_id uuid references public.found_items(id) on delete set null,
  request_id uuid references public.recovery_requests(id) on delete set null,
  conversation_id uuid references public.recovery_conversations(id) on delete set null,
  event_key text not null,
  alert_enabled boolean not null,
  created_at timestamptz not null default clock_timestamp(),
  read_at timestamptz,
  unique(recipient_id,event_key)
);
create index notifications_history on public.notifications(recipient_id,created_at desc,id desc);
create index notifications_unread on public.notifications(recipient_id) where read_at is null and alert_enabled;
alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;
revoke all on public.notifications,public.notification_preferences from public,anon,authenticated;
grant select on public.notifications,public.notification_preferences to authenticated;
create policy notifications_own on public.notifications for select to authenticated using(recipient_id=(select auth.uid()));
create policy notification_preferences_own on public.notification_preferences for select to authenticated using(user_id=(select auth.uid()));

-- Solo triggers privados llaman este helper. No acepta contenido del cliente.
create function encuentralo_private.record_notification(p_recipient uuid,p_key text,p_kind text,p_title text,p_body text,
  p_item uuid,p_request uuid,p_conversation uuid default null) returns void
language plpgsql security definer set search_path='' as $$
declare enabled boolean;
begin
  select case p_kind when 'recovery_request' then recovery_requests
    when 'private_message' then private_messages else status_returns end into enabled
    from public.notification_preferences where user_id=p_recipient;
  insert into public.notifications(recipient_id,event_key,kind,title,body,item_id,request_id,conversation_id,alert_enabled)
    values(p_recipient,p_key,p_kind,p_title,p_body,p_item,p_request,p_conversation,coalesce(enabled,true))
    on conflict(recipient_id,event_key) do nothing;
end $$;

create function encuentralo_private.notify_recovery_event() returns trigger
language plpgsql security definer set search_path='' as $$
declare r public.recovery_requests; recipient uuid; kind text; title text; body text;
begin
  select * into strict r from public.recovery_requests where id=new.request_id;
  kind:=case when new.action='created' then 'recovery_request'
    when new.action='returned' then 'return_confirmed'
    when new.action in ('item_returned','item_withdrawn','prefecture') then 'publication_changed'
    else 'request_status' end;
  title:=case new.action when 'created' then 'Nueva solicitud de recuperación'
    when 'accept' then 'Solicitud aceptada' when 'reject' then 'Solicitud rechazada'
    when 'cancel' then 'Solicitud cancelada' when 'returned' then 'Devolución confirmada'
    when 'finder_confirmed' then 'Entrega confirmada por el encontrador'
    when 'requester_confirmed' then 'Recepción confirmada por el solicitante'
    when 'prefecture' then 'Entrega declarada a Prefectura'
    when 'item_withdrawn' then 'Publicación retirada' when 'item_returned' then 'Objeto devuelto'
    when 'meeting' then 'Acuerdo actualizado' else 'Solicitud cerrada' end;
  body:=case when new.action='returned' then 'Ambas personas confirmaron la devolución. Consulta tu solicitud.'
    when new.action in ('finder_confirmed','requester_confirmed') then 'Consulta la solicitud. La devolución requiere ambas confirmaciones.'
    when new.action='prefecture' then 'Consulta la solicitud y las indicaciones presenciales de la publicación.'
    else 'Consulta los detalles en tu solicitud privada.' end;
  foreach recipient in array array[r.finder_id,r.requester_id] loop
    if (new.action='created' and recipient<>r.finder_id)
      or (new.action<>'returned' and recipient=new.actor_id) then continue; end if;
    perform encuentralo_private.record_notification(recipient,'event:'||new.id::text,kind,title,body,r.item_id,r.id);
  end loop;
  return new;
end $$;
create trigger notifications_recovery_event after insert on public.recovery_events
  for each row execute function encuentralo_private.notify_recovery_event();

create function encuentralo_private.notify_private_message() returns trigger
language plpgsql security definer set search_path='' as $$
declare r public.recovery_requests; recipient uuid;
begin
  select q.* into strict r from public.recovery_requests q join public.recovery_conversations c on c.request_id=q.id
    where c.id=new.conversation_id;
  recipient:=case when new.sender_id=r.finder_id then r.requester_id else r.finder_id end;
  perform encuentralo_private.record_notification(recipient,'message:'||new.id::text,'private_message',
    'Nuevo mensaje privado','Tienes un mensaje en un chat de recuperación.',r.item_id,r.id,new.conversation_id);
  return new;
end $$;
create trigger notifications_private_message after insert on public.recovery_messages
  for each row execute function encuentralo_private.notify_private_message();

-- Los cierres por retiro, Prefectura y devolución ya generan recovery_events.
-- Aquí solo avisamos de ediciones a quienes tienen una solicitud activa.
create function encuentralo_private.notify_publication_edit() returns trigger
language plpgsql security definer set search_path='' as $$
declare r record;
begin
  if new.status is distinct from old.status or new.custody is distinct from old.custody then return new; end if;
  if row(new.title,new.description,new.category,new.zone,new.found_on,new.photo_path)
    is not distinct from row(old.title,old.description,old.category,old.zone,old.found_on,old.photo_path) then return new; end if;
  for r in select id,requester_id from public.recovery_requests where item_id=new.id and status in ('pending','accepted') loop
    perform encuentralo_private.record_notification(r.requester_id,'publication:'||new.id::text||':'||gen_random_uuid()::text,
      'publication_changed','Publicación actualizada','Consulta los datos actuales del hallazgo.',new.id,r.id);
  end loop;
  return new;
end $$;
create trigger notifications_publication_edit after update on public.found_items
  for each row execute function encuentralo_private.notify_publication_edit();

create function public.encuentralo_save_notification_preferences(p_actor uuid,p_requests boolean,p_messages boolean,
  p_status boolean,p_matches boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result public.notification_preferences;
begin
  if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'La sesión cambió.' using errcode='42501'; end if;
  insert into public.notification_preferences(user_id,recovery_requests,private_messages,status_returns,matches)
    values(auth.uid(),p_requests,p_messages,p_status,p_matches)
    on conflict(user_id) do update set recovery_requests=excluded.recovery_requests,private_messages=excluded.private_messages,
      status_returns=excluded.status_returns,matches=excluded.matches,updated_at=clock_timestamp() returning * into result;
  return to_jsonb(result);
end $$;
create function public.encuentralo_complete_tutorial(p_actor uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'La sesión cambió.' using errcode='42501'; end if;
  insert into public.notification_preferences(user_id,tutorial_version) values(auth.uid(),1)
    on conflict(user_id) do update set tutorial_version=1,updated_at=clock_timestamp();
end $$;
-- p_before evita marcar eventos que llegaron después de abrir el centro.
create function public.encuentralo_read_notifications(p_actor uuid,p_id uuid default null,p_before timestamptz default null) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'La sesión cambió.' using errcode='42501'; end if;
  if p_id is null and p_before is null then raise exception 'Indica el aviso o el límite de lectura.' using errcode='22023'; end if;
  update public.notifications set read_at=clock_timestamp() where recipient_id=auth.uid() and read_at is null
    and ((p_id is not null and id=p_id) or (p_id is null and created_at<=least(p_before,clock_timestamp())));
end $$;
revoke all on function encuentralo_private.record_notification(uuid,text,text,text,text,uuid,uuid,uuid),
  encuentralo_private.notify_recovery_event(),encuentralo_private.notify_private_message(),encuentralo_private.notify_publication_edit()
  from public,anon,authenticated;
revoke all on function public.encuentralo_save_notification_preferences(uuid,boolean,boolean,boolean,boolean),
  public.encuentralo_complete_tutorial(uuid),public.encuentralo_read_notifications(uuid,uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.encuentralo_save_notification_preferences(uuid,boolean,boolean,boolean,boolean),
  public.encuentralo_complete_tutorial(uuid),public.encuentralo_read_notifications(uuid,uuid,timestamptz) to authenticated;
do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    alter publication supabase_realtime add table public.notifications,public.notification_preferences;
  end if;
end $$;
commit;
