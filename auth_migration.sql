-- ============================================================
-- Caferio Auth Migration — Username-based auth
-- Run this ONCE in Supabase Dashboard → SQL Editor.
-- It is safe to re-run: all operations use IF EXISTS guards.
-- ============================================================

-- 1) ADD username COLUMN TO profiles --------------------------
alter table public.profiles
  add column if not exists username text unique,
  add column if not exists full_name text;

-- 2) UPDATE handle_new_user TRIGGER ---------------------------
-- Now also stores username from raw_user_meta_data.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, role, username)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    (new.raw_app_meta_data  ->> 'role')::public.user_role,
    new.raw_user_meta_data ->> 'username'
  )
  on conflict (id) do update
    set username  = excluded.username,
        full_name = excluded.full_name;
  return new;
end;
$$;

-- 3) REMOVE OLD SEEDED ACCOUNTS (if they exist) ---------------
-- These used real email addresses. We replace them with
-- username-based internal addresses.
do $$
begin
  -- Delete identities first (FK constraint)
  delete from auth.identities
    where user_id in (
      select id from auth.users
      where email in (
        'baccongeine@gmail.com',
        'ananiaanand@gmail.com',
        -- also clean up if migration was partially run before
        'chef_123@caferio.com',
        'admin_123@caferio.com',
        'chef@myapp.app',
        'admin@myapp.app'
      )
    );

  -- Then delete the users (cascades to public.profiles via FK)
  delete from auth.users
    where email in (
      'baccongeine@gmail.com',
      'ananiaanand@gmail.com',
      'chef_123@caferio.com',
      'admin_123@caferio.com',
      'chef@myapp.app',
      'admin@myapp.app'
    );
end;
$$;

-- 4) SEED NEW RESERVED ACCOUNTS -------------------------------
-- Passwords are bcrypt-hashed (cost factor 10) via extensions.crypt().
-- Internal email domain (@myapp.app) is never shown to users,
-- never confirmed, and never sent to any inbox.
-- username-to-email mapping: username + "@myapp.app"
do $$
declare
  seed record;
  uid  uuid;
begin
  for seed in
    select * from (values
      --  internal email                 password  role       username
      ('chef@myapp.app',   'chef',   'kitchen', 'chef'),
      ('admin@myapp.app',  'admin',  'admin',   'admin')
    ) as t (email, pw, role, username)
  loop
    uid := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token,
      email_change_token_new, email_change, email_change_token_current,
      phone_change, phone_change_token, reauthentication_token
    ) values (
      '00000000-0000-0000-0000-000000000000',
      uid,
      'authenticated',
      'authenticated',
      seed.email,
      -- bcrypt hash (bf = blowfish = bcrypt, cost 10)
      extensions.crypt(seed.pw, extensions.gen_salt('bf')),
      now(),
      -- app_metadata: role set here, protected by set_default_role trigger
      jsonb_build_object(
        'provider', 'email',
        'providers', array['email'],
        'role', seed.role
      ),
      -- user_metadata: username and display name
      jsonb_build_object(
        'username',   seed.username,
        'full_name',  seed.username
      ),
      now(), now(),
      '', '', '', '', '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), uid, uid::text,
      jsonb_build_object(
        'sub', uid::text,
        'email', seed.email,
        'email_verified', true
      ),
      'email', now(), now(), now()
    );
  end loop;
end;
$$;

-- 5) VERIFY (optional — check the output tab) -----------------
select
  u.email,
  p.username,
  p.role,
  (u.raw_app_meta_data ->> 'role') as jwt_role
from auth.users u
join public.profiles p on p.id = u.id
where u.email like '%@myapp.app'
order by p.role;
