-- =============================================================================
-- CAFERIO RESTAURANT PLATFORM: SUPABASE AUTHENTICATION & DATA ISOLATION (RLS)
-- =============================================================================
-- Execute this entire script in the Supabase Dashboard -> SQL Editor
-- This script sets up:
--   1. public.profiles table (linked 1:1 with auth.users)
--   2. Automatic Database Trigger on new user signup
--   3. Strict Row Level Security (RLS) policies for complete data isolation
--   4. RLS for user orders and preferences
--   5. Account Deletion procedure
-- =============================================================================

-- Enable UUID extension if not already enabled
create extension if not exists "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1. PROFILES TABLE
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Validation rule: username must be 3-20 chars, letters/numbers/_/. only
  constraint username_format check (
    username ~ '^[a-zA-Z0-9_.]{3,20}$'
  )
);

comment on table public.profiles is 'Public user profile information, strictly isolated via RLS.';

-- -----------------------------------------------------------------------------
-- 2. AUTOMATIC SIGNUP TRIGGER
-- -----------------------------------------------------------------------------
-- When a user registers in Supabase Auth, this trigger automatically creates
-- their corresponding row in public.profiles using their chosen username.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  user_name text;
begin
  -- 1. Extract username from raw_user_meta_data, or fallback to email prefix
  user_name := coalesce(
    new.raw_user_meta_data->>'username',
    split_part(new.email, '@', 1)
  );

  -- 2. Clean and lower-case the username
  user_name := lower(trim(user_name));

  -- 3. Insert new row into public.profiles
  insert into public.profiles (id, username, created_at, updated_at)
  values (new.id, user_name, now(), now())
  on conflict (id) do update
  set username = excluded.username,
      updated_at = now();

  return new;
end;
$$;

-- Drop existing trigger if it exists and recreate
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 3. ROW LEVEL SECURITY (RLS) FOR PROFILES
-- -----------------------------------------------------------------------------
-- Enable Row Level Security to ensure strict multi-tenant isolation
alter table public.profiles enable row level security;

-- Policy 1: Authenticated users can view all usernames (needed for directory/orders)
drop policy if exists "Profiles are viewable by authenticated users" on public.profiles;
create policy "Profiles are viewable by authenticated users"
  on public.profiles
  for select
  to authenticated
  using (true);

-- Policy 2: Users can only insert their own profile
drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

-- Policy 3: Users can only update their own profile
drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Policy 4: Users can only delete their own profile
drop policy if exists "Users can delete own profile" on public.profiles;
create policy "Users can delete own profile"
  on public.profiles
  for delete
  to authenticated
  using (auth.uid() = id);

-- -----------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS) FOR ORDERS
-- -----------------------------------------------------------------------------
-- Ensure one logged-in user can NEVER see or modify another user's orders
alter table if exists public.orders enable row level security;

-- Policy 1: Users can only read their own orders
drop policy if exists "Users can view own orders" on public.orders;
create policy "Users can view own orders"
  on public.orders
  for select
  to authenticated
  using (
    customer_id is not null and auth.uid()::text = customer_id
  );

-- Policy 2: Users can only create orders for themselves
drop policy if exists "Users can create own orders" on public.orders;
create policy "Users can create own orders"
  on public.orders
  for insert
  to authenticated
  with check (
    customer_id is not null and auth.uid()::text = customer_id
  );

-- Policy 3: Users can only update their own orders
drop policy if exists "Users can update own orders" on public.orders;
create policy "Users can update own orders"
  on public.orders
  for update
  to authenticated
  using (
    customer_id is not null and auth.uid()::text = customer_id
  );

-- Policy 4: Users can only delete their own orders
drop policy if exists "Users can delete own orders" on public.orders;
create policy "Users can delete own orders"
  on public.orders
  for delete
  to authenticated
  using (
    customer_id is not null and auth.uid()::text = customer_id
  );

-- -----------------------------------------------------------------------------
-- 5. SECURE ACCOUNT DELETION RPC
-- -----------------------------------------------------------------------------
-- Allows an authenticated user to permanently delete their account from auth.users.
-- Cascading foreign keys will automatically delete public.profiles and related records.
create or replace function public.delete_user()
returns void
language plpgsql
security definer
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;
