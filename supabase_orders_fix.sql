-- =============================================================================
-- CAFERIO: Minimal fix to make order placement work
-- Run this ONE TIME in Supabase SQL Editor > New Query > Run
-- =============================================================================

-- 1. Drop FK constraint on order_items.menu_item_id so we can store text IDs
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_menu_item_id_fkey;

-- 2. Change menu_item_id column type from UUID to TEXT (to match app's string IDs)
ALTER TABLE order_items ALTER COLUMN menu_item_id TYPE TEXT USING menu_item_id::text;

-- 3. Add created_at to orders (needed for sorting & display)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now());

-- 4. Add served_at to orders (for tracking when order was served)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS served_at TIMESTAMP WITH TIME ZONE;

-- 5. Enable Realtime for orders and order_items (so kitchen gets live updates)
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE order_items;

-- 6. Row Level Security — allow all reads and writes (for dev; tighten for prod)
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_all" ON orders;
CREATE POLICY "orders_all" ON orders FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "order_items_all" ON order_items;
CREATE POLICY "order_items_all" ON order_items FOR ALL USING (true) WITH CHECK (true);

-- Done! Your app can now place and track orders.
