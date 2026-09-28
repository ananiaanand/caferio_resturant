# Caferio — Backend Authentication (Supabase Auth + PostgreSQL + RLS)

Replaces the old username→`name@myapp.app` scheme. **Supabase Auth still owns passwords and sessions.**
No password column, no manual hashing, no custom tokens, no service-role key in the app.

## 1. Architecture (decision)

```
Flutter ──username+password──▶ Edge Function (auth-login / auth-register)      [TLS]
                                   │  rate-limit → validate → resolve username → private alias
                                   ▼
                          Supabase Auth (GoTrue)  ◀── verifies bcrypt password, issues JWT + refresh token
                                   │
Flutter ◀── session (access+refresh token) ── adopted with auth.setSession() → normal supabase_flutter session
```

* Each account has an **internal alias e-mail**: `u<128 random bits>@ALIAS_DOMAIN`. It is random (not derived from the
  username), stored only in `auth.users`, never sent to the client, never mailed. The `username → alias` lookup is a
  `SECURITY DEFINER` function callable **only by `service_role`** (i.e. only by the Edge Functions).
* Why not `username@domain` (old design)? Predictable ⇒ anyone can hit Supabase's public `/token` endpoint directly and
  brute-force a known account, bypassing app-side limits. Migration 3 rotates every legacy alias.
* Why an Edge Function and not a client-callable RPC? An anonymous "username → email" RPC is a username-enumeration
  and identity-leak oracle. Here nothing about identity is ever anonymously callable.
* Self-signup through GoTrue is blocked **in the database** (`BEFORE INSERT` trigger on `auth.users` demands a flag only
  the service role can set), so even a misconfigured dashboard can't open registration.
* Profile row is created by an `AFTER INSERT` trigger **in the same transaction** as the auth user ⇒ atomic. Profile
  failure (e.g. lost race on the unique index) rolls back the auth user: no orphans either way.

## 2. What's in the box

| Path | Purpose |
|---|---|
| `supabase/migrations/…0001_auth_core.sql` | profiles (+username rules/uniqueness), triggers, role guard, RLS, service-only RPCs, legacy clean-up |
| `supabase/migrations/…0002_data_rls_hardening.sql` | closes `USING (true)` on orders etc., fixes IDOR in recommendation RPCs |
| `supabase/migrations/…0003_rotate_legacy_aliases.sql` | replaces guessable `@myapp.app` aliases with random ones |
| `supabase/APPLY_ALL.sql` | the three above concatenated (paste into SQL editor) |
| `supabase/functions/auth-{login,register,change-password,admin-reset-password}` | Edge Functions |
| `supabase/functions/_shared/` | `validation.ts`, `handlers.ts` (all logic), `deps.ts` (real supabase-js wiring) |
| `supabase/config.toml` | auth settings to merge |
| `lib/services/auth_service.dart` | **drop-in replacement** for your `lib/services/auth_service.dart` |
| `tests/` | 48 SQL/RLS tests + 22 end-to-end handler tests + `scripts/smoke.sh` for the live project |

## 3. Deploy (in this order)

1. **Back up** (Dashboard → Database → Backups). The migrations reset self-assigned roles and ban weak privileged accounts (see §6).
2. **Pick the alias domain.** Default `caferio-auth.invalid` (can never belong to anyone). If registration later fails with
   `email_address_invalid`, GoTrue is validating the domain: use one you own (`auth.yourdomain.com`) and use the **same** value in step 3 and in
   `select set_config('caferio.alias_domain','auth.yourdomain.com',false);` before running migration 3.
3. **SQL:** run `supabase/APPLY_ALL.sql` in the SQL editor (or `supabase db push`). Re-running is safe.
4. **Dashboard → Authentication:**
   * Providers → Email: **on**, "Confirm email" **off**. *Sign-ups:* **disable "Allow new users to sign up"**. Anonymous sign-ins **off**.
   * Sessions: JWT expiry 3600, refresh-token rotation **on**, reuse interval 10 s. (Optional: time-box / inactivity timeout on paid plans.)
   * Password: minimum length 8.
   * Rate limits: keep defaults (they protect `/token` too).
   * URL config: leave as is (no e-mail links are used).
5. **Functions:**
   ```bash
   supabase secrets set ALIAS_DOMAIN=caferio-auth.invalid         # same value as step 2
   supabase functions deploy auth-login auth-register auth-change-password auth-admin-reset-password --no-verify-jwt
   ```
   `SUPABASE_URL / ANON_KEY / SERVICE_ROLE_KEY` are injected by Supabase; **never** put the service-role key in Flutter, git or a `.env` you ship.
6. **First admin** (SQL editor only, cannot be called by any client):
   ```sql
   -- 1) register normally in the app as e.g. "owner_cafe", then:
   select private.bootstrap_set_role('owner_cafe', 'admin');
   -- kitchen / manager staff: an admin uses the app (calls admin_set_user_role) or SQL:
   select private.bootstrap_set_role('somechef', 'kitchen');
   ```
   Legacy `admin` / `chef` accounts were seeded with password = username; the migration **banned** them. Reset with:
   `AuthService().adminResetPassword(username: 'chef', newPassword: '…', unban: true)` (signed in as an admin), or delete them.
7. **Flutter:** replace `lib/services/auth_service.dart` with the provided one. Screens/AuthGate compile unchanged.
   **One UI fix needed** (I was told not to touch UI): `lib/screens/profile_screen.dart` line ~60 shows `currentUser?.email`, which is now the internal alias.
   Show `AuthService().username` instead.
8. **Verify live:** `SUPABASE_URL=… SUPABASE_ANON_KEY=… ./scripts/smoke.sh`

## 4. Flows

* **Register** → normalize/validate (client + server + DB) → rate-limit (10/h/IP) → availability pre-check (UX only) → `admin.createUser`
  (pre-confirmed, `app_metadata.caferio_provisioned`) → DB triggers create profile atomically → password grant → session.
  Duplicate/concurrent → unique index `profiles_username_normalized_key` decides; loser gets `409 username_taken`, no orphan.
* **Login** → 3 limiters (IP 40/10 min, user+IP 8/15 min, user 60/h) → resolve alias → Supabase password grant → session only.
  Wrong password, unknown user, malformed input, banned account: **byte-identical 401**. Unknown users still cost a bcrypt round.
* **Logout / persistence / refresh / expiry / auth events**: 100 % `supabase_flutter` (`signOut`, persisted session, auto-refresh, `onAuthStateChange`).
* **Change password** (signed-in): validates token with GoTrue, re-verifies current password, sets new one, **revokes all other sessions**.
* **Password reset (forgot password)**: there is deliberately no e-mail, so no self-service reset. Options: (a) admin reset function (implemented; also revokes sessions),
  (b) later, add an optional real recovery e-mail on the profile. Do **not** use the alias for mail.
* **Roles**: `profiles.role` is the only authority. RLS/functions read it from the table, never from a JWT claim. Clients cannot write it
  (column grants + trigger). It's mirrored to `app_metadata.role` only so `AuthGate` can route; it refreshes at the next token refresh.
  Promote via `admin_set_user_role` (admin-only RPC) or `private.bootstrap_set_role` (SQL editor).
* **Account deletion** → `ON DELETE CASCADE` removes profile, purchases, stats; orders keep history with `customer_id = NULL`.

## 5. Username rules (enforced in Flutter, Edge Function **and** PostgreSQL)

3–30 chars, ASCII letters/digits/`_`/`-`, must start and end with letter/digit, case-insensitive uniqueness, reserved names blocked at signup
(`admin`, `root`, `support`, …). DB constraints: `UNIQUE(username_normalized)`, format `CHECK`, `username`≡`username_normalized` up to case, ASCII-only display form
(blocks e.g. KELVIN SIGN `K`). Username is **immutable** (guard trigger + no column grant).

## 6. Security review — findings in the original project and what changed

| # | Finding in the uploaded project | Severity | Fix |
|---|---|---|---|
| 1 | Predictable alias `username@myapp.app`; direct `/token` brute force possible | High | random 128-bit aliases, lookup service-only (mig. 1 + 3) |
| 2 | `orders`, `order_items`: `USING (true) WITH CHECK (true)` → anyone with the public anon key could read/alter/delete every order | Critical | owner/staff RLS + column grants (mig. 2) |
| 3 | `customer_purchases`, `customer_behaviour_stats`, `sales`, `ingredients`, `users`(with e-mail column): **RLS off** | High | RLS on, own-row / staff-only |
| 4 | Recommendation RPCs `SECURITY DEFINER` trusting `p_customer_id` (IDOR: read/write any customer) | High | wrapper enforces `p_customer_id = auth.uid()`; impls locked down |
| 5 | "Users can update own profile" policy with no column limits → any user could set `role='admin'` (reproduced in my legacy test DB) | Critical | column-level grants + guard trigger; roles reconciled (a self-promoted `mallory` was reset to customer in the test) |
| 6 | `auth.user_role()` read role from `user_metadata` (client-writable) | High | dropped; RLS reads `profiles.role` |
| 7 | `get_user_role(uuid)` callable by anon for any UUID | Medium | dropped |
| 8 | Seeded `admin`/`chef` with password = username | Critical | banned + sessions revoked; reset via admin function |
| 9 | Signup open at GoTrue level; `handle_new_user` accepted `role` from `raw_user_meta_data` | Critical | signup blocked in DB; role always `customer` |
| 10 | Client-side-only lockout (bypassable) | Medium | server-side DB-backed limiters |
| 11 | `profiles.email` column duplicated identity | Low | dropped |
| 12 | SECURITY DEFINER functions without pinned `search_path` | Medium | all pinned (test asserts it) |
| 13 | **Your zip contains `.dart_tool/chrome-device/…/leveldb` with real signed-in JWTs / refresh tokens** | High (if shared) | delete `.dart_tool`, `build/`; treat those sessions as compromised — change those passwords / sign out everywhere |

Also checked: no service-role key or `sb_secret_` anywhere in the repo (only the public anon key in `main.dart`, which is designed to be public).

## 7. Tests — what ran and what did not

Ran here (PostgreSQL 16 + Deno 2.9), **all green**:
* `tests/test_db.py` — 48 tests against a database built from your **original scripts + dirty data** (self-promoted admin, weak seeded admins, Dave/dave collision, invalid legacy names), then the 3 migrations, twice (idempotency). Covers registration constraints, duplicate/case, malformed usernames, RLS per role, IDOR, escalation, column grants, forged JWT claims, service-only RPCs, rate limiter, cascade, orphan checks, a 2-connection race, and audits (RLS everywhere, no `USING(true)`, no anon grants, pinned `search_path`, no password columns).
* `tests/handlers_test.ts` — 22 end-to-end tests of the real handler code on the real DB: register/login/change-password/admin-reset, enumeration parity, injection strings, 20-way parallel registration, brute-force lockout (and that an attacker elsewhere can't lock out the victim), forged-role JWT, session revocation.
* Also: `deno check` on all four functions; fresh-install path.

**Not run (be aware):**
* **Real GoTrue.** Handler tests use a faithful *fake* of GoTrue's password grant/`createUser`/`updateUserById`. Run `scripts/smoke.sh` against your project — it is the one-command proof (registers, duplicate, login, wrong pw, closed signup, role self-update denied). Points to watch: alias-domain validation (§3.2) and the exact error shape GoTrue returns when a DB trigger rejects an insert (the code treats any create failure as "re-check availability, else 500", so it is safe either way).
* **Dart**: `auth_service.dart` was written against the `supabase_flutter ^2.x` API but not compiled here (no Flutter SDK). Run `flutter analyze`.
* Load/pen-testing, and the Realtime `orders` channel (RLS applies to it, but not exercised here).

## 8. Known limits / choices

* Rate limits use the client IP header set by Supabase's edge (`cf-connecting-ip` / `x-forwarded-for`); behind your own proxy, make sure it can't be spoofed.
* No self-service forgot-password (by design, §4). Users who forget it need an admin.
* `orders_insert_own` forces `status='received'`; kitchen/manager/admin advance status (matches the app). Adjust if your kitchen role differs.
* Role change reaches the JWT-based UI routing at the next token refresh (≤ 1 h) — authorization itself is immediate (DB).
* `ALIAS_DOMAIN` must never change after users exist, unless you re-run the rotation (aliases are stored, so old ones keep working; changing only affects new users).
