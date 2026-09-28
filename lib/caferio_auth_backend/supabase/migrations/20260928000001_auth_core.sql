-- =============================================================================
-- CAFERIO — AUTH CORE (username login on top of Supabase Auth)
--
-- What this does
--   * profiles: username + username_normalized (unique), immutable identity
--   * profiles can no longer carry an email (alias lives only in auth.users)
--   * self-signup through GoTrue is BLOCKED at the database (trigger); accounts
--     are created only by the `auth-register` Edge Function (service role)
--   * role is server-controlled; client can never write role / restaurant_id
--   * RLS + column-level grants on profiles / restaurants
--   * service-role-only helper RPCs (login lookup, rate limit, session revoke)
--   * legacy clean-up: forgeable role sources, weak seeded admin/chef accounts
--
-- Safe to re-run. Run in Supabase SQL editor (role: postgres).
-- BACK UP FIRST (Dashboard -> Database -> Backups).
-- =============================================================================

begin;

-- 0. Schemas ------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated, service_role; -- RLS policies call private.* helpers

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where t.typname = 'user_role' and n.nspname = 'public') then
    create type public.user_role as enum ('customer', 'kitchen', 'manager', 'admin');
  end if;
end $$;

create table if not exists public.restaurants (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz default timezone('utc', now()),
  updated_at timestamptz default timezone('utc', now())
);

create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  name          text,
  phone         text,
  role          public.user_role not null default 'customer',
  restaurant_id uuid references public.restaurants (id) on delete set null,
  created_at    timestamptz not null default timezone('utc', now()),
  updated_at    timestamptz not null default timezone('utc', now())
);

-- 1. Username helpers (single source of truth for the rules) --------------------
-- Rules: 3-30 chars, ASCII letters/digits/underscore/hyphen, must start and end
-- with a letter or digit. ASCII-only => no homoglyph / unicode-normalisation abuse.
create or replace function private.normalize_username(p_username text)
returns text
language sql
immutable
set search_path = ''
as $$
  select lower(btrim(p_username));
$$;

create or replace function private.is_valid_username(p_normalized text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_normalized is not null
     and p_normalized ~ '^[a-z0-9][a-z0-9_-]{1,28}[a-z0-9]$';
$$;

-- Names that cannot be self-registered (checked at provisioning, not as a table
-- CHECK, so legacy accounts such as "admin"/"chef" can still exist).
create or replace function private.is_reserved_username(p_normalized text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_normalized = any (array[
    'admin','administrator','root','system','support','staff','kitchen','chef',
    'manager','owner','caferio','cafe','moderator','mod','service','null',
    'undefined','anonymous','guest','help','security','official','api','auth'
  ]);
$$;

-- 2. profiles: add columns, backfill, constrain ---------------------------------
alter table public.profiles add column if not exists username            text;
alter table public.profiles add column if not exists username_normalized text;

-- The guard trigger (created below) must not interfere with this one-off backfill.
drop trigger if exists profiles_guard on public.profiles;
drop trigger if exists profiles_mirror_role on public.profiles;

-- Users that exist in auth.users but have no profile row.
insert into public.profiles (id, role)
select u.id, 'customer'
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;

-- Backfill usernames deterministically (oldest account wins a contested name).
do $$
declare
  r         record;
  candidate text;
  norm      text;
begin
  for r in
    select p.id, p.username as p_username,
           u.raw_user_meta_data ->> 'username' as meta_username,
           split_part(coalesce(u.email, ''), '@', 1) as email_local
    from public.profiles p
    join auth.users u on u.id = p.id
    where p.username_normalized is null or p.username is null
    order by p.created_at, p.id
  loop
    norm := null;
    foreach candidate in array array[r.p_username, r.meta_username, r.email_local] loop
      continue when candidate is null;
      candidate := btrim(candidate);
      if private.is_valid_username(private.normalize_username(candidate))
         and not exists (select 1 from public.profiles x
                         where x.username_normalized = private.normalize_username(candidate)
                           and x.id <> r.id) then
        norm := private.normalize_username(candidate);
        exit;
      end if;
    end loop;

    if norm is null then
      candidate := 'user_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);
      norm := candidate;
    end if;

    update public.profiles
       set username = candidate, username_normalized = norm
     where id = r.id;
  end loop;
end $$;

-- Drop the columns / constraints that must never be client-visible or are redundant.
alter table public.profiles drop column if exists email;
alter table public.profiles drop constraint if exists profiles_username_key;

update public.profiles set role = 'customer' where role is null;
alter table public.profiles alter column role set not null;
alter table public.profiles alter column role set default 'customer';
alter table public.profiles alter column username set not null;
alter table public.profiles alter column username_normalized set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_username_normalized_key') then
    alter table public.profiles
      add constraint profiles_username_normalized_key unique (username_normalized);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_username_normalized_format') then
    alter table public.profiles
      add constraint profiles_username_normalized_format
      check (private.is_valid_username(username_normalized));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_username_consistent') then
    -- display name must equal the normalized name up to letter case, so "Ananya"
    -- and "ananya" can never become two different identities.
    alter table public.profiles
      add constraint profiles_username_consistent
      check (username = btrim(username) and lower(username) = username_normalized);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_username_ascii') then
    -- display form must be plain ASCII too (KELVIN SIGN etc. lowercase to ASCII).
    alter table public.profiles
      add constraint profiles_username_ascii
      check (username ~ '^[A-Za-z0-9][A-Za-z0-9_-]{1,28}[A-Za-z0-9]$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_name_length') then
    alter table public.profiles
      add constraint profiles_name_length check (name is null or char_length(name) <= 80);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_phone_length') then
    alter table public.profiles
      add constraint profiles_phone_length check (phone is null or char_length(phone) <= 32);
  end if;
end $$;

create index if not exists profiles_restaurant_id_idx on public.profiles (restaurant_id);
create index if not exists profiles_role_idx          on public.profiles (role) where role <> 'customer';

-- 3. Role reconciliation --------------------------------------------------------
-- Source of truth = auth.users.raw_app_meta_data->>'role' (writable only with the
-- service role / SQL). A role that exists only in profiles.role could have been
-- self-assigned through the old "update own profile" policy, so it is reset.
do $$
declare
  r record;
  truth text;
begin
  for r in
    select p.id, p.username, p.role::text as old_role,
           coalesce(nullif(u.raw_app_meta_data ->> 'role', ''), 'customer') as claimed
    from public.profiles p
    join auth.users u on u.id = p.id
  loop
    truth := case when r.claimed = any (select unnest(enum_range(null::public.user_role))::text)
                  then r.claimed else 'customer' end;
    if truth <> r.old_role then
      raise notice 'ROLE RESET: % (%) % -> % (profiles.role had no server-side backing)',
        r.username, r.id, r.old_role, truth;
      update public.profiles set role = truth::public.user_role where id = r.id;
    end if;
  end loop;

  update auth.users u
     set raw_app_meta_data = coalesce(u.raw_app_meta_data, '{}'::jsonb)
                             || jsonb_build_object('role', p.role::text)
    from public.profiles p
   where p.id = u.id
     and (u.raw_app_meta_data ->> 'role') is distinct from p.role::text;
end $$;

-- 4. Privileged-account hygiene: ban trivially guessable passwords ---------------
-- The old migration seeded admin/chef accounts with password == username.
-- Any kitchen/manager/admin account whose password equals its own username (or a
-- tiny list of defaults) is banned (reversible) and its sessions revoked.
do $$
declare
  r record;
begin
  for r in
    select u.id, u.email, p.username, p.role::text as role
    from auth.users u
    join public.profiles p on p.id = u.id
    where p.role <> 'customer'
      and coalesce(u.encrypted_password, '') <> ''
      and exists (
        select 1
        from unnest(array[p.username, p.username_normalized, split_part(u.email, '@', 1),
                          'password', '12345678', 'admin', 'chef', 'kitchen']) w
        where extensions.crypt(w, u.encrypted_password) = u.encrypted_password
      )
  loop
    raise warning 'WEAK PRIVILEGED ACCOUNT BANNED: % (role %). Set a strong password via auth-admin-reset-password, then unban.',
      r.username, r.role;
    -- NOT 'infinity': GoTrue (Go) cannot parse it.
    update auth.users set banned_until = timestamptz '2999-12-31 00:00:00+00' where id = r.id;
    begin
      delete from auth.sessions where user_id = r.id;
    exception when undefined_table then null;
    end;
  end loop;
exception when undefined_function or invalid_schema_name then
  raise notice 'extensions.crypt() not available; skipped weak-password check - do it manually.';
end $$;

-- 5. Remove the old, unsafe provisioning path -----------------------------------
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

do $$
begin
  drop function if exists auth.user_role();          -- read role from user_metadata (client-writable)
  drop function if exists auth.user_restaurant_id();
exception when others then
  raise notice 'Could not drop auth.user_role()/user_restaurant_id(): % (drop manually if present)', sqlerrm;
end $$;

-- 6. Private helpers used by RLS ------------------------------------------------
create or replace function private.current_app_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select p.role from public.profiles p where p.id = (select auth.uid())),
    'customer'::public.user_role);
$$;

create or replace function private.current_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.restaurant_id from public.profiles p where p.id = (select auth.uid());
$$;

revoke all on function private.current_app_role()      from public, anon;
revoke all on function private.current_restaurant_id() from public, anon;
grant execute on function private.current_app_role()      to authenticated, service_role;
grant execute on function private.current_restaurant_id() to authenticated, service_role;



-- 7. Account provisioning triggers on auth.users --------------------------------
-- AFTER INSERT: create the profile in the SAME transaction. If the profile
-- insert fails (e.g. unique violation from a concurrent registration) the
-- whole auth.users insert rolls back => no orphan auth user is possible.
create or replace function private.auth_users_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_display text := btrim(new.raw_user_meta_data ->> 'username');
  v_name    text := nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), 80), '');
begin
  insert into public.profiles (id, username, username_normalized, name, role)
  values (new.id, v_display, private.normalize_username(v_display), v_name, 'customer');
  return new;
end;
$$;

drop trigger if exists auth_users_before_insert on auth.users;

drop trigger if exists auth_users_after_insert on auth.users;
create trigger auth_users_after_insert
  after insert on auth.users
  for each row execute function private.auth_users_after_insert();

-- 8. profiles integrity guard ---------------------------------------------------
-- id / username / username_normalized / created_at are immutable for everyone but
-- database owners. role / restaurant_id can only change through privileged code
-- (SECURITY DEFINER functions owned by postgres, or an owner in the SQL editor).
create or replace function private.profiles_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_owner boolean := current_user in ('postgres', 'supabase_admin');
begin
  if not v_owner then
    if new.id is distinct from old.id
       or new.username is distinct from old.username
       or new.username_normalized is distinct from old.username_normalized
       or new.created_at is distinct from old.created_at then
      raise exception 'profile_identity_immutable' using errcode = '42501';
    end if;
    if new.role is distinct from old.role
       or new.restaurant_id is distinct from old.restaurant_id then
      raise exception 'profile_privileged_column' using errcode = '42501';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_guard
  before update on public.profiles
  for each row execute function private.profiles_guard();

-- Mirror role into app_metadata so the JWT carries it (UI routing only; RLS reads
-- profiles.role directly and never trusts the JWT for authorization).
create or replace function private.profiles_mirror_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update auth.users
     set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
                             || jsonb_build_object('role', new.role::text)
   where id = new.id;
  return null;
end;
$$;

create trigger profiles_mirror_role
  after update of role on public.profiles
  for each row when (old.role is distinct from new.role)
  execute function private.profiles_mirror_role();

-- restaurants.updated_at (old helper had no fixed search_path)
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;   -- profiles_guard does it
drop trigger if exists set_restaurants_updated_at on public.restaurants;
create trigger set_restaurants_updated_at
  before update on public.restaurants
  for each row execute function public.handle_updated_at();

-- 9. RLS + grants ---------------------------------------------------------------
alter table public.profiles    enable row level security;
alter table public.restaurants enable row level security;

-- wipe every existing policy on these two tables (names differ between installs)
do $$
declare pol record;
begin
  for pol in select schemaname, tablename, policyname from pg_policies
             where schemaname = 'public' and tablename in ('profiles', 'restaurants')
  loop
    execute format('drop policy %I on %I.%I', pol.policyname, pol.schemaname, pol.tablename);
  end loop;
end $$;

-- Privilege baseline: nothing for anon; minimum for authenticated.
revoke all on public.profiles    from anon, authenticated;
revoke all on public.restaurants from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (name, phone) on public.profiles to authenticated;   -- NOT role / username / id / restaurant_id
grant select on public.restaurants to authenticated;
grant insert, update, delete on public.restaurants to authenticated; -- gated by RLS to admin/manager below

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_select_admin on public.profiles
  for select to authenticated
  using ((select private.current_app_role()) = 'admin');

create policy profiles_select_manager on public.profiles
  for select to authenticated
  using (
    (select private.current_app_role()) = 'manager'
    and restaurant_id is not null
    and restaurant_id = (select private.current_restaurant_id())
    and role <> 'admin'
  );

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Reviewed exception: restaurant name/contact info is intentionally readable by any
-- signed-in user (needed to place an order). Not readable by anon.
create policy restaurants_select_authenticated on public.restaurants
  for select to authenticated
  using (true);

create policy restaurants_admin_all on public.restaurants
  for all to authenticated
  using ((select private.current_app_role()) = 'admin')
  with check ((select private.current_app_role()) = 'admin');

create policy restaurants_manager_update on public.restaurants
  for update to authenticated
  using ((select private.current_app_role()) = 'manager'
         and id = (select private.current_restaurant_id()))
  with check ((select private.current_app_role()) = 'manager'
              and id = (select private.current_restaurant_id()));

-- Old helper RPCs let ANY caller (even anon) look up any user's role by UUID.
do $$
begin
  drop function if exists public.get_user_role(uuid);
  drop function if exists public.get_user_restaurant_id(uuid);
exception when others then
  raise notice 'Could not drop legacy get_user_* helpers: % (drop manually)', sqlerrm;
end $$;

-- 10. Service-role-only RPCs (called by Edge Functions) --------------------------
create table if not exists private.auth_rate_limits (
  key          text primary key check (char_length(key) <= 200),
  window_start timestamptz not null default now(),
  hits         integer     not null default 0
);
alter table private.auth_rate_limits enable row level security;   -- no policies => no client access
revoke all on private.auth_rate_limits from public, anon, authenticated;

-- login lookup: username -> internal alias e-mail. NEVER callable by clients.
create or replace function public.internal_resolve_login_identity(p_username text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select u.email::text
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.username_normalized = private.normalize_username(p_username)
  limit 1;
$$;

create or replace function public.internal_username_of(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.username_normalized from public.profiles p where p.id = p_user_id;
$$;

create or replace function public.internal_username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_valid_username(private.normalize_username(p_username))
     and not private.is_reserved_username(private.normalize_username(p_username))
     and not exists (select 1 from public.profiles p
                     where p.username_normalized = private.normalize_username(p_username));
$$;

-- Fixed-window counter. Returns true while the caller is still within the limit.
create or replace function public.internal_rate_limit(p_key text, p_limit integer, p_window_seconds integer)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hits integer;
begin
  if p_key is null or char_length(p_key) > 200 or p_limit < 1 or p_window_seconds < 1 then
    raise exception 'bad_rate_limit_args';
  end if;

  insert into private.auth_rate_limits as t (key, window_start, hits)
  values (p_key, now(), 1)
  on conflict (key) do update
    set hits = case when t.window_start < now() - make_interval(secs => p_window_seconds)
                    then 1 else t.hits + 1 end,
        window_start = case when t.window_start < now() - make_interval(secs => p_window_seconds)
                            then now() else t.window_start end
  returning t.hits into v_hits;

  if random() < 0.01 then  -- opportunistic garbage collection
    delete from private.auth_rate_limits where window_start < now() - interval '1 day';
  end if;

  return v_hits <= p_limit;
end;
$$;

create or replace function public.internal_rate_limit_reset(p_key text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.auth_rate_limits where key = p_key;
$$;

-- Revoke sessions (all, or all except the caller's current one).
create or replace function public.internal_revoke_sessions(p_user_id uuid, p_except_session uuid default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  delete from auth.sessions
   where user_id = p_user_id
     and (p_except_session is null or id <> p_except_session);
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Admin action: change someone's role. Only callable by a signed-in admin.
create or replace function public.admin_set_user_role(
  p_user_id uuid,
  p_role public.user_role,
  p_restaurant_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or private.current_app_role() <> 'admin' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_user_id = (select auth.uid()) then
    raise exception 'cannot_change_own_role' using errcode = '42501';
  end if;

  update public.profiles
     set role = p_role,
         restaurant_id = coalesce(p_restaurant_id, restaurant_id)
   where id = p_user_id;

  if not found then
    raise exception 'user_not_found' using errcode = 'P0002';
  end if;
end;
$$;

-- Owner action (SQL editor only): bootstrap the first admin / staff.
--   select private.bootstrap_set_role('myusername', 'admin');
create or replace function private.bootstrap_set_role(p_username text, p_role public.user_role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
     set role = p_role
   where username_normalized = private.normalize_username(p_username);
  if not found then
    raise exception 'user_not_found';
  end if;
end;
$$;

-- Function privileges -----------------------------------------------------------
revoke all on function public.internal_resolve_login_identity(text)          from public, anon, authenticated;
revoke all on function public.internal_username_available(text)              from public, anon, authenticated;
revoke all on function public.internal_username_of(uuid)                     from public, anon, authenticated;
grant execute on function public.internal_username_of(uuid)                  to service_role;
revoke all on function public.internal_rate_limit(text, integer, integer)    from public, anon, authenticated;
revoke all on function public.internal_rate_limit_reset(text)                from public, anon, authenticated;
revoke all on function public.internal_revoke_sessions(uuid, uuid)           from public, anon, authenticated;
grant execute on function public.internal_resolve_login_identity(text)       to service_role;
grant execute on function public.internal_username_available(text)           to service_role;
grant execute on function public.internal_rate_limit(text, integer, integer) to service_role;
grant execute on function public.internal_rate_limit_reset(text)             to service_role;
grant execute on function public.internal_revoke_sessions(uuid, uuid)        to service_role;

revoke all on function public.admin_set_user_role(uuid, public.user_role, uuid) from public, anon;
grant execute on function public.admin_set_user_role(uuid, public.user_role, uuid) to authenticated;

revoke all on function private.bootstrap_set_role(text, public.user_role) from public, anon, authenticated, service_role;

revoke all on function private.auth_users_after_insert()  from public, anon, authenticated;
revoke all on function private.profiles_mirror_role()     from public, anon, authenticated;
revoke all on function private.profiles_guard()           from public, anon, authenticated;

commit;
