-- Run this in your Supabase SQL Editor to delete all tables in the public schema except 'profiles'

DO $$ 
DECLARE
  r RECORD;
BEGIN
  -- Loop through all tables in the public schema that are not named 'profiles'
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename != 'profiles') 
  LOOP
    -- Execute the drop table command for each matching table
    EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;

-- Create tables

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL
);

CREATE TABLE restaurants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL
);

CREATE TABLE menu_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price NUMERIC NOT NULL,
  category TEXT
);

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL,
  total_amount NUMERIC NOT NULL DEFAULT 0
);

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  menu_item_id UUID REFERENCES menu_items(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE ingredients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  current_stock NUMERIC NOT NULL DEFAULT 0
);

CREATE TABLE ingredient_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id UUID REFERENCES ingredients(id) ON DELETE CASCADE,
  quantity_used NUMERIC NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id UUID REFERENCES restaurants(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

-- Recommendation System Tables & RPC Functions
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

CREATE TABLE IF NOT EXISTS customer_behaviour_stats (
  customer_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  total_orders INTEGER NOT NULL DEFAULT 0,
  total_spend NUMERIC NOT NULL DEFAULT 0,
  avg_order_value NUMERIC NOT NULL DEFAULT 0,
  favorite_categories JSONB NOT NULL DEFAULT '{}'::jsonb,
  frequent_items JSONB NOT NULL DEFAULT '{}'::jsonb,
  recent_items JSONB NOT NULL DEFAULT '[]'::jsonb,
  preferred_hour INTEGER DEFAULT NULL,
  preferred_day INTEGER DEFAULT NULL,
  last_order_date TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc', now())
);

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

