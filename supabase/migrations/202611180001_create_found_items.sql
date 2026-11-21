-- Aplicar MANUALMENTE después de revisar. No modifica Supabase Auth ni profiles.
-- Falla si los objetos ya existen: revisar el esquema antes de reintentar.
begin;

create table public.found_items (
  id uuid primary key default gen_random_uuid(),
  finder_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (title = btrim(title) and char_length(title) between 4 and 60),
  category text not null check (category in ('electronics','documents','keys','clothing','supplies','bottles','bags','other')),
  description text not null check (description = btrim(description) and char_length(description) between 10 and 500),
  found_on date not null check (found_on >= date '2020-01-01' and found_on <= (now() at time zone 'America/Mexico_City')::date),
  zone text not null check (zone in ('Edificio de Gobierno','Edificio 1','Edificio 2','Edificio 3','Edificio 4','Biblioteca','Cafetería','Laboratorios de cómputo','Auditorio','Canchas','Explanada','Estacionamiento','Baños','Otro')),
  custody text not null check (custody in ('student','prefecture')),
  status text not null default 'active' check (status in ('active','withdrawn','returned')),
  photo_path text check (photo_path is null or photo_path ~ ('^' || finder_id::text || '/' || id::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.](jpg|png|webp)$')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index found_items_catalog on public.found_items (created_at desc, id) where status = 'active';
create index found_items_owner on public.found_items (finder_id, created_at desc);
alter table public.found_items enable row level security;
revoke all on table public.found_items from public, anon, authenticated;
grant select on public.found_items to authenticated;
-- El autor explícito liga el formulario a su sesión de origen. RLS exige que
-- coincida con auth.uid(), incluso si la sesión cambia durante el envío.
-- Las fechas y el estado inicial los fija exclusivamente la BD.
grant insert (id,finder_id,title,category,description,found_on,zone,custody,photo_path)
  on public.found_items to authenticated;
grant update (title,category,description,found_on,zone,custody,photo_path,status)
  on public.found_items to authenticated;

create policy found_items_read on public.found_items for select to authenticated
  using (status = 'active' or finder_id = (select auth.uid()));
create policy found_items_create_own on public.found_items for insert to authenticated
  with check (finder_id = (select auth.uid()) and status = 'active');
create policy found_items_update_own on public.found_items for update to authenticated
  using (finder_id = (select auth.uid()) and status = 'active')
  with check (finder_id = (select auth.uid()) and status in ('active','withdrawn'));
-- Sin DELETE: retirar conserva el historial y es terminal para el cliente.

create function public.encuentralo_guard_found_item()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.id is distinct from old.id or new.finder_id is distinct from old.finder_id
    or new.created_at is distinct from old.created_at then
    raise exception 'La identidad y autoría de la publicación son inmutables.' using errcode = '42501';
  end if;
  if current_user in ('authenticated','anon') then
    if old.status <> 'active' or new.status not in ('active','withdrawn') then
      raise exception 'El cliente no puede confirmar ni reactivar devoluciones.' using errcode = '42501';
    end if;
    if old.custody = 'prefecture' and new.custody <> 'prefecture' then
      raise exception 'Una entrega declarada a Prefectura no puede revertirse.' using errcode = '42501';
    end if;
  end if;
  new.updated_at = clock_timestamp();
  return new;
end;
$$;
revoke all on function public.encuentralo_guard_found_item() from public, anon, authenticated;
create trigger encuentralo_found_item_updated before update on public.found_items
  for each row execute function public.encuentralo_guard_found_item();

commit;
