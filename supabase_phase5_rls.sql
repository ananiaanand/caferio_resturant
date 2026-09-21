-- =============================================================================
-- CAFERIO: Phase 5 Row Level Security (RLS) Setup
-- =============================================================================

-- 1. Helper functions to avoid infinite recursion in RLS policies
CREATE OR REPLACE FUNCTION auth.user_role() RETURNS text AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json->'user_metadata'->>'role',
    'customer'
  );
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION auth.user_restaurant_id() RETURNS uuid AS $$
  SELECT (current_setting('request.jwt.claims', true)::json->'user_metadata'->>'restaurant_id')::uuid;
$$ LANGUAGE SQL STABLE;

-- Alternative: look up directly from profiles table, but using a security definer function to bypass RLS
CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid) RETURNS public.user_role AS $$
DECLARE
  v_role public.user_role;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = user_id;
  RETURN COALESCE(v_role, 'customer'::public.user_role);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_user_restaurant_id(user_id uuid) RETURNS uuid AS $$
DECLARE
  v_rest_id uuid;
BEGIN
  SELECT restaurant_id INTO v_rest_id FROM public.profiles WHERE id = user_id;
  RETURN v_rest_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- 2. RLS for Profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can do everything to profiles" ON public.profiles;
DROP POLICY IF EXISTS "Managers can read profiles of their restaurant" ON public.profiles;
DROP POLICY IF EXISTS "Managers can update profiles of their restaurant" ON public.profiles;

CREATE POLICY "Users can read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can do everything to profiles" ON public.profiles
  FOR ALL USING (public.get_user_role(auth.uid()) = 'admin'::public.user_role);

CREATE POLICY "Managers can read profiles of their restaurant" ON public.profiles
  FOR SELECT USING (
    public.get_user_role(auth.uid()) = 'manager'::public.user_role 
    AND restaurant_id = public.get_user_restaurant_id(auth.uid())
  );

CREATE POLICY "Managers can update profiles of their restaurant" ON public.profiles
  FOR UPDATE USING (
    public.get_user_role(auth.uid()) = 'manager'::public.user_role 
    AND restaurant_id = public.get_user_restaurant_id(auth.uid())
  );

-- 3. RLS for Restaurants
ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read restaurants" ON public.restaurants;
DROP POLICY IF EXISTS "Admins can do everything to restaurants" ON public.restaurants;
DROP POLICY IF EXISTS "Managers can update their own restaurant" ON public.restaurants;

-- For this app, usually anyone (or authenticated users) can view restaurants to place an order
CREATE POLICY "Anyone can read restaurants" ON public.restaurants
  FOR SELECT USING (true);

CREATE POLICY "Admins can do everything to restaurants" ON public.restaurants
  FOR ALL USING (public.get_user_role(auth.uid()) = 'admin'::public.user_role);

CREATE POLICY "Managers can update their own restaurant" ON public.restaurants
  FOR UPDATE USING (
    public.get_user_role(auth.uid()) = 'manager'::public.user_role 
    AND id = public.get_user_restaurant_id(auth.uid())
  );

-- =============================================================================
-- RLS setup complete
-- =============================================================================
