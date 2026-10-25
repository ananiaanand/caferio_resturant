# RAG Integration — Caferio Restaurant App

## Architecture Overview

```
Customer  →  CustomerChatSheet  →  rag-chat (edge fn)  →  pgvector  →  Gemini AI
                                        ↕ role resolved server-side
Chef      →  StaffChatSheet     →  rag-chat (edge fn)  →  pgvector  →  Gemini AI
                                        ↕ (chef scope: orders+menu, no prices)
Admin     →  StaffChatSheet     →  rag-chat (edge fn)  →  pgvector  →  Gemini AI
                                        ↕ (admin scope: full access)
```

## Role-based access control

| Role     | Menu items | Orders (chef view) | Orders (admin view) | Revenue/Prices |
|----------|-----------|-------------------|--------------------|-|
| customer | ✅ (name, desc, price, availability) | ❌ | ❌ | Menu prices only |
| chef     | ✅ + ingredients/prep time | ✅ | ❌ | ❌ |
| admin    | ✅ full | ✅ | ✅ + customer + payment | ✅ |

Role is **always resolved server-side** from the `profiles.role` column.
The Flutter app never sends a role claim. The edge function ignores any client-provided role.

---

## Deployment Steps

### 1. Run DB Migration

In **Supabase Dashboard → SQL Editor**, run:
```
supabase/migrations/001_rag.sql
```

This creates:
- `rag_documents` table with `vector(768)` embeddings
- `match_rag_documents()` RPC function (role-filtered)
- `profiles` table for role lookup (if not already present)
- Appropriate RLS policies

### 2. Set Edge Function Secrets

```bash
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
supabase secrets set RAG_SYNC_SECRET=some_long_random_secret_string
```

### 3. Deploy Edge Functions

```bash
supabase functions deploy rag-sync --no-verify-jwt
supabase functions deploy rag-chat
```

### 4. Initial Data Index (Full Re-index)

```bash
curl -X POST https://<project-ref>.supabase.co/functions/v1/rag-sync \
  -H "x-rag-secret: <your RAG_SYNC_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{"mode":"full"}'
```

This embeds all existing menu items and orders into the vector store.

### 5. Set Up Auto-Sync Webhooks

In **Supabase Dashboard → Database → Webhooks**, create webhooks for:

| Table | Events | Function | Header |
|-------|--------|----------|--------|
| `menu_items` | INSERT, UPDATE, DELETE | `rag-sync` | `x-rag-secret: <secret>` |
| `orders` | INSERT, UPDATE, DELETE | `rag-sync` | `x-rag-secret: <secret>` |
| `order_items` | INSERT, UPDATE, DELETE | `rag-sync` | `x-rag-secret: <secret>` |

### 6. Set Up User Roles

For chef and admin access, insert rows into the `profiles` table:
```sql
-- Make a user an admin
INSERT INTO profiles (id, role) VALUES ('<user-uuid>', 'admin')
ON CONFLICT (id) DO UPDATE SET role = 'admin';

-- Make a user a chef
INSERT INTO profiles (id, role) VALUES ('<user-uuid>', 'chef')
ON CONFLICT (id) DO UPDATE SET role = 'chef');
```

Unauthenticated users and users not in `profiles` automatically get the `customer` role.

---

## Flutter Integration

### Customer AI Chatbot
- **Location**: `DashboardScreen` (bottom-right FAB)
- **Widget**: `CustomerChatFab` → opens `CustomerChatSheet`
- **Access**: Public (no auth required)
- **Capabilities**: Menu browsing, prices, availability, dietary info

### Chef AI Assistant
- **Location**: `KitchenLayout` (floating action button, all screens)
- **Widget**: `StaffChatFab(role: ChatRole.chef)` → opens `StaffChatSheet`
- **Access**: Authenticated chef users
- **Capabilities**: Pending orders, prep notes, allergens, ingredients

### Admin AI Assistant
- **Location**: `AdminLayout` (floating action button, all screens)
- **Widget**: `StaffChatFab(role: ChatRole.admin)` → opens `StaffChatSheet`
- **Access**: Authenticated admin users
- **Capabilities**: Full data — sales, revenue, orders, stock, menu management

---

## File Structure

```
lib/
  services/
    rag_service.dart          # Supabase functions.invoke wrapper
  widgets/
    customer_chat_widget.dart # Customer-facing chat UI (FAB + sheet)
    staff_chat_widget.dart    # Chef/Admin internal assistant UI

supabase/
  migrations/
    001_rag.sql               # DB migration (pgvector + RLS)
  functions/
    _shared/
      gemini.ts               # Gemini embed + generate helpers
    rag-chat/
      index.ts                # Chat edge function (role resolution + retrieval)
    rag-sync/
      index.ts                # Sync edge function (embed + upsert documents)
```
