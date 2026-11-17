-- Run once, manually, in the SQL Editor of encuentralo-escom-dev.
-- This intentionally fails if these objects already exist; inspect before rerun.
begin;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  boleta text check (boleta is null or char_length(boleta) <= 32),
  phone text check (phone is null or char_length(phone) <= 30),
  notifications_enabled boolean not null default true,
  dark_mode boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

revoke all on table public.profiles from public, anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (name, boleta, phone, notifications_enabled, dark_mode)
  on table public.profiles to authenticated;

create policy profiles_select_own on public.profiles
  for select to authenticated using ((select auth.uid()) = id);

create policy profiles_update_own on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Clients have no INSERT/DELETE privilege. Only this server trigger creates
-- profiles, using the real auth.users UUID. Metadata grants no privileges.
create function public.encuentralo_create_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, name, boleta)
  values (
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'name'), ''), 'Usuario'), 200),
    left(nullif(btrim(new.raw_user_meta_data ->> 'boleta'), ''), 32)
  );
  return new;
end;
$$;

revoke all on function public.encuentralo_create_profile() from public, anon, authenticated;

create trigger encuentralo_on_auth_user_created
  after insert on auth.users for each row
  execute function public.encuentralo_create_profile();

create function public.encuentralo_touch_profile()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.encuentralo_touch_profile() from public, anon, authenticated;

create trigger encuentralo_on_profile_updated
  before update on public.profiles for each row
  execute function public.encuentralo_touch_profile();

-- Backfill only users already in Supabase Auth; no local credentials are read.
insert into public.profiles (id, name, boleta, created_at)
select id,
  left(coalesce(nullif(btrim(raw_user_meta_data ->> 'name'), ''), 'Usuario'), 200),
  left(nullif(btrim(raw_user_meta_data ->> 'boleta'), ''), 32), created_at
from auth.users
on conflict (id) do nothing;

commit;
