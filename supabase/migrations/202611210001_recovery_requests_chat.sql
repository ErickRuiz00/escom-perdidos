-- Fase 4. Revisar y aplicar después de las migraciones de Fase 3.
-- Transacción aditiva: no borra datos ni altera Auth/profiles/Storage.
begin;
create schema encuentralo_private;
revoke all on schema encuentralo_private from public, anon, authenticated;
grant usage on schema encuentralo_private to authenticated;

create table public.recovery_requests (
  id uuid primary key,
  item_id uuid not null references public.found_items(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  finder_id uuid not null references auth.users(id) on delete cascade,
  item_title text not null,
  evidence text not null check (evidence=btrim(evidence) and char_length(evidence) between 20 and 1200),
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled','closed')),
  close_reason text,
  meeting_point text check (meeting_point is null or char_length(meeting_point) between 3 and 120),
  meeting_at timestamptz,
  finder_confirmed_at timestamptz,
  requester_confirmed_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (requester_id<>finder_id)
);
create unique index recovery_one_active on public.recovery_requests(item_id,requester_id) where status in ('pending','accepted');
create index recovery_inbox on public.recovery_requests(finder_id,created_at desc,id);
create index recovery_outbox on public.recovery_requests(requester_id,created_at desc,id);
create table public.recovery_conversations (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.recovery_requests(id) on delete cascade,
  created_at timestamptz not null default clock_timestamp(),
  closed_at timestamptz
);
create table public.recovery_messages (
  id uuid primary key,
  conversation_id uuid not null references public.recovery_conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (body=btrim(body) and char_length(body) between 1 and 2000),
  created_at timestamptz not null default clock_timestamp()
);
create index recovery_message_page on public.recovery_messages(conversation_id,created_at desc,id);
create table public.recovery_events (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.recovery_requests(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  created_at timestamptz not null default clock_timestamp()
);
create index recovery_event_history on public.recovery_events(request_id,id);
create table public.recovery_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default clock_timestamp(),
  primary key(blocker_id,blocked_id), check (blocker_id<>blocked_id)
);
create table public.recovery_abuse_reports (
  id uuid primary key,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null references public.recovery_requests(id) on delete cascade,
  reason text not null check(char_length(reason) between 10 and 1000),
  created_at timestamptz not null default clock_timestamp(),
  unique(reporter_id,request_id)
);

-- Helpers de lectura sin recursión de RLS. No devuelven datos de otro usuario.
create function encuentralo_private.participant(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.recovery_requests r where r.id=p_id
    and auth.uid() in (r.requester_id,r.finder_id))
$$;
create function encuentralo_private.can_chat(p_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.recovery_requests r join public.found_items f on f.id=r.item_id
    where r.id=p_id and auth.uid() in (r.requester_id,r.finder_id)
    and r.status='accepted' and f.status='active' and f.custody='student'
    and not exists(select 1 from public.recovery_blocks b where
      (b.blocker_id=r.finder_id and b.blocked_id=r.requester_id)
      or (b.blocker_id=r.requester_id and b.blocked_id=r.finder_id)))
$$;
revoke all on function encuentralo_private.participant(uuid),encuentralo_private.can_chat(uuid) from public,anon,authenticated;
grant execute on function encuentralo_private.participant(uuid),encuentralo_private.can_chat(uuid) to authenticated;

alter table public.recovery_requests enable row level security;
alter table public.recovery_conversations enable row level security;
alter table public.recovery_messages enable row level security;
alter table public.recovery_events enable row level security;
alter table public.recovery_blocks enable row level security;
alter table public.recovery_abuse_reports enable row level security;
revoke all on public.recovery_requests,public.recovery_conversations,public.recovery_messages,
  public.recovery_events,public.recovery_blocks,public.recovery_abuse_reports from public,anon,authenticated;
grant select on public.recovery_requests,public.recovery_conversations,public.recovery_messages,
  public.recovery_events,public.recovery_blocks,public.recovery_abuse_reports to authenticated;
create policy recovery_participants on public.recovery_requests for select to authenticated
  using (auth.uid() in (requester_id,finder_id));
create policy recovery_conversation_participants on public.recovery_conversations for select to authenticated
  using (encuentralo_private.participant(request_id));
create policy recovery_message_participants on public.recovery_messages for select to authenticated using (
  exists(select 1 from public.recovery_conversations c where c.id=conversation_id
    and c.closed_at is null and encuentralo_private.can_chat(c.request_id)));
create policy recovery_history_participants on public.recovery_events for select to authenticated
  using (encuentralo_private.participant(request_id));
create policy recovery_own_blocks on public.recovery_blocks for select to authenticated using(blocker_id=auth.uid());
create policy recovery_own_reports on public.recovery_abuse_reports for select to authenticated using(reporter_id=auth.uid());

-- Todas las escrituras pasan por RPC: identidad derivada de auth.uid(), nunca
-- de un UUID de participante enviado por Flutter. Locks siempre hallazgo -> solicitud.
create function public.encuentralo_request_recovery(p_actor uuid,p_id uuid,p_item_id uuid,p_evidence text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); f public.found_items; r public.recovery_requests;
begin
  if u is null or u is distinct from p_actor then raise exception 'La sesión cambió.' using errcode='42501'; end if;
  select * into f from public.found_items where id=p_item_id for update;
  if not found or f.finder_id=u then raise exception 'No puedes solicitar este hallazgo.' using errcode='42501'; end if;
  select * into r from public.recovery_requests where id=p_id;
  if found then
    if r.requester_id=u and r.item_id=p_item_id and r.evidence=btrim(p_evidence) then return to_jsonb(r); end if;
    raise exception 'Identificador de solicitud no disponible.' using errcode='42501';
  end if;
  if f.status<>'active' or f.custody<>'student' then raise exception 'El hallazgo ya no admite solicitudes.' using errcode='P0001'; end if;
  if exists(select 1 from public.recovery_blocks b where (b.blocker_id=u and b.blocked_id=f.finder_id)
    or (b.blocker_id=f.finder_id and b.blocked_id=u)) then raise exception 'No se puede contactar a este participante.' using errcode='42501'; end if;
  if exists(select 1 from public.recovery_requests where item_id=p_item_id and requester_id=u and status in ('pending','accepted')) then
    raise exception 'Ya tienes una solicitud activa para este hallazgo.' using errcode='23505'; end if;
  if (select count(*) from public.recovery_requests where item_id=p_item_id and requester_id=u)>=3
    or exists(select 1 from public.recovery_requests where item_id=p_item_id and requester_id=u and created_at>clock_timestamp()-interval '24 hours') then
    raise exception 'Espera 24 horas antes de volver a solicitar. Máximo tres intentos por hallazgo.' using errcode='P0001'; end if;
  -- Serializa también los límites globales de un solicitante sin bloquear otros usuarios.
  perform pg_advisory_xact_lock(hashtextextended(u::text,412));
  if (select count(*) from public.recovery_requests where requester_id=u and created_at>clock_timestamp()-interval '24 hours')>=10 then
    raise exception 'Alcanzaste el límite diario de diez solicitudes.' using errcode='P0001'; end if;
  insert into public.recovery_requests(id,item_id,requester_id,finder_id,item_title,evidence)
    values(p_id,p_item_id,u,f.finder_id,f.title,btrim(p_evidence)) returning * into r;
  insert into public.recovery_events(request_id,actor_id,action) values(r.id,u,'created');
  return to_jsonb(r);
end $$;

create function public.encuentralo_manage_recovery(p_actor uuid,p_id uuid,p_action text,p_version integer,
  p_meeting_point text default null,p_meeting_at timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); item uuid; f public.found_items; r public.recovery_requests; event text:=p_action;
begin
  if u is null or u is distinct from p_actor then raise exception 'La sesión cambió.' using errcode='42501'; end if;
  select item_id into item from public.recovery_requests where id=p_id and u in (finder_id,requester_id);
  if item is null then raise exception 'Solicitud no disponible para tu cuenta.' using errcode='42501'; end if;
  select * into f from public.found_items where id=item for update;
  select * into r from public.recovery_requests where id=p_id for update;
  if (p_action='accept' and u=r.finder_id and r.status='accepted')
    or (p_action='reject' and u=r.finder_id and r.status='rejected')
    or (p_action='cancel' and u=r.requester_id and r.status='cancelled')
    or (p_action='confirm' and r.status='closed' and r.close_reason='returned') then return to_jsonb(r); end if;
  if p_version is null or r.version<>p_version then raise exception 'La solicitud cambió. Actualiza antes de continuar.' using errcode='40001'; end if;
  if f.status<>'active' or f.custody<>'student' or r.status not in ('pending','accepted') then
    raise exception 'La solicitud ya no está disponible.' using errcode='P0001'; end if;
  if p_action in ('accept','reject') and r.status='pending' and u=r.finder_id then
    r.status:=case when p_action='accept' then 'accepted' else 'rejected' end;
    if p_action='accept' then
      -- Comprueba bloqueo de ambas partes, incluso si otra sesión actúa simultáneamente.
      if exists(select 1 from public.recovery_blocks b where (b.blocker_id=r.finder_id and b.blocked_id=r.requester_id)
        or (b.blocker_id=r.requester_id and b.blocked_id=r.finder_id)) then
        raise exception 'No se puede abrir esta conversación.' using errcode='42501'; end if;
      insert into public.recovery_conversations(request_id) values(r.id);
    end if;
  elsif p_action='cancel' and u=r.requester_id and r.finder_confirmed_at is null and r.requester_confirmed_at is null then
    r.status:='cancelled';
  elsif p_action='close' and r.status='accepted' and r.finder_confirmed_at is null and r.requester_confirmed_at is null then
    r.status:='closed'; r.close_reason:='participant_closed';
  elsif p_action in ('meeting','confirm') and encuentralo_private.can_chat(r.id) then
    if p_action='meeting' then
      if p_meeting_point is null or char_length(btrim(p_meeting_point)) not between 3 and 120
        or btrim(p_meeting_point) not in ('Edificio de Gobierno','Edificio 1','Edificio 2','Edificio 3','Edificio 4','Biblioteca','Cafetería','Laboratorios de cómputo','Auditorio','Canchas','Explanada','Estacionamiento','Baños','Otro')
        or p_meeting_at is null or p_meeting_at<=clock_timestamp() or p_meeting_at>clock_timestamp()+interval '30 days' then
        raise exception 'Indica un punto dentro de ESCOM y una fecha futura de hasta 30 días.' using errcode='P0001'; end if;
      if r.finder_confirmed_at is not null or r.requester_confirmed_at is not null then
        raise exception 'La devolución ya tiene una confirmación; no cambies el acuerdo.' using errcode='P0001'; end if;
      if r.meeting_point=btrim(p_meeting_point) and r.meeting_at=p_meeting_at then return to_jsonb(r); end if;
      r.meeting_point:=btrim(p_meeting_point); r.meeting_at:=p_meeting_at;
    else
      if (u=r.finder_id and r.finder_confirmed_at is not null) or (u=r.requester_id and r.requester_confirmed_at is not null) then return to_jsonb(r); end if;
      if u=r.finder_id then r.finder_confirmed_at:=clock_timestamp(); event:='finder_confirmed';
      else r.requester_confirmed_at:=clock_timestamp(); event:='requester_confirmed'; end if;
      if r.finder_confirmed_at is not null and r.requester_confirmed_at is not null then
        r.status:='closed'; r.close_reason:='returned'; event:='returned';
      end if;
    end if;
  else raise exception 'No tienes permiso para realizar esta acción.' using errcode='42501'; end if;
  update public.recovery_requests set status=r.status,close_reason=r.close_reason,meeting_point=r.meeting_point,
    meeting_at=r.meeting_at,finder_confirmed_at=r.finder_confirmed_at,requester_confirmed_at=r.requester_confirmed_at,
    version=version+1,updated_at=clock_timestamp() where id=r.id returning * into r;
  if r.status<>'accepted' then update public.recovery_conversations set closed_at=coalesce(closed_at,clock_timestamp()) where request_id=r.id; end if;
  insert into public.recovery_events(request_id,actor_id,action) values(r.id,u,event);
  if r.close_reason='returned' then update public.found_items set status='returned' where id=item; end if;
  return to_jsonb(r);
end $$;

create function public.encuentralo_send_message(p_actor uuid,p_id uuid,p_conversation_id uuid,p_body text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); item uuid; req uuid; m public.recovery_messages;
begin
  if u is null or u is distinct from p_actor then raise exception 'La sesión cambió.' using errcode='42501'; end if;
  select r.item_id,r.id into item,req from public.recovery_conversations c join public.recovery_requests r on r.id=c.request_id
    where c.id=p_conversation_id and c.closed_at is null and u in (r.finder_id,r.requester_id);
  if item is null then raise exception 'Conversación no disponible.' using errcode='42501'; end if;
  perform 1 from public.found_items where id=item for update;
  perform 1 from public.recovery_requests where id=req for update;
  if not encuentralo_private.can_chat(req) then raise exception 'La conversación ya no está activa.' using errcode='42501'; end if;
  select * into m from public.recovery_messages where id=p_id;
  if found then
    if m.sender_id=u and m.conversation_id=p_conversation_id and m.body=btrim(p_body) then return to_jsonb(m); end if;
    raise exception 'Identificador de mensaje no disponible.' using errcode='42501'; end if;
  if exists(select 1 from public.recovery_messages where conversation_id=p_conversation_id and sender_id=u
    and created_at>clock_timestamp()-interval '2 seconds') then
    raise exception 'Espera dos segundos antes de enviar otro mensaje.' using errcode='P0001'; end if;
  insert into public.recovery_messages(id,conversation_id,sender_id,body) values(p_id,p_conversation_id,u,btrim(p_body)) returning * into m;
  return to_jsonb(m);
end $$;

create function encuentralo_private.close_unavailable() returns trigger
language plpgsql security definer set search_path='' as $$
declare reason text; r record;
begin
  if new.status=old.status and new.custody=old.custody then return new; end if;
  if new.status='active' and new.custody='student' then return new; end if;
  reason:=case when new.status='returned' then 'item_returned' when new.status='withdrawn' then 'item_withdrawn' else 'prefecture' end;
  for r in update public.recovery_requests set status='closed',close_reason=reason,version=version+1,updated_at=clock_timestamp()
    where item_id=new.id and status in ('pending','accepted') returning id loop
    update public.recovery_conversations set closed_at=coalesce(closed_at,clock_timestamp()) where request_id=r.id;
    insert into public.recovery_events(request_id,actor_id,action) values(r.id,auth.uid(),reason);
  end loop;
  return new;
end $$;
revoke all on function encuentralo_private.close_unavailable() from public,anon,authenticated;
create trigger recovery_close_unavailable after update of status,custody on public.found_items
  for each row execute function encuentralo_private.close_unavailable();

create function public.encuentralo_block_user(p_actor uuid,p_peer uuid,p_block boolean) returns void
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); item record; r record;
begin
  if u is null or u is distinct from p_actor or p_peer=u or p_peer is null or p_block is null then raise exception 'Participante no válido.' using errcode='42501'; end if;
  if not exists(select 1 from public.recovery_requests where (requester_id=u and finder_id=p_peer) or (finder_id=u and requester_id=p_peer)) then
    raise exception 'No existe una solicitud compartida.' using errcode='42501'; end if;
  -- Locks de hallazgos ordenados: mismo orden que creación, envío y resolución.
  for item in select f.id from public.found_items f where exists(select 1 from public.recovery_requests q where q.item_id=f.id
    and ((q.requester_id=u and q.finder_id=p_peer) or (q.finder_id=u and q.requester_id=p_peer))) order by f.id for update loop
    null;
  end loop;
  if not p_block then delete from public.recovery_blocks where blocker_id=u and blocked_id=p_peer; return; end if;
  insert into public.recovery_blocks(blocker_id,blocked_id) values(u,p_peer) on conflict do nothing;
  for r in update public.recovery_requests set status='closed',close_reason='blocked',version=version+1,updated_at=clock_timestamp()
    where status in ('pending','accepted') and ((requester_id=u and finder_id=p_peer) or (finder_id=u and requester_id=p_peer)) returning id loop
    update public.recovery_conversations set closed_at=coalesce(closed_at,clock_timestamp()) where request_id=r.id;
    insert into public.recovery_events(request_id,actor_id,action) values(r.id,u,'blocked');
  end loop;
end $$;
create function public.encuentralo_report_abuse(p_actor uuid,p_id uuid,p_request_id uuid,p_reason text) returns void
language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or auth.uid() is distinct from p_actor then raise exception 'La sesión cambió.' using errcode='42501'; end if;
  if not encuentralo_private.participant(p_request_id) then raise exception 'Solicitud no disponible.' using errcode='42501'; end if;
  if p_reason is null or char_length(btrim(p_reason)) not between 10 and 1000 then raise exception 'Describe el motivo en 10 a 1000 caracteres.' using errcode='P0001'; end if;
  insert into public.recovery_abuse_reports(id,reporter_id,request_id,reason) values(p_id,auth.uid(),p_request_id,btrim(p_reason))
    on conflict(reporter_id,request_id) do nothing;
end $$;
revoke all on function public.encuentralo_request_recovery(uuid,uuid,uuid,text),public.encuentralo_manage_recovery(uuid,uuid,text,integer,text,timestamptz),
  public.encuentralo_send_message(uuid,uuid,uuid,text),public.encuentralo_block_user(uuid,uuid,boolean),public.encuentralo_report_abuse(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.encuentralo_request_recovery(uuid,uuid,uuid,text),public.encuentralo_manage_recovery(uuid,uuid,text,integer,text,timestamptz),
  public.encuentralo_send_message(uuid,uuid,uuid,text),public.encuentralo_block_user(uuid,uuid,boolean),public.encuentralo_report_abuse(uuid,uuid,uuid,text) to authenticated;

-- Postgres Changes respeta SELECT/RLS para INSERT/UPDATE. No se concede DELETE
-- al cliente ni se usa REPLICA IDENTITY FULL: una eliminación administrativa
-- eventual no debe incluir contenido privado en la imagen antigua de la fila.
do $$ declare tab text; begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    foreach tab in array array['recovery_requests','recovery_conversations','recovery_messages'] loop
      if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=tab) then
        execute format('alter publication supabase_realtime add table public.%I',tab);
      end if;
    end loop;
  end if;
end $$;
commit;
