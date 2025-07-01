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
CREATE INDEX IF NOT EXISTS documents_chat_id_idx ON public.documents (chat_id);
CREATE INDEX IF NOT EXISTS documents_source_type_idx ON public.documents (source_type);
CREATE INDEX IF NOT EXISTS documents_classification_idx ON public.documents (classification);
CREATE INDEX IF NOT EXISTS documents_created_at_idx ON public.documents (created_at);
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
CREATE INDEX IF NOT EXISTS chat_memory_created_at_idx ON public.chat_memory (created_at);

-- ================================
-- DCWF TASKS TABLE
-- ================================
CREATE TABLE IF NOT EXISTS public.dcwf_tasks (
  task_id text NOT NULL,
  task_name text NOT NULL,
  category text NOT NULL,
  description text,
  keywords text[],
  typical_roles text[],
  
  CONSTRAINT dcwf_tasks_pkey PRIMARY KEY (task_id)
);

-- Create indexes for DCWF tasks
CREATE INDEX IF NOT EXISTS dcwf_tasks_category_idx ON public.dcwf_tasks (category);
CREATE INDEX IF NOT EXISTS dcwf_tasks_keywords_idx ON public.dcwf_tasks USING gin (keywords);

-- ================================
-- DCWF DESCRIPTIONS TABLE
-- ================================
CREATE TABLE IF NOT EXISTS public.dcwf_descriptions (
  code text NOT NULL,
  category text NOT NULL,
  name text NOT NULL,
  description text NOT NULL,
  ai_impact text,
  examples text[],
  
  CONSTRAINT dcwf_descriptions_pkey PRIMARY KEY (code)
);

-- Create indexes for DCWF descriptions
CREATE INDEX IF NOT EXISTS dcwf_descriptions_category_idx ON public.dcwf_descriptions (category);

-- ================================
-- DOCUMENT PROCESSING LOG TABLE
-- ================================
CREATE TABLE IF NOT EXISTS public.document_processing_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  processing_key text NOT NULL,
  user_id text,
  filename text,
  source text,
  status text DEFAULT 'processing', -- 'processing', 'completed', 'failed'
  error_message text,
  processed_at timestamp without time zone DEFAULT now(),
  
  CONSTRAINT document_processing_log_pkey PRIMARY KEY (id),
  CONSTRAINT document_processing_log_processing_key_unique UNIQUE (processing_key)
);

-- Create indexes for processing log
CREATE INDEX IF NOT EXISTS document_processing_log_user_id_idx ON public.document_processing_log (user_id);
CREATE INDEX IF NOT EXISTS document_processing_log_status_idx ON public.document_processing_log (status);
CREATE INDEX IF NOT EXISTS document_processing_log_processed_at_idx ON public.document_processing_log (processed_at);

-- ================================
-- ROW LEVEL SECURITY (RLS)
-- ================================

-- Enable RLS on documents table
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own documents
CREATE POLICY "Users can view own documents" ON public.documents
  FOR SELECT USING (auth.uid()::text = user_id OR user_id = 'system');

-- Policy: Users can insert their own documents
CREATE POLICY "Users can insert own documents" ON public.documents
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- Policy: Users can update their own documents
CREATE POLICY "Users can update own documents" ON public.documents
  FOR UPDATE USING (auth.uid()::text = user_id);

-- Enable RLS on chat_memory table
ALTER TABLE public.chat_memory ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own chat history
CREATE POLICY "Users can view own chat history" ON public.chat_memory
  FOR SELECT USING (auth.uid()::text = user_id);

-- Policy: Users can insert their own chat messages
CREATE POLICY "Users can insert own chat messages" ON public.chat_memory
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);

-- ================================
-- TRIGGERS FOR UPDATED_AT
-- ================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for documents table
CREATE TRIGGER update_documents_updated_at 
  BEFORE UPDATE ON public.documents 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================
-- COMMENTS FOR DOCUMENTATION
-- ================================

COMMENT ON TABLE public.documents IS 'Stores processed documents with AI classifications and vector embeddings';
COMMENT ON COLUMN public.documents.embedding IS 'Vector embedding for semantic similarity search (1536 dimensions for OpenAI ada-002)';
COMMENT ON COLUMN public.documents.classification IS 'AI impact classification: Replace, Augment, Remain Human, or New Task';
COMMENT ON COLUMN public.documents.dcwf_task_ids IS 'Array of DCWF task IDs that this document relates to';

COMMENT ON TABLE public.chat_memory IS 'Stores conversation history for contextual chat responses';
COMMENT ON TABLE public.dcwf_tasks IS 'Reference table for Department of Homeland Security Cybersecurity Workforce Framework tasks';
COMMENT ON TABLE public.document_processing_log IS 'Tracks document processing status to prevent duplicates and enable monitoring';