-- ==============================================================================
-- CAFERIO: PERSONALIZED CUSTOMER RECOMMENDATION SYSTEM SCHEMA & RPC FUNCTIONS
-- ==============================================================================

-- 1. Customer Purchases Table
-- Tracks individual line item purchases for granular customer behavior analysis
CREATE TABLE IF NOT EXISTS customer_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    order_id UUID,
    item_id TEXT NOT NULL,
    item_name TEXT NOT NULL,
    category TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    price NUMERIC NOT NULL DEFAULT 0,
    order_date TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS idx_customer_purchases_customer ON customer_purchases(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_purchases_item ON customer_purchases(item_id);
CREATE INDEX IF NOT EXISTS idx_customer_purchases_date ON customer_purchases(order_date);

-- 2. Customer Behaviour Statistics (Precomputed & Cached for High Performance)
CREATE TABLE IF NOT EXISTS customer_behaviour_stats (
    customer_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    total_orders INTEGER NOT NULL DEFAULT 0,
    total_spend NUMERIC NOT NULL DEFAULT 0,
    avg_order_value NUMERIC NOT NULL DEFAULT 0,
    favorite_categories JSONB NOT NULL DEFAULT '{}'::jsonb, -- e.g. {"Curry": 12, "Starters": 8}
    frequent_items JSONB NOT NULL DEFAULT '{}'::jsonb,      -- e.g. {"3": 10, "1": 7}
    recent_items JSONB NOT NULL DEFAULT '[]'::jsonb,        -- array of recent item IDs
    preferred_hour INTEGER DEFAULT NULL,                    -- 0 - 23 peak ordering hour
    preferred_day INTEGER DEFAULT NULL,                     -- 0 - 6 day of week
    last_order_date TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

-- 3. Item Co-occurrences Table (Items Frequently Purchased Together)
CREATE TABLE IF NOT EXISTS item_co_occurrences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_a_id TEXT NOT NULL,
    item_b_id TEXT NOT NULL,
    pair_frequency INTEGER NOT NULL DEFAULT 1,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now()),
    CONSTRAINT unique_item_pair UNIQUE (item_a_id, item_b_id)
);

CREATE INDEX IF NOT EXISTS idx_item_co_occurrences_a ON item_co_occurrences(item_a_id);
CREATE INDEX IF NOT EXISTS idx_item_co_occurrences_b ON item_co_occurrences(item_b_id);

-- ==============================================================================
-- RPC FUNCTION: Record Order Purchases and Update Behavior & Co-occurrences
-- ==============================================================================
CREATE OR REPLACE FUNCTION record_order_purchases(
    p_order_id UUID,
    p_customer_id UUID,
    p_items JSONB,
    p_order_total NUMERIC DEFAULT 0
) RETURNS VOID AS $$
DECLARE
    item RECORD;
    item_arr TEXT[];
    i INT;
    j INT;
    item_a TEXT;
    item_b TEXT;
    curr_hour INT := EXTRACT(HOUR FROM timezone('utc', now()));
    curr_day INT := EXTRACT(DOW FROM timezone('utc', now()));
BEGIN
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RETURN;
    END IF;

    -- 1. Insert line items into customer_purchases
    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
        item_id TEXT,
        item_name TEXT,
        category TEXT,
        quantity INT,
        price NUMERIC
    )
    LOOP
        INSERT INTO customer_purchases (
            customer_id,
            order_id,
            item_id,
            item_name,
            category,
            quantity,
            price,
            order_date
        ) VALUES (
            p_customer_id,
            p_order_id,
            item.item_id,
            COALESCE(item.item_name, 'Unknown'),
            COALESCE(item.category, 'General'),
            COALESCE(item.quantity, 1),
            COALESCE(item.price, 0),
            timezone('utc', now())
        );

        item_arr := array_append(item_arr, item.item_id);
    END LOOP;

    -- 2. Update Item-to-Item Co-occurrence Matrix
    IF array_length(item_arr, 1) > 1 THEN
        FOR i IN 1..array_length(item_arr, 1) LOOP
            FOR j IN 1..array_length(item_arr, 1) LOOP
                IF i <> j THEN
                    item_a := item_arr[i];
                    item_b := item_arr[j];

                    INSERT INTO item_co_occurrences (item_a_id, item_b_id, pair_frequency, last_updated)
                    VALUES (item_a, item_b, 1, timezone('utc', now()))
                    ON CONFLICT (item_a_id, item_b_id)
                    DO UPDATE SET
                        pair_frequency = item_co_occurrences.pair_frequency + 1,
                        last_updated = timezone('utc', now());
                END IF;
            END LOOP;
        END LOOP;
    END IF;

    -- 3. Update Customer Behaviour Statistics (if customer_id provided)
    IF p_customer_id IS NOT NULL THEN
        WITH cust_data AS (
            SELECT
                COUNT(DISTINCT order_id) AS total_orders,
                COALESCE(SUM(price * quantity), 0) AS total_spend,
                COALESCE(AVG(price * quantity), 0) AS avg_order_val
            FROM customer_purchases
            WHERE customer_id = p_customer_id
        ),
        fav_cats AS (
            SELECT jsonb_object_agg(category, count) AS categories_map
            FROM (
                SELECT category, COUNT(*) as count
                FROM customer_purchases
                WHERE customer_id = p_customer_id
                GROUP BY category
                ORDER BY count DESC
                LIMIT 10
            ) c
        ),
        freq_items AS (
            SELECT jsonb_object_agg(item_id, count) AS items_map
            FROM (
                SELECT item_id, COUNT(*) as count
                WHERE customer_id = p_customer_id
                GROUP BY item_id
                ORDER BY count DESC
                LIMIT 15
            ) f
        ),
        rec_items AS (
            SELECT COALESCE(jsonb_agg(item_id), '[]'::jsonb) AS recent_arr
            FROM (
                SELECT DISTINCT item_id, MAX(order_date) as max_date
                FROM customer_purchases
                WHERE customer_id = p_customer_id
                GROUP BY item_id
                ORDER BY max_date DESC
                LIMIT 8
            ) r
        )
        INSERT INTO customer_behaviour_stats (
            customer_id,
            total_orders,
            total_spend,
            avg_order_value,
            favorite_categories,
            frequent_items,
            recent_items,
            preferred_hour,
            preferred_day,
            last_order_date,
            updated_at
        )
        SELECT
            p_customer_id,
            cd.total_orders,
            cd.total_spend,
            CASE WHEN cd.total_orders > 0 THEN cd.total_spend / cd.total_orders ELSE 0 END,
            COALESCE(fc.categories_map, '{}'::jsonb),
            COALESCE(fi.items_map, '{}'::jsonb),
            COALESCE(ri.recent_arr, '[]'::jsonb),
            curr_hour,
            curr_day,
            timezone('utc', now()),
            timezone('utc', now())
        FROM cust_data cd
        CROSS JOIN fav_cats fc
        CROSS JOIN freq_items fi
        CROSS JOIN rec_items ri
        ON CONFLICT (customer_id)
        DO UPDATE SET
            total_orders = EXCLUDED.total_orders,
            total_spend = EXCLUDED.total_spend,
            avg_order_value = EXCLUDED.avg_order_value,
            favorite_categories = EXCLUDED.favorite_categories,
            frequent_items = EXCLUDED.frequent_items,
            recent_items = EXCLUDED.recent_items,
            preferred_hour = EXCLUDED.preferred_hour,
            preferred_day = EXCLUDED.preferred_day,
            last_order_date = timezone('utc', now()),
            updated_at = timezone('utc', now());
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- RPC FUNCTION: Get Personalized Recommendations
-- Rule-Based Scoring based on:
-- 1. Customer purchase frequency (weight: 2.5)
-- 2. Recency / repeat interest (weight: 1.5)
-- 3. Co-occurrence with items currently in cart / last ordered (weight: 3.5)
-- 4. Category affinity (weight: 1.2)
-- 5. Global popularity / top picks fallback (weight: 0.8)
-- ==============================================================================
CREATE OR REPLACE FUNCTION get_personalized_recommendations(
    p_customer_id UUID DEFAULT NULL,
    p_cart_item_ids TEXT[] DEFAULT '{}'::TEXT[],
    p_limit INT DEFAULT 6
) RETURNS TABLE (
    item_id TEXT,
    item_name TEXT,
    category TEXT,
    price NUMERIC,
    score NUMERIC,
    reason_tag TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH candidate_scores AS (
        SELECT
            cp.item_id,
            cp.item_name,
            cp.category,
            cp.price,
            -- Frequency Score (User-specific)
            COALESCE(
                (SELECT COUNT(*)::NUMERIC 
                 FROM customer_purchases p 
                 WHERE p.customer_id = p_customer_id AND p.item_id = cp.item_id), 
                0
            ) * 2.5 AS frequency_score,

            -- Recency Score (User-specific: ordered within 30 days)
            COALESCE(
                (SELECT CASE 
                    WHEN MAX(p.order_date) > timezone('utc', now()) - INTERVAL '7 days' THEN 2.0
                    WHEN MAX(p.order_date) > timezone('utc', now()) - INTERVAL '30 days' THEN 1.0
                    ELSE 0.5 END
                 FROM customer_purchases p 
                 WHERE p.customer_id = p_customer_id AND p.item_id = cp.item_id),
                0
            ) * 1.5 AS recency_score,

            -- Cart Co-occurrence Score (Frequently bought with items currently in cart)
            COALESCE(
                (SELECT SUM(pair_frequency)::NUMERIC
                 FROM item_co_occurrences ico
                 WHERE ico.item_a_id = ANY(p_cart_item_ids) AND ico.item_b_id = cp.item_id),
                0
            ) * 3.5 AS co_occurrence_score,

            -- Category Affinity Score
            COALESCE(
                (SELECT COUNT(*)::NUMERIC
                 FROM customer_purchases p
                 WHERE p.customer_id = p_customer_id AND p.category = cp.category),
                0
            ) * 1.2 AS category_score,

            -- Global Popularity
            COUNT(*)::NUMERIC * 0.8 AS popularity_score
        FROM customer_purchases cp
        WHERE (p_cart_item_ids IS NULL OR NOT (cp.item_id = ANY(p_cart_item_ids))) -- Avoid recommending items already in active cart
        GROUP BY cp.item_id, cp.item_name, cp.category, cp.price
    ),
    scored AS (
        SELECT
            cs.item_id,
            cs.item_name,
            cs.category,
            cs.price,
            (cs.frequency_score + cs.recency_score + cs.co_occurrence_score + cs.category_score + cs.popularity_score) AS final_score,
            CASE
                WHEN cs.co_occurrence_score > 0 THEN '🔥 Frequently Paired'
                WHEN cs.frequency_score >= 5 THEN '⭐ Your Favorite'
                WHEN cs.frequency_score > 0 THEN '🔄 Order Again'
                WHEN cs.category_score > 0 THEN '✨ Recommended for You'
                ELSE '🏆 Popular Choice'
            END AS calculated_reason
        FROM candidate_scores cs
    )
    SELECT
        s.item_id,
        s.item_name,
        s.category,
        s.price,
        ROUND(s.final_score, 2) AS score,
        s.calculated_reason AS reason_tag
    FROM scored s
    ORDER BY s.final_score DESC, s.price DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- RPC FUNCTION: Get Customer Behaviour Insights (for Profile & ML feature vector)
-- ==============================================================================
CREATE OR REPLACE FUNCTION get_customer_behaviour_insights(
    p_customer_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_stats RECORD;
BEGIN
    SELECT * INTO v_stats FROM customer_behaviour_stats WHERE customer_id = p_customer_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'has_history', false,
            'total_orders', 0,
            'avg_order_value', 0,
            'favorite_categories', '{}'::jsonb,
            'frequent_items', '{}'::jsonb,
            'recent_items', '[]'::jsonb,
            'preferred_hour', null,
            'preferred_day', null,
            'last_order_date', null
        );
    END IF;

    RETURN jsonb_build_object(
        'has_history', true,
        'customer_id', v_stats.customer_id,
        'total_orders', v_stats.total_orders,
        'total_spend', v_stats.total_spend,
        'avg_order_value', ROUND(v_stats.avg_order_value, 2),
        'favorite_categories', v_stats.favorite_categories,
        'frequent_items', v_stats.frequent_items,
        'recent_items', v_stats.recent_items,
        'preferred_hour', v_stats.preferred_hour,
        'preferred_day', v_stats.preferred_day,
        'last_order_date', v_stats.last_order_date
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
