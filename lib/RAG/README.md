# RAG setup (Supabase + Gemini + Flutter)

## 1. DB
Run `supabase/migrations/001_rag.sql` in SQL editor (or `supabase db push`).

## 2. Secrets (Gemini key stays server-side)
```
supabase secrets set GEMINI_API_KEY=your_key
supabase secrets set RAG_SYNC_SECRET=some_long_random_string
```

## 3. Deploy functions
```
supabase functions deploy rag-sync --no-verify-jwt
supabase functions deploy rag-chat
```

## 4. First index (all existing data)
```
curl -X POST https://<project-ref>.supabase.co/functions/v1/rag-sync \
  -H "x-rag-secret: <RAG_SYNC_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{"mode":"full"}'
```

## 5. Auto re-index
Dashboard > Database > Webhooks. Create webhook for `menu_items`, `orders`, `order_items`
(Insert, Update, Delete) -> Supabase Edge Function `rag-sync`, add HTTP header `x-rag-secret`.

## 6. Flutter
Copy `lib/services/rag_service.dart` and `lib/widgets/rag_chat_sheet.dart`.
`pubspec.yaml`: `supabase_flutter` already needed.
Add FAB with `RagChatSheet.show(context)` in chef + admin dashboards.

## Adjust to your schema
- `rag-sync/index.ts`: builders `menuDocs`, `orderDocs` (table + column names are guesses)
- `rag-chat/index.ts`: `profiles.role` lookup
