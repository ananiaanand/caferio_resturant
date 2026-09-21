# Flutter + Supabase role-based auth

Roles: `admin`, `kitchen`, `user`. Sign-up always creates `user`.
Reserved accounts (`admin`, `kitchen`) are seeded server-side by `supabase/schema.sql`.

## Setup
1. Create Supabase project.
2. SQL Editor -> paste + run `supabase/schema.sql`.
3. Auth -> Providers -> Email. Turn "Confirm email" OFF for dev (or keep ON and handle deep link).
4. In this folder: `flutter create .`  (generates android/ios/web folders; keeps lib/ + pubspec.yaml)
5. `flutter pub get`
6. Run:
   ```
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR-REF.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
   ```

## How it works
- Supabase Auth issues a JWT (access token) + refresh token; SDK persists + refreshes it.
- Role rides in JWT at `app_metadata.role` (server-only writable).
- `AuthGate` routes by role. UI routing is convenience only:
  real protection = Row Level Security policies in `schema.sql`.
- Add new tables? Write RLS with `public.jwt_role()`.

## Reserved logins (dev only)
| Dashboard | Email | Password |
|---|---|---|
| Kitchen | baccongeine@gmail.com | chef |
| Admin | ananiaanand@gmail.com | admin |

Change both passwords before production.
