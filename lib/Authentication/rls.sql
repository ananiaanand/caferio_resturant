-- Example: a profiles table locked down with Row Level Security.
-- Run in Supabase Dashboard -> SQL Editor. Swap "profiles" for your own table.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- 1) Users can only read their own row.
create policy "Users can read own profile"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

-- 2) Users can only insert their own row.
create policy "Users can insert own profile"
  on public.profiles
  for insert
  to authenticated
  with check ((select auth.uid()) = id);

-- 3) Users can only update their own row.
create policy "Users can update own profile"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- 4) RESTRICTIVE policy: even with a valid login, the session must have
--    passed MFA (aal2). Restrictive policies are ANDed with the ones above.
create policy "Require MFA for profiles"
  on public.profiles
  as restrictive
  to authenticated
  using ((select auth.jwt() ->> 'aal') = 'aal2');
