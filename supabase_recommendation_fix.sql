-- =============================================================================
-- CAFERIO: Recommendation Engine Supabase Setup
-- Run this in Supabase SQL Editor to resolve RPC errors
-- =============================================================================

-- 1. Create customer_purchases table if not exists
CREATE TABLE IF NOT EXISTS public.customer_purchases (
    id SERIAL PRIMARY KEY,
    customer_id TEXT NOT NULL,
    order_id TEXT,
    item_id TEXT NOT NULL,
    item_name TEXT,
    category TEXT,
    quantity INTEGER DEFAULT 1,
    price NUMERIC,
    order_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

-- 2. Mock get_personalized_recommendations function
CREATE OR REPLACE FUNCTION public.get_personalized_recommendations(
    p_customer_id TEXT DEFAULT NULL,
    p_cart_item_ids TEXT[] DEFAULT '{}',
    p_limit INTEGER DEFAULT 6
)
RETURNS TABLE (
    item_id TEXT,
    score NUMERIC
) AS $$
BEGIN
    -- Just returning empty to let the Flutter app use its intelligent local fallback
    -- In a real scenario, this would query customer_purchases and apply collaborative filtering
    RETURN;
END;
$$ LANGUAGE plpgsql;


-- 3. Mock get_customer_behaviour_insights function
CREATE OR REPLACE FUNCTION public.get_customer_behaviour_insights(
    p_customer_id TEXT
)
RETURNS JSON AS $$
DECLARE
    purchase_count INT;
    fav_category TEXT;
    fav_item TEXT;
BEGIN
    -- Count purchases for this customer
    SELECT count(*) INTO purchase_count FROM public.customer_purchases WHERE customer_id = p_customer_id;
    
    IF purchase_count = 0 THEN
        RETURN json_build_object('hasHistory', false, 'customerId', p_customer_id);
    END IF;

    -- Get favorite category
    SELECT category INTO fav_category FROM public.customer_purchases 
    WHERE customer_id = p_customer_id 
    GROUP BY category ORDER BY sum(quantity) DESC LIMIT 1;
    
    -- Get favorite item name
    SELECT item_name INTO fav_item FROM public.customer_purchases 
    WHERE customer_id = p_customer_id 
    GROUP BY item_name ORDER BY sum(quantity) DESC LIMIT 1;

    RETURN json_build_object(
        'hasHistory', true,
        'customerId', p_customer_id,
        'favoriteCategory', fav_category,
        'favoriteItem', fav_item,
        'totalOrders', purchase_count
    );
END;
$$ LANGUAGE plpgsql;


-- 4. record_order_purchases function
CREATE OR REPLACE FUNCTION public.record_order_purchases(
    p_order_id TEXT,
    p_customer_id TEXT,
    p_items JSONB,
    p_order_total NUMERIC
)
RETURNS VOID AS $$
DECLARE
    item JSONB;
BEGIN
    FOR item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO public.customer_purchases (customer_id, order_id, item_id, item_name, category, quantity, price)
        VALUES (
            p_customer_id, 
            p_order_id, 
            item->>'item_id', 
            item->>'item_name', 
            item->>'category', 
            (item->>'quantity')::INT, 
            (item->>'price')::NUMERIC
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;
