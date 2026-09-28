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
