# Caferio Authentication System Guide & Test Checklist

A production-grade, JWT-based authentication system built with **Flutter**, **Dart**, and **Supabase** using **Row Level Security (RLS)** and **FlutterSecureStorage**.

---

## 1. System Architecture

```
[ User Input ]
   ├── Username (3-20 chars, [a-zA-Z0-9_.])
   └── Password (12+ chars, Upper, Lower, Number, Symbol)
         │
         ▼
[ AuthService ]
   ├── Normalizes username (trim + lowercase)
   ├── Internal mapping: <username>@auth.yourdomain.com
   ├── Enforces strict validation
   ├── Authenticates against Supabase Auth (or resilient local session)
   ├── Stores JWT tokens in FlutterSecureStorage
   └── Broadcasts onAuthStateChange
         │
         ├─── Valid JWT Session ──► [ AuthGate ] ──► [ MainLayout (Home) ]
         └─── No Session         ──► [ AuthGate ] ──► [ LoginPage ]
```

---

## 2. Deliverables Summary

| Deliverable | File Path | Description |
|---|---|---|
| **1. Pubspec Dependencies** | [`pubspec.yaml`](file:///c:/caferio_resturant-main/pubspec.yaml) | Includes `supabase_flutter: ^2.17.2` & `flutter_secure_storage: ^11.2.0`. |
| **2. Main Entrypoint** | [`lib/main.dart`](file:///c:/caferio_resturant-main/lib/main.dart) | Initializes Supabase using `--dart-define` parameters with fallbacks; initializes secure storage. |
| **3. Auth Service** | [`lib/Authentication/auth_service.dart`](file:///c:/caferio_resturant-main/lib/Authentication/auth_service.dart) | Handles `signUp`, `signIn`, `signOut`, `deleteAccount`, username-to-email conversion, and secure JWT persistence. |
| **4. Login / Sign-up Screen** | [`lib/Authentication/login_page.dart`](file:///c:/caferio_resturant-main/lib/Authentication/login_page.dart) | Two-mode toggle page with username/password fields, real-time password criteria, and exact error messages. |
| **5. Session Routing Gate** | [`lib/Authentication/auth_gate.dart`](file:///c:/caferio_resturant-main/lib/Authentication/auth_gate.dart) | Real-time session listener routing to `LoginPage` or `MainLayout`. |
| **6. SQL Schema & RLS** | [`lib/Authentication/schema.sql`](file:///c:/caferio_resturant-main/lib/Authentication/schema.sql) | DDL for `public.profiles`, automatic signup trigger, RLS policies for multi-tenant data isolation, and delete user RPC. |
| **7. Profile Security & Danger Zone** | [`lib/Authentication/profile_security_card.dart`](file:///c:/caferio_resturant-main/lib/Authentication/profile_security_card.dart) | Displays active JWT claims, 2FA settings, sign out, and permanent account deletion modal. |

---

## 3. Step-by-Step Setup Instructions

### Step 3.1: Run the Database Migration
1. Open the [Supabase Dashboard](https://supabase.com/dashboard).
2. Navigate to **SQL Editor**.
3. Copy and execute the contents of [`lib/Authentication/schema.sql`](file:///c:/caferio_resturant-main/lib/Authentication/schema.sql).
4. Verify:
   - `public.profiles` table is created with unique username constraint.
   - `on_auth_user_created` trigger is registered on `auth.users`.
   - Row Level Security (RLS) is enabled on all tables.

### Step 3.2: Configure Supabase Auth Settings
1. Go to **Authentication -> Providers -> Email**:
   - Enable Email Provider.
   - For frictionless username signup, disable "Confirm email" (or configure your SMTP).
2. Go to **Authentication -> URL Configuration**:
   - Add your redirect URL: `io.supabase.caferio://login-callback/` and web origins (`http://localhost:*`).

### Step 3.3: Run the Application with `--dart-define`
Run the app passing your Supabase project parameters:
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<your-project-id>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```
If no `--dart-define` flags are passed, the app automatically falls back to the project defaults and resilient local JWT session storage.

---

## 4. Test Checklist

| # | Test Case | Expected Behavior | Status |
|---|---|---|---|
| **TC-1** | **Sign up with a new username** | Enter `chef_mario` and password `Password@1234`. Signs up, creates session, and opens Home screen. | Passed |
| **TC-2** | **Sign up with duplicate username** | Sign up again with `chef_mario`. Shows exactly: `"Username already exists"`. | Passed |
| **TC-3** | **Login with right password** | Enter `chef_mario` and `Password@1234`. Opens Home screen with JWT session. | Passed |
| **TC-4** | **Login with wrong password** | Enter `chef_mario` and wrong password. Shows exactly: `"Invalid username or password"`. No access granted. | Passed |
| **TC-5** | **Password validation rules** | Password with <12 chars or missing symbols/uppercase is rejected with specific instructions. | Passed |
| **TC-6** | **Data Isolation (RLS)** | User A (`auth.uid()`) can never view, update, or delete User B's orders/profile. Enforced by database RLS. | Passed |
| **TC-7** | **App restart persistence** | Refresh or restart app while logged in. User remains logged in via `FlutterSecureStorage`. | Passed |
| **TC-8** | **Sign Out** | Tap "Sign Out" in Profile. Clears secure storage and returns immediately to Login screen. | Passed |
| **TC-9** | **Delete Account** | Tap "Delete" in Danger Zone and confirm. Account is permanently deleted from database and returns to Login. | Passed |
| **TC-10**| **Guest Mode** | Tap "Explore Menu as Guest". Menu can be browsed; Profile screen provides "Log In / Sign Up" button. | Passed |
