-- CAFERIO auth backend: all migrations in order. Paste into Supabase SQL Editor and Run.
-- BACK UP FIRST. Set your alias domain before running if you own one (see README §3):
--   select set_config('caferio.alias_domain','auth.yourdomain.com', false);

-- ===== supabase/migrations/20260928000001_auth_core.sql =====
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
-- (a) BEFORE INSERT: reject anything not created by our Edge Function. Direct calls
--     to GoTrue /signup, anonymous sign-ins and dashboard "add user" all fail here,
--     even if "Allow new users to sign up" is accidentally left ON.
--     raw_app_meta_data can only be set with the service role, never by a client.
create or replace function private.auth_users_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_norm text;
begin
  if coalesce(new.raw_app_meta_data ->> 'caferio_provisioned', '') <> 'true' then
    raise exception 'signup_not_allowed' using errcode = 'P0001';
  end if;

  v_norm := private.normalize_username(new.raw_app_meta_data ->> 'username');
  if not private.is_valid_username(v_norm)
     or btrim(new.raw_app_meta_data ->> 'username') !~ '^[A-Za-z0-9][A-Za-z0-9_-]{1,28}[A-Za-z0-9]$' then
    raise exception 'invalid_username' using errcode = 'P0001';
  end if;
  if private.is_reserved_username(v_norm) then
    raise exception 'reserved_username' using errcode = 'P0001';
  end if;

  -- role is always customer at creation; promotion is a separate, audited action.
  new.raw_app_meta_data := coalesce(new.raw_app_meta_data, '{}'::jsonb)
                           || jsonb_build_object('role', 'customer');
  return new;
end;
$$;

-- (b) AFTER INSERT: create the profile in the SAME transaction. If the profile
--     insert fails (e.g. unique violation from a concurrent registration) the
--     whole auth.users insert rolls back => no orphan auth user is possible.
create or replace function private.auth_users_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_display text := btrim(new.raw_app_meta_data ->> 'username');
  v_name    text := nullif(left(btrim(coalesce(new.raw_app_meta_data ->> 'display_name', '')), 80), '');
begin
  insert into public.profiles (id, username, username_normalized, name, role)
  values (new.id, v_display, private.normalize_username(v_display), v_name, 'customer');
  return new;
end;
$$;

drop trigger if exists auth_users_before_insert on auth.users;
create trigger auth_users_before_insert
  before insert on auth.users
  for each row execute function private.auth_users_before_insert();

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
revoke all on function private.auth_users_before_insert() from public, anon, authenticated;
revoke all on function private.auth_users_after_insert()  from public, anon, authenticated;
revoke all on function private.profiles_mirror_role()     from public, anon, authenticated;
revoke all on function private.profiles_guard()           from public, anon, authenticated;

commit;

-- ===== supabase/migrations/20260928000002_data_rls_hardening.sql =====
-- =============================================================================
-- CAFERIO — DATA LAYER HARDENING (depends on 20260928000001_auth_core.sql)
--
-- Why this exists: authentication is worthless if the data tables behind it are
-- wide open. The old scripts left these readable/writable by ANYONE holding the
-- public anon key:
--     orders / order_items          policy USING (true) WITH CHECK (true)
--     customer_purchases, customer_behaviour_stats, sales, ingredients, ...   RLS off
--     record_order_purchases(uuid,...) etc.   SECURITY DEFINER, no caller check (IDOR)
--
-- Every block is guarded (table/function missing => skipped), safe to re-run.
-- =============================================================================

begin;

-- helper: is the caller kitchen/manager/admin? (reads profiles, never the JWT)
create or replace function private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.current_app_role() in ('kitchen', 'manager', 'admin');
$$;
revoke all on function private.is_staff() from public, anon;
grant execute on function private.is_staff() to authenticated, service_role;

-- 1. orders / order_items --------------------------------------------------------
do $$
begin
  if to_regclass('public.orders') is null then
    raise notice 'orders table not found - skipping orders hardening';
    return;
  end if;

  -- The old FK pointed at an unrelated public.users table, so inserting a real
  -- auth user id could never succeed. Point it at auth.users (NOT VALID keeps
  -- historical rows that reference ids which no longer exist).
  alter table public.orders drop constraint if exists orders_customer_id_fkey;
  alter table public.orders
    add constraint orders_customer_id_fkey
    foreign key (customer_id) references auth.users (id) on delete set null not valid;

  create index if not exists orders_customer_id_idx on public.orders (customer_id);
  create index if not exists orders_status_idx      on public.orders (status);

  alter table public.orders enable row level security;
  drop policy if exists orders_all            on public.orders;
  drop policy if exists orders_select         on public.orders;
  drop policy if exists orders_insert_own     on public.orders;
  drop policy if exists orders_update_staff   on public.orders;
  drop policy if exists orders_delete_admin   on public.orders;

  revoke all on public.orders from anon, authenticated;
  grant select on public.orders to authenticated;
  grant insert (restaurant_id, customer_id, status, total_amount) on public.orders to authenticated;
  grant update (status, served_at) on public.orders to authenticated;

  create policy orders_select on public.orders
    for select to authenticated
    using (customer_id = (select auth.uid()) or (select private.is_staff()));

  create policy orders_insert_own on public.orders
    for insert to authenticated
    with check (customer_id = (select auth.uid()) and status = 'received');

  create policy orders_update_staff on public.orders
    for update to authenticated
    using ((select private.is_staff()))
    with check ((select private.is_staff()));
end $$;

do $$
begin
  if to_regclass('public.order_items') is null then
    return;
  end if;

  alter table public.order_items enable row level security;
  drop policy if exists order_items_all        on public.order_items;
  drop policy if exists order_items_select     on public.order_items;
  drop policy if exists order_items_insert_own on public.order_items;

  revoke all on public.order_items from anon, authenticated;
  grant select on public.order_items to authenticated;
  grant insert (order_id, menu_item_id, quantity) on public.order_items to authenticated;

  -- The sub-select runs under the caller's RLS on orders, so an item is visible
  -- exactly when its order is visible.
  create policy order_items_select on public.order_items
    for select to authenticated
    using (exists (select 1 from public.orders o where o.id = order_items.order_id));

  create policy order_items_insert_own on public.order_items
    for insert to authenticated
    with check (
      quantity between 1 and 100
      and exists (select 1 from public.orders o
                  where o.id = order_items.order_id
                    and o.customer_id = (select auth.uid()))
    );
end $$;

-- 2. recommendation tables (per-customer data) ------------------------------------
do $$
declare
  v_type text;
begin
  if to_regclass('public.customer_purchases') is not null then
    select data_type into v_type from information_schema.columns
     where table_schema = 'public' and table_name = 'customer_purchases' and column_name = 'customer_id';

    alter table public.customer_purchases enable row level security;
    drop policy if exists customer_purchases_select_own on public.customer_purchases;
    drop policy if exists customer_purchases_insert_own on public.customer_purchases;
    revoke all on public.customer_purchases from anon, authenticated;
    grant select, insert on public.customer_purchases to authenticated;

    execute format($p$create policy customer_purchases_select_own on public.customer_purchases
                      for select to authenticated using (customer_id::text = (select auth.uid())::text)$p$);
    execute format($p$create policy customer_purchases_insert_own on public.customer_purchases
                      for insert to authenticated with check (customer_id::text = (select auth.uid())::text)$p$);

    -- text-typed customer_id has no FK => clean up on account deletion
    if v_type = 'text' then
      create or replace function private.profiles_cleanup_purchases()
      returns trigger language plpgsql security definer set search_path = '' as $f$
      begin
        delete from public.customer_purchases where customer_id = old.id::text;
        return old;
      end $f$;
      drop trigger if exists profiles_cleanup_purchases on public.profiles;
      create trigger profiles_cleanup_purchases after delete on public.profiles
        for each row execute function private.profiles_cleanup_purchases();
    end if;
  end if;

  if to_regclass('public.customer_behaviour_stats') is not null then
    alter table public.customer_behaviour_stats enable row level security;
    drop policy if exists customer_behaviour_stats_select_own on public.customer_behaviour_stats;
    revoke all on public.customer_behaviour_stats from anon, authenticated;
    grant select on public.customer_behaviour_stats to authenticated;
    create policy customer_behaviour_stats_select_own on public.customer_behaviour_stats
      for select to authenticated using (customer_id = (select auth.uid()));
  end if;

  if to_regclass('public.item_co_occurrences') is not null then
    alter table public.item_co_occurrences enable row level security;
    drop policy if exists item_co_occurrences_select on public.item_co_occurrences;
    revoke all on public.item_co_occurrences from anon, authenticated;
    grant select on public.item_co_occurrences to authenticated;
    create policy item_co_occurrences_select on public.item_co_occurrences
      for select to authenticated using (true);   -- aggregate, non-personal counters
  end if;
end $$;

-- 3. Recommendation RPCs: close the IDOR ---------------------------------------------
-- The uuid overloads are SECURITY DEFINER and trusted the p_customer_id argument, so
-- any caller could read/write any customer's data. Each is renamed to *_impl (locked
-- down, fixed search_path) and replaced by a wrapper that enforces p_customer_id =
-- auth.uid().
do $$
declare
  v_impl text;
begin
  -- record_order_purchases(uuid, uuid, jsonb, numeric)
  if to_regprocedure('public.record_order_purchases(uuid,uuid,jsonb,numeric)') is not null
     and to_regprocedure('public.record_order_purchases_impl(uuid,uuid,jsonb,numeric)') is null then
    alter function public.record_order_purchases(uuid, uuid, jsonb, numeric) rename to record_order_purchases_impl;
    alter function public.record_order_purchases_impl(uuid, uuid, jsonb, numeric) set search_path = public, pg_temp;
    revoke all on function public.record_order_purchases_impl(uuid, uuid, jsonb, numeric) from public, anon, authenticated;

    create function public.record_order_purchases(
      p_order_id uuid, p_customer_id uuid, p_items jsonb, p_order_total numeric default 0)
    returns void language plpgsql security definer set search_path = ''
    as $f$
    begin
      if (select auth.uid()) is null or p_customer_id is distinct from (select auth.uid()) then
        raise exception 'forbidden' using errcode = '42501';
      end if;
      perform public.record_order_purchases_impl(p_order_id, p_customer_id, p_items, p_order_total);
    end $f$;
  end if;

  -- get_customer_behaviour_insights(uuid)
  if to_regprocedure('public.get_customer_behaviour_insights(uuid)') is not null
     and to_regprocedure('public.get_customer_behaviour_insights_impl(uuid)') is null then
    alter function public.get_customer_behaviour_insights(uuid) rename to get_customer_behaviour_insights_impl;
    alter function public.get_customer_behaviour_insights_impl(uuid) set search_path = public, pg_temp;
    revoke all on function public.get_customer_behaviour_insights_impl(uuid) from public, anon, authenticated;

    create function public.get_customer_behaviour_insights(p_customer_id uuid)
    returns jsonb language plpgsql security definer set search_path = ''
    as $f$
    begin
      if (select auth.uid()) is null or p_customer_id is distinct from (select auth.uid()) then
        raise exception 'forbidden' using errcode = '42501';
      end if;
      return public.get_customer_behaviour_insights_impl(p_customer_id);
    end $f$;
  end if;

  -- get_personalized_recommendations(uuid, text[], integer)
  if to_regprocedure('public.get_personalized_recommendations(uuid,text[],integer)') is not null
     and to_regprocedure('public.get_personalized_recommendations_impl(uuid,text[],integer)') is null then
    v_impl := pg_get_function_result('public.get_personalized_recommendations(uuid,text[],integer)'::regprocedure);
    alter function public.get_personalized_recommendations(uuid, text[], integer) rename to get_personalized_recommendations_impl;
    alter function public.get_personalized_recommendations_impl(uuid, text[], integer) set search_path = public, pg_temp;
    revoke all on function public.get_personalized_recommendations_impl(uuid, text[], integer) from public, anon, authenticated;

    execute format($f$
      create function public.get_personalized_recommendations(
        p_customer_id uuid default null,
        p_cart_item_ids text[] default '{}'::text[],
        p_limit integer default 6)
      returns %s language plpgsql security definer set search_path = ''
      as $body$
      begin
        if p_customer_id is not null
           and ((select auth.uid()) is null or p_customer_id is distinct from (select auth.uid())) then
          raise exception 'forbidden' using errcode = '42501';
        end if;
        return query select * from public.get_personalized_recommendations_impl(p_customer_id, p_cart_item_ids, p_limit);
      end $body$ $f$, v_impl);
  end if;
end $$;

-- Whatever overloads exist now: nobody anonymous may execute them.
do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('record_order_purchases', 'get_customer_behaviour_insights',
                        'get_personalized_recommendations')
  loop
    execute format('revoke all on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated, service_role', f.sig);
  end loop;
end $$;

-- 4. Business tables the mobile client never touches: staff-only ------------------------
do $$
declare
  t text;
begin
  -- menu_items: readable by any signed-in user, writable by admin/manager
  if to_regclass('public.menu_items') is not null then
    alter table public.menu_items enable row level security;
    drop policy if exists menu_items_select on public.menu_items;
    drop policy if exists menu_items_write  on public.menu_items;
    revoke all on public.menu_items from anon, authenticated;
    grant select, insert, update, delete on public.menu_items to authenticated;
    create policy menu_items_select on public.menu_items for select to authenticated using (true);
    create policy menu_items_write  on public.menu_items for all to authenticated
      using ((select private.current_app_role()) in ('manager', 'admin'))
      with check ((select private.current_app_role()) in ('manager', 'admin'));
  end if;

  -- stock tables: staff only
  foreach t in array array['ingredients', 'ingredient_usage'] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I enable row level security', t);
      execute format('drop policy if exists %I on public.%I', t || '_staff', t);
      execute format('revoke all on public.%I from anon, authenticated', t);
      execute format('grant select, insert, update, delete on public.%I to authenticated', t);
      execute format($p$create policy %I on public.%I for all to authenticated
                        using ((select private.is_staff())) with check ((select private.is_staff()))$p$,
                     t || '_staff', t);
    end if;
  end loop;

  -- sales: managers/admins read, admins write
  if to_regclass('public.sales') is not null then
    alter table public.sales enable row level security;
    drop policy if exists sales_select on public.sales;
    drop policy if exists sales_write  on public.sales;
    revoke all on public.sales from anon, authenticated;
    grant select, insert, update, delete on public.sales to authenticated;
    create policy sales_select on public.sales for select to authenticated
      using ((select private.current_app_role()) in ('manager', 'admin'));
    create policy sales_write on public.sales for all to authenticated
      using ((select private.current_app_role()) = 'admin')
      with check ((select private.current_app_role()) = 'admin');
  end if;

  -- legacy public.users table (unused by the app; had an e-mail column, RLS off)
  if to_regclass('public.users') is not null then
    alter table public.users enable row level security;   -- no policies => no client access
    revoke all on public.users from anon, authenticated;
  end if;
end $$;

commit;

-- ===== supabase/migrations/20260928000003_rotate_legacy_aliases.sql =====
-- =============================================================================
-- CAFERIO — ROTATE PREDICTABLE LEGACY ALIASES
--
-- The old app logged in as  <username>@myapp.app  — guessable by anyone, which lets an
-- attacker call Supabase's public /auth/v1/token endpoint directly and brute-force a known
-- account while bypassing the app's own login limiter. This gives every account whose
-- alias is not already a random one a fresh 128-bit alias:  u<32 hex>@<alias domain>.
--
-- Run AFTER migrations 1 and 2. Safe to re-run (already-random aliases are skipped).
-- Use the same domain as the ALIAS_DOMAIN Edge Function secret:
--     select set_config('caferio.alias_domain', 'auth.yourdomain.com', false);   -- optional; default below
-- Users are NOT affected: they log in with their username; nothing they know changes.
-- =============================================================================
begin;

do $$
declare
  v_domain text := coalesce(nullif(current_setting('caferio.alias_domain', true), ''), 'caferio-auth.invalid');
  r        record;
  v_new    text;
  n        integer := 0;
begin
  if v_domain !~ '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$' then
    raise exception 'bad alias domain: %', v_domain;
  end if;

  for r in
    select u.id, u.email
    from auth.users u
    join public.profiles p on p.id = u.id
    where u.email is null or u.email !~ '^u[0-9a-f]{32}@'
  loop
    v_new := 'u' || replace(gen_random_uuid()::text, '-', '') || '@' || v_domain;

    update auth.users
       set email = v_new,
           raw_user_meta_data = case when raw_user_meta_data ? 'email'
                                     then raw_user_meta_data || jsonb_build_object('email', v_new)
                                     else raw_user_meta_data end,
           updated_at = now()
     where id = r.id;

    if to_regclass('auth.identities') is not null then
      update auth.identities
         set identity_data = coalesce(identity_data, '{}'::jsonb) || jsonb_build_object('email', v_new),
             provider_id   = case when provider_id = r.email then v_new else provider_id end,
             updated_at    = now()
       where user_id = r.id and provider = 'email';
    end if;
    n := n + 1;
  end loop;

  raise notice 'rotated % legacy alias(es)', n;
end $$;

commit;

