-- AI Horizon RAG Agent - Database Schema
-- Execute this in Supabase SQL Editor to create all required tables

-- Enable pgvector extension for vector similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- ================================
-- DOCUMENTS TABLE
-- ================================
CREATE TABLE IF NOT EXISTS public.documents (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  artifact_id text NOT NULL,
  title text,
  summary text,
  content text,
  source_url text,
  source_type text, -- 'pdf', 'docx', 'youtube', 'tiktok', 'csv', 'article'
  filename text,
  classification text, -- 'Replace', 'Augment', 'Remain Human', 'New Task'
  confidence double precision,
  rationale text,
  impact_score double precision,
  dcwf_task_ids text[], -- Array of DCWF task IDs
  work_roles text[], -- Array of work roles
  category text,
  tags text[],
  embedding vector(1536), -- OpenAI ada-002 embeddings
  metadata jsonb DEFAULT '{}'::jsonb,
  user_id text NOT NULL,
  chat_id text,
  username text,
  created_at timestamp without time zone DEFAULT now(),
  updated_at timestamp without time zone DEFAULT now(),
  
  CONSTRAINT documents_pkey PRIMARY KEY (id),
  CONSTRAINT documents_artifact_id_unique UNIQUE (artifact_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS documents_user_id_idx ON public.documents (user_id);
CREATE INDEX IF NOT EXISTS documents_embedding_idx ON public.documents USING ivfflat (embedding vector_cosine_ops);

-- ================================
-- CHAT MEMORY TABLE
-- ================================
CREATE TABLE IF NOT EXISTS public.chat_memory (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id text NOT NULL,
  chat_id text DEFAULT 'default_chat'::text,
  username text,
  role text, -- 'user', 'assistant', 'system'
  content text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp without time zone DEFAULT now(),
  
  CONSTRAINT chat_memory_pkey PRIMARY KEY (id)
);

-- Create indexes for chat memory
CREATE INDEX IF NOT EXISTS chat_memory_user_id_idx ON public.chat_memory (user_id);
CREATE INDEX IF NOT EXISTS chat_memory_chat_id_idx ON public.chat_memory (chat_id);