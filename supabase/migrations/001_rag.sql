-- ============================================================
-- RAG Migration: rag_documents table + vector search function
-- Supports role-based access: customer | chef | admin
-- Run in Supabase SQL Editor or via `supabase db push`
-- ============================================================

-- 1. Enable pgvector extension
create extension if not exists vector;

-- 2. RAG knowledge store
--    allowed_roles controls which roles can retrieve each document.
--    Defaults to all roles when not specified.
create table if not exists rag_documents (
  id            uuid primary key default gen_random_uuid(),
  source_table  text not null,           -- e.g. 'menu_items', 'orders'
  source_id     text not null,           -- e.g. '42:customer', '42:chef', '42:admin'
  content       text not null,           -- plaintext that was embedded
  metadata      jsonb not null default '{}',
  allowed_roles text[] not null default '{customer,chef,admin}',
  embedding     vector(768),             -- Gemini embedding-001 outputs 768 dims
  updated_at    timestamptz not null default now(),
  unique (source_table, source_id)       -- enables upsert by conflict
);

-- HNSW index for fast cosine-similarity search
create index if not exists rag_documents_embedding_idx
  on rag_documents using hnsw (embedding vector_cosine_ops);

-- Index on allowed_roles for faster role-filtered queries
create index if not exists rag_documents_roles_idx
  on rag_documents using gin (allowed_roles);

-- 3. Row Level Security
--    Enabled but NO policies — only the edge function (service_role key) can
--    read/write. Flutter clients never touch this table directly.
alter table rag_documents enable row level security;

-- 4. Role-filtered similarity search function
--    Called from the rag-chat edge function with the server-resolved role.
--    Returns documents where the caller_role is in the document's allowed_roles.
create or replace function match_rag_documents(
  query_embedding vector(768),
  match_count     int     default 8,
  caller_role     text    default 'customer'
)
returns table (id uuid, content text, metadata jsonb, similarity float)
language sql stable
as $$
  select
    d.id,
    d.content,
    d.metadata,
    1 - (d.embedding <=> query_embedding) as similarity
  from rag_documents d
  where caller_role = any (d.allowed_roles)
    and d.embedding is not null
  order by d.embedding <=> query_embedding
  limit match_count;
$$;

-- 5. Optional: profiles table for role lookup (if not already created)
--    The rag-chat edge function reads `profiles.role` to resolve user roles.
--    Create this table if it doesn't exist in your project.
create table if not exists profiles (
  id    uuid primary key references auth.users(id) on delete cascade,
  role  text not null default 'customer'
             check (role in ('customer', 'chef', 'admin')),
  created_at timestamptz not null default now()
);

-- Allow authenticated users to read their own profile
alter table profiles enable row level security;

create policy "Users can read own profile"
  on profiles for select
  to authenticated
  using (auth.uid() = id);

-- Service role can manage all profiles (for admin operations)
-- (service_role bypasses RLS automatically)

-- 6. Webhook auto re-index hint
-- After deploying rag-sync edge function, set up Database Webhooks in
-- Supabase Dashboard → Database → Webhooks:
--   • Table: menu_items  | Events: INSERT, UPDATE, DELETE
--   • Table: orders      | Events: INSERT, UPDATE, DELETE
--   • Table: order_items | Events: INSERT, UPDATE, DELETE
--   → HTTP endpoint: https://<project>.supabase.co/functions/v1/rag-sync
--   → Header: x-rag-secret = <your RAG_SYNC_SECRET>
