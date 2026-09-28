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
