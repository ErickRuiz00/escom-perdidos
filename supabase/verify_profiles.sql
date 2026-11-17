-- Read-only structural checks. Run after the migration as postgres in SQL Editor.
select relrowsecurity from pg_class where oid = 'public.profiles'::regclass;

select policyname, roles, cmd, qual, with_check
from pg_policies where schemaname = 'public' and tablename = 'profiles';

select grantee, privilege_type from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'profiles'
order by grantee, privilege_type;

select grantee, column_name, privilege_type
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles'
  and grantee in ('anon', 'authenticated')
order by grantee, column_name, privilege_type;

select u.id, u.email_confirmed_at, p.id as profile_id
from auth.users u left join public.profiles p on p.id = u.id;

-- This count must be zero.
select count(*) as users_without_profile
from auth.users u left join public.profiles p on p.id = u.id where p.id is null;
