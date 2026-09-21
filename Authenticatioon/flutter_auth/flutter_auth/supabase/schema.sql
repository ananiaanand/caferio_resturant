-- ============================================================
-- Run whole file once in Supabase Dashboard -> SQL Editor.
-- ============================================================

-- 1) PROFILES ------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text not null,
  full_name  text,
  role       text not null default 'user' check (role in ('admin', 'kitchen', 'user')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- 2) ROLE HELPER (reads role from the caller's JWT) ----------
create or replace function public.jwt_role()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', 'user');
$$;

-- 3) RLS POLICIES --------------------------------------------
drop policy if exists "read own profile"  on public.profiles;
drop policy if exists "admin read all"    on public.profiles;

create policy "read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "admin read all"
  on public.profiles for select
  using (public.jwt_role() = 'admin');

-- No insert/update/delete policies: clients cannot write profiles or
-- escalate their own role. Only the triggers below (security definer) write.

-- 4) TRIGGERS ------------------------------------------------
-- 4a) Make sure every new auth user has app_metadata.role.
--     Normal signups have none -> 'user'. Seeded accounts set it explicitly.
--     Clients can NOT set app_metadata on signup (only user_metadata).
create or replace function public.set_default_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.raw_app_meta_data :=
    coalesce(new.raw_app_meta_data, '{}'::jsonb)
    || jsonb_build_object(
         'role', coalesce(new.raw_app_meta_data ->> 'role', 'user')
       );
  return new;
end;
$$;

drop trigger if exists before_auth_user_insert on auth.users;
create trigger before_auth_user_insert
  before insert on auth.users
  for each row execute function public.set_default_role();

-- 4b) Mirror the new auth user into public.profiles.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_app_meta_data ->> 'role'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5) SEED RESERVED ACCOUNTS ----------------------------------
-- Inserted straight into auth tables, so they exist before anyone can
-- sign up with those emails (signup with them will fail: "already registered").
-- Must run AFTER the triggers above so profiles rows get created.
do $$
declare
  seed record;
  uid  uuid;
begin
  for seed in
    select * from (values
      ('baccongeine@gmail.com', 'chef',  'kitchen'),
      ('ananiaanand@gmail.com', 'admin', 'admin')
    ) as t (email, pw, role)
  loop
    if not exists (select 1 from auth.users where email = seed.email) then
      uid := gen_random_uuid();

      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at,
        confirmation_token, recovery_token,
        email_change_token_new, email_change, email_change_token_current,
        phone_change, phone_change_token, reauthentication_token
      ) values (
        '00000000-0000-0000-0000-000000000000', uid,
        'authenticated', 'authenticated', seed.email,
        extensions.crypt(seed.pw, extensions.gen_salt('bf')),
        now(),
        jsonb_build_object('provider', 'email', 'providers', array['email'], 'role', seed.role),
        '{}'::jsonb,
        now(), now(),
        '', '', '', '', '', '', '', ''
      );

      insert into auth.identities (
        id, user_id, provider_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
      ) values (
        gen_random_uuid(), uid, uid::text,
        jsonb_build_object('sub', uid::text, 'email', seed.email, 'email_verified', true),
        'email', now(), now(), now()
      );
    end if;
  end loop;
end;
$$;
