-- 1. pgvector
create extension if not exists vector;

-- 2. knowledge store (768 dims = Gemini embedding outputDimensionality)
create table if not exists rag_documents (
  id            uuid primary key default gen_random_uuid(),
  source_table  text not null,
  source_id     text not null,
  content       text not null,
  metadata      jsonb not null default '{}',
  allowed_roles text[] not null default '{admin,chef}',
  embedding     vector(768),
  updated_at    timestamptz not null default now(),
  unique (source_table, source_id)
);

create index if not exists rag_documents_embedding_idx
  on rag_documents using hnsw (embedding vector_cosine_ops);

-- RLS on, NO policies: only the edge function (service role) can touch it.
alter table rag_documents enable row level security;

-- 3. similarity search, filtered by caller role
create or replace function match_rag_documents(
  query_embedding vector(768),
  match_count     int default 8,
  caller_role     text default 'admin'
)
returns table (id uuid, content text, metadata jsonb, similarity float)
language sql stable
as $$
  select d.id, d.content, d.metadata,
         1 - (d.embedding <=> query_embedding) as similarity
  from rag_documents d
  where caller_role = any (d.allowed_roles)
    and d.embedding is not null
  order by d.embedding <=> query_embedding
  limit match_count;
$$;

-- 4. OPTIONAL: auto re-index on change via Database Webhooks
-- Dashboard > Database > Webhooks > create webhook on tables
--   menu_items, orders (INSERT, UPDATE, DELETE)
--   -> Supabase Edge Function: rag-sync
--   -> header: x-rag-secret = <your RAG_SYNC_SECRET>
