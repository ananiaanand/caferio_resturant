-- Minimal stand-in for a Supabase project, ONLY for testing the SQL on plain
-- PostgreSQL. Do NOT run against a real Supabase project.
-- (A real project already has all of this.)

do $$ begin
  if not exists (select from pg_roles where rolname = 'anon')          then create role anon nologin; end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select from pg_roles where rolname = 'service_role')   then create role service_role nologin bypassrls; end if;
end $$;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists auth;

create table auth.users (
  instance_id               uuid,
  id                        uuid primary key,
  aud                       varchar(255),
  role                      varchar(255),
  email                     varchar(255) unique,
  encrypted_password        varchar(255),
  email_confirmed_at        timestamptz,
  raw_app_meta_data         jsonb,
  raw_user_meta_data        jsonb,
  is_anonymous              boolean not null default false,
  banned_until              timestamptz,
  created_at                timestamptz,
  updated_at                timestamptz,
  confirmation_token        varchar(255),
  recovery_token            varchar(255),
  email_change_token_new    varchar(255),
  email_change              varchar(255),
  email_change_token_current varchar(255),
  phone_change              text,
  phone_change_token        varchar(255),
  reauthentication_token    varchar(255)
);

create table auth.identities (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  provider_id text,
  identity_data jsonb,
  provider text,
  last_sign_in_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
);

create table auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz default now()
);

create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

create or replace function auth.role() returns text language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;

grant usage on schema public, extensions to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid(), auth.role() to anon, authenticated, service_role;

-- Supabase's default privileges for objects created in public
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

do $$ begin
  if not exists (select from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;
