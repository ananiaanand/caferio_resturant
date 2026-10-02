-- =============================================================================
-- CAFERIO: Production RLS Policies for Orders
-- Run this in your Supabase SQL Editor to secure your tables for production!
-- =============================================================================

-- 1. Remove the completely open development policies
DROP POLICY IF EXISTS "orders_all" ON orders;
DROP POLICY IF EXISTS "order_items_all" ON order_items;

-- =============================================================================
-- ORDERS POLICIES
-- =============================================================================

-- Allow users to SELECT their own orders, AND allow staff (kitchen/admin/manager) to see ALL orders.
CREATE POLICY "orders_select_policy" ON orders FOR SELECT USING (
  customer_id = auth.uid() OR 
  (SELECT private.current_app_role()) IN ('kitchen'::public.user_role, 'manager'::public.user_role, 'admin'::public.user_role)
);

-- Allow authenticated users to INSERT their own orders, or anonymous users to insert orders (guest checkout).
CREATE POLICY "orders_insert_policy" ON orders FOR INSERT WITH CHECK (
  (auth.role() = 'authenticated' AND customer_id = auth.uid()) OR 
  (auth.role() = 'anon' AND customer_id IS NULL)
);

-- Only allow kitchen, manager, and admin to UPDATE order statuses.
CREATE POLICY "orders_update_policy" ON orders FOR UPDATE USING (
  (SELECT private.current_app_role()) IN ('kitchen'::public.user_role, 'manager'::public.user_role, 'admin'::public.user_role)
);

-- =============================================================================
-- ORDER ITEMS POLICIES
-- =============================================================================

-- Users can see their own order items; staff can see all order items.
CREATE POLICY "order_items_select_policy" ON order_items FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM orders 
    WHERE orders.id = order_items.order_id 
    AND (orders.customer_id = auth.uid() OR (SELECT private.current_app_role()) IN ('kitchen'::public.user_role, 'manager'::public.user_role, 'admin'::public.user_role))
  )
);

-- Users can insert items into their own orders.
CREATE POLICY "order_items_insert_policy" ON order_items FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM orders 
    WHERE orders.id = order_items.order_id 
    AND (orders.customer_id = auth.uid() OR (auth.role() = 'anon' AND orders.customer_id IS NULL))
  )
);
